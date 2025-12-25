package main

import (
	"bufio"
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os/exec"
)

func handler(w http.ResponseWriter, r *http.Request) {
	// 获取请求参数中的cmd参数值
	// curl "172.17.0.2:8080" -d "cmd-base64=docker ps"
	cmd := r.FormValue("cmd")
	// 有+号需要请求端urlencode
	cmdBase64 := r.FormValue("cmd-base64")
	cmdBaseUrl64 := r.FormValue("cmd-base64-url")

	if cmdBaseUrl64 != "" {
		// URL解码
		cmdURLDecoded, cmdURLDecodedErr := url.QueryUnescape(cmdBaseUrl64)
		if cmdURLDecodedErr != nil {
			log.Printf("URL解码错误 cmd-base64-url='%s', 错误信息:  %v", cmdBaseUrl64, cmdURLDecodedErr)
			http.Error(w, fmt.Sprintf("URL解码错误 cmd-base64-url='%s', 错误信息:  %v", cmdBaseUrl64, cmdURLDecodedErr), http.StatusBadRequest)
			return
		}
		cmdBase64 = cmdURLDecoded
	}

	// curl "172.17.0.2:8080" -d "cmd-base64=$(echo docker ps|base64)"
	if cmdBase64 != "" {
		cmd2, baseErr := base64.StdEncoding.DecodeString(cmdBase64)

		if baseErr != nil {
			log.Printf("base64错误 cmd-base64='%s', 错误信息: %v", cmdBase64, baseErr)
			http.Error(
				w,
				fmt.Sprintf("base64错误 cmd-base64='%s', 错误信息: %v", cmdBase64, baseErr),
				http.StatusBadRequest)
			return
		}
		cmd = string(cmd2)
	}

	if cmd == "" {
		log.Println("缺少执行命令 'cmd'")
		http.Error(w, "缺少执行命令 'cmd'", http.StatusBadRequest)
		return
	}
	log.Printf("执行的命令: %s", cmd)

	executeCommand(w, cmd)
}

// flushWriter 包装 io.Writer，每次写入后自动 flush
type flushWriter struct {
	http.Flusher
	io.Writer
}

func (fw *flushWriter) Write(p []byte) (n int, err error) {
	n, err = fw.Writer.Write(p)
	if fw.Flusher != nil {
		fw.Flush()
	}
	return
}

func executeCommand(w http.ResponseWriter, cmd string) {
	// 检查是否支持 Flush
	flusher, ok := w.(http.Flusher)
	if !ok {
		log.Println("不支持流式输出")
		http.Error(w, "http_shell 不支持流式输出", http.StatusInternalServerError)
		return
	}

	// 创建一个命令
	cmdExec := exec.Command("sh", "-c", cmd)

	// 创建管道
	stdoutPipe, err := cmdExec.StdoutPipe()
	if err != nil {
		log.Println("无法获取stdout管道:", err)
		http.Error(w, "http_shell 无法执行命令", http.StatusInternalServerError)
		return
	}

	stderrPipe, err := cmdExec.StderrPipe()
	if err != nil {
		log.Println("无法获取stderr管道:", err)
		http.Error(w, "http_shell 无法执行命令", http.StatusInternalServerError)
		return
	}

	// 启动命令
	if err := cmdExec.Start(); err != nil {
		log.Println("命令启动失败:", err)
		http.Error(w, "http_shell 无法执行命令", http.StatusInternalServerError)
		return
	}

	// 创建带 flush 功能的 writer
	fw := &flushWriter{
		Flusher: flusher,
		Writer:  w,
	}

	// 使用带 flush 功能的 writer 逐行输出标准输出
	go func() {
		scanner := bufio.NewScanner(stdoutPipe)
		for scanner.Scan() {
			fmt.Fprintln(fw, scanner.Text())
		}
		if err := scanner.Err(); err != nil {
			log.Println("标准输出读取失败:", err)
		}
	}()

	// 使用带 flush 功能的 writer 逐行输出标准错误
	go func() {
		scanner := bufio.NewScanner(stderrPipe)
		for scanner.Scan() {
			fmt.Fprintln(fw, scanner.Text())
		}
		if err := scanner.Err(); err != nil {
			log.Println("标准错误读取失败:", err)
		}
	}()

	// 等待命令完成
	err = cmdExec.Wait()
	if err != nil {
		log.Println("命令执行失败:", err)
		http.Error(w, "http_shell 命令执行失败", http.StatusInternalServerError)
	}

	flusher.Flush()
	log.Println("----------执行命令---完毕-------")
}
