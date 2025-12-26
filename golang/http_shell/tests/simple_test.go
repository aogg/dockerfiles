package main

import (
	"bufio"
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

	fmt.Println("Testing MCP SSE connection...")
	resp, err := client.Get(serverURL)
	if err != nil {
		fmt.Printf("Failed to connect: %v\n", err)
		return
	}
	defer resp.Body.Close()

	fmt.Printf("Content-Type: %s\n", resp.Header.Get("Content-Type"))

	scanner := bufio.NewScanner(resp.Body)
	eventChan := make(chan SSEEvent, 100)
	done := make(chan bool)

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
		done <- true
	}()

	// Wait for endpoint event
	select {
	case event := <-eventChan:
		fmt.Printf("Received event: %s\n", event.Event)
		fmt.Printf("Data: %s\n", event.Data)

		// Check if it's endpoint notification
		var data map[string]interface{}
		if err := json.Unmarshal([]byte(event.Data), &data); err == nil {
			if method, ok := data["method"].(string); ok {
				fmt.Printf("Method: %s\n", method)
			}
		}
	case <-time.After(5 * time.Second):
		fmt.Println("Timeout waiting for initial event")
		return
	}

	fmt.Println("Connection test PASSED!")
}
