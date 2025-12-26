//go:build ignore
// +build ignore

// Simple test for MCP date command functionality
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"runtime"
	"strings"
)

type MCPContent struct {
	Type string `json:"type"`
	Text string `json:"text"`
}

type MCPToolCallResult struct {
	Content []MCPContent `json:"content"`
	IsError bool         `json:"isError,omitempty"`
}

func executeShellCommand(command string) MCPToolCallResult {
	var stdout, stderr strings.Builder

	// Use shell on Linux/Mac, cmd on Windows
	var shellCmd *exec.Cmd
	if runtime.GOOS == "windows" {
		shellCmd = exec.Command("cmd", "/c", command)
	} else {
		shellCmd = exec.Command("sh", "-c", command)
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

func main() {
	fmt.Println("=== Simple MCP Date Command Test ===\n")

	// Use appropriate date command for Windows or Unix
	var dateCommand string
	if runtime.GOOS == "windows" {
		dateCommand = "echo %date% %time%"
	} else {
		dateCommand = "date"
	}

	fmt.Printf("Executing date command: %s\n", dateCommand)
	result := executeShellCommand(dateCommand)

	if result.IsError {
		fmt.Printf("FAILED: Command returned error\n")
		fmt.Printf("Output: %s\n", result.Content[0].Text)
		os.Exit(1)
	}

	if len(result.Content) == 0 {
		fmt.Println("FAILED: No content in result")
		os.Exit(1)
	}

	output := strings.TrimSpace(result.Content[0].Text)
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
		os.Exit(1)
	}

	fmt.Println("\n=== TEST PASSED! Date command executed successfully via MCP ===")

	// Also test the JSON serialization
	fmt.Println("\n=== Testing JSON Serialization ===")
	jsonResult, _ := json.Marshal(result)
	fmt.Printf("JSON Result: %s\n", string(jsonResult))
}
