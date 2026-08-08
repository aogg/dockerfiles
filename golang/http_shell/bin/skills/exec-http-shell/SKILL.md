---
name: exec-http-shell
description: 用时上传文件作为 shell 命令到服务端执行。Use when你有一个 http_shell 服务地址（如 http://localhost:8080 | http://http-shell.common-all:8080）和一个本地命令文件，需要把文件内容作为命令在服务端 shell 中执行。
---

# exec-http-shell（上传文件作为 shell 命令执行）

把本地文件内容作为 shell 命令，POST 到 http_shell 服务端执行。核心动作就是一条 curl。

## 触发条件
- 已部署/运行 http_shell 服务（Go），有服务地址（示例 `http://localhost:8080`）
- 本地有一个命令文件（内容即要在服务端执行的命令）（最好是，需要生成随机得临时文件(/tmp/[唯一文件])）

## 步骤

1. 准备命令文件：把要执行的命令写进一个本地文件（如 `docker-ps`，内容是 `docker ps`）。
2. 执行上传（`$HOST` 填服务地址，`$FILE_PATH` 填命令文件的绝对/相对路径）：

```sh
curl --location --request POST "$HOST" \
    --form "cmd-file=@\"$FILE_PATH\""
```

3. 服务端读取 `cmd-file` 字段内容并作为 shell 命令执行，返回输出。

## 参数
- `HOST`：http_shell 服务地址，含协议，如 `http://localhost:8080`
- `FILE_PATH`：命令文件路径；`"..."` 整体引用，兼容路径含空格

## 等价脚本
- `exec-http-shell.sh`（本 skill 对应，sh 版）
- `exec-http-shell.bat`（Windows 批处理版，功能等价）

## 陷阱
- 命令文件路径含空格时必须用引号整体包裹，否则 curl 会把路径拆成多个 form 字段。
- 服务端执行的是文件**内容**（命令文本），不是 bash 语法解析；复杂命令建议写成完整脚本文件再上传。