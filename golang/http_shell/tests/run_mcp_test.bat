@echo off
cd /d d:\code\www\my\github\dockerfiles\golang\http_shell\src
start /B go run . mcp > server.log 2>&1
echo Waiting for server to start...
timeout /t 5 /nobreak >nul
echo Running tests...
cd /d d:\code\www\my\github\dockerfiles\golang\http_shell
go test ./tests/... -v -run TestMCPExecuteDateCommand
echo Done.
type server.log
