package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/isaacphi/mcp-language-server/internal/lsp"
	"github.com/isaacphi/mcp-language-server/internal/tools"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "用法: %s <符号名>\n", os.Args[0])
		fmt.Fprintf(os.Stderr, "示例: %s foo_bar\n", os.Args[0])
		os.Exit(1)
	}

	symbolName := os.Args[1]
	workspaceDir, err := filepath.Abs("./integrationtests/workspaces/clangd")
	if err != nil {
		log.Fatalf("获取工作目录绝对路径失败: %v", err)
	}

	fmt.Printf("=== MCP Language Server 手动定义查找测试 ===\n")
	fmt.Printf("工作目录: %s\n", workspaceDir)
	fmt.Printf("查找符号: %s\n", symbolName)
	fmt.Println()

	// 创建上下文，设置超时
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// 启动 LSP 客户端
	fmt.Println("1. 启动 clangd...")
	client, err := lsp.NewClient("clangd", "--compile-commands-dir="+workspaceDir)
	if err != nil {
		log.Fatalf("启动 LSP 客户端失败: %v", err)
	}
	defer client.Close()

	fmt.Println("2. 初始化 LSP...")
	// 初始化 LSP 客户端
	_, err = client.InitializeLSPClient(ctx, workspaceDir)
	if err != nil {
		log.Fatalf("LSP 初始化失败: %v", err)
	}
	fmt.Println("✅ LSP 初始化成功")

	// 等待服务器就绪
	fmt.Println("3. 等待服务器就绪...")
	err = client.WaitForServerReady(ctx)
	if err != nil {
		log.Fatalf("服务器未就绪: %v", err)
	}
	fmt.Println("✅ 服务器就绪")

	// 打开主文件以触发索引
	mainFile := filepath.Join(workspaceDir, "src/main.cpp")
	fmt.Printf("4. 打开文件: %s\n", mainFile)
	err = client.OpenFile(ctx, mainFile)
	if err != nil {
		log.Printf("打开文件失败: %v", err)
	} else {
		fmt.Println("✅ 文件打开成功")
	}

	// 等待索引完成
	fmt.Println("5. 等待索引完成...")
	time.Sleep(10 * time.Second)

	// 查找符号定义
	fmt.Printf("5. 查找符号定义: %s\n", symbolName)
	result, err := tools.ReadDefinition(ctx, client, symbolName)
	if err != nil {
		log.Fatalf("查找定义失败: %v", err)
	}

	fmt.Println()
	fmt.Println("=== 查找结果 ===")
	fmt.Println(result)
}