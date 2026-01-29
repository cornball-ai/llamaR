# llamar

A simple Claude Code-style demo using R and `menu()`.

## What is this?

A minimal example showing how to build an interactive CLI agent in R using:

- `readline()` for user input
- `menu()` for interactive choices
- Simple intent parsing with regex
- Tool dispatch with `switch()`

## Usage

```bash
# With littler
r llamar.R

# Or with Rscript
Rscript llamar.R
```

## Commands

| Command | Description |
|---------|-------------|
| `read <file>` | Display file contents |
| `find <pattern>` | Find files matching glob |
| `search <pattern>` | Search file contents |
| `run <command>` | Execute shell command |
| `write <file>` | Write content to file |
| `help` | Show help |
| `quit` | Exit |

## Example Session

```
> read README.md
[Reading: README.md]
   1 | # llamar
   2 |
   3 | A simple Claude Code-style demo...

> find *.R
[Glob: *.R in .]
- ./llamar.R
( 1 files)

> search function
[Grep: function in .]
./llamar.R:
    12:   tool_read <- function(path) {
    32:   tool_glob <- function(pattern, path = ".") {
    45:   tool_grep <- function(pattern, path = ".") {
```

## Architecture

```
User Input
    │
    ▼
parse_intent()  ──▶  keyword matching
    │
    ▼
run_tool()  ──▶  switch() dispatch
    │
    ├──▶ tool_read()
    ├──▶ tool_glob()
    ├──▶ tool_grep()
    ├──▶ tool_bash()
    └──▶ tool_write()
```

## MCP Server

`mcp_server.R` is a minimal MCP (Model Context Protocol) server using stdio transport.

**Only dependency:** `jsonlite`

### How it works

```
Claude Desktop/Client
        │
        │ stdin: JSON-RPC request
        ▼
   ┌─────────────┐
   │ mcp_server.R │  ◄── reads line from stdin()
   └─────────────┘      parses JSON, handles method
        │               writes response to stdout()
        │ stdout: JSON-RPC response
        ▼
Claude Desktop/Client
```

### Tools provided

| Tool | Description |
|------|-------------|
| `read_file` | Read file contents |
| `list_files` | List directory with optional glob |
| `run_r` | Execute R code |

### Claude Desktop config

Add to `~/.config/claude-desktop/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "llamar": {
      "command": "r",
      "args": ["/path/to/mcp_server.R"]
    }
  }
}
```

### Test manually

```bash
# Start server
r mcp_server.R

# Paste JSON-RPC (server reads from stdin):
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}
{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"list_files","arguments":{"path":"."}}}
```

### MCP Protocol basics

MCP uses JSON-RPC 2.0. Key methods:

| Method | Purpose |
|--------|---------|
| `initialize` | Handshake, return capabilities |
| `tools/list` | Return available tools |
| `tools/call` | Execute a tool |

Request format:
```json
{"jsonrpc": "2.0", "id": 1, "method": "tools/call", "params": {"name": "read_file", "arguments": {"path": "README.md"}}}
```

Response format:
```json
{"jsonrpc": "2.0", "id": 1, "result": {"content": [{"type": "text", "text": "file contents..."}]}}
```

## License

MIT
