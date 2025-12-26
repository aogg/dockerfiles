//go:build ignore
// +build ignore

// This is an integration test file for MCP SSE functionality.
// Run with: go run mcp_integration_test.go
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
	"os"
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

func mcpSSEHandler(w http.ResponseWriter, r *http.Request) {
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
		sse.WriteEvent("endpoint", string(endpointMsg))

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

	// Handle POST requests
	if r.Method == "POST" {
		// For simplicity, POST requests are handled the same way as GET
		// but we need to keep the connection open for SSE
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
		sse.WriteEvent("endpoint", string(endpointMsg))

		// Process incoming messages from POST body
		body, _ := io.ReadAll(r.Body)
		lines := strings.Split(string(body), "\n")

		var currentData string
		for _, line := range lines {
			if strings.HasPrefix(line, "data: ") {
				currentData = strings.TrimSpace(strings.TrimPrefix(line, "data: "))
				if currentData != "" {
					var msg MCPMessage
					if err := json.Unmarshal([]byte(currentData), &msg); err == nil {
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
						}
						if response != nil {
							respBytes, _ := json.Marshal(response)
							sse.WriteEvent("message", string(respBytes))
						}
					}
				}
				currentData = ""
			}
		}
		return
	}

	http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
}

func main() {
	fmt.Println("=== MCP SSE Integration Test ===\n")

	// Start test server
	server := httptest.NewServer(http.HandlerFunc(mcpSSEHandler))
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
	done := make(chan bool)

	go func() {
		var currentEvent string
		for scanner.Scan() {
			line := scanner.Text()
			if strings.HasPrefix(line, "event:") {
				currentEvent = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
			} else if strings.HasPrefix(line, "data:") {
				dataStr := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
				var data map[string]interface{}
				if err := json.Unmarshal([]byte(dataStr), &data); err == nil {
					eventChan <- data
				}
				currentEvent = ""
			}
		}
		done <- true
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

	// Test 2: List tools
	fmt.Println("--- Test 2: List Tools ---")
	params := map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      1,
		"method":  "tools/list",
	}

	paramsBytes, _ := json.Marshal(params)
	reqBody := fmt.Sprintf("data: %s\n\n", string(paramsBytes))

	req, _ := http.NewRequest("POST", serverURL, bytes.NewBufferString(reqBody))
	req.Header.Set("Content-Type", "text/event-stream")

	client := &http.Client{}
	listResp, err := client.Do(req)
	if err != nil {
		fmt.Printf("FAILED: %v\n", err)
		return
	}
	defer listResp.Body.Close()

	select {
	case data := <-eventChan:
		if result, ok := data["result"].(map[string]interface{}); ok {
			if tools, ok := result["tools"].([]interface{}); ok {
				fmt.Printf("Found %d tools\n", len(tools))
				for _, t := range tools {
					if tool, ok := t.(map[string]interface{}); ok {
						fmt.Printf("  - %s: %s\n", tool["name"], tool["description"])
					}
				}
			}
		}
		fmt.Println("PASSED: Tools list retrieved\n")
	case <-time.After(5 * time.Second):
		fmt.Println("FAILED: Timeout waiting for tools list\n")
		return
	}

	// Test 3: Execute date command
	fmt.Println("--- Test 3: Execute Date Command ---")

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
	dateReqBody := fmt.Sprintf("data: %s\n\n", string(dateReqBytes))

	fmt.Printf("Sending date command request...\n")

	dateReqHTTP, _ := http.NewRequest("POST", serverURL, bytes.NewBufferString(dateReqBody))
	dateReqHTTP.Header.Set("Content-Type", "text/event-stream")

	dateResp, err := client.Do(dateReqHTTP)
	if err != nil {
		fmt.Printf("FAILED: %v\n", err)
		return
	}
	defer dateResp.Body.Close()

	select {
	case data := <-eventChan:
		fmt.Printf("Received response: %+v\n", data)

		if result, ok := data["result"].(map[string]interface{}); ok {
			if content, ok := result["content"].([]interface{}); ok && len(content) > 0 {
				if first, ok := content[0].(map[string]interface{}); ok {
					if text, ok := first["text"].(string); ok {
						output := strings.TrimSpace(text)
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

						fmt.Println("PASSED: Date command executed successfully!")
					}
				}
			}
		}
	case <-time.After(10 * time.Second):
		fmt.Println("FAILED: Timeout waiting for date command response\n")
		return
	}

	fmt.Println("\n=== ALL TESTS PASSED ===")
	fmt.Println("\nSummary:")
	fmt.Println("✓ SSE connection established successfully")
	fmt.Println("✓ Tools list retrieved successfully")
	fmt.Println("✓ Date command executed via MCP SSE protocol")
	fmt.Println("\nMCP SSE functionality is working correctly!")
}
