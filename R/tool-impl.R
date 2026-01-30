# MCP Tool Implementations
# Actual implementations of tools exposed by the MCP server

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

  # Use fyi package for documentation (generates fyi.md-style output)
  if (!requireNamespace("fyi", quietly = TRUE)) {
    return(err("fyi package not installed. Install with: install.packages('fyi')"))
  }

  tryCatch({
    # If topic looks like a package name, get full package info
    if (is.null(pkg) && topic %in% rownames(installed.packages())) {
      out <- capture.output(fyi::fyi(topic))
      ok(paste(out, collapse = "\n"))
    } else {
      # For functions, try to find the package and get info
      pkg_name <- pkg %||% tryCatch({
        # Find which package contains this function
        envs <- search()
        for (e in envs) {
          if (exists(topic, where = e, mode = "function")) {
            sub("^package:", "", e)
          }
        }
        NULL
      }, error = function(e) NULL)

      if (!is.null(pkg_name) && pkg_name != ".GlobalEnv") {
        out <- capture.output(fyi::fyi(pkg_name))
        ok(paste(out, collapse = "\n"))
      } else {
        err(paste("Could not find package for:", topic))
      }
    }
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

tool_web_search <- function(args) {
  query <- args$query
  max_results <- args$max_results %||% 5L

  api_key <- Sys.getenv("TAVILY_API_KEY")
  if (nchar(api_key) == 0) {
    return(err("TAVILY_API_KEY not set in .Renviron"))
  }

  tryCatch({
    body <- list(
      api_key = api_key,
      query = query,
      max_results = max_results,
      include_answer = TRUE
    )

    h <- curl::new_handle()
    curl::handle_setopt(h,
      customrequest = "POST",
      postfields = jsonlite::toJSON(body, auto_unbox = TRUE)
    )
    curl::handle_setheaders(h, "Content-Type" = "application/json")

    resp <- curl::curl_fetch_memory("https://api.tavily.com/search", handle = h)

    if (resp$status_code >= 400) {
      return(err(paste("Tavily API error:", resp$status_code)))
    }

    data <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)

    # Format results
    parts <- character()

    # Include AI-generated answer if available
    if (!is.null(data$answer) && nchar(data$answer) > 0) {
      parts <- c(parts, "Answer:", data$answer, "")
    }

    parts <- c(parts, "Results:")
    for (r in data$results) {
      parts <- c(parts, sprintf("- %s", r$title))
      parts <- c(parts, sprintf("  %s", r$url))
      if (!is.null(r$content)) {
        snippet <- substr(r$content, 1, 200)
        if (nchar(r$content) > 200) snippet <- paste0(snippet, "...")
        parts <- c(parts, sprintf("  %s", snippet))
      }
      parts <- c(parts, "")
    }

    ok(paste(parts, collapse = "\n"))
  }, error = function(e) {
    err(paste("Search error:", e$message))
  })
}

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

# Chat (llm.api) ----

tool_chat <- function(args) {
  if (!requireNamespace("llm.api", quietly = TRUE)) {
    return(err("llm.api not installed. Install with: install.packages('llm.api')"))
  }

  prompt <- args$prompt
  provider <- args$provider %||% "ollama"
  model <- args$model
  system_prompt <- args$system
  temperature <- args$temperature %||% 0.7

  tryCatch({
    result <- llm.api::chat(
      prompt = prompt,
      provider = provider,
      model = model,
      system = system_prompt,
      temperature = temperature,
      stream = FALSE
    )
    ok(result$content)
  }, error = function(e) {
    err(paste("Chat error:", e$message))
  })
}

tool_chat_models <- function(args) {
  if (!requireNamespace("llm.api", quietly = TRUE)) {
    return(err("llm.api not installed"))
  }

  provider <- args$provider %||% "ollama"

  tryCatch({
    if (provider == "ollama") {
      # Query ollama API for models
      result <- tryCatch({
        con <- url("http://localhost:11434/api/tags")
        on.exit(close(con))
        data <- jsonlite::fromJSON(paste(readLines(con, warn = FALSE), collapse = ""))
        models <- data$models$name
        if (length(models) == 0) "No models found"
        else paste(models, collapse = "\n")
      }, error = function(e) {
        "Ollama not running or no models installed"
      })
      ok(result)
    } else if (provider == "local") {
      models <- llm.api::list_local_models()
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

#' Call a tool by name
#' @param name Tool name
#' @param args List of arguments
#' @return MCP tool result
#' @noRd
call_tool <- function(name, args) {
  args <- args %||% list()

  # Wrap in tryCatch to prevent server crashes
  tryCatch({
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
      "web_search" = tool_web_search(args),
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
  }, error = function(e) {
    err(paste("Tool error:", e$message))
  })
}
