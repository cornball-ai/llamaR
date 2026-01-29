#!/usr/bin/env r
#
# Minimal MCP server using stdio transport
# Dependencies: jsonlite, llamaR (optional, for chat)
#

library(jsonlite)

# Load llamaR if available
HAS_LLAMAR <- requireNamespace("llamaR", quietly = TRUE)
if (HAS_LLAMAR) library(llamaR)

# ============================================================================
# Tool definitions
# ============================================================================

TOOLS <- list(
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

  # Chat (requires llamaR)
  list(
    name = "chat",
    description = "Chat with an LLM (requires llamaR). Supports ollama, claude, openai providers.",
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

# ============================================================================
# Tool implementations
# ============================================================================

# Helper for consistent responses
ok <- function(text) {
  list(content = list(list(type = "text", text = text)))
}

err <- function(text) {
  list(isError = TRUE, content = list(list(type = "text", text = text)))
}

# File operations ----

tool_read_file <- function(args) {
  path <- path.expand(args$path)
  if (!file.exists(path)) return(err(paste("File not found:", path)))

  lines <- readLines(path, warn = FALSE)
  if (!is.null(args$lines)) {
    lines <- head(lines, args$lines)
  }
  ok(paste(lines, collapse = "\n"))
}

tool_write_file <- function(args) {
  path <- path.expand(args$path)
  content <- args$content

  tryCatch({
    writeLines(content, path)
    ok(paste("Written", nchar(content), "chars to", path))
  }, error = function(e) {
    err(paste("Write failed:", e$message))
  })
}

tool_list_files <- function(args) {
  path <- path.expand(args$path %||% ".")
  pattern <- args$pattern
  recursive <- isTRUE(args$recursive)

  if (!dir.exists(path)) return(err(paste("Directory not found:", path)))

  if (!is.null(pattern)) {
    if (recursive) {
      files <- Sys.glob(file.path(path, "**", pattern))
    } else {
      files <- Sys.glob(file.path(path, pattern))
    }
  } else {
    files <- list.files(path, full.names = TRUE, recursive = recursive)
  }

  if (length(files) == 0) return(ok("No files found"))
  ok(paste(files, collapse = "\n"))
}

tool_grep_files <- function(args) {
  pattern <- args$pattern
  path <- path.expand(args$path %||% ".")
  file_pattern <- args$file_pattern %||% "*.R"

  files <- Sys.glob(file.path(path, file_pattern))
  if (length(files) == 0) return(ok("No files to search"))

  results <- character()
  for (f in files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) NULL)
    if (is.null(lines)) next

    hits <- grep(pattern, lines)
    if (length(hits) > 0) {
      for (i in hits) {
        results <- c(results, sprintf("%s:%d: %s", f, i, lines[i]))
      }
    }
  }

  if (length(results) == 0) return(ok("No matches found"))
  ok(paste(results, collapse = "\n"))
}

# Code execution ----

tool_run_r <- function(args) {
  code <- args$code
  result <- tryCatch({
    out <- capture.output(eval(parse(text = code), envir = globalenv()))
    paste(out, collapse = "\n")
  }, error = function(e) {
    paste("Error:", e$message)
  })
  ok(result)
}

tool_bash <- function(args) {
  cmd <- args$command
  timeout <- args$timeout %||% 30

  result <- tryCatch({
    out <- system(cmd, intern = TRUE, timeout = timeout)
    paste(out, collapse = "\n")
  }, error = function(e) {
    paste("Error:", e$message)
  })
  ok(result)
}

# R-specific ----

tool_r_help <- function(args) {
  topic <- args$topic
  pkg <- args$package

  result <- tryCatch({
    if (!is.null(pkg)) {
      help_file <- help(topic, package = (pkg))
    } else {
      help_file <- help(topic)
    }

    if (length(help_file) == 0) {
      return(err(paste("No help found for:", topic)))
    }

    # Capture help text
    out <- capture.output(tools:::Rd2txt(
      utils:::.getHelpFile(help_file),
      options = list(width = 80)
    ))
    ok(paste(out, collapse = "\n"))
  }, error = function(e) {
    err(paste("Help error:", e$message))
  })
}

tool_installed_packages <- function(args) {
  pattern <- args$pattern

  pkgs <- rownames(installed.packages())
  if (!is.null(pattern)) {
    pkgs <- grep(pattern, pkgs, value = TRUE, ignore.case = TRUE)
  }

  if (length(pkgs) == 0) return(ok("No packages found"))
  ok(paste(sort(pkgs), collapse = "\n"))
}

# Data ----

