# MCP Tool Definitions
# Schema definitions for all tools exposed by the MCP server

#' Get list of available MCP tools
#' @return List of tool definitions with names, descriptions, and schemas
#' @noRd
get_tools <- function() {
  list(
    # File operations
    list(
      name = "read_file",
      description = "Read contents of a file",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "File path to read"),
          lines = list(type = "integer", description = "Max lines to read (default: all)")
        ),
        required = list("path")
      )
    ),
    list(
      name = "write_file",
      description = "Write content to a file",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "File path to write"),
          content = list(type = "string", description = "Content to write")
        ),
        required = list("path", "content")
      )
    ),
    list(
      name = "list_files",
      description = "List files in a directory",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "Directory path"),
          pattern = list(type = "string", description = "Glob pattern (optional)"),
          recursive = list(type = "boolean", description = "Search recursively (default: false)")
        ),
        required = list("path")
      )
    ),
    list(
      name = "grep_files",
      description = "Search file contents with regex pattern",
      inputSchema = list(
        type = "object",
        properties = list(
          pattern = list(type = "string", description = "Regex pattern to search"),
          path = list(type = "string", description = "Directory to search (default: .)"),
          file_pattern = list(type = "string", description = "File glob pattern (default: *.R)")
        ),
        required = list("pattern")
      )
    ),

    # Code execution
    list(
      name = "run_r",
      description = "Execute R code and return result",
      inputSchema = list(
        type = "object",
        properties = list(
          code = list(type = "string", description = "R code to execute")
        ),
        required = list("code")
      )
    ),
    list(
      name = "bash",
      description = "Run a shell command",
      inputSchema = list(
        type = "object",
        properties = list(
          command = list(type = "string", description = "Shell command to execute"),
          timeout = list(type = "integer", description = "Timeout in seconds (default: 30)")
        ),
        required = list("command")
      )
    ),

    # R-specific
    list(
      name = "r_help",
      description = "Get R documentation for a function or package",
      inputSchema = list(
        type = "object",
        properties = list(
          topic = list(type = "string", description = "Function or package name"),
          package = list(type = "string", description = "Package to search in (optional)")
        ),
        required = list("topic")
      )
    ),
    list(
      name = "installed_packages",
      description = "List installed R packages, optionally filtered",
      inputSchema = list(
        type = "object",
        properties = list(
          pattern = list(type = "string", description = "Regex to filter package names")
        )
      )
    ),

    # Data
    list(
      name = "read_csv",
      description = "Read a CSV file and return summary or head",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "Path to CSV file"),
          head = list(type = "integer", description = "Number of rows to show (default: 10)"),
          summary = list(type = "boolean", description = "Include summary statistics (default: true)")
        ),
        required = list("path")
      )
    ),

    # Web
    list(
      name = "fetch_url",
      description = "Fetch content from a URL",
      inputSchema = list(
        type = "object",
        properties = list(
          url = list(type = "string", description = "URL to fetch"),
          method = list(type = "string", description = "HTTP method (default: GET)")
        ),
        required = list("url")
      )
    ),

    # Git
    list(
      name = "git_status",
      description = "Get git repository status",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "Repository path (default: .)")
        )
      )
    ),
    list(
      name = "git_diff",
      description = "Show git diff",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "Repository path (default: .)"),
          staged = list(type = "boolean", description = "Show staged changes only")
        )
      )
    ),
    list(
      name = "git_log",
      description = "Show recent git commits",
      inputSchema = list(
        type = "object",
        properties = list(
          path = list(type = "string", description = "Repository path (default: .)"),
          n = list(type = "integer", description = "Number of commits (default: 10)")
        )
      )
    ),

    # Chat (requires llm.api)
    list(
      name = "chat",
      description = "Chat with an LLM (requires llm.api). Supports ollama, claude, openai providers.",
      inputSchema = list(
        type = "object",
        properties = list(
          prompt = list(type = "string", description = "The message to send"),
          provider = list(type = "string", description = "Provider: ollama, claude, openai (default: ollama)"),
          model = list(type = "string", description = "Model name (default: provider-specific)"),
          system = list(type = "string", description = "System prompt (optional)"),
          temperature = list(type = "number", description = "Temperature 0-1 (default: 0.7)")
        ),
        required = list("prompt")
      )
    ),
    list(
      name = "chat_models",
      description = "List available models for chat",
      inputSchema = list(
        type = "object",
        properties = list(
          provider = list(type = "string", description = "Provider to list models for (default: ollama)")
        )
      )
    )
  )
}
