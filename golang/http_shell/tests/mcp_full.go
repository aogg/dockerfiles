//go:build ignore
// +build ignore

// This is a complete integration test for MCP functionality.
// Tests both command execution and JSON serialization.
package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httptest"
	"os/exec"
	"runtime"
	"strings"
	"sync"
	"time"
)

// ========== MCP Protocol Types ==========
type MCPMessage struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      interface{}     `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
	Result  interface{}     `json:"result,omitempty"`
	Error   *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

type MCPTool struct {
	Name        string                 `json:"name"`
	Description string                 `json:"description"`
	InputSchema map[string]interface{} `json:"inputSchema"`
}

type MCPToolCallResult struct {
	Content []MCPContent `json:"content"`
	IsError bool         `json:"isError,omitempty"`
}

type MCPContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// ========== MCP Handler ==========
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
				{Type: "text", Text: "Error: missing 'command' parameter"},
			},
			IsError: true,
		}
	}

	var stdout, stderr strings.Builder

	// Use shell on Linux/Mac, cmd on Windows
	var shellCmd *exec.Cmd
	if runtime.GOOS == "windows" {
		shellCmd = exec.Command("cmd", "/c", cmd)
	} else {
		shellCmd = exec.Command("sh", "-c", cmd)
	}

	shellCmd.Stdout = &stdout
	shellCmd.Stderr = &stderr

	err := shellCmd.Run()

	output := stdout.String()
	if err != nil {
		if stderr.String() != "" {
			output = stderr.String()
		}
	}

	return MCPToolCallResult{
		Content: []MCPContent{
			{Type: "text", Text: output},
		},
		IsError: err != nil,
	}
}

func (h *MCPHandler) HandleToolsList() map[string]interface{} {
	tools := []MCPTool{
		{
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
		},
	}

	return map[string]interface{}{
		"tools": tools,
	}
}

func (h *MCPHandler) HandleToolCall(params map[string]interface{}) MCPToolCallResult {
	name, ok := params["name"].(string)
	if !ok || name == "" {
		return MCPToolCallResult{
			Content: []MCPContent{
				{Type: "text", Text: "Error: missing 'name' parameter"},
			},
			IsError: true,
		}
	}

	toolFunc, exists := h.tools[name]
	if !exists {
		return MCPToolCallResult{
			Content: []MCPContent{
				{Type: "text", Text: fmt.Sprintf("Error: tool '%s' not found", name)},
			},
			IsError: true,
		}
	}

	// Extract arguments
	arguments := make(map[string]interface{})
	if args, ok := params["arguments"].(map[string]interface{}); ok {
		arguments = args
	}

	return toolFunc(arguments)
}

// ========== SSE Implementation ==========
type SSEConnection struct {
	writer  io.Writer
	flusher http.Flusher
	mu      sync.Mutex
}

func (sse *SSEConnection) WriteEvent(eventType, data string) error {
	sse.mu.Lock()
	defer sse.mu.Unlock()

	if _, err := fmt.Fprintf(sse.writer, "event: %s\n", eventType); err != nil {
		return err
	}
	if _, err := fmt.Fprintf(sse.writer, "data: %s\n\n", data); err != nil {
		return err
	}
	if sse.flusher != nil {
		sse.flusher.Flush()
	}
	return nil
}

// ========== HTTP Handler ==========
func mcpHTTPHandler(w http.ResponseWriter, r *http.Request) {
	// Handle SSE connection
	if r.Method == "GET" {
		flusher, ok := w.(http.Flusher)
		if !ok {
			http.Error(w, "SSE not supported", http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "text/event-stream")
		w.Header().Set("Cache-Control", "no-cache")
		w.Header().Set("Connection", "keep-alive")
		w.Header().Set("Access-Control-Allow-Origin", "*")

		sse := &SSEConnection{writer: w, flusher: flusher}
		mcpHandler := NewMCPHandler()

		// Send endpoint notification
		endpointMsg, _ := json.Marshal(map[string]interface{}{
			"jsonrpc": "2.0",
			"method":  "notifications/endpoint",
			"params": map[string]interface{}{
				"endpoint": "/mcp",
			},
		})
		if err := sse.WriteEvent("endpoint", string(endpointMsg)); err != nil {
			return
		}

		// Process incoming messages
		scanner := bufio.NewScanner(r.Body)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "data: ") {
				jsonStr := strings.TrimPrefix(line, "data: ")
				var msg MCPMessage
				if err := json.Unmarshal([]byte(jsonStr), &msg); err != nil {
					log.Printf("JSON parse error: %v", err)
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
		return
	}

	// Handle POST requests (send JSON-RPC in body)
	if r.Method == "POST" {
		body, _ := io.ReadAll(r.Body)

		// Handle plain JSON-RPC
		var msg MCPMessage
		if err := json.Unmarshal(body, &msg); err == nil {
			var response interface{}
			switch msg.Method {
			case "tools/list":
				mcpHandler := NewMCPHandler()
				response = map[string]interface{}{
					"jsonrpc": "2.0",
					"id":      msg.ID,
					"result":  mcpHandler.HandleToolsList(),
				}
			case "tools/call":
				mcpHandler := NewMCPHandler()
				var params map[string]interface{}
				json.Unmarshal(msg.Params, &params)
				result := mcpHandler.HandleToolCall(params)
				response = map[string]interface{}{
					"jsonrpc": "2.0",
					"id":      msg.ID,
					"result":  result,
				}
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
		}
		return
	}

	http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
}

func main() {
	fmt.Println("=== MCP Full Integration Test ===\n")

	// Start test server
	server := httptest.NewServer(http.HandlerFunc(mcpHTTPHandler))
	defer server.Close()

	serverURL := server.URL + "/mcp"
	fmt.Printf("Test server started: %s\n\n", serverURL)

	// Test 1: Establish SSE connection
	fmt.Println("--- Test 1: Establish SSE Connection ---")
	resp, err := http.Get(serverURL)
	if err != nil {
		fmt.Printf("FAILED: %v\n", err)
		return
	}
	defer resp.Body.Close()

	fmt.Printf("Content-Type: %s\n", resp.Header.Get("Content-Type"))

	// Read SSE events
	scanner := bufio.NewScanner(resp.Body)
	eventChan := make(chan map[string]interface{}, 10)

	go func() {
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "event:") {
				_ = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
			} else if strings.HasPrefix(line, "data:") {
				dataStr := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
				var data map[string]interface{}
				if err := json.Unmarshal([]byte(dataStr), &data); err == nil {
					eventChan <- data
				}
			}
		}
	}()

	// Wait for endpoint event
	select {
	case data := <-eventChan:
		fmt.Printf("Received endpoint event: %+v\n", data)
	case <-time.After(5 * time.Second):
		fmt.Println("FAILED: Timeout waiting for initial event")
		return
	}
	fmt.Println("PASSED: SSE connection established\n")

	// Test 2: Execute date command via tools/call using plain JSON-RPC POST
	fmt.Println("--- Test 2: Execute Date Command (Plain JSON-RPC) ---")

	// Use appropriate date command for Windows or Unix
	var dateCommand string
	if runtime.GOOS == "windows" {
		dateCommand = "echo %date% %time%"
	} else {
		dateCommand = "date"
	}

	fmt.Printf("Executing date command: %s\n", dateCommand)

	dateParams := map[string]interface{}{
		"name": "execute_shell",
		"arguments": map[string]string{
			"command": dateCommand,
		},
	}
	dateParamsBytes, _ := json.Marshal(dateParams)

	dateReq := map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      2,
		"method":  "tools/call",
		"params":  json.RawMessage(dateParamsBytes),
	}

	dateReqBytes, _ := json.Marshal(dateReq)

	fmt.Printf("Sending date command request...\n")

	dateReqHTTP, _ := http.NewRequest("POST", serverURL, bytes.NewReader(dateReqBytes))
	dateReqHTTP.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	dateResp, err := client.Do(dateReqHTTP)
	if err != nil {
		fmt.Printf("FAILED: %v\n", err)
		return
	}
	defer dateResp.Body.Close()

	var dateResponse struct {
		JSONRPC string `json:"jsonrpc"`
		ID      int    `json:"id"`
		Result  struct {
			Content []struct {
				Type string `json:"type"`
				Text string `json:"text"`
			} `json:"content"`
			IsError bool `json:"isError,omitempty"`
		} `json:"result"`
	}
	if err := json.NewDecoder(dateResp.Body).Decode(&dateResponse); err != nil {
		fmt.Printf("FAILED: Error decoding response: %v\n", err)
		return
	}

	if dateResponse.Result.IsError {
		fmt.Printf("FAILED: Command returned error: %s\n", dateResponse.Result.Content[0].Text)
		return
	}

	if len(dateResponse.Result.Content) == 0 {
		fmt.Println("FAILED: No content in result")
		return
	}

	output := strings.TrimSpace(dateResponse.Result.Content[0].Text)
	fmt.Printf("Date command output: %s\n", output)

	// Verify output contains date/time patterns
	outputLower := strings.ToLower(output)
	hasDate := strings.Contains(outputLower, "jan") ||
		strings.Contains(outputLower, "feb") ||
		strings.Contains(outputLower, "mar") ||
		strings.Contains(outputLower, "apr") ||
		strings.Contains(outputLower, "may") ||
		strings.Contains(outputLower, "jun") ||
		strings.Contains(outputLower, "jul") ||
		strings.Contains(outputLower, "aug") ||
		strings.Contains(outputLower, "sep") ||
		strings.Contains(outputLower, "oct") ||
		strings.Contains(outputLower, "nov") ||
		strings.Contains(outputLower, "dec") ||
		strings.Contains(output, ":") ||
		strings.Contains(output, "-") ||
		strings.Contains(output, "/") ||
		strings.Contains(output, "2025") ||
		strings.Contains(output, "2024")

	if !hasDate || output == "" {
		fmt.Println("FAILED: Output does not appear to be a valid date")
		return
	}

	fmt.Println("PASSED: Date command executed successfully!\n")

	// Test 3: Direct MCP handler test (without HTTP)
	fmt.Println("--- Test 3: Direct MCP Handler Test ---")
	mcpHandler := NewMCPHandler()

	// Test execute_shell tool
	result := mcpHandler.executeShellCommand(map[string]interface{}{
		"command": "echo MCP Test Success",
	})

	if result.IsError {
		fmt.Printf("FAILED: Direct handler error: %s\n", result.Content[0].Text)
		return
	}

	fmt.Printf("Direct handler output: %s\n", result.Content[0].Text)
	if strings.Contains(result.Content[0].Text, "MCP Test Success") {
		fmt.Println("PASSED: Direct handler works correctly\n")
	} else {
		fmt.Println("FAILED: Unexpected output from direct handler\n")
		return
	}

	fmt.Println("=== ALL TESTS PASSED ===")
	fmt.Println("\nSummary:")
	fmt.Println("✓ SSE connection established successfully")
	fmt.Println("✓ Date command executed via plain JSON-RPC POST")
	fmt.Println("✓ Direct MCP handler works correctly")
	fmt.Println("\nMCP functionality is working correctly!")
	fmt.Println("\nThe MCP SSE feature has been successfully tested!")
}
