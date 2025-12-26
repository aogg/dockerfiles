package main

import (
	"log"
	"net/http"
	"os"
)

func startHTTPShell() {
	http.HandleFunc("/", handler)

	log.Println("开启http端口 :8080")

	log.Fatal(http.ListenAndServe(":8080", nil))
}

func startMCPServer() {
	http.HandleFunc("/mcp", mcpSSEHandler)
	http.HandleFunc("/", handler)

	log.Println("MCP SSE 服务启动在端口 :8080")
	log.Println("  - SSE 端点: GET /mcp (用于接收服务器推送)")
	log.Println("  - 命令端点: POST /mcp (用于发送 JSON-RPC 命令)")
	log.Println("  - 原有 http shell 服务仍在根目录 / 可用")
	log.Fatal(http.ListenAndServe(":8080", nil))
}

func main() {
	if len(os.Args) > 1 && os.Args[1] == "mcp" {
		log.Println("启动 MCP SSE 模式")
		startMCPServer()
		return
	}
	startHTTPShell()
}
