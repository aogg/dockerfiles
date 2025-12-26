package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"sync"
	"time"
)

// ==================== MCP SSE Protocol Implementation ====================

// MCPMessage represents a standard MCP JSON-RPC message
type MCPMessage struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      interface{}     `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  interface{}     `json:"result,omitempty"`
	Error   *MCPError       `json:"error,omitempty"`
}

// MCPError represents an MCP protocol error
type MCPError struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data,omitempty"`
}

// MCPTool represents a tool definition in MCP
type MCPTool struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	InputSchema map[string]interface{} `json:"inputSchema"`
}

// MCPToolCallResult represents the result of a tool execution
type MCPToolCallResult struct {
	Content []MCPContent `json:"content"`
	IsError bool         `json:"isError,omitempty"`
}

// MCPContent represents content returned by a tool
type MCPContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// SSEConnection manages an SSE connection
type SSEConnection struct {
	writer  http.ResponseWriter
	flusher http.Flusher
	mu      sync.Mutex
	closed  bool
}

func (sse *SSEConnection) WriteEvent(eventType, data string) error {
	sse.mu.Lock()
	defer sse.mu.Unlock()

	if sse.closed {
		return fmt.Errorf("SSE connection closed")
	}

	fmt.Fprintf(sse.writer, "event: %s\n", eventType)
	fmt.Fprintf(sse.writer, "data: %s\n\n", data)
	sse.flusher.Flush()
	return nil
}

func (sse *SSEConnection) Close() {
	sse.mu.Lock()
	defer sse.mu.Unlock()
	sse.closed = true
}

// Global SSE connection manager
var (
	sseConnections     = make(map[string]*SSEConnection)
	sseConnectionsLock sync.RWMutex
)

// MCPHandler manages MCP protocol handling
type MCPHandler struct {
	tools map[string]func(map[string]interface{}) MCPToolCallResult
}

func NewMCPHandler() *MCPHandler {
	h := &MCPHandler{
		tools: make(map[string]func(map[string]interface{}) MCPToolCallResult),
	}
	h.registerTools()
	return h
}

func (h *MCPHandler) registerTools() {
	h.tools["execute_shell"] = h.executeShellCommand
}

func (h *MCPHandler) executeShellCommand(params map[string]interface{}) MCPToolCallResult {
	cmd, ok := params["command"].(string)
	if !ok || cmd == "" {
		return MCPToolCallResult{
			Content: []MCPContent{
				{Type: "text", Text: "错误: 缺少 'command' 参数"},
			},
			IsError: true,
		}
	}

	var stdout, stderr strings.Builder
	var exitCode int

	cmdExec := exec.Command("sh", "-c", cmd)
	cmdExec.Stdout = &stdout
	cmdExec.Stderr = &stderr

	err := cmdExec.Run()
	if err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			exitCode = exitErr.ExitCode()
		}
	}

	result := stdout.String() + stderr.String()
	return MCPToolCallResult{
		Content: []MCPContent{
			{Type: "text", Text: result},
		},
		IsError: exitCode != 0,
	}
}

func (h *MCPHandler) HandleToolsList() map[string]interface{} {
	tool := MCPTool{
		Name:        "execute_shell",
		Description: "Execute a shell command and return the output",
		InputSchema: map[string]interface{}{
			"type": "object",
			"properties": map[string]interface{}{
				"command": map[string]interface{}{
					"type":        "string",
					"description": "The shell command to execute",
				},
			},
			"required": []string{"command"},
		},
	}

	return map[string]interface{}{
		"tools": []MCPTool{tool},
	}
}

func (h *MCPHandler) HandleToolCall(params map[string]interface{}) MCPToolCallResult {
	name, ok := params["name"].(string)
	if !ok {
		return MCPToolCallResult{
			Content: []MCPContent{
				{Type: "text", Text: "错误: 缺少 'name' 参数"},
			},
			IsError: true,
		}
	}

	arguments := make(map[string]interface{})
	if args, ok := params["arguments"].(map[string]interface{}); ok {
		arguments = args
	}

	if toolFunc, exists := h.tools[name]; exists {
		return toolFunc(arguments)
	}

	return MCPToolCallResult{
		Content: []MCPContent{
			{Type: "text", Text: fmt.Sprintf("错误: 未找到工具 '%s'", name)},
		},
		IsError: true,
	}
}

