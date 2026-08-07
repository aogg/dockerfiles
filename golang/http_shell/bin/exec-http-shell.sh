#!/bin/sh
# 将文件作为 shell 命令上传到服务端执行（与 exec-http-shell.bat 功能等价）
# 用法: exec-http-shell.sh 服务地址 文件路径

# 检查参数
if [ "$#" -lt 2 ]; then
    echo "使用方法: $(basename "$0") 域名:端口 文件路径"
    echo "示例: $(basename "$0") http://localhost:8387 \"/path/to/my file/docker-ps\""
    exit 1
fi

# 接收参数
HOST="$1"
FILE_PATH="$2"

# 执行 curl 上传文件（\" 将路径整体引用，兼容路径含空格）
curl --location --request POST "$HOST" \
    --form "cmd-file=@\"$FILE_PATH\""