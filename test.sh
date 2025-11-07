#!/bin/bash
# 测试 MCP 工具的脚本（需要手动发送 JSON-RPC 请求）

# 这个脚本演示如何与 mcp-language-server 交互
# 实际使用时，MCP 客户端（如 Claude）会自动处理这些交互

echo "MCP Language Server 测试工具"
echo "============================="
echo ""
echo "可用的 MCP 工具:"
echo "1. definition - 获取符号定义"
echo "2. references - 查找符号引用"
echo "3. diagnostics - 获取诊断信息"
echo "4. hover - 显示悬停信息"
echo "5. rename_symbol - 重命名符号"
echo "6. edit_file - 编辑文件"
echo ""
echo "示例 JSON-RPC 请求格式:"
echo ""
cat << 'EOF'
# 获取定义
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "definition",
    "arguments": {
      "filepath": "/path/to/file.cpp",
      "line": 10,
      "character": 5
    }
  }
}

# 查找引用
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "references",
    "arguments": {
      "filepath": "/path/to/file.cpp",
      "line": 10,
      "character": 5
    }
  }
}

# 获取诊断
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "diagnostics",
    "arguments": {
      "filepath": "/path/to/file.cpp"
    }
  }
}
EOF

echo ""
echo "要查看实际交互，请:"
echo "1. 在 Claude Desktop 中使用该 MCP server"
echo "2. 或者运行集成测试: go test ./integrationtests/... -v"
