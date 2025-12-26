package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"
)

func main() {
	// Start the server
	fmt.Println("Starting MCP server...")
	// Server should already be running on port 8080

	// Test 1: Check if server is running
	client := &http.Client{}
	resp, err := client.Get("http://localhost:8080/mcp")
	if err != nil {
		fmt.Printf("Failed to connect to server: %v\n", err)
		fmt.Println("Please start the server with: cd src && go run . mcp")
		os.Exit(1)
	}
	defer resp.Body.Close()

	fmt.Println("Connected to MCP SSE server")
	fmt.Printf("Content-Type: %s\n", resp.Header.Get("Content-Type"))

	// Read SSE events
	scanner := bufio.NewScanner(resp.Body)
	eventChan := make(chan map[string]interface{}, 10)
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
	}()

	// Wait for endpoint event
	select {
	case data := <-eventChan:
		fmt.Printf("Received event: %+v\n", data)
	case <-time.After(5 * time.Second):
		fmt.Println("Timeout waiting for initial event")
		os.Exit(1)
	}

	// Send date command request
	fmt.Println("\nSending date command...")

	// Create POST request to send command
	params := map[string]interface{}{
		"name": "execute_shell",
		"arguments": map[string]string{
			"command": "date",
		},
	}
	paramsBytes, _ := json.Marshal(params)

	request := map[string]interface{}{
		"jsonrpc": "2.0",
		"id":      1,
		"method":  "tools/call",
		"params":  json.RawMessage(paramsBytes),
	}

	requestBytes, _ := json.Marshal(request)

	// Send as SSE format
	reqBody := fmt.Sprintf("data: %s\n\n", string(requestBytes))
	fmt.Printf("Request body: %s", reqBody)

	// Create new request
	req, _ := http.NewRequest("POST", "http://localhost:8080/mcp", strings.NewReader(reqBody))
	req.Header.Set("Content-Type", "text/event-stream")

	// Send request
	postClient := &http.Client{}
	postResp, err := postClient.Do(req)
	if err != nil {
		fmt.Printf("Failed to send POST request: %v\n", err)
		os.Exit(1)
	}
	defer postResp.Body.Close()
	io.Copy(io.Discard, postResp.Body)

	// Wait for response
	select {
	case data := <-eventChan:
		fmt.Printf("\nReceived response: %+v\n", data)

		if result, ok := data["result"].(map[string]interface{}); ok {
			if content, ok := result["content"].([]interface{}); ok && len(content) > 0 {
				if first, ok := content[0].(map[string]interface{}); ok {
					if text, ok := first["text"].(string); ok {
						fmt.Printf("\nDate command output: %s\n", text)
						fmt.Println("\n=== SUCCESS! Date command executed via MCP! ===")
						return
					}
				}
			}
		}

		fmt.Println("\n=== Failed to parse response ===")
	case <-time.After(10 * time.Second):
		fmt.Println("\n=== Timeout waiting for date command response ===")
		os.Exit(1)
	}
}
