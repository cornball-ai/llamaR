# llamaR

A CLI-first AI agent runtime for R. Self-hosted, model-agnostic, tinyverse.

**Reference:** ~/openclaw - TypeScript CLI agent we're interoperable with.

## Isomorphism with openclaw

llamaR aims to be interoperable with openclaw on front-end matters:

| Component | Approach |
|-----------|----------|
| Skills | Same SKILL.md format, same loading |
| Sessions | JSONL transcripts + JSON metadata (planned) |
| Memory | Daily markdown logs + MEMORY.md (planned) |
| Config | JSON with hierarchical overrides |

**Guidelines:**
1. If it can be a SKILL.md, make it a skill (portable)
2. If openclaw has a format, match it
3. R-specific features (stateful `run_r`) stay in llamaR, exposed via MCP

See `docs/isomorphism.md` for full details.

## Quick Start

```bash
# Start agent in current directory
llamar

# Resume last session
llamar --resume

# List sessions for this directory
llamar --list

# Use specific provider/model
llamar --provider ollama --model llama3.2
```

## Architecture

```
User (terminal)
     │
     ▼
┌─────────────────┐
│  llamar CLI     │  ← inst/bin/llamar (Rscript shebang)
└────────┬────────┘
         │
         ├── llm.api (provider abstraction)
         │      ├── Anthropic
         │      ├── OpenAI
         │      └── Ollama
         │
         └── llamaR MCP Server (port 7850)
                ├── File tools (read/write/list/grep)
                ├── R tools (run_r, r_help, installed_packages)
                ├── System tools (bash, git_*)
                ├── Web tools (web_search, fetch_url)
                └── Chat tools (chat, chat_models via llm.api)
```

## Package Structure

```
R/
├── config.R        # Config file loading (~/.llamar/config.json, .llamar/config.json)
├── context.R       # Context file loading (README.md, PLAN.md, fyi.md, etc.)
├── log.R           # Structured JSON logging
├── session.R       # Session persistence (.llamar/sessions/*.json)
├── skill.R         # Skill system (SKILL.md parsing, registry)
├── mcp-handler.R   # JSON-RPC request handling
├── mcp-transport.R # Stdio and socket transports
├── serve.R         # Main serve() export
├── tools.R         # Tool definitions (MCP schema)
├── tool-impl.R     # Tool implementations + built-in skill registration
├── install-cli.R   # CLI installer (install_cli/uninstall_cli)
└── utils.R         # Helpers (ok/err/log_msg)

inst/
├── bin/llamar      # CLI executable (symlinked to ~/bin/llamar)
└── tinytest/       # Tests (157 total)
```

## Key Files

| File | Purpose |
|------|---------|
| `.llamar/sessions/` | Project-local session storage |
| `.llamar/config.json` | Project config (provider, model, context_files) |
| `~/.llamar/config.json` | Global config defaults |
| `AGENTS.md` | Project-specific agent instructions |

## Context Files (Auto-loaded)

Default files loaded into system prompt (configurable via config):
- `README.md` - Project description
- `PLAN.md` - Development roadmap
- `fyi.md` - Package introspection (from fyi package)
- `AGENTS.md` - Behavior guidelines

## Environment Variables

Set in `~/.Renviron`:

| Variable | Required For |
|----------|--------------|
| `ANTHROPIC_API_KEY` | Anthropic provider |
| `OPENAI_API_KEY` | OpenAI provider |
| `TAVILY_API_KEY` | web_search tool |

## Config Example

```json
{
  "provider": "ollama",
  "model": "llama3.2",
  "port": 7850,
  "context_files": ["README.md", "PLAN.md", "fyi.md", "LLAMAR.md"]
}
```

## CLI Commands

In-session commands:
- `/quit`, `/exit`, `/q` - Exit
- `/tools` - List available tools
- `/sessions` - List sessions for this directory
- `/context` - Show loaded context files
- `/clear` - Clear conversation (keeps session)
- `/model <name>` - Switch model
- `/provider <p>` - Switch provider

## MCP Server

Two transport modes:

**Stdio** (for Claude Desktop):
```r
llamaR::serve()
```

**Socket** (for llamar CLI):
```r
llamaR::serve(port = 7850)
```

Claude Desktop config (`~/.config/claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "llamar": {
      "command": "Rscript",
      "args": ["-e", "llamaR::serve()"]
    }
  }
}
```

## Development

```bash
# Full workflow
r -e 'rformat::rformat_dir("R"); tinyrox::document(); tinypkgr::install(); tinytest::test_package("llamaR")'

# Regenerate fyi.md
r -e 'fyi::use_fyi_md("llamaR", docs = TRUE)'

# Run tests only
r -e 'tinytest::test_package("llamaR")'
```

## Coding Conventions

### Prefer system2() over system()

Use `system2()` for shell commands - it gives better control over stdout/stderr:
```r
# Good
system2("git", c("status", "--short"), stdout = TRUE)

# Avoid
system("git status --short", intern = TRUE)
```

### Shell commands need explicit bash

When using bash-specific features (like `read -e`), explicitly call bash since `/bin/sh` is dash on Ubuntu:
```r
system('bash -c "read -e -p \"> \" input && echo $input"', intern = TRUE)
```

## Connection Handling

The CLI automatically reconnects if the MCP server connection drops mid-session. When a tool call fails with "closed connection", it will:
1. Attempt to reconnect to the server
2. Retry the failed tool call
3. Continue the conversation

This handles transient socket issues without losing the session.

## Known Issues

### littler doesn't pass CLI args

The CLI uses `#!/usr/bin/env Rscript` instead of `#!/usr/bin/env r` because littler doesn't pass command-line arguments through shebang scripts. This means slightly slower startup but correct arg handling.

### MCP server port conflicts

If `llamar` fails to connect, check for stale server processes:
```bash
pkill -f "llamaR::serve"
```

## Dependencies

**Imports:**
- `jsonlite` - JSON handling

**Suggests:**
- `llm.api` - LLM provider abstraction (required for CLI agent)
- `tinytest` - Testing

## Exports

| Function | Purpose |
|----------|---------|
| `serve(port, cwd)` | Start MCP server |
| `install_cli(path, force)` | Install llamar to PATH |
| `uninstall_cli(path)` | Remove llamar from PATH |

## Roadmap

See `PLAN.md` for detailed development plan. Current status:
- Phase 1 (Core Loop) ✅
- Phase 2 (MCP Foundation) ✅
- Phase 3.1 (Session Persistence) ✅
- Phase 3.2 (Context Injection) ✅
- Phase 3.3 (Long-term Memory) - TODO
- Phase 4 (Channels) - TODO
- Phase 5 (Proactive Behavior) - TODO
