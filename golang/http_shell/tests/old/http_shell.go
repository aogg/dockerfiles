package main

import (
    "fmt"
    "log"
    "encoding/base64"
    "net/http"
    "net/url"
    "os/exec"
    "io"
    // "bytes"
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
        cmd=string(cmd2)    
    }

    if cmd == "" {
        log.Println("缺少执行命令 'cmd'")
        http.Error(w, "缺少执行命令 'cmd'", http.StatusBadRequest)
        return
    }
    log.Printf("-----开始----执行的命令: %s--------", cmd)


    executeCommand(w, cmd)

    // // 执行Shell命令，必须sh
    // // 请确保将 "your-command" 替换为实际的命令，并将 "arg1", "arg2" 替换为实际的命令参数（如果有的话）。
    // cmdExec := exec.Command("sh", "-c", cmd)
    // var out bytes.Buffer
    // var stderr bytes.Buffer
    // cmdExec.Stdout = &out
    // cmdExec.Stderr = &stderr

    // err := cmdExec.Run()

    // if err != nil {
    //     errMsg := stderr.String()
    //     outMsg := out.String()
    //     log.Println("----------执行命令---报错-------")
    //     log.Printf("执行命令报错: 正常输出: %s 错误：%s", outMsg, errMsg)
    //     http.Error(
    //         w,
    //         fmt.Sprintf("执行命令报错: 正常输出: %s 错误：%s", outMsg, errMsg),
    //         http.StatusInternalServerError,
    //     )
    //     return
    // }

    // log.Println("----------执行命令---完毕-------")
    // // 将命令输出返回给客户端
    // fmt.Fprintf(w, "%s", out)
}


func executeCommand(w http.ResponseWriter, cmd string) {

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

    // 创建一个多写入器，将标准输出和标准错误合并
    multiWriter := io.MultiWriter(w)

    // 使用goroutine实时输出标准输出
    go func() {
        _, err := io.Copy(multiWriter, stdoutPipe)
        if err != nil {
            log.Println("标准输出复制失败:", err)
        }
    }()

    // 使用goroutine实时输出标准错误
    go func() {
        _, err := io.Copy(multiWriter, stderrPipe)
        if err != nil {
            log.Println("标准错误复制失败:", err)
        }
    }()

    // 等待命令完成
    err = cmdExec.Wait()
    if err != nil {
        log.Println("命令执行失败:", err)
        http.Error(w, "http_shell 命令执行失败", http.StatusInternalServerError)
    }

    log.Println("----------执行命令---完毕-------")
}


func main() {
    http.HandleFunc("/", handler)
    
    log.Println("开启http端口 :8080")

    log.Fatal(http.ListenAndServe(":8080", nil))
}
