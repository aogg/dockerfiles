package main

import (
    "fmt"
    "log"
    "encoding/base64"
    "net/http"
    "os/exec"
)

func handler(w http.ResponseWriter, r *http.Request) {
    // 获取请求参数中的cmd参数值
    // curl "172.17.0.2:8080" -d "cmd-base64=docker ps"
    cmd := r.FormValue("cmd")
    cmdBase64 := r.FormValue("cmd-base64")

    // curl "172.17.0.2:8080" -d "cmd-base64=$(echo docker ps|base64)"
    if cmdBase64 != "" {
        cmd2, baseErr := base64.StdEncoding.DecodeString(cmdBase64)

        if baseErr != nil {
            http.Error(
                w, 
                fmt.Sprintf("base64错误 cmd-base64='%s', 错误信息: %v", cmdBase64, baseErr), 
                http.StatusBadRequest)
            return
        }
        cmd=string(cmd2)    
    }

    if cmd == "" {
        http.Error(w, "缺少执行命令 'cmd'", http.StatusBadRequest)
        return
    }
    log.Printf("执行的命令: %s", cmd)

    // 执行Shell命令
    out, err := exec.Command("sh", "-c", cmd).Output()
    if err != nil {
        http.Error(w, fmt.Sprintf("执行命令报错 '%s': %v", cmd, err), http.StatusInternalServerError)
        return
    }

    // 将命令输出返回给客户端
    fmt.Fprintf(w, "%s", out)
}

func main() {
    http.HandleFunc("/", handler)
    
    log.Println("开启http端口 :8080")

    log.Fatal(http.ListenAndServe(":8080", nil))
}
