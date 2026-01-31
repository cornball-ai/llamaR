# Session management for llamaR
# Handles conversation persistence with project-local storage

#' Get the sessions directory for current working directory
#' @param cwd Working directory (default: getwd())
#' @return Path to sessions directory
#' @noRd
sessions_dir <- function (cwd = getwd()) {
    file.path(cwd, ".llamar", "sessions")
}

#' Generate a new session ID
#' @return Character string with date prefix and random suffix
#' @noRd
session_id <- function () {
    paste0(format(Sys.Date(), "%Y-%m-%d"), "_",
        substring(paste0(sample(c(0:9, letters[1:6]), 8, replace = TRUE), collapse = ""), 1, 8))
}

#' Create a new session
#' @param provider LLM provider name
#' @param model Model name
#' @param cwd Working directory
#' @return Session list object
#' @noRd
session_new <- function (provider = "anthropic", model = NULL, cwd = getwd()) {
    list(
        id = session_id(),
        created = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
        updated = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
        provider = provider,
        model = model,
        cwd = normalizePath(cwd, mustWork = FALSE),
        messages = list()
    )
}

#' Save session to disk
#' @param session Session object
#' @param cwd Working directory (default: session's cwd or getwd())
#' @return Path to saved file (invisibly)
#' @noRd
session_save <- function (session, cwd = NULL) {
    cwd <- cwd %||% session$cwd %||% getwd()
    dir <- sessions_dir(cwd)

    if (!dir.exists(dir)) {
        dir.create(dir, recursive = TRUE)
    }

    session$updated <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S")

    path <- file.path(dir, paste0(session$id, ".json"))
    writeLines(jsonlite::toJSON(session, auto_unbox = TRUE, pretty = TRUE), path)
    invisible(path)
}

#' Load session from disk
#' @param id Session ID
#' @param cwd Working directory
#' @return Session object, or NULL if not found
#' @noRd
session_load <- function (id, cwd = getwd()) {
    path <- file.path(sessions_dir(cwd), paste0(id, ".json"))

    if (!file.exists(path)) {
        return(NULL)
    }

    jsonlite::fromJSON(path, simplifyVector = FALSE)
}

#' List sessions for current directory
#' @param cwd Working directory
#' @param n Maximum number of sessions to return (most recent first)
#' @return List of session summaries (id, created, updated, message_count)
#' @noRd
session_list <- function (cwd = getwd(), n = 20) {
    dir <- sessions_dir(cwd)

    if (!dir.exists(dir)) {
        return(list())
    }

    files <- list.files(dir, pattern = "\\.json$", full.names = TRUE)

    if (length(files) == 0) {
        return(list())
    }

    # Get file info for sorting by modification time
    info <- file.info(files)
    files <- files[order(info$mtime, decreasing = TRUE)]

    # Limit to n most recent
    files <- head(files, n)

    # Load summaries
    lapply(files, function (f) {
            session <- jsonlite::fromJSON(f, simplifyVector = FALSE)
            list(
                id = session$id,
                created = session$created,
                updated = session$updated,
                messages = length(session$messages),
                provider = session$provider,
                model = session$model
            )
        })
}

#' Get the latest session for current directory
#' @param cwd Working directory
#' @return Session object, or NULL if no sessions exist
#' @noRd
session_latest <- function (cwd = getwd()) {
    sessions <- session_list(cwd, n = 1)

    if (length(sessions) == 0) {
        return(NULL)
    }

    session_load(sessions[[1]]$id, cwd)
}

#' Add a message to a session
#' @param session Session object
#' @param role Message role (user, assistant, tool)
#' @param content Message content
#' @param tool_calls Optional tool calls (for assistant messages)
#' @param name Optional tool name (for tool messages)
#' @return Updated session object
#' @noRd
session_add_message <- function (session, role, content, tool_calls = NULL,
                                 name = NULL) {
    msg <- list(
        role = role,
        content = content,
        ts = format(Sys.time(), "%Y-%m-%dT%H:%M:%S")
    )

    if (!is.null(tool_calls)) {
        msg$tool_calls <- tool_calls
    }

    if (!is.null(name)) {
        msg$name <- name
    }

    session$messages <- c(session$messages, list(msg))
    session
}

