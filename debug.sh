#!/bin/bash
# 调试 mcp-language-server + clangd 的脚本

set -e

# 配置这些路径
MCP_SERVER="/media/code/llm/mcp-language-server/mcp-language-server"
CPP_PROJECT="/media/code/llm/mcp-language-server/integrationtests/tests/clangd/definition"
CLANGD="/opt/clangd_21.1.0/bin/clangd"
BUILD_DIR="/media/code/llm/mcp-language-server/integrationtests/workspaces/clangd"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== MCP Language Server + clangd 调试 ===${NC}\n"

# 1. 检查必要文件
echo -e "${YELLOW}[1/6] 检查必要文件...${NC}"
if [ ! -f "$MCP_SERVER" ]; then
    echo -e "${RED}错误: mcp-language-server 不存在: $MCP_SERVER${NC}"
    exit 1
fi
echo "✓ mcp-language-server: $MCP_SERVER"

if [ ! -f "$CLANGD" ]; then
    echo -e "${RED}错误: clangd 不存在: $CLANGD${NC}"
    exit 1
fi
echo "✓ clangd: $CLANGD"

if [ ! -d "$CPP_PROJECT" ]; then
    echo -e "${RED}错误: C++ 项目目录不存在: $CPP_PROJECT${NC}"
    exit 1
fi
echo "✓ C++ 项目: $CPP_PROJECT"

# 2. 检查 compile_commands.json
echo -e "\n${YELLOW}[2/6] 检查编译数据库...${NC}"
if [ ! -f "$BUILD_DIR/compile_commands.json" ]; then
    echo -e "${RED}警告: compile_commands.json 不存在${NC}"
    echo "尝试生成..."
    cd "$CPP_PROJECT"
    if [ -f "CMakeLists.txt" ]; then
        cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=1 -B build
        echo -e "${GREEN}✓ 已生成 compile_commands.json${NC}"
    else
        echo -e "${RED}错误: 找不到 CMakeLists.txt，无法生成编译数据库${NC}"
        exit 1
    fi
else
    echo "✓ compile_commands.json: $BUILD_DIR/compile_commands.json"
    ENTRIES=$(jq '. | length' "$BUILD_DIR/compile_commands.json")
    echo "  包含 $ENTRIES 个编译条目"
fi

# 3. 测试 clangd 单独运行
echo -e "\n${YELLOW}[3/6] 测试 clangd 独立运行...${NC}"
$CLANGD --version
echo "✓ clangd 可以正常运行"

# 4. 创建日志目录
echo -e "\n${YELLOW}[4/6] 创建日志目录...${NC}"
LOG_DIR="./mcp-debug-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
echo "✓ 日志目录: $LOG_DIR"

# 5. 运行 mcp-language-server
echo -e "\n${YELLOW}[5/6] 启动 mcp-language-server (按 Ctrl+C 停止)...${NC}"
echo "日志将保存到: $LOG_DIR/mcp-server.log"
echo -e "${GREEN}开始监控日志...${NC}\n"

export LOG_LEVEL=DEBUG

"$MCP_SERVER" \
  --workspace "$CPP_PROJECT" \
  --lsp "$CLANGD" \
  -- \
  --compile-commands-dir="$BUILD_DIR" \
  --background-index \
  --log=verbose \
  2>&1 | tee "$LOG_DIR/mcp-server.log"

# 6. 日志分析提示
echo -e "\n${YELLOW}[6/6] 调试提示:${NC}"
echo "1. 查看完整日志:"
echo "   cat $LOG_DIR/mcp-server.log"
echo ""
echo "2. 搜索错误信息:"
echo "   grep -i error $LOG_DIR/mcp-server.log"
echo "   grep -i warning $LOG_DIR/mcp-server.log"
echo ""
echo "3. 查看 clangd 输出:"
echo "   grep 'clangd' $LOG_DIR/mcp-server.log"
echo ""
echo "4. 查看符号解析相关:"
echo "   grep -i 'definition\|reference\|symbol' $LOG_DIR/mcp-server.log"
