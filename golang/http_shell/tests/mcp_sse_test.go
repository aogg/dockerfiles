package tests

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

// JSONRPCRequest represents a JSON-RPC 2.0 request
type JSONRPCRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int             `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
}

// JSONRPCResponse represents a JSON-RPC 2.0 response
type JSONRPCResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int             `json:"id,omitempty"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// MCPContent represents content in a tool result
type MCPContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

// MCPToolCallResult represents the result of a tool call
type MCPToolCallResult struct {
	Content []MCPContent `json:"content"`
	IsError bool         `json:"isError,omitempty"`
}

// SSEEvent represents an SSE event
type SSEEvent struct {
	Event string
	Data  string
}

// TestMCPExecuteDateCommand tests the MCP SSE functionality by executing the 'date' command
func TestMCPExecuteDateCommand(t *testing.T) {
	// SSE endpoint configuration
	serverURL := "http://localhost:8080/mcp"

	// Wait a bit for server to be ready (if running tests right after server start)
	time.Sleep(1 * time.Second)

	// Test 1: Establish SSE connection
	t.Run("Establish SSE Connection", func(t *testing.T) {
		resp, err := http.Get(serverURL)
		if err != nil {
			t.Fatalf("Failed to connect to SSE endpoint: %v", err)
		}
		defer resp.Body.Close()

		// Verify SSE response headers
		contentType := resp.Header.Get("Content-Type")
		if contentType != "text/event-stream" {
			t.Errorf("Expected Content-Type 'text/event-stream', got '%s'", contentType)
		}

		t.Logf("SSE connection established successfully")
	})

	// Test 2: Send tools/list request
	t.Run("List Tools", func(t *testing.T) {
		client := &http.Client{Timeout: 30 * time.Second}
		resp, err := http.Get(serverURL)
		if err != nil {
			t.Fatalf("Failed to connect: %v", err)
		}
		defer resp.Body.Close()

		// Read the initial endpoint event
		scanner := bufio.NewScanner(resp.Body)
		eventChan := make(chan SSEEvent, 100)

		// Start reading events in a goroutine
		go readSSEEvents(scanner, eventChan)

		// Wait for endpoint event
		select {
		case event := <-eventChan:
			t.Logf("Received event: %s, Data: %s", event.Event, event.Data)
		case <-time.After(5 * time.Second):
			t.Fatal("Timeout waiting for initial endpoint event")
		}

		// Send tools/list request
		request := JSONRPCRequest{
			JSONRPC: "2.0",
			ID:      1,
			Method:  "tools/list",
		}

		requestBytes, _ := json.Marshal(request)
		sendRequest(t, client, serverURL, requestBytes)

		// Read response
		select {
		case event := <-eventChan:
			if event.Event == "message" {
				var resp JSONRPCResponse
				if err := json.Unmarshal([]byte(event.Data), &resp); err == nil {
					t.Logf("Tools list response: %s", event.Data)
				}
			}
		case <-time.After(10 * time.Second):
			t.Fatal("Timeout waiting for tools/list response")
		}
	})

	// Test 3: Execute 'date' command via tools/call
	t.Run("Execute Date Command", func(t *testing.T) {
		client := &http.Client{Timeout: 30 * time.Second}
		resp, err := http.Get(serverURL)
		if err != nil {
			t.Fatalf("Failed to connect: %v", err)
		}
		defer resp.Body.Close()

		scanner := bufio.NewScanner(resp.Body)
		eventChan := make(chan SSEEvent, 100)

		// Start reading events
		go readSSEEvents(scanner, eventChan)

		// Wait for endpoint event
		select {
		case <-eventChan:
		case <-time.After(5 * time.Second):
			t.Fatal("Timeout waiting for initial event")
		}

		// Send tools/call request for 'date' command
		params := map[string]interface{}{
			"name": "execute_shell",
			"arguments": map[string]string{
				"command": "date",
			},
		}
		paramsBytes, _ := json.Marshal(params)

		request := JSONRPCRequest{
			JSONRPC: "2.0",
			ID:      2,
			Method:  "tools/call",
			Params:  paramsBytes,
		}

		requestBytes, _ := json.Marshal(request)
		t.Logf("Sending request: %s", string(requestBytes))
		sendRequest(t, client, serverURL, requestBytes)

		// Read response
		select {
		case event := <-eventChan:
			if event.Event == "message" {
				t.Logf("Received response: %s", event.Data)

				var resp JSONRPCResponse
				if err := json.Unmarshal([]byte(event.Data), &resp); err != nil {
					t.Fatalf("Failed to parse JSON-RPC response: %v", err)
				}

				// Check for error
				if resp.Error != nil {
					t.Fatalf("JSON-RPC error: %s", resp.Error.Message)
				}

				// Parse tool call result
				var toolResult MCPToolCallResult
				if err := json.Unmarshal(resp.Result, &toolResult); err != nil {
					t.Fatalf("Failed to parse tool result: %v", err)
				}

				// Check if there was an execution error
				if toolResult.IsError {
					t.Fatalf("Tool execution returned error: %s", toolResult.Content[0].Text)
				}

				// Verify we got content
				if len(toolResult.Content) == 0 {
					t.Fatal("No content in tool result")
				}

				output := toolResult.Content[0].Text
				t.Logf("Date command output: %s", output)

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
					// Check for ISO format or time patterns
					strings.Contains(output, ":") ||
					strings.Contains(output, "-") ||
					strings.Contains(output, "/")

				if !hasDate {
					t.Errorf("Output does not appear to be a date: %s", output)
				} else {
					t.Log("SUCCESS: Date command executed successfully!")
				}
			}
		case <-time.After(10 * time.Second):
			t.Fatal("Timeout waiting for date command response")
		}
	})
}

// readSSEEvents reads SSE events from the scanner and sends them to the channel
func readSSEEvents(scanner *bufio.Scanner, eventChan chan<- SSEEvent) {
	var currentEvent string

	for scanner.Scan() {
		line := scanner.Text()
		line = strings.TrimSpace(line)

		if line == "" {
			// Empty line marks end of event
			continue
		}

		if strings.HasPrefix(line, "event:") {
			currentEvent = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
		} else if strings.HasPrefix(line, "data:") {
			data := strings.TrimSpace(strings.TrimPrefix(line, "data:"))
			eventChan <- SSEEvent{Event: currentEvent, Data: data}
			currentEvent = ""
		}
	}

	if err := scanner.Err(); err != nil && err != io.EOF {
		fmt.Printf("Error reading SSE stream: %v\n", err)
	}
}

// sendRequest sends a JSON-RPC request to the SSE endpoint
func sendRequest(t *testing.T, client *http.Client, url string, data []byte) {
	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		t.Fatalf("Failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("Failed to send request: %v", err)
	}
	defer resp.Body.Close()

	// We don't expect a response body for POST requests to SSE
	io.Copy(io.Discard, resp.Body)
}
