# llamaR Development Plan

## Vision

A CLI-first AI agent runtime for R. Self-hosted, model-agnostic, tinyverse.

## Guiding Principles

- Base R over tidyverse
- Minimal dependencies
- MCP-native (tools are portable)
- Local-first (Ollama priority)
- Composable over monolithic

---

## Phase 1: Core Loop ✅

Get the fundamental agent cycle working.

### 1.1 R Execution Engine
- [x] `run_r()` — execute R code, capture output + errors
- [x] Stateful session — environment persists across calls
- [x] `r_help()` — query R documentation
- [x] `installed_packages()` — list/search packages

### 1.2 LLM Backend (llm.api)
- [x] Anthropic support (Claude)
- [x] OpenAI support
- [x] **Ollama support** — priority for local inference
- [ ] ~~Streaming responses~~ (not needed for agent loop)
- [x] Tool/function calling interface

### 1.3 CLI Agent (`llamar`)
- [x] Interactive REPL loop
- [x] Message → LLM → tool calls → response cycle
- [x] Basic conversation history (in-memory)
- [x] Clean exit handling

### 1.4 File Operations
- [x] `read_file()` / `write_file()` / `list_files()`
- [x] Working directory awareness
- [ ] ~~Path safety (no escaping workspace)~~ (LLM asks for permission - good UX)

---

## Phase 2: MCP Foundation ✅

Make llamaR speak the protocol.

### 2.1 MCP Server
- [x] `llamaR::serve()` — expose tools via MCP
- [x] JSON-RPC over stdio
- [x] Tool discovery (`tools/list`)
- [x] Tool invocation (`tools/call`)
- [x] Works with Claude Desktop, Claude Code

### 2.2 MCP Client (in llm.api)
- [x] `mcp_connect()` — connect to external MCP servers
- [x] `mcp_tools()` — list available tools
- [x] Tool call forwarding
- [ ] Aggregate tools from multiple servers

### 2.3 Skill System (fyi)
- [ ] Skill = directory with `SKILL.md` + R functions
- [ ] `fyi::register_skill()` — load a skill
- [ ] `fyi::list_skills()` — discover available skills
- [ ] Skills export MCP-compatible tool definitions
- [ ] Copy-paste install from community skills

---

## Phase 3: Context & Memory

Make the agent remember.

### 3.1 Conversation Persistence ✅
- [x] Save/load conversation history (JSON)
- [x] Session IDs (date + random hex)
- [x] `llamar --continue` to resume latest session
- [x] `llamar --session <id>` to resume specific session
- [x] `llamar --list` / `/sessions` to list sessions
- [x] Project-local storage (`.llamar/sessions/`)

### 3.2 Context Injection
- [ ] `LLAMAR.md` — project-level instructions
- [ ] `SOUL.md` — personality/behavior guidelines
- [ ] Workspace-aware context loading

### 3.3 Long-term Memory (later)
- [ ] User facts/preferences (Markdown or SQLite)
- [ ] RAG over past conversations
- [ ] Explicit `remember` / `forget` commands

---

## Phase 4: Channels (SLOW)

Messaging integrations. Personal use first.

### 4.1 Signal
- [ ] signal-cli integration
- [ ] Inbound message handling
- [ ] Outbound replies
- [ ] Allowlist for senders

### 4.2 iMessage (macOS only)
- [ ] AppleScript or `imessage-cli` bridge
- [ ] Same inbound/outbound pattern
- [ ] Group handling (if needed)

### 4.3 Future Channels
- Telegram (grammY or bot API)
- Discord (later)
- Slack (later)

---

## Phase 5: Proactive Behavior (DELIBERATE)

Let the agent initiate. Earn trust first.

### 5.1 Scheduled Tasks
- [ ] Cron-like scheduling
- [ ] Daily summaries
- [ ] Reminder system

### 5.2 Event Triggers
- [ ] File watchers
- [ ] Webhook endpoints
- [ ] Email (Gmail Pub/Sub pattern)

### 5.3 Autonomous Actions
- [ ] Gated by explicit user approval
- [ ] Audit log of actions taken
- [ ] Kill switch

---

## Architecture Notes

```
User (terminal)
     │
     ▼
┌─────────────────┐
│  llamar CLI     │  ← interactive agent
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  llm.api        │  ← model-agnostic LLM calls
└────────┬────────┘
         │
         ├── Anthropic
         ├── OpenAI
         └── Ollama (local)

┌─────────────────┐
│  llamaR (MCP)   │  ← R tools exposed via MCP
└────────┬────────┘
         │
         ├── run_r
         ├── r_help
         ├── file ops
         └── fyi skills
```

---

## Non-Goals (for now)

- Shiny UI
- RStudio integration
- Cloud deployment
- Multi-user / auth
- Paid API wrappers

---

## Open Questions

1. **Session isolation** — one R session per conversation, or shared?
2. **Skill format** — match MCP tool schema exactly, or R-native with adapter?
3. **Memory format** — Markdown (human-readable) vs SQLite (queryable)?
4. **Channel security** — allowlist-only, or pairing codes like moltbot?

---

## Next Actions

1. ~~Get `llamar` CLI loop working with Ollama~~ ✅
2. ~~Implement core R tools (run_r, r_help, file ops)~~ ✅
3. ~~Test MCP server mode with Claude Desktop~~ ✅
4. ~~Implement session persistence~~ ✅
5. Add `LLAMAR.md` context injection (3.2)
6. Document skill format for fyi (2.3)
