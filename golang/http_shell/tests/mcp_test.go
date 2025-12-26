package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os/exec"
	"strings"
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

func main() {
	// Start the MCP server in the background
	fmt.Println("Starting MCP server...")
	cmd := exec.Command("go", "run", ".", "mcp")
	cmd.Dir = "../src"
	if err := cmd.Start(); err != nil {
		fmt.Printf("Failed to start server: %v\n", err)
		return
	}
	defer cmd.Process.Kill()

	// Wait for server to be ready
	fmt.Println("Waiting for server to start...")
	time.Sleep(5 * time.Second)

	// Run the test
	serverURL := "http://localhost:8080/mcp"
	client := &http.Client{Timeout: 30 * time.Second}

	fmt.Println("=== Testing MCP SSE Connection ===")
	if err := testConnection(client, serverURL); err != nil {
		fmt.Printf("Connection test FAILED: %v\n", err)
		return
	}
	fmt.Println("Connection test PASSED\n")

	fmt.Println("=== Testing MCP Date Command Execution ===")
	output, err := testDateCommand(client, serverURL)
	if err != nil {
		fmt.Printf("Date command test FAILED: %v\n", err)
		return
	}
	fmt.Printf("Date command test PASSED!\n")
	fmt.Printf("Output: %s\n", output)
}

func testConnection(client *http.Client, serverURL string) error {
	resp, err := client.Get(serverURL)
	if err != nil {
		return fmt.Errorf("failed to connect to SSE endpoint: %v", err)
	}
	defer resp.Body.Close()

	contentType := resp.Header.Get("Content-Type")
	if contentType != "text/event-stream" {
		return fmt.Errorf("expected Content-Type 'text/event-stream', got '%s'", contentType)
	}

	// Read the initial endpoint event
	scanner := bufio.NewScanner(resp.Body)
	eventChan := make(chan SSEEvent, 100)
	done := make(chan bool)

	go readSSEEvents(scanner, eventChan, done)

	select {
	case event := <-eventChan:
		fmt.Printf("Received event: %s\n", event.Event)
		fmt.Printf("Data: %s\n", event.Data)
		return nil
	case <-time.After(5 * time.Second):
		return fmt.Errorf("timeout waiting for initial endpoint event")
	}
}

func testDateCommand(client *http.Client, serverURL string) (string, error) {
	resp, err := client.Get(serverURL)
	if err != nil {
		return "", fmt.Errorf("failed to connect: %v", err)
	}
	defer resp.Body.Close()

	scanner := bufio.NewScanner(resp.Body)
	eventChan := make(chan SSEEvent, 100)
	done := make(chan bool)

	go readSSEEvents(scanner, eventChan, done)

	// Wait for endpoint event
	select {
	case <-eventChan:
	case <-time.After(5 * time.Second):
		return "", fmt.Errorf("timeout waiting for initial event")
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
		ID:      1,
		Method:  "tools/call",
		Params:  paramsBytes,
	}

	requestBytes, _ := json.Marshal(request)
	fmt.Printf("Sending request: %s\n", string(requestBytes))

	if err := sendRequest(client, serverURL, requestBytes); err != nil {
		return "", err
	}

	// Read response
	select {
	case event := <-eventChan:
		if event.Event == "message" {
			fmt.Printf("Received response: %s\n", event.Data)

			var resp JSONRPCResponse
			if err := json.Unmarshal([]byte(event.Data), &resp); err != nil {
				return "", fmt.Errorf("failed to parse JSON-RPC response: %v", err)
			}

			if resp.Error != nil {
				return "", fmt.Errorf("JSON-RPC error: %s", resp.Error.Message)
			}

			var toolResult MCPToolCallResult
			if err := json.Unmarshal(resp.Result, &toolResult); err != nil {
				return "", fmt.Errorf("failed to parse tool result: %v", err)
			}

			if toolResult.IsError {
				return "", fmt.Errorf("tool execution returned error: %s", toolResult.Content[0].Text)
			}

			if len(toolResult.Content) == 0 {
				return "", fmt.Errorf("no content in tool result")
			}

			output := toolResult.Content[0].Text

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
				strings.Contains(output, "/")

			if !hasDate {
				return "", fmt.Errorf("output does not appear to be a date: %s", output)
			}

			return output, nil
		}
	case <-time.After(15 * time.Second):
		return "", fmt.Errorf("timeout waiting for date command response")
	}

	return "", fmt.Errorf("no valid response received")
}

func readSSEEvents(scanner *bufio.Scanner, eventChan chan<- SSEEvent, done chan<- bool) {
	defer func() { done <- true }()

	var currentEvent string

	for scanner.Scan() {
		line := scanner.Text()
		line = strings.TrimSpace(line)

		if line == "" {
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
}

func sendRequest(client *http.Client, url string, data []byte) error {
	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return fmt.Errorf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send request: %v", err)
	}
	defer resp.Body.Close()

	io.Copy(io.Discard, resp.Body)
	return nil
}
