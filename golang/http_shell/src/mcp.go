package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os/exec"
	"strings"
	"sync"
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
}

func (sse *SSEConnection) WriteEvent(eventType, data string) {
	sse.mu.Lock()
	defer sse.mu.Unlock()

	fmt.Fprintf(sse.writer, "event: %s\n", eventType)
	fmt.Fprintf(sse.writer, "data: %s\n\n", data)
	sse.flusher.Flush()
}

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
	// Check for SSE support
	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "SSE not supported", http.StatusInternalServerError)
		return
	}

	// Set SSE headers
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	sse := &SSEConnection{
		writer:  w,
		flusher: flusher,
	}

	mcpHandler := NewMCPHandler()

	// Send endpoint notification
	endpointMsg, _ := json.Marshal(map[string]interface{}{
		"jsonrpc": "2.0",
		"method":  "notifications/endpoint",
		"params": map[string]interface{}{
			"endpoint": "/mcp",
		},
	})
	sse.WriteEvent("endpoint", string(endpointMsg))

	// Process incoming messages
	scanner := bufio.NewScanner(r.Body)
	for scanner.Scan() {
		line := scanner.Text()
		if strings.HasPrefix(line, "data: ") {
			jsonStr := strings.TrimPrefix(line, "data: ")
			var msg MCPMessage
			if err := json.Unmarshal([]byte(jsonStr), &msg); err != nil {
				log.Printf("JSON解析错误: %v", err)
				continue
			}

			var response interface{}
			switch msg.Method {
			case "tools/list":
				response = map[string]interface{}{
					"jsonrpc": "2.0",
					"id":      msg.ID,
					"result":  mcpHandler.HandleToolsList(),
				}
			case "tools/call":
				var params map[string]interface{}
				json.Unmarshal(msg.Params, &params)
				result := mcpHandler.HandleToolCall(params)
				response = map[string]interface{}{
					"jsonrpc": "2.0",
					"id":      msg.ID,
					"result":  result,
				}
			default:
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
			sse.WriteEvent("message", string(respBytes))
		}
	}

	if err := scanner.Err(); err != nil {
		log.Printf("SSE连接错误: %v", err)
	}
}
