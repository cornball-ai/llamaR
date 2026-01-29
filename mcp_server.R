#!/usr/bin/env r
#
# Minimal MCP server using stdio transport
# Only dependency: jsonlite
#

library(jsonlite)

# ============================================================================
# Tool definitions
# ============================================================================

TOOLS <- list(
  list(
    name = "read_file",
    description = "Read contents of a file",
    inputSchema = list(
      type = "object",
      properties = list(
        path = list(type = "string", description = "File path to read")
      ),
      required = "path"
    )
  ),
  list(
    name = "list_files",
    description = "List files in a directory",
    inputSchema = list(
      type = "object",
      properties = list(
        path = list(type = "string", description = "Directory path"),
        pattern = list(type = "string", description = "Glob pattern (optional)")
      ),
      required = "path"
    )
  ),
  list(
    name = "run_r",
    description = "Execute R code and return result",
    inputSchema = list(
      type = "object",
      properties = list(
        code = list(type = "string", description = "R code to execute")
      ),
      required = "code"
    )
  )
)

# ============================================================================
# Tool implementations
# ============================================================================

tool_read_file <- function(args) {
  path <- args$path
  if (!file.exists(path)) {
    return(list(isError = TRUE, content = list(
      list(type = "text", text = paste("File not found:", path))
    )))
  }
  content <- paste(readLines(path, warn = FALSE), collapse = "\n")
  list(content = list(list(type = "text", text = content)))
}

tool_list_files <- function(args) {
  path <- args$path
  pattern <- args$pattern

  if (!dir.exists(path)) {
    return(list(isError = TRUE, content = list(
      list(type = "text", text = paste("Directory not found:", path))
    )))
  }

  if (!is.null(pattern)) {
    files <- Sys.glob(file.path(path, pattern))
  } else {
    files <- list.files(path, full.names = TRUE)
  }

  list(content = list(list(type = "text", text = paste(files, collapse = "\n"))))
}

tool_run_r <- function(args) {
  code <- args$code
  result <- tryCatch({
    out <- capture.output(eval(parse(text = code), envir = globalenv()))
    paste(out, collapse = "\n")
  }, error = function(e) {
    paste("Error:", e$message)
  })
  list(content = list(list(type = "text", text = result)))
}

call_tool <- function(name, args) {
  switch(name,
    "read_file" = tool_read_file(args),
    "list_files" = tool_list_files(args),
    "run_r" = tool_run_r(args),
    list(isError = TRUE, content = list(
      list(type = "text", text = paste("Unknown tool:", name))
    ))
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
# Stdio transport
# ============================================================================

send_response <- function(response) {
  if (is.null(response)) return()
  json <- toJSON(response, auto_unbox = TRUE, null = "null")
  cat(json, "\n", sep = "", file = stdout())
  flush(stdout())
}

log_msg <- function(...) {
  cat(..., "\n", file = stderr())
}

run_server <- function() {
  log_msg("codeR MCP server starting...")

  while (TRUE) {
    # Read line from stdin
    line <- readLines(stdin(), n = 1, warn = FALSE)

    # EOF - client disconnected
    if (length(line) == 0) {
      log_msg("Client disconnected")
      break
    }

    # Skip empty lines
    if (nchar(trimws(line)) == 0) next

    # Parse JSON-RPC request
    req <- tryCatch(
      fromJSON(line, simplifyVector = FALSE),
      error = function(e) NULL
    )

    if (is.null(req)) {
      log_msg("Invalid JSON received")
      next
    }

    log_msg("Received:", req$method)

    # Handle and respond
    response <- handle_request(req)
    send_response(response)
  }

  log_msg("Server stopped")
}

# ============================================================================
# Entry point
# ============================================================================

if (!interactive()) {
  run_server()
}
