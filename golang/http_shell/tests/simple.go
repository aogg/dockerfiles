package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

type SSEEvent struct {
	Event string
	Data  string
}

func main() {
	client := &http.Client{Timeout: 30 * time.Second}
	serverURL := "http://localhost:8080/mcp"

	fmt.Println("=== Testing MCP SSE Connection ===")
	resp, err := http.Get(serverURL)
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		return
	}
	defer resp.Body.Close()

	fmt.Printf("Content-Type: %s\n", resp.Header.Get("Content-Type"))

	scanner := bufio.NewScanner(resp.Body)
	eventChan := make(chan SSEEvent, 100)

	go func() {
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
	}()

	// Wait for endpoint event
	select {
	case event := <-eventChan:
		fmt.Printf("Event: %s\n", event.Event)
		fmt.Printf("Data: %s\n", event.Data)
	case <-time.After(5 * time.Second):
		fmt.Println("Timeout waiting for initial event")
		return
	}

	fmt.Println("\n=== Testing Date Command Execution ===")

	// Send tools/call request for 'date' command
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

	// Send request using the SSE connection (POST to same URL with JSON body)
	reqBody := fmt.Sprintf("data: %s\n\n", string(requestBytes))
	fmt.Printf("Sending via SSE: %s", reqBody)

	// Create a POST request to send the command
	req, _ := http.NewRequest("POST", serverURL, bytes.NewBufferString(reqBody))
	req.Header.Set("Content-Type", "text/event-stream")
	req.Header.Set("Accept", "text/event-stream")

	// Use a separate HTTP client for sending the request
	httpClient := &http.Client{Timeout: 10 * time.Second}
	httpResp, err := httpClient.Do(req)
	if err != nil {
		fmt.Printf("Failed to send request: %v\n", err)
		return
	}
	defer httpResp.Body.Close()
	io.Copy(io.Discard, httpResp.Body)

	// Read response from the SSE connection
	select {
	case event := <-eventChan:
		fmt.Printf("\nResponse: %s\n", event.Data)

		var response struct {
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
		if err := json.Unmarshal([]byte(event.Data), &response); err == nil {
			if response.Result.IsError {
				fmt.Printf("Error: %s\n", response.Result.Content[0].Text)
				return
			}
			output := response.Result.Content[0].Text
			fmt.Printf("\nDate command output: %s\n", output)

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
				fmt.Println("\nOutput does not appear to be a valid date!")
				return
			}

			fmt.Println("\n=== SUCCESS! Date command executed via MCP! ===")
		}
	case <-time.After(10 * time.Second):
		fmt.Println("\nTimeout waiting for response")
	}
}
