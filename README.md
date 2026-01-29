# codeR

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
r codeR.R

# Or with Rscript
Rscript codeR.R
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
   1 | # codeR
   2 |
   3 | A simple Claude Code-style demo...

> find *.R
[Glob: *.R in .]
- ./codeR.R
( 1 files)

> search function
[Grep: function in .]
./codeR.R:
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

## License

MIT
