# llamaR

<img src="man/figures/llamaR.png" alt="llamaR logo" width="200" />

**A CLI-first AI coding agent, written in R.**

Built on the Model Context Protocol (MCP). Connects to LLMs (Anthropic, OpenAI, Ollama) and gives them tools to act.

The `llamar` CLI is the human-facing agent.
The `llamaR` package is the engine and MCP server.

-----

In Spanish, *llamar* (pronounced [“Ya Mar”](https://www.youtube.com/watch?v=p-2EZXOoFt8)) means “to call.”

-----

## Why R?

The same power as [moltbot](https://github.com/moltbot/moltbot) or [Claude Code](https://docs.anthropic.com/en/docs/claude-code), in a language you already know.

- **Readable** — R users can inspect exactly what the agent does
- **Extensible** — add tools by writing R functions
- **Tinyverse** — minimize dependencies, maximize stability
- **MCP-native** — skills are portable, not locked in

-----

## What is llamaR?

1. **`llamar` (CLI agent)**
   An interactive terminal agent that connects to LLMs and uses tools to act.
1. **MCP server**
   A standalone server exposing tools for any MCP client (Claude Desktop, Claude Code, etc.).

It can run:

- as a CLI agent for humans
- as a tool provider for other MCP clients
- as an MCP client connecting to other servers

-----

## Relationship to mcptools

llamaR draws inspiration from [mcptools](https://posit-dev.github.io/mcptools/).

The ecosystems have parallel structure:

|Role          |Posit (tidyverse)                      |cornyverse|
|--------------|---------------------------------------|----------|
|LLM API client|[ellmer](https://ellmer.tidyverse.org/)|llm.api   |
|Context tools |[btw](https://posit-dev.github.io/btw/)|fyi       |
|MCP bridge    |mcptools                               |llamaR    |

**Different philosophies:**

mcptools integrates R into the broader MCP ecosystem—Claude Desktop, VS Code Copilot, Positron, shiny apps via ellmer. It’s polished, on CRAN, and backed by Posit.

llamaR is a standalone agent runtime. It ships its own CLI, handles LLM connections internally, and doesn’t require external clients.

|If you want to…                               |Consider|
|----------------------------------------------|--------|
|Use R from Claude Desktop / VS Code / Positron|mcptools|
|Run an AI agent from your terminal            |llamaR  |

AI and CLI coding agents enable bespoke software. This is our take.

-----

## Tools

llamaR exposes tools to LLMs:

|Tool                |Description                           |
|--------------------|--------------------------------------|
|`bash`              |Run shell commands                    |
|`read_file`         |Read file contents                    |
|`write_file`        |Write or create files                 |
|`edit_file`         |Surgical file edits                   |
|`list_files`        |List directory contents               |
|`git`               |Status, diff, commit, log             |
|`run_r`             |Execute R code in a persistent session|
|`r_help`            |Query R documentation via fyi         |
|`installed_packages`|List and search R packages            |
|`web_search`        |Search the web via Tavily             |

Plus any tools from connected MCP servers.

### Web Search

Web search is powered by [Tavily](https://tavily.com), an AI-native search engine with a free tier. Set `TAVILY_API_KEY` in `~/.Renviron` to enable.

-----

## Architecture

### As a CLI Agent

```bash
llamar
```

```
> summarize this CSV
> fix the bug in app.R
> commit with a good message
> refactor this into smaller functions
```

### As an MCP Server

For Claude Desktop:

```json
{
  "mcpServers": {
    "llamaR": {
      "command": "Rscript",
      "args": ["-e", "llamaR::serve()"]
    }
  }
}
```

### As an MCP Client

```r
web_tools <- mcp_connect(port = 7851)
db_tools  <- mcp_connect(port = 7852)

all_tools <- c(
  mcp_tools_for_api(web_tools),
  mcp_tools_for_api(db_tools)
)
```

Chain tools from multiple servers.

-----

## Installation

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

-----

## Platform Support

|Platform|Status                          |
|--------|--------------------------------|
|Linux   |Fully supported                 |
|macOS   |Expected to work                |
|Windows |Partial (stdin handling pending)|

-----

## Design Philosophy

- CLI-first
- tinyverse: minimal dependencies
- model-agnostic (Ollama, Anthropic, OpenAI)
- MCP-native
- composable
- hackable

-----

## Status

Experimental. Interfaces may change.

-----

## License

MIT