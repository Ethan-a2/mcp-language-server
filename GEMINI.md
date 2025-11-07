# Project Overview

This project is a Language Server Protocol (LSP) server that is exposed through the Model Context Protocol (MCP). It allows Large Language Models (LLMs) to interact with language servers, enabling them to perform code analysis and manipulation tasks. The server is written in Go and uses the `mcp-go` library for MCP communication. It can be configured to work with various language servers, such as `gopls` for Go, `rust-analyzer` for Rust, and `pyright` for Python.

The server provides the following tools to the LLM:

*   `edit_file`: Apply multiple text edits to a file.
*   `definition`: Read the source code definition of a symbol.
*   `references`: Find all usages and references of a symbol.
*   `diagnostics`: Get diagnostic information for a specific file.
*   `hover`: Get hover information (type, documentation) for a symbol.
*   `rename_symbol`: Rename a symbol and update all references.

# Building and Running

A `justfile` is provided for convenience. The following commands can be used to build, run, and test the project:

*   `just build`: Build the server.
*   `just install`: Install the server locally.
*   `just test`: Run the tests.
*   `just check`: Run code audit checks.
*   `just fmt`: Format the code.
*   `just generate`: Generate LSP types and methods.

To run the server, you need to provide the workspace directory and the language server command as command-line arguments. For example:

```bash
mcp-language-server --workspace /path/to/your/project --lsp gopls
```

# Development Conventions

The project follows standard Go development conventions. It uses `testify` for testing and has a snapshot test suite for integration tests. The snapshot tests run actual language servers on mock workspaces and capture the output and logs. To update the snapshots, run `UPDATE_SNAPSHOTS=true go test ./integrationtests/...`.

Pull requests should be small and focused. Issues should be opened for any substantial changes. AI-generated code is acceptable as long as it is tested, passes checks, and is of reasonable quality.
