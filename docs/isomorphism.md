# Isomorphism with openclaw

llamaR aims to be interoperable with [openclaw](https://github.com/mariozechner/openclaw) on front-end matters. This document describes our approach.

## Philosophy

Two agent runtimes, one ecosystem:

| Layer | llamaR | openclaw |
|-------|--------|----------|
| Language | R | TypeScript |
| Runtime | Single-threaded R process | Node.js |
| Strength | R ecosystem, data science | Web, async, plugins |

Rather than building parallel ecosystems, we share what can be shared.

## What We Share

### Skills (SKILL.md)

Same format, same loading, same behavior.

```
~/.llamar/skills/     # llamaR reads from here
~/.openclaw/skills/   # openclaw reads from here
```

Symlink one to the other and skills work in both.

**Verified openclaw skills:**

| Skill | Works in llamaR | Notes |
|-------|-----------------|-------|
| `github` | ✅ | `gh` CLI for issues, PRs, CI runs |
| `weather` | ✅ | wttr.in weather lookup |
| `tmux` | ✅ | Remote-control tmux sessions |

Shell-based skills work without modification. llamaR templates `{baseDir}` to the skill's directory using `gsub("{baseDir}", dirname(path), body)`, so helper scripts resolve correctly when symlinked.

See [skills.md](skills.md) for the full specification.

### Session Format (planned)

JSONL transcripts with JSON metadata store:

```
.llamar/sessions/
├── sessions.json           # Metadata index
└── 2025-01-30_abc123.jsonl # Transcript
```

Compatible structure enables:
- Session migration between runtimes
- Shared tooling for session analysis
- Consistent backup/restore

### Memory Format (planned)

Markdown-based memory with optional database indexing:

```
~/.llamar/
├── MEMORY.md              # Curated long-term memory
└── memory/
    ├── 2025-01-30.md      # Daily append log
    └── memory.duckdb      # Vector + FTS index
```

#### Database Choice: DuckDB vs SQLite

openclaw uses SQLite for the memory index. llamaR uses DuckDB. Analysis:

**Real-world usage data (2026-01):**

| Agent | Storage | Sessions | Largest |
|-------|---------|----------|---------|
| Claude Code | 522 MB | 899 | 60 MB |
| OpenAI Codex | 12 MB | 5 | 7.3 MB |
| llamaR | 332 KB | few | small |

At 500+ MB scale (heavy Claude Code user), DuckDB's advantages apply:

| Factor | SQLite | DuckDB | At 500MB |
|--------|--------|--------|----------|
| Vector similarity | Row-by-row | Vectorized | **DuckDB** |
| Bulk reindex | Slow | Fast | **DuckDB** |
| Hybrid search scoring | OK | Optimized | **DuckDB** |
| Native arrays | JSON text | `DOUBLE[]` | **DuckDB** |
| Startup latency | Fast | Slower | SQLite |
| Concurrent writes | WAL | Single writer | SQLite |

**Decision**: DuckDB for llamaR because:
1. Memory indexing is async (startup latency doesn't block CLI)
2. Single-writer is fine (indexer is one process)
3. Vector search at scale benefits from columnar execution
4. Native `DOUBLE[]` arrays avoid JSON encoding overhead

**Schema compatibility**: Same logical tables (files, chunks, meta), different engine.

```sql
-- DuckDB schema (llamaR)
CREATE TABLE chunks (
  id TEXT PRIMARY KEY,
  path TEXT NOT NULL,
  text TEXT NOT NULL,
  embedding DOUBLE[] NOT NULL,  -- native array
  ...
);

-- SQLite schema (openclaw)
CREATE TABLE chunks (
  id TEXT PRIMARY KEY,
  path TEXT NOT NULL,
  text TEXT NOT NULL,
  embedding TEXT NOT NULL,  -- JSON array
  ...
);
```

### Configuration (planned)

JSON/JSON5 with hierarchical overrides:

```
~/.llamar/config.json      # Global defaults
.llamar/config.json        # Project overrides
```

## Channels (Signal, Discord, etc.)

### Signal Config Comparison

**openclaw** (`~/.openclaw/openclaw.json`):
```json5
{
  channels: {
    signal: {
      enabled: true,
      account: "+15551234567",
      cliPath: "signal-cli",
      httpHost: "127.0.0.1",
      httpPort: 8080,
      httpUrl: "http://127.0.0.1:8080",  // overrides host/port
      autoStart: true,
      dmPolicy: "pairing",  // pairing | allowlist | open | disabled
      allowFrom: ["+15557654321"],
      groupPolicy: "allowlist",
      // Multi-account support
      accounts: {
        "work": { account: "+15559999999", allowFrom: ["*"] }
      }
    }
  }
}
```

**llamaR** (`~/.llamar/config.json`):
```json
{
  "channels": {
    "signal": {
      "enabled": true,
      "account": "+15551234567",
      "httpHost": "127.0.0.1",
      "httpPort": 8080,
      "httpUrl": "http://127.0.0.1:8080",
      "allowFrom": ["+15557654321"]
    }
  }
}
```

Config structure now matches openclaw.

### Feature Parity

| Feature | openclaw | llamaR | Notes |
|---------|----------|--------|-------|
| Basic send/receive | ✅ | ✅ | |
| Typing indicators | ✅ | ✅ | |
| Per-sender history | ✅ | ✅ | |
| Allowlist | ✅ | ✅ | |
| Message chunking | ✅ | ✅ | Same config: `textChunkLimit`, `chunkMode` |
| Attachments | ✅ | ✅ | Send and receive |
| Group support | ✅ | ✅ | Group ID, name, and type in metadata |
| Reactions | ✅ | ✅ | Send and receive |
| Read receipts | ✅ | ✅ | Delivery and read receipts |
| Multi-account | ✅ | ❌ | Low priority |
| Pairing codes | ✅ | ❌ | Medium priority |
| Auto-spawn daemon | ✅ | ❌ | Low priority |

### Running Modes

| Mode | openclaw | llamaR |
|------|----------|--------|
| Integrated gateway | ✅ Gateway daemon | ❌ |
| Standalone bot | ❌ | ✅ `llamar-signal` |
| Terminal REPL | ✅ `openclaw chat` | ✅ `llamar` |

### TODO for Signal Parity

**Completed (Sprint 2):**
- ~~Move config under `channels.signal.*`~~ ✅
- ~~Add `httpUrl` as alternative to `httpHost`/`httpPort`~~ ✅
- ~~Message chunking for long responses~~ ✅
- ~~Group message handling~~ ✅
- ~~Attachment support~~ ✅
- ~~Reactions~~ ✅
- ~~Read receipts~~ ✅

**Medium:**
- Pairing code flow for initial setup

**Low:**
- Multi-account support
- Auto-spawn daemon

## Workspace Files

| File | Purpose | llamaR Status |
|------|---------|---------------|
| `SOUL.md` | Agent personality | ✅ |
| `USER.md` | User preferences | ✅ |
| `MEMORY.md` | Long-term memory | ✅ |
| `AGENTS.md` | Operating instructions | ✅ |
| `memory/YYYY-MM-DD.md` | Daily logs | ❌ Planned |
| `IDENTITY.md` | Agent name/emoji | ❌ |
| `TOOLS.md` | Tool notes | ❌ |
| `HEARTBEAT.md` | Proactive checklist | ❌ |

## What Differs

### Stateful R

llamaR provides `run_r`—a persistent R session in the MCP server. This is R-specific and not isomorphic.

openclaw users who need stateful R connect to llamaR as an MCP server:

```bash
# Start llamaR MCP server
Rscript -e 'llamaR::serve(port = 7850)'
```

### Transport

| llamaR | openclaw |
|--------|----------|
| stdio (MCP) | WebSocket gateway |
| Socket (CLI) | HTTP/WS protocol |

Different transports, but MCP compatibility means tools work across both.

### Plugin Hooks

openclaw has a rich plugin system with lifecycle hooks. llamaR focuses on:
- Skills (SKILL.md) for shell-based extensions
- R functions for R-native tools
- MCP for tool composition

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| Skills (SKILL.md) | ✅ Done | Full compatibility |
| Session format | 🔄 Planned | Adopt JSONL + metadata store |
| Memory format | 🔄 Planned | Adopt daily logs + MEMORY.md |
| SQLite indexes | 🔄 Planned | Same schema as openclaw |
| Config format | ⚠️ Partial | JSON works, need JSON5 + includes |

## Why Isomorphism?

**For users:**
- Learn once, use in both
- Skills aren't locked to a runtime
- Choose the right tool for the job

**For the R community:**
- Access to openclaw's skill ecosystem
- Contributions benefit TypeScript users too
- R becomes a first-class agent runtime

**For maintainers:**
- Shared skill testing
- Documentation applies to both
- Smaller surface area to maintain

## Contributing

When adding features to llamaR, consider:

1. **Can this be a SKILL.md?** If yes, make it a skill.
2. **Does openclaw have this?** If yes, match their format.
3. **Is this R-specific?** If yes, document the boundary.

Skills should be created in a way that works in both systems. R-specific features should be clearly marked and exposed via MCP for cross-runtime access.