#' Format session list for display
#' @param sessions List of session summaries from session_list()
#' @return Character string for printing
#' @noRd
format_session_list <- function (sessions) {
    if (length(sessions) == 0) {
        return("No sessions found.")
    }

    # Helper to safely get string value
    safe_str <- function (x, default = "?") {
        if (is.null(x) || length(x) == 0 || identical(x, list())) default else as.character(x)
    }

    lines <- vapply(sessions, function (s) {
            sprintf("  %s  %s  %d msgs  %s/%s",
                safe_str(s$id, "?"),
                safe_str(s$updated, "?"),
                if (is.numeric(s$messages)) s$messages else 0L,
                safe_str(s$provider, "?"),
                safe_str(s$model, "default"))
        }, character(1))

    paste(c("Sessions:", lines), collapse = "\n")
}

# Trace storage ----

#' Get path to trace file for a session
#' @param session_id Session ID
#' @param cwd Working directory
#' @return Path to trace file
#' @noRd
trace_path <- function (session_id, cwd = getwd()) {
    file.path(sessions_dir(cwd), paste0(session_id, "_trace.jsonl"))
}

#' Add a trace entry for a tool execution
#'
#' Appends a JSONL entry to the session's trace file.
#'
#' @param session_id Session ID
#' @param tool Tool name
#' @param args Tool arguments
#' @param result Result text (truncated if large)
#' @param success TRUE if successful
#' @param elapsed_ms Execution time in milliseconds
#' @param approved_by How tool was approved: "user", "always", "config"
#' @param turn Conversation turn number
#' @param cwd Working directory
#' @return Invisible path to trace file
#' @noRd
trace_add <- function (session_id, tool, args, result, success, elapsed_ms,
                       approved_by = NULL, turn = NULL, cwd = getwd()) {
    path <- trace_path(session_id, cwd)

    # Ensure directory exists
    dir <- dirname(path)
    if (!dir.exists(dir)) {
        dir.create(dir, recursive = TRUE)
    }

    # Truncate large values
    args_summary <- lapply(args, function (x) {
            if (is.character(x) && nchar(x) > 200) {
                paste0(substr(x, 1, 197), "...")
            } else {
                x
            }
        })

    result_summary <- if (is.character(result) && nchar(result) > 500) {
        paste0(substr(result, 1, 497), "...")
    } else {
        result
    }

    entry <- list(
        timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%OS3Z", tz = "UTC"),
        turn = turn,
        tool = tool,
        args = args_summary,
        result = result_summary,
        success = success,
        elapsed_ms = elapsed_ms,
        approved_by = approved_by
    )

    json <- jsonlite::toJSON(entry, auto_unbox = TRUE, null = "null")
    cat(json, "\n", file = path, append = TRUE)

    invisible(path)
}

#' Load trace for a session
#'
#' @param session_id Session ID
#' @param cwd Working directory
#' @param n Maximum number of entries to return (NULL for all)
#' @return List of trace entries (most recent last)
#' @noRd
trace_load <- function (session_id, cwd = getwd(), n = NULL) {
    path <- trace_path(session_id, cwd)

    if (!file.exists(path)) {
        return(list())
    }

    lines <- readLines(path, warn = FALSE)

    if (length(lines) == 0) {
        return(list())
    }

    # Limit to last n entries if specified
    if (!is.null(n) && n < length(lines)) {
        lines <- tail(lines, n)
    }

    lapply(lines, function (line) {
            tryCatch(
                jsonlite::fromJSON(line, simplifyVector = FALSE),
                error = function (e) NULL
            )
        })
}

#' Format trace for display
#'
#' @param trace List of trace entries from trace_load()
#' @param show_args Whether to show arguments
#' @return Character string for printing
#' @noRd
format_trace <- function(trace, show_args = FALSE) {
    if (length(trace) == 0) {
        return("No tool calls recorded.")
    }

    lines <- vapply(trace, function(entry) {
            if (is.null(entry)) return("")

            status <- if (isTRUE(entry$success)) "OK" else "ERR"
            time_str <- if (!is.null(entry$elapsed_ms)) {
                sprintf("%dms", entry$elapsed_ms)
            } else {
                "?"
            }

            base <- sprintf("  [%s] %s %s (%s)",
                status, entry$tool, time_str,
                substr(entry$timestamp, 12, 19))

            if (show_args && length(entry$args) > 0) {
                args_str <- paste(names(entry$args), "=",
                    vapply(entry$args, function(x) {
                            if (is.character(x)) {
                                s <- if (nchar(x) > 30) paste0(substr(x, 1, 27), "...") else x
                                sprintf('"%s"', s)
                            } else {
                                as.character(x)
                            }
                        }, character(1)),
                    collapse = ", ")
                base <- paste0(base, "\n    ", args_str)
            }

            base
        }, character(1))

    lines <- lines[nchar(lines) > 0]
    paste(c("Tool execution trace:", lines), collapse = "\n")
}

