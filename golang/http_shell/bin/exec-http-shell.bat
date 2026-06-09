@echo off
setlocal enabledelayedexpansion

:: 检查参数
if "%~2"=="" (
    echo 使用方法: %~nx0 域名:端口 文件路径
    echo 示例: %~nx0 http://localhost:8387 "C:\my file\docker-ps"
    pause
    exit /b 1
)

:: 接收参数
set "HOST=%~1"
set "FILE_PATH=%~2"

:: 执行 curl 上传文件
curl --location --request POST "%HOST%" ^
--form "cmd-file=@\"%FILE_PATH%\""
