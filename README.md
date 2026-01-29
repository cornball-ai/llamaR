# llamaR

**llamaR is a CLI-first AI agent runtime for R built on the Model Context Protocol (MCP).**
It connects to LLMs (Anthropic, OpenAI, Ollama) and gives them direct access to a live R session with real tools.

The `llamar` CLI is the human-facing agent.
The `llamaR` package is the R engine and MCP server.

---

In Spanish, *llamar* (pronounced ["Ya Mar"](https://www.youtube.com/watch?v=p-2EZXOoFt8)) means “to call,” reflecting that the tool calls out to language models and MCP tools.

---

## What is llamaR?

llamaR provides two things:

1. **`llamar` (CLI agent)**
   An interactive terminal agent that connects to LLMs and uses MCP tools to act.

2. **MCP server (R)**
   A standalone MCP server exposing R-native tools: file operations, git, R execution, documentation lookup, and data inspection.

It can run:

* as a tool provider for Claude Desktop or other MCP clients
* as a CLI agent for humans
* as an MCP client connecting to other MCP servers

---

## Why llamaR?

llamaR draws inspiration from several projects:

- [btw](https://posit-dev.github.io/btw/) — directly inspired `fyi`
- [moltbot](https://github.com/moltbot/moltbot) — the CLI-first, multi-channel personal agent pattern
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) — terminal-native AI workflows

llamaR and the mcptools ecosystems have parallel structure:

| Role              | Posit (tidyverse)                        | cornyverse                |
| ----------------- | ---------------------------------------- | ------------------------- |
| LLM API client    | [ellmer](https://ellmer.tidyverse.org/)  | llm.api                   |
| Context tools     | [btw](https://posit-dev.github.io/btw/)  | fyi                       |
| MCP bridge        | mcptools                                 | llamaR                    |

**Different philosophies:**

mcptools integrates R into the broader MCP ecosystem—Claude Desktop, VS Code Copilot, Positron, shiny apps via ellmer. It's polished, on CRAN, and backed by Posit.
 
llamaR is a standalone agent runtime. It ships its own CLI, handles LLM connections internally, and doesn't require external clients. It follows tinyverse principles: minimal dependencies, base R idioms, no heavy frameworks.

| If you want to...                              | Consider     |
| ---------------------------------------------- | ------------ |
| Use R from Claude Desktop / VS Code / Positron | mcptools     |
| Build shiny apps with MCP tools                | mcptools     |
| Run an AI agent from your terminal             | llamaR       |
| Stay in the tinyverse                          | llamaR       |
| Avoid external client dependencies             | llamaR       |

AI and CLI coding agents enable bespoke software, this is our take.

---

## R-Specific Superpowers

llamaR exposes real R tools to LLMs (not just `Rscript` shell calls):

| Tool                 | Description                                       |
| -------------------- | ------------------------------------------------- |
| `run_r`              | Execute arbitrary R code and return results       |
| `r_help`             | Query R documentation for any function or package |
| `installed_packages` | List and search installed R packages              |
| `read_csv`           | Read CSV and return summary statistics            |
| `chat`               | Call LLMs via `llm.api`                           |
| file ops             | Read/write/list files                             |
| git ops              | Repo inspection and commands                      |

This allows:

* stateful data analysis
* inspection of R environments
* iterative computation
* agent-driven exploration

---

## Architecture

llamaR supports three roles:

### 1. As an MCP Server (for other agents)

Example Claude Desktop config:

```json
{
  "mcpServers": {
    "llamaR": {
      "command": "r",
      "args": ["-e", "llamaR::serve()"]
    }
  }
}
```

Now Claude can:

* run R code
* inspect packages
* analyze data
* use R as a reasoning engine

---

### 2. As an MCP Client (connecting to other servers)

```r
r_tools   <- mcp_connect(port = 7850)
web_tools <- mcp_connect(port = 7851)
db_tools  <- mcp_connect(port = 7852)

all_tools <- c(
  mcp_tools_for_api(r_tools),
  mcp_tools_for_api(web_tools),
  mcp_tools_for_api(db_tools)
)
```

This allows chaining:

* R tools
* filesystem tools
* database tools
* APIs
* other agents

---

### 3. As a CLI Agent (for humans)

```bash
llamar
```

Interactive prompt:

```
> load this CSV and summarize it
> explain this error
> refactor this function
> install missing packages and retry
```

---

## Installation

Planned as an R package with optional CLI:

```r
install.packages("llamaR")
llamaR::install_cli()
```

Then:

```bash
llamar
```

Or from R:

```r
llamaR::run()
```

---

## Platform Support

| Platform | Status                           |
| -------- | -------------------------------- |
| Linux    | Fully supported                  |
| macOS    | Expected to work                 |
| Windows  | Partial (stdin handling pending) |

The MCP server is pure R and works everywhere.

---

## Design Philosophy

* CLI-first, not IDE-first
* tinyverse: minimal dependencies
* model-agnostic
* MCP-native
* composable
* scriptable
* inspectable
* stateful
* hackable

No Shiny. No RStudio dependency. No heavy frameworks.

---

## Roadmap

* Proper package structure (DESCRIPTION, NAMESPACE)
* Cross-platform input backend (pure R readline)
* Session management (history + context)
* Streaming responses
* Improved error handling
* `tinytest` suite
* CI
* Documentation and examples

---

## When should you use llamaR?

Use llamaR if you want:

* an AI agent that can *actually run R*
* a CLI interface for R + LLM workflows
* an MCP server exposing R tools
* a hub that connects multiple MCP servers
* something closer to Claude Code, but R-native

Use `mcptools` if you only want:

* to expose one or two R functions as MCP endpoints

---

## Status

Experimental.
Interfaces may change.
Designed for research and agent workflows.

---

## License

MIT
