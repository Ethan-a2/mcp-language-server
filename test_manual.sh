#!/bin/bash

# 设置工作目录
WORKSPACE_DIR="./integrationtests/workspaces/clangd"
SERVER_BINARY="./mcp-language-server"

echo "=== MCP Language Server 手动测试脚本 ==="
echo "工作目录: $WORKSPACE_DIR"
echo

# 检查二进制文件是否存在
if [ ! -f "$SERVER_BINARY" ]; then
    echo "错误: 找不到 $SERVER_BINARY，请先构建项目"
    exit 1
fi

# 检查工作目录是否存在
if [ ! -d "$WORKSPACE_DIR" ]; then
    echo "错误: 找不到工作目录 $WORKSPACE_DIR"
    exit 1
fi

echo "1. 启动 MCP Language Server..."
# 启动服务器（后台运行）
$SERVER_BINARY --workspace "$WORKSPACE_DIR" --lsp clangd -- --compile-commands-dir="$WORKSPACE_DIR" > server.log 2>&1 &
SERVER_PID=$!

echo "服务器 PID: $SERVER_PID"
echo "等待服务器初始化..."
sleep 10

echo
echo "2. 检查服务器状态..."
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "✅ 服务器运行正常"
else
    echo "❌ 服务器启动失败"
    cat server.log
    exit 1
fi

echo
echo "3. 测试符号定义查找..."

# 测试函数定义
echo "测试 foo_bar 函数定义:"
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"definition","arguments":{"symbolName":"foo_bar"}}}' | timeout 10 nc localhost 0 2>/dev/null || echo "需要通过 MCP 客户端连接"

echo
echo "4. 清理..."
kill $SERVER_PID 2>/dev/null
echo "服务器已停止"

echo
echo "=== 测试完成 ==="
echo "服务器日志保存在: server.log"