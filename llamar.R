#!/usr/bin/env r
#
# llamar - A simple Claude Code demo using R and menu()
#
# Usage:
#   r llamar.R
#   # or
#   Rscript llamar.R

# ============================================================================
# Tool implementations (simulated)
# ============================================================================

tool_read <- function(path) {
  cat("\n[Reading:", path, "]\n\n")
  if (file.exists(path)) {
    lines <- readLines(path, warn = FALSE)
    n <- length(lines)
    if (n > 20) {
      cat(paste(sprintf("%4d | %s", 1:10, lines[1:10]), collapse = "\n"))
      cat("\n     ... (", n - 20, " lines omitted) ...\n")
      cat(paste(sprintf("%4d | %s", (n-9):n, lines[(n-9):n]), collapse = "\n"))
    } else {
      cat(paste(sprintf("%4d | %s", seq_along(lines), lines), collapse = "\n"))
    }
    cat("\n")
  } else {
    cat("File not found:", path, "\n")
  }
}

tool_glob <- function(pattern, path = ".") {
  cat("\n[Glob:", pattern, "in", path, "]\n\n")
  files <- Sys.glob(file.path(path, pattern))
  if (length(files) == 0) {
    cat("No files matched.\n")
  } else {
    cat(paste("-", files), sep = "\n")
    cat("\n(", length(files), " files)\n")
  }
  invisible(files)
}

tool_grep <- function(pattern, path = ".") {
  cat("\n[Grep:", pattern, "in", path, "]\n\n")

  # Find R and text files
  files <- list.files(path, pattern = "\\.(R|r|txt|md)$",
                      recursive = TRUE, full.names = TRUE)

  matches <- 0
  for (f in files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) NULL)
    if (is.null(lines)) next

    hits <- grep(pattern, lines, value = FALSE)
    if (length(hits) > 0) {
      cat(f, ":\n", sep = "")
      for (i in hits[1:min(3, length(hits))]) {
        cat(sprintf("  %4d: %s\n", i, substr(lines[i], 1, 80)))
      }
      if (length(hits) > 3) cat("  ... (", length(hits) - 3, " more matches)\n")
      matches <- matches + length(hits)
    }
  }

  if (matches == 0) cat("No matches found.\n")
  cat("\n")
}

tool_bash <- function(cmd) {
  cat("\n[Bash:", cmd, "]\n\n")
  result <- tryCatch(
    system(cmd, intern = TRUE),
    error = function(e) paste("Error:", e$message)
  )
  cat(paste(result, collapse = "\n"), "\n\n")
  invisible(result)
}

tool_write <- function(path, content) {
  cat("\n[Write:", path, "]\n\n")

  # Confirm before writing
  confirm <- menu(c("Yes, write the file", "No, cancel"),
                  title = paste("Write", nchar(content), "chars to", path, "?"))

  if (confirm == 1) {
    writeLines(content, path)
    cat("File written successfully.\n\n")
  } else {
    cat("Cancelled.\n\n")
  }
}

# ============================================================================
# Agent logic
# ============================================================================

parse_intent <- function(input) {
  input_lower <- tolower(input)

  # Simple keyword matching
  if (grepl("read|show|cat|view|open", input_lower)) return("read")
  if (grepl("find|glob|list|ls", input_lower)) return("glob")
  if (grepl("search|grep|look for", input_lower)) return("grep")
  if (grepl("run|exec|bash|shell", input_lower)) return("bash")
  if (grepl("write|create|save", input_lower)) return("write")
  if (grepl("help|\\?", input_lower)) return("help")

  "unknown"
}

extract_path <- function(input) {
  # Look for quoted strings first

  quoted <- regmatches(input, regexpr('"[^"]+"', input))
  if (length(quoted) > 0) return(gsub('"', '', quoted[1]))

  # Look for file-like patterns
  words <- strsplit(input, "\\s+")[[1]]
  for (w in words) {
    if (grepl("\\.|/", w)) return(w)
  }

  NULL
}

show_help <- function() {
  cat("
llamar - Simple Claude Code Demo
================================

Commands (natural language):
  read <file>       - Display file contents
  find <pattern>    - Find files matching glob pattern
  search <pattern>  - Search file contents (grep)
  run <command>     - Execute shell command
  write <file>      - Write content to file
  help              - Show this help
  quit/exit         - Exit llamar

Examples:
  > read README.md
  > find *.R
  > search function
  > run git status
  > write notes.txt

")
}

run_tool <- function(intent, input) {
  path <- extract_path(input)

  switch(intent,
    "read" = {
      if (is.null(path)) {
        path <- readline("File path: ")
      }
      tool_read(path)
    },
    "glob" = {
      if (is.null(path)) {
        path <- readline("Pattern (e.g., *.R): ")
      }
      tool_glob(path)
    },
    "grep" = {
      pattern <- readline("Search pattern: ")
      tool_grep(pattern, if (!is.null(path)) path else ".")
    },
    "bash" = {
      # Extract command after "run" or similar
      cmd <- sub("^(run|exec|bash|shell)\\s+", "", input, ignore.case = TRUE)
      if (nchar(trimws(cmd)) == 0) {
        cmd <- readline("Command: ")
      }
      tool_bash(cmd)
    },
    "write" = {
      if (is.null(path)) {
        path <- readline("File path: ")
      }
      cat("Enter content (end with empty line):\n")
      lines <- character()
      repeat {
        line <- readline()
        if (nchar(line) == 0) break
        lines <- c(lines, line)
      }
      tool_write(path, paste(lines, collapse = "\n"))
    },
    "help" = show_help(),
    "unknown" = {
      cat("\nI'm not sure what you want to do.\n\n")
      choice <- menu(
        c("Read a file", "Find files", "Search contents",
          "Run a command", "Write a file", "Show help"),
        title = "What would you like to do?"
      )
      if (choice > 0) {
        new_intent <- c("read", "glob", "grep", "bash", "write", "help")[choice]
        run_tool(new_intent, input)
      }
    }
  )
}

# ============================================================================
# Main REPL
# ============================================================================

llamar <- function() {
  cat("\n")
  cat("  ___  ___  ___| |___  \n")
  cat(" / __|/ _ \\/ _ \\  _/ -_)\n")
  cat(" \\___\\___/\\___/\\__\\___| R\n")
  cat("\n")
  cat("A simple Claude Code demo using R and menu()\n")
  cat("Type 'help' for commands, 'quit' to exit.\n\n")

  # Set working directory context
  cat("Working directory:", getwd(), "\n\n")

  while (TRUE) {
    # Prompt
    input <- readline("\033[32m>\033[0m ")

    # Handle exit
    if (tolower(trimws(input)) %in% c("quit", "exit", "q")) {
      cat("\nGoodbye.\n")
      break
    }

    # Skip empty input
    if (nchar(trimws(input)) == 0) next

    # Parse and execute
    intent <- parse_intent(input)
    run_tool(intent, input)
  }
}

# Run if executed directly
if (!interactive() || identical(environment(), globalenv())) {
  llamar()
}