func mcpSSEHandler(w http.ResponseWriter, r *http.Request) {
	clientID := r.RemoteAddr + ":" + time.Now().Format("20060102150405")
	log.Printf("[SSE] 新连接 %s 来自: %s, Method: %s", clientID, r.RemoteAddr, r.Method)

	// POST requests handle JSON-RPC commands
	if r.Method == "POST" {
		mcpRequestHandler(w, r)
		return
	}

	// GET requests establish SSE connection
	if r.Method != "GET" {
		log.Printf("[SSE] 错误: 客户端 %s 使用了错误的 HTTP 方法: %s", clientID, r.Method)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Check for SSE support
	flusher, ok := w.(http.Flusher)
	if !ok {
		log.Printf("[SSE] 错误: 客户端 %s 不支持 SSE", clientID)
		http.Error(w, "SSE not supported", http.StatusInternalServerError)
		return
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	log.Printf("[SSE] 客户端 %s: SSE 响应头已设置", clientID)

	sse := &SSEConnection{
		writer:  w,
		flusher: flusher,
	}

	// Register connection
	sseConnectionsLock.Lock()
	sseConnections[clientID] = sse
	sseConnectionsLock.Unlock()

	// Clean up on disconnect
	defer func() {
		sse.Close()
		sseConnectionsLock.Lock()
		delete(sseConnections, clientID)
		sseConnectionsLock.Unlock()
		log.Printf("[SSE] 客户端 %s: 已断开连接", clientID)
	}()

	// Send endpoint notification
	endpointMsg, _ := json.Marshal(map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  "notifications/endpoint",
		"params": map[string]interface{}{
			"endpoint": "/mcp",
		},
	})
	sse.WriteEvent("endpoint", string(endpointMsg))
	log.Printf("[SSE] 客户端 %s: 已发送 endpoint 通知", clientID)

	// Wait for disconnect (SSE is server-push only)
	notify := r.Context().Done()
	<-notify
	log.Printf("[SSE] 客户端 %s: 上下文已关闭", clientID)
}

// mcpRequestHandler handles POST requests for MCP commands
func mcpRequestHandler(w http.ResponseWriter, r *http.Request) {
	clientIP := r.RemoteAddr
	log.Printf("[MCP-POST] 收到请求来自: %s, Method: %s", clientIP, r.Method)

	if r.Method != "POST" {
		log.Printf("[MCP-POST] 错误: 客户端 %s 使用了错误的 HTTP 方法: %s (期望 POST)", clientIP, r.Method)
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Read request body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		log.Printf("[MCP-POST] 客户端 %s: 读取请求体失败: %v", clientIP, err)
		http.Error(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	log.Printf("[MCP-POST] 客户端 %s: 请求体: %s", clientIP, string(body))

	// Check if request body is SSE format or direct JSON
	var msg MCPMessage
	var jsonStr string

	if strings.HasPrefix(string(body), "data: ") {
		// SSE format
		jsonStr = strings.TrimPrefix(string(body), "data: ")
	} else {
		// Direct JSON
		jsonStr = string(body)
	}

	if err := json.Unmarshal([]byte(jsonStr), &msg); err != nil {
		log.Printf("[MCP-POST] 客户端 %s: JSON解析错误: %v, 原始内容: %s", clientIP, err, jsonStr)
		http.Error(w, fmt.Sprintf("JSON parse error: %v", err), http.StatusBadRequest)
		return
	}

	log.Printf("[MCP-POST] 客户端 %s: 解析成功, Method: %s, ID: %v", clientIP, msg.Method, msg.ID)

	mcpHandler := NewMCPHandler()

	// Handle notifications (no id, no response needed)
	if msg.ID == nil && strings.HasPrefix(msg.Method, "notifications/") {
		log.Printf("[MCP-POST] 客户端 %s: 忽略通知 %s", clientIP, msg.Method)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("{}"))
		return
	}

	// Handle "initialized" notification
	if msg.ID == nil && msg.Method == "initialized" {
		log.Printf("[MCP-POST] 客户端 %s: 收到 initialized 通知", clientIP)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("{}"))
		return
	}

	var response interface{}
	switch msg.Method {
	case "initialize":
		log.Printf("[MCP-POST] 客户端 %s: 处理 initialize 请求", clientIP)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"result": map[string]interface{}{
				"protocolVersion": "2025-06-18",
				"capabilities": map[string]interface{}{
					"tools": map[string]interface{}{
						"listChanged": false,
					},
					"prompts": map[string]interface{}{
						"listChanged": false,
					},
					"resources": map[string]interface{}{
						"listChanged": false,
					},
					"logging": map[string]interface{}{},
				},
				"serverInfo": map[string]interface{}{
					"name":    "http-shell-mcp",
					"version": "1.0.0",
				},
			},
		}
	case "tools/list":
		log.Printf("[MCP-POST] 客户端 %s: 处理 tools/list 请求", clientIP)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"result":  mcpHandler.HandleToolsList(),
		}
	case "tools/call":
		log.Printf("[MCP-POST] 客户端 %s: 处理 tools/call 请求", clientIP)
		var params map[string]interface{}
		json.Unmarshal(msg.Params, &params)
		result := mcpHandler.HandleToolCall(params)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"result":  result,
		}
	case "prompts/list":
		log.Printf("[MCP-POST] 客户端 %s: 处理 prompts/list 请求", clientIP)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"result": map[string]interface{}{
				"prompts": []interface{}{},
			},
		}
	case "resources/list":
		log.Printf("[MCP-POST] 客户端 %s: 处理 resources/list 请求", clientIP)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"result": map[string]interface{}{
				"resources": []interface{}{},
			},
		}
	case "ping":
		log.Printf("[MCP-POST] 客户端 %s: 处理 ping 请求", clientIP)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"result": map[string]interface{}{},
		}
	default:
		log.Printf("[MCP-POST] 客户端 %s: 未知方法: %s", clientIP, msg.Method)
		response = map[string]interface{}{
			"jsonrpc": "2.0",
			"id":      msg.ID,
			"error": map[string]interface{}{
				"code":    -32601,
				"message": "Method not found",
			},
		}
	}

	respBytes, _ := json.Marshal(response)
	w.Header().Set("Content-Type", "application/json")
	w.Write(respBytes)

	log.Printf("[MCP-POST] 客户端 %s: 已发送响应: %s", clientIP, string(respBytes))
}
