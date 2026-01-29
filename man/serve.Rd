% tinyrox says don't edit this manually, but it can't stop you!
\name{serve}
\alias{serve}
\title{Start MCP Server}
\usage{
serve(port = NULL, cwd = NULL)
}
\arguments{
\item{port}{Port number for socket transport. If NULL, uses stdio transport.}

\item{cwd}{Working directory for the server. Defaults to current directory.}
}
\value{
NULL (runs until interrupted or client disconnects)
}
\description{
Start the llamaR MCP server. This exposes R tools to MCP clients like
Claude Desktop, VS Code, or the llamar CLI.
}
\details{
The server supports two transport modes:

- **stdio** (default): For Claude Desktop and other MCP clients.
  Communication happens via stdin/stdout.

- **socket**: For the llamar CLI and R clients. Listens on a TCP port.

## Tools Provided

- `read_file`, `write_file`, `list_files`, `grep_files` - File operations
- `run_r` - Execute R code in the server session
- `bash` - Run shell commands
- `r_help` - Query R documentation
- `installed_packages` - List installed packages
- `read_csv` - Read and summarize CSV files
- `fetch_url` - Fetch web content
- `git_status`, `git_diff`, `git_log` - Git operations
- `chat`, `chat_models` - LLM chat (requires llm.api)
}
\examples{
\dontrun{
# For Claude Desktop (stdio)
serve()

# For llamar CLI (socket)
serve(port = 7850)
}
}
