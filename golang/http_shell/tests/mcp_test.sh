#!/bin/bash

# Start the MCP server in background
echo "Starting MCP server..."
cd d:/code/www/my/github/dockerfiles/golang/http_shell/src
go run . mcp &
SERVER_PID=$!

# Wait for server to start
echo "Waiting for server to start..."
sleep 3

# Run the test
echo "Running MCP test..."
cd d:/code/www/my/github/dockerfiles/golang/http_shell/tests
go run test.go
TEST_RESULT=$?

# Clean up
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

# Return test result
if [ $TEST_RESULT -eq 0 ]; then
    echo "=== MCP TEST PASSED ==="
else
    echo "=== MCP TEST FAILED ==="
fi
exit $TEST_RESULT