tool_read_csv <- function(args) {
  path <- path.expand(args$path)
  n_head <- args$head %||% 10
  show_summary <- args$summary %||% TRUE

  if (!file.exists(path)) return(err(paste("File not found:", path)))

  tryCatch({
    df <- read.csv(path)
    parts <- character()

    # Dimensions
    parts <- c(parts, sprintf("Dimensions: %d rows x %d columns", nrow(df), ncol(df)))
    parts <- c(parts, sprintf("Columns: %s", paste(names(df), collapse = ", ")))
    parts <- c(parts, "")

    # Summary
    if (show_summary) {
      parts <- c(parts, "Summary:", capture.output(summary(df)), "")
    }

    # Head
    parts <- c(parts, sprintf("First %d rows:", min(n_head, nrow(df))))
    parts <- c(parts, capture.output(print(head(df, n_head))))

    ok(paste(parts, collapse = "\n"))
  }, error = function(e) {
    err(paste("CSV read error:", e$message))
  })
}

# Web ----

tool_fetch_url <- function(args) {
  url <- args$url
  method <- toupper(args$method %||% "GET")

  tryCatch({
    con <- url(url, method = method)
    on.exit(close(con))
    content <- paste(readLines(con, warn = FALSE), collapse = "\n")
    ok(content)
  }, error = function(e) {
    err(paste("Fetch error:", e$message))
  })
}

# Git ----

tool_git_status <- function(args) {
  path <- path.expand(args$path %||% ".")
  cmd <- sprintf("git -C %s status --short", shQuote(path))
  result <- tryCatch(
    system(cmd, intern = TRUE),
    error = function(e) paste("Error:", e$message)
  )
  if (length(result) == 0) result <- "Working tree clean"
  ok(paste(result, collapse = "\n"))
}

tool_git_diff <- function(args) {
  path <- path.expand(args$path %||% ".")
  staged <- if (isTRUE(args$staged)) "--staged" else ""
  cmd <- sprintf("git -C %s diff %s", shQuote(path), staged)
  result <- tryCatch(
    system(cmd, intern = TRUE),
    error = function(e) paste("Error:", e$message)
  )
  if (length(result) == 0) result <- "No changes"
  ok(paste(result, collapse = "\n"))
}

tool_git_log <- function(args) {
  path <- path.expand(args$path %||% ".")
  n <- args$n %||% 10
  cmd <- sprintf("git -C %s log --oneline -n %d", shQuote(path), n)
  result <- tryCatch(
    system(cmd, intern = TRUE),
    error = function(e) paste("Error:", e$message)
  )
  ok(paste(result, collapse = "\n"))
}

# Chat (llamaR) ----

tool_chat <- function(args) {
  if (!HAS_LLAMAR) {
    return(err("llamaR not installed. Install with: install.packages('llamaR')"))
  }

  prompt <- args$prompt
  provider <- args$provider %||% "ollama"
  model <- args$model
  system_prompt <- args$system
  temperature <- args$temperature %||% 0.7

  tryCatch({
    result <- llamaR::chat(
      prompt = prompt,
      provider = provider,
      model = model,
      system = system_prompt,
      temperature = temperature,
      stream = FALSE
    )
    ok(result)
  }, error = function(e) {
    err(paste("Chat error:", e$message))
  })
}

tool_chat_models <- function(args) {
  if (!HAS_LLAMAR) {
    return(err("llamaR not installed"))
  }

  provider <- args$provider %||% "ollama"

  tryCatch({
    if (provider == "ollama") {
      # Query ollama API for models
      result <- tryCatch({
        con <- url("http://localhost:11434/api/tags")
        on.exit(close(con))
        data <- fromJSON(paste(readLines(con, warn = FALSE), collapse = ""))
        models <- data$models$name
        if (length(models) == 0) "No models found"
        else paste(models, collapse = "\n")
      }, error = function(e) {
        "Ollama not running or no models installed"
      })
      ok(result)
    } else if (provider == "local") {
      models <- llamaR::list_local_models()
      if (length(models) == 0) ok("No local models found")
      else ok(paste(basename(models), collapse = "\n"))
    } else {
      ok(paste("Model listing not supported for provider:", provider))
    }
  }, error = function(e) {
    err(paste("Error listing models:", e$message))
  })
}

# Dispatcher ----

