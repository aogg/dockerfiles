@echo off
echo Starting MCP server...
cd /d d:\code\www\my\github\dockerfiles\golang\http_shell\src
start /min cmd /c "go run . mcp && pause"

echo Waiting for server to start...
timeout /t 5 /nobreak

echo Running test...
cd /d d:\code\www\my\github\dockerfiles\golang\http_shell\tests
go run test.go

pause
