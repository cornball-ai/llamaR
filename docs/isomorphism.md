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

Most shell-based skills work without modification. Skills using `{baseDir}` placeholders need those helper scripts on PATH.

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

Markdown-based memory with optional SQLite indexing:

```
~/.llamar/
├── MEMORY.md              # Curated long-term memory
└── memory/
    ├── 2025-01-30.md      # Daily append log
    └── memory.sqlite      # Vector index (optional)
```

### Configuration (planned)

JSON/JSON5 with hierarchical overrides:

```
~/.llamar/config.json      # Global defaults
.llamar/config.json        # Project overrides
```

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