call_tool <- function(name, args) {
  args <- args %||% list()

  switch(name,
    # File operations
    "read_file" = tool_read_file(args),
    "write_file" = tool_write_file(args),
    "list_files" = tool_list_files(args),
    "grep_files" = tool_grep_files(args),

    # Code execution
    "run_r" = tool_run_r(args),
    "bash" = tool_bash(args),

    # R-specific
    "r_help" = tool_r_help(args),
    "installed_packages" = tool_installed_packages(args),

    # Data
    "read_csv" = tool_read_csv(args),

    # Web
    "fetch_url" = tool_fetch_url(args),

    # Git
    "git_status" = tool_git_status(args),
    "git_diff" = tool_git_diff(args),
    "git_log" = tool_git_log(args),

    # Chat
    "chat" = tool_chat(args),
    "chat_models" = tool_chat_models(args),

    # Unknown
    err(paste("Unknown tool:", name))
  )
}

# ============================================================================
# JSON-RPC handling
# ============================================================================

handle_request <- function(req) {
  method <- req$method
  id <- req$id
  params <- req$params %||% list()

  result <- switch(method,
    "initialize" = list(
      protocolVersion = "2024-11-05",
      capabilities = list(tools = list()),
      serverInfo = list(name = "codeR-mcp", version = "0.1.0")
    ),

    "notifications/initialized" = NULL,  # No response for notifications

    "tools/list" = list(tools = TOOLS),

    "tools/call" = call_tool(params$name, params$arguments),

    # Default: method not found
    list(.error = list(code = -32601, message = paste("Method not found:", method)))
  )

  # Notifications don't get responses
  if (is.null(result)) return(NULL)

  # Build response
  if (!is.null(result$.error)) {
    list(jsonrpc = "2.0", id = id, error = result$.error)
  } else {
    list(jsonrpc = "2.0", id = id, result = result)
  }
}

# ============================================================================
# Transport layer
# ============================================================================

log_msg <- function(...) {
  cat(..., "\n", file = stderr())
}

# Process a single request from a connection
process_request <- function(line, send_fn) {
  # Skip empty lines
  if (nchar(trimws(line)) == 0) return(TRUE)

  # Parse JSON-RPC request
  req <- tryCatch(
    fromJSON(line, simplifyVector = FALSE),
    error = function(e) NULL
  )

  if (is.null(req)) {
    log_msg("Invalid JSON received")
    return(TRUE)
  }

  log_msg("Received:", req$method)

  # Handle and respond
  response <- handle_request(req)
  if (!is.null(response)) {
    json <- toJSON(response, auto_unbox = TRUE, null = "null")
    send_fn(json)
  }

  TRUE
}

# Stdio transport (for Claude Desktop compatibility)
run_stdio <- function() {
  log_msg("codeR MCP server starting (stdio)...")

  send_fn <- function(json) {
    cat(json, "\n", sep = "", file = stdout())
    flush(stdout())
  }

  while (TRUE) {
    line <- readLines(stdin(), n = 1, warn = FALSE)
    if (length(line) == 0) {
      log_msg("Client disconnected")
      break
    }
    process_request(line, send_fn)
  }

  log_msg("Server stopped")
}

# Socket transport (for llamaR/R clients)
run_socket <- function(port) {
  log_msg(sprintf("codeR MCP server starting (socket port %d)...", port))

  # Create server socket
  server <- serverSocket(port)
  on.exit(close(server))

  log_msg("Listening on port", port)

  while (TRUE) {
    # Accept client connection
    client <- tryCatch(
      socketAccept(server, blocking = TRUE, open = "r+b"),
      error = function(e) NULL
    )

    if (is.null(client)) {
      log_msg("Accept failed, retrying...")
      next
    }

    log_msg("Client connected")

    send_fn <- function(json) {
      writeLines(json, client)
    }

    # Handle client requests
    tryCatch({
      while (TRUE) {
        line <- readLines(client, n = 1, warn = FALSE)
        if (length(line) == 0) {
          log_msg("Client disconnected")
          break
        }
        process_request(line, send_fn)
      }
    }, error = function(e) {
      log_msg("Client error:", e$message)
    })

    tryCatch(close(client), error = function(e) NULL)
  }
}

# ============================================================================
# Entry point
# ============================================================================

if (!interactive()) {
  # Parse command line args
  # Format: port [cwd]
  args <- commandArgs(trailingOnly = TRUE)

  port <- NULL
  cwd <- NULL

  # First arg is port (number)
  if (length(args) >= 1 && grepl("^[0-9]+$", args[1])) {
    port <- as.integer(args[1])
  }

  # Second arg is working directory
  if (length(args) >= 2) {
    cwd <- args[2]
    if (dir.exists(cwd)) {
      setwd(cwd)
    }
  }

  if (!is.null(port)) {
    run_socket(port)
  } else {
    run_stdio()
  }
}
