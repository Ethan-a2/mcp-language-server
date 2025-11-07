#!/bin/bash

# This script has been updated to use a single, persistent server instance
# communicating over a named pipe (FIFO). This fixes the original issue where
# separate server processes were started for initialization and tool calls,
# preventing clangd from being properly indexed.

# --- Configuration ---
set -e # Exit immediately if a command exits with a non-zero status.
WORKSPACE_DIR=$(realpath ./integrationtests/workspaces/clangd)
SERVER_BINARY="./mcp-language-server"
REQUEST_PIPE=$(mktemp -u)
RESPONSE_FILE=$(mktemp)
SERVER_PID=""

# --- Cleanup Function ---
cleanup() {
    echo "--- Cleaning up ---"
    if [ -n "$SERVER_PID" ]; then
        echo "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
    fi
    if [ -p "$REQUEST_PIPE" ]; then
        echo "Removing named pipe..."
        rm -f "$REQUEST_PIPE"
    fi
    if [ -f "$RESPONSE_FILE" ]; then
        echo "Removing response file..."
        rm -f "$RESPONSE_FILE"
    fi
    echo "Cleanup complete."
}

# Register the cleanup function to be called on script exit
trap cleanup EXIT

# --- Pre-flight Checks ---
echo "=== MCP Language Server Manual JSON-RPC Test Script ==="
echo "Workspace: $WORKSPACE_DIR"
echo

if [ ! -f "$SERVER_BINARY" ]; then
    echo "Error: Server binary not found at $SERVER_BINARY. Please build the project first."
    exit 1
fi

if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "Error: Workspace directory not found at $WORKSPACE_DIR."
    exit 1
fi

# --- Main Execution ---

echo "1. Creating named pipe for communication..."
mkfifo "$REQUEST_PIPE"

echo "2. Starting MCP Language Server in the background..."
# The server will read from the pipe and write its output to the response file
timeout 30s "$SERVER_BINARY" --workspace "$WORKSPACE_DIR" --lsp clangd -- --compile-commands-dir="$WORKSPACE_DIR" < "$REQUEST_PIPE" > "$RESPONSE_FILE" &
SERVER_PID=$!
# Wait a moment to ensure the server process has started
sleep 1

echo "3. Sending requests to the server..."

# Group all writes into a single block to keep the pipe open.
# This prevents the server from seeing an EOF after the first request.
{
  # Send Initialize Request
  echo "   -> initialize"
  cat <<EOF
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test-client","version":"1.0.0"}}}
EOF

  # Send Initialized Notification
  echo "   -> initialized"
  cat <<EOF
{"jsonrpc":"2.0","method":"notifications/initialized"}
EOF

  # Send didOpen Notification to trigger indexing
  echo "   -> textDocument/didOpen (to trigger indexing)"
  cat <<EOF
{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file://$WORKSPACE_DIR/src/main.cpp","languageId":"cpp","version":1,"text":""}}}
EOF

  echo "4. Waiting for clangd to finish indexing by monitoring its logs..."
  # We actively wait for clangd to signal it has completed its background indexing.
  # This is far more reliable than a fixed-duration sleep.
  # We'll use a timeout as a safeguard in case something goes wrong.
  if timeout 25s grep -q "BackgroundIndex: building version" <(tail -f -n0 "$RESPONSE_FILE" &); then
      echo "✅ Clangd indexing appears to be complete."
  else
      echo "⚠️ Timed out waiting for clangd to finish indexing. The test may fail."
  fi
  
  # Send Definition Tool Call
  echo "   -> tools/call (definition for 'foo_bar')"
  cat <<EOF
{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"definition","arguments":{"symbolName":"foo_bar"}}}
EOF
} > "$REQUEST_PIPE"
  
  # Wait a moment for the final response to be written
  sleep 2
echo "5. Analyzing server response..."
if [ ! -s "$RESPONSE_FILE" ]; then
    echo "Error: Response file is empty. The server may have crashed."
    exit 1
fi

echo "Full server output:"
cat "$RESPONSE_FILE"
echo
echo "----------------------------------------"

echo "6. Extracting definition result..."
# Look for the line containing the result of the tool call (id: 2)
if grep -q '"id":2,"result"' "$RESPONSE_FILE"; then
    echo "✅ Definition found successfully!"
    grep '"id":2,"result"' "$RESPONSE_FILE" | jq
else
    echo "❌ Failed to find the definition in the server response."
fi

echo
echo "=== Test Complete ==="