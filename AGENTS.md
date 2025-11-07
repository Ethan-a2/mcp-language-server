# MCP Language Server - Project Context

## Project Overview

This is an **MCP (Model Context Protocol) Language Server** - a Go-based server that bridges LLMs with language servers, providing semantic code navigation and manipulation capabilities. The project acts as an MCP server that exposes Language Server Protocol (LSP) functionality to AI assistants.

**Key Technologies:**
- **Language**: Go 1.24.0
- **Protocol**: MCP (Model Context Protocol) + LSP (Language Server Protocol)
- **Main Dependencies**: 
  - `github.com/mark3labs/mcp-go` for MCP communication
  - Custom LSP client implementation (based on gopls code)
  - Standard Go tooling for testing and static analysis

**Architecture:**
- `main.go` - Entry point and server lifecycle management
- `internal/lsp/` - LSP client implementation and protocol handling
- `internal/tools/` - MCP tool implementations (definition, references, diagnostics, etc.)
- `internal/protocol/` - LSP type definitions and protocol handling
- `internal/watcher/` - Workspace file watching capabilities
- `integrationtests/` - Comprehensive test suite with snapshot testing

## Building and Running

### Development Commands
```bash
# Build the project
just build    # or: go build -o mcp-language-server

# Install locally
just install  # or: go install

# Run tests
just test     # or: go test ./...

# Format code
just fmt      # or: gofmt -w .

# Run comprehensive checks
just check    # Includes formatting, staticcheck, errcheck, gopls check, govulncheck

# Generate LSP types and methods
just generate # or: go run ./cmd/generate

# Update snapshot tests
just snapshot # or: UPDATE_SNAPSHOTS=true go test ./integrationtests/...
```

### Installation and Setup
```bash
# Install the latest version
go install github.com/isaacphi/mcp-language-server@latest

# Run with specific language server
mcp-language-server --workspace /path/to/project --lsp gopls
```

### Configuration for MCP Clients
The server requires workspace directory and LSP command configuration. Environment variables can be passed through to the underlying language server.

## Development Conventions

### Code Style
- **Formatting**: Uses `gofmt` for consistent code formatting
- **Static Analysis**: Comprehensive tooling including `staticcheck`, `errcheck`, `gopls check`, and `govulncheck`
- **Testing**: Snapshot-based integration testing for LSP interactions
- **Error Handling**: Explicit error handling with structured logging

### Project Structure
- **Clean Architecture**: Clear separation between MCP protocol handling, LSP client logic, and tool implementations
- **Modular Design**: Each tool (definition, references, etc.) is implemented as a separate module
- **Context-Driven**: Heavy use of Go contexts for request lifecycle management

### Testing Strategy
- **Unit Tests**: Standard Go unit tests for individual components
- **Integration Tests**: Snapshot testing with real language servers (gopls, rust-analyzer, pyright, typescript-language-server)
- **Mock Workspaces**: Predefined workspaces in `integrationtests/workspaces/` for consistent testing
- **Snapshot Updates**: Automated snapshot updates for test maintenance

### Logging and Debugging
- **Structured Logging**: Custom logging package with different components (Core, LSP, etc.)
- **Debug Mode**: Set `LOG_LEVEL=DEBUG` for verbose logging including LSP message traces
- **Parent Process Monitoring**: Built-in monitoring for proper cleanup when parent process terminates

## Available MCP Tools

The server exposes these semantic code tools to LLMs:

1. **`definition`** - Retrieve complete source code definitions of symbols
2. **`references`** - Find all usages and references of symbols throughout codebase
3. **`diagnostics`** - Get diagnostic information (errors, warnings) for files
4. **`hover`** - Display documentation and type hints for code locations
5. **`rename_symbol`** - Rename symbols across the entire project
6. **`edit_file`** - Make precise text edits to files using line numbers
7. **`get_codelens`** - Retrieve CodeLens information from language servers
8. **`execute_codelens`** - Execute CodeLens actions

## Supported Language Servers

- **Go**: gopls
- **Rust**: rust-analyzer  
- **Python**: pyright-langserver
- **TypeScript**: typescript-language-server
- **C/C++**: clangd
- **Other**: Any stdio-based LSP server

## Key Implementation Details

### LSP Integration
- Uses modified gopls protocol code for LSP communication
- Handles LSP's flexible return types with interface workarounds
- Implements proper LSP lifecycle (initialize → shutdown → exit)
- Maintains diagnostic cache and open file tracking

### MCP Protocol
- Built on `mcp-go` library for MCP communication
- Implements proper MCP server patterns with recovery and logging
- Tools return structured responses suitable for LLM consumption

### Workspace Management
- Real-time file watching for workspace changes
- Automatic file opening/closing with LSP server
- Parent process monitoring for graceful shutdown

## Contributing Guidelines

- **Keep PRs small** and open Issues first for substantial changes
- **AI-generated code is acceptable** if tested, passes checks, and maintains quality
- **Testing required**: All changes must pass the comprehensive test suite
- **Snapshot updates**: Use `UPDATE_SNAPSHOTS=true` when updating integration tests
- **Code quality**: Must pass all static analysis tools in `just check`

## Development Workflow

1. **Setup**: Clone repo and run `just install` for local development
2. **Testing**: Use `just test` for unit tests, integration tests run automatically
3. **Development**: Make changes and rebuild with `just build`
4. **Quality Assurance**: Run `just check` before submitting PRs
5. **Debugging**: Set `LOG_LEVEL=DEBUG` for verbose troubleshooting

This project is beta software focused on providing robust LSP capabilities to AI assistants through the MCP protocol.

## Qwen Added Memories
- MCP Language Server integration tests use snapshot testing pattern with common.SnapshotTest() function, testing various language constructs (functions, classes, methods, structs, types, constants, variables) across different language servers (clangd, gopls, rust-analyzer, pyright, typescript-language-server). Tests include indexing wait periods and proper timeout management.
- Clangd definition test file details: Tests ReadDefinition tool with C++ constructs including functions (foo_bar, helperFunction), classes (TestClass), methods (method), structs (TestStruct), type aliases (TestType), constants (TEST_CONSTANT), and variables (TEST_VARIABLE). Uses 10-second indexing wait for main test, 5-second for cross-file test. Employs snapshot testing with common.SnapshotTest() and validates results contain expected text patterns.
- Clangd integration test execution results: TestReadDefinition passed in 13.98s with all 7 subtests (Function, Class, Method, Struct, Type, Constant, Variable) passing. TestReadDefinitionInAnotherFile passed in 8.37s with cross-file function definition test passing. Total test time: 22.346s. Tests successfully validate ReadDefinition tool functionality with clangd for various C++ constructs.
- Manual command-line implementation steps for TestReadDefinition: 1) Create manual_demo.go with LSP client initialization using lsp.NewClient("clangd", "--compile-commands-dir="+workspaceDir), 2) Use absolute path for workspace directory with filepath.Abs(), 3) Initialize LSP with client.InitializeLSPClient(ctx, workspaceDir), 4) Wait for server readiness with client.WaitForServerReady(ctx), 5) Open main.cpp file to trigger indexing with client.OpenFile(ctx, mainFile), 6) Wait 10 seconds for indexing completion, 7) Use tools.ReadDefinition(ctx, client, symbolName) to find symbol definitions, 8) Display results with file path, range, and line-numbered source code. Usage: go run manual_demo.go <symbol_name>. Successfully tested with foo_bar and TestClass symbols.
