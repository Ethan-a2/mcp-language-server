#!/bin/bash

# LSP Symbol Finder - 通过JSON-RPC调用clangd查找符号定义
# 使用方法: ./lsp_symbol_finder.sh <workspace_dir> <symbol_name>

set -e

# 配置参数
WORKSPACE_DIR="${1:-/media/code/llm/mcp-language-server/integrationtests/workspaces/clangd}"
SYMBOL_NAME="${2:-foo_bar}"
CLANGD_BIN="${CLANGD_BIN:-clangd}"
COMPILE_COMMANDS_DIR="$WORKSPACE_DIR"

# 临时文件
FIFO_IN="/tmp/lsp_in_$$"
FIFO_OUT="/tmp/lsp_out_$$"
LOG_FILE="/tmp/lsp_debug_$$.log"

# 清理函数
cleanup() {
    echo "清理资源..." >&2
    if [[ -n "$CLANGD_PID" ]]; then
        kill $CLANGD_PID 2>/dev/null || true
    fi
    rm -f "$FIFO_IN" "$FIFO_OUT" "$LOG_FILE"
}
trap cleanup EXIT

# 创建命名管道
mkfifo "$FIFO_IN"
mkfifo "$FIFO_OUT"

# 发送JSON-RPC消息
send_message() {
    local message="$1"
    local content_length=${#message}
    echo "-> 发送: $message" >> "$LOG_FILE"
    printf "Content-Length: %d\r\n\r\n%s" "$content_length" "$message" > "$FIFO_IN"
}

# 接收JSON-RPC消息
receive_message() {
    local header
    local content_length=0
    
    # 读取headers
    while IFS= read -r header; do
        header=$(echo "$header" | tr -d '\r\n')
        echo "<- Header: $header" >> "$LOG_FILE"
        
        if [[ "$header" =~ Content-Length:\ ([0-9]+) ]]; then
            content_length="${BASH_REMATCH[1]}"
        fi
        
        # 空行表示header结束
        if [[ -z "$header" ]]; then
            break
        fi
    done < "$FIFO_OUT"
    
    # 读取内容
    if [[ $content_length -gt 0 ]]; then
        local content
        content=$(dd bs=1 count=$content_length 2>/dev/null < "$FIFO_OUT")
        echo "<- Received: $content" >> "$LOG_FILE"
        echo "$content"
    fi
}

# 启动clangd
echo "=== MCP Language Server 手动定义查找测试 ===" >&2
echo "工作目录: $WORKSPACE_DIR" >&2
echo "查找符号: $SYMBOL_NAME" >&2
echo "" >&2

echo "1. 启动 clangd..." >&2
$CLANGD_BIN --compile-commands-dir="$COMPILE_COMMANDS_DIR" < "$FIFO_IN" > "$FIFO_OUT" 2>> "$LOG_FILE" &
CLANGD_PID=$!

# 等待clangd启动
sleep 0.5

# 2. 初始化LSP
echo "2. 初始化 LSP..." >&2
INIT_MSG=$(cat <<EOF
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":$$,"clientInfo":{"name":"mcp-language-server","version":"0.1.0"},"rootPath":"$WORKSPACE_DIR","rootUri":"file://$WORKSPACE_DIR","capabilities":{"workspace":{"didChangeConfiguration":{"dynamicRegistration":true},"didChangeWatchedFiles":{"dynamicRegistration":true,"relativePatternSupport":true},"configuration":true},"textDocument":{"synchronization":{"dynamicRegistration":true,"didSave":true},"completion":{"completionItem":{}},"documentSymbol":{},"codeAction":{"codeActionLiteralSupport":{"codeActionKind":{"valueSet":[]}}},"codeLens":{"dynamicRegistration":true},"publishDiagnostics":{"versionSupport":true},"semanticTokens":{"requests":{"range":null,"full":null},"tokenTypes":[],"tokenModifiers":[],"formats":[]}},"window":{}},"workspaceFolders":[{"uri":"file://$WORKSPACE_DIR","name":"$WORKSPACE_DIR"}]}}
EOF
)

send_message "$INIT_MSG"
INIT_RESPONSE=$(receive_message)

if echo "$INIT_RESPONSE" | grep -q '"result"'; then
    echo "✅ LSP 初始化成功" >&2
else
    echo "❌ LSP 初始化失败" >&2
    exit 1
fi

# 发送initialized通知
send_message '{"jsonrpc":"2.0","method":"initialized","params":{}}'

echo "3. 等待服务器就绪..." >&2
sleep 1
echo "✅ 服务器就绪" >&2

# 4. 打开文件
MAIN_CPP="$WORKSPACE_DIR/src/main.cpp"
echo "4. 打开文件: $MAIN_CPP" >&2

if [[ ! -f "$MAIN_CPP" ]]; then
    echo "❌ 文件不存在: $MAIN_CPP" >&2
    exit 1
fi

FILE_CONTENT=$(cat "$MAIN_CPP" | jq -Rs .)
OPEN_MSG=$(cat <<EOF
{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file://$MAIN_CPP","languageId":"cpp","version":1,"text":$FILE_CONTENT}}}
EOF
)

send_message "$OPEN_MSG"
echo "✅ 文件打开成功" >&2

# 5. 等待索引完成
echo "5. 等待索引完成..." >&2
sleep 10

# 消费可能的诊断消息
while read -t 0.1 line 2>/dev/null; do
    :
done < "$FIFO_OUT"

# 6. 查找符号定义
echo "6. 查找符号定义: $SYMBOL_NAME" >&2
SYMBOL_MSG=$(cat <<EOF
{"jsonrpc":"2.0","id":2,"method":"workspace/symbol","params":{"query":"$SYMBOL_NAME"}}
EOF
)

send_message "$SYMBOL_MSG"
SYMBOL_RESPONSE=$(receive_message)

echo "" >&2
echo "=== 查找结果 ===" >&2
echo "---" >&2

if echo "$SYMBOL_RESPONSE" | jq -e '.result | length > 0' > /dev/null 2>&1; then
    # 提取符号信息
    SYMBOL_FILE=$(echo "$SYMBOL_RESPONSE" | jq -r '.result[0].location.uri' | sed 's|file://||')
    START_LINE=$(echo "$SYMBOL_RESPONSE" | jq -r '.result[0].location.range.start.line')
    START_CHAR=$(echo "$SYMBOL_RESPONSE" | jq -r '.result[0].location.range.start.character')
    END_LINE=$(echo "$SYMBOL_RESPONSE" | jq -r '.result[0].location.range.end.line')
    END_CHAR=$(echo "$SYMBOL_RESPONSE" | jq -r '.result[0].location.range.end.character')
    
    echo "" >&2
    echo "Symbol: $SYMBOL_NAME" >&2
    echo "File: $SYMBOL_FILE" >&2
    echo "Range: L$((START_LINE+1)):C$((START_CHAR+1)) - L$((END_LINE+1)):C$((END_CHAR+1))" >&2
    echo "" >&2
    
    # 获取文档符号以显示完整定义
    DOC_SYMBOL_MSG=$(cat <<EOF
{"jsonrpc":"2.0","id":3,"method":"textDocument/documentSymbol","params":{"textDocument":{"uri":"file://$SYMBOL_FILE"}}}
EOF
)
    
    send_message "$DOC_SYMBOL_MSG"
    DOC_RESPONSE=$(receive_message)
    
    # 查找匹配的符号并显示代码
    if [[ -f "$SYMBOL_FILE" ]]; then
        # 从文档符号中找到完整范围
        FULL_START=$(echo "$DOC_RESPONSE" | jq -r ".result[] | select(.name==\"$SYMBOL_NAME\") | .location.range.start.line")
        FULL_END=$(echo "$DOC_RESPONSE" | jq -r ".result[] | select(.name==\"$SYMBOL_NAME\") | .location.range.end.line")
        
        if [[ -n "$FULL_START" && -n "$FULL_END" ]]; then
            # 显示代码（行号从0开始，需要+1）
            awk -v start=$((FULL_START+1)) -v end=$((FULL_END+1)) \
                'NR>=start && NR<=end {printf "%d|%s\n", NR, $0}' "$SYMBOL_FILE" >&2
            echo "" >&2
        fi
    fi
    
    # 输出JSON结果
    echo "$SYMBOL_RESPONSE" | jq .
else
    echo "❌ 未找到符号: $SYMBOL_NAME" >&2
    exit 1
fi

# 关闭文件
CLOSE_MSG=$(cat <<EOF
{"jsonrpc":"2.0","method":"textDocument/didClose","params":{"textDocument":{"uri":"file://$MAIN_CPP"}}}
EOF
)
send_message "$CLOSE_MSG"

# 关闭LSP
send_message '{"jsonrpc":"2.0","id":99,"method":"shutdown","params":{}}'
sleep 0.5
send_message '{"jsonrpc":"2.0","method":"exit","params":{}}'

echo "✅ 完成" >&2
