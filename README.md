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
- **Isomorphic** — skills work in llamaR *and* [openclaw](https://github.com/mariozechner/openclaw)

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

## Skills

Skills are portable agent extensions—Markdown files that teach the LLM how to use shell commands.

```markdown
---
name: weather
description: Get current weather (no API key required)
---

# Weather

```bash
curl -s "wttr.in/London?format=3"
```
```

Drop a `SKILL.md` file in `~/.llamar/skills/weather/` and it's immediately available.

### Isomorphic with openclaw

llamaR uses the same skill format as [openclaw](https://github.com/mariozechner/openclaw). Skills are portable between R (llamaR) and TypeScript (openclaw) agent runtimes.

```bash
# Use openclaw skills in llamaR
ln -s ~/.openclaw/skills ~/.llamar/skills
```

**Why this matters:**

- **Write once, run anywhere** — same skill works in both systems
- **No lock-in** — skills are Markdown, not code
- **Ecosystem access** — R users get the openclaw skill library
- **Community leverage** — contributions benefit both communities

**Tested openclaw skills:**

|Skill|Description|
|-----|-----------|
|`github`|GitHub CLI (`gh`) for issues, PRs, runs|
|`weather`|Weather via wttr.in|
|`tmux`|Remote-control tmux sessions|

See [docs/isomorphism.md](docs/isomorphism.md) for our full interoperability approach.

### R Skills

R runs from shell via [littler](https://github.com/eddelbuettel/littler) (`r`) or `Rscript`:

```markdown
---
name: r-eval
description: Execute R code
---

# R Evaluation

```bash
r -e 'summary(lm(mpg ~ wt, mtcars))'
```
```

Shell-based R is **stateless**—each call is a fresh session. For **stateful** R (persistent variables across calls), use llamaR's built-in `run_r` tool. openclaw users can access stateful R by connecting to llamaR as an MCP server.

See [docs/skills.md](docs/skills.md) for the full specification.

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

### System Requirements

- **R** (>= 4.4.0)
- **littler** — fast R scripting frontend (recommended)

```bash
# Ubuntu/Debian
sudo apt install littler

# Or from R
install.packages("littler")
```

### R Package

```r
# Install llamaR (not yet on CRAN)
remotes::install_github("cornball-ai/llamaR")

# Install the CLI to ~/bin
llamaR::install_cli()

# Add ~/bin to PATH if needed
export PATH="$HOME/bin:$PATH"
```

### Required R Packages

```r
# Core dependencies (on CRAN)
install.packages(c("curl", "jsonlite"))

# LLM provider abstraction (not on CRAN)
remotes::install_github("cornball-ai/llm.api")
```

### API Keys

Set in `~/.Renviron`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
TAVILY_API_KEY=tvly-...   # Optional, for web search
```

### Voice Mode (Optional)

Voice mode requires additional packages and services:

```r
# R packages
remotes::install_github("cornball-ai/stt.api")  # Speech-to-text
remotes::install_github("cornball-ai/tts.api")  # Text-to-speech

# System packages (Ubuntu)
sudo apt install sox alsa-utils ffmpeg
```

Voice services must be running:
- STT: `whisper` or compatible API on port 4123
- TTS: `qwen3-tts-api` or compatible API on port 7812

### Memory Index (Optional)

For searchable conversation history:

```r
install.packages("duckdb")
install.packages("digest")

# Import Claude Code history
llamaR::memory_import_claude()

# Search
llamaR::memory_search_fts("your query")
```

-----

## Quick Start

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