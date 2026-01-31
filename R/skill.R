# Skill System for llamaR
# Defines the standard interface for tools/skills
#
# Two types of skills:
# 1. SKILL.md files - markdown docs injected into context (shell-based)
# 2. R handlers - built-in MCP tools (R-native)

# Skill registry for R handlers (package-level environment)
.skill_registry <- new.env(parent = emptyenv())

# Skill docs registry for SKILL.md files
.skill_docs <- new.env(parent = emptyenv())

#' Create a skill specification
#'
#' Defines a skill with its schema and handler function.
#'
#' @param name Tool name (snake_case)
#' @param description What the skill does
#' @param params Named list of parameter definitions, each with:
#'   - type: "string", "integer", "number", "boolean", "array", "object"
#'   - description: Parameter description
#'   - required: TRUE/FALSE (default FALSE)
#'   - enum: Optional list of allowed values
#' @param handler Function(args, ctx) that returns a result
#' @return Skill specification list
#' @noRd
skill_spec <- function (name, description, params = list(), handler) {
    # Build required list from params
    required <- names(params)[vapply(params, function (p) {
            isTRUE(p$required)
        }, logical(1))]

    # Strip 'required' from properties (not part of JSON Schema)
    properties <- lapply(params, function (p) {
            p$required <- NULL
            p
        })

    list(
        name = name,
        description = description,
        inputSchema = list(
            type = "object",
            properties = properties,
            required = if (length(required) > 0) as.list(required) else list()
        ),
        handler = handler
    )
}

#' Run a skill
#'
#' Executes a skill's handler with validation and optional timeout.
#' Logs tool calls and results for observability.
#'
#' @param skill Skill spec from skill_spec()
#' @param args Named list of arguments
#' @param ctx Context list (cwd, session, config, etc.)
#' @param timeout Timeout in seconds (default 30, NULL for no timeout)
#' @return Result from handler (should be ok() or err())
#' @noRd
skill_run <- function (skill, args, ctx = list(), timeout = 30L) {
    args <- args %||% list()
    start_time <- Sys.time()

    # Log tool call
    log_tool_call(skill$name, args)

    # Validate required params
    required <- skill$inputSchema$required
    if (length(required) > 0) {
        missing <- setdiff(unlist(required), names(args))
        if (length(missing) > 0) {
            result <- err(paste("Missing required parameters:", paste(missing, collapse = ", ")))
            log_tool_result(skill$name, success = FALSE, elapsed_ms = 0)
            return(result)
        }
    }

    # Execute with optional timeout
    if (!is.null(timeout) && timeout > 0) {
        result <- tryCatch({
                setTimeLimit(cpu = timeout, elapsed = timeout, transient = TRUE)
                on.exit(setTimeLimit(cpu = Inf, elapsed = Inf, transient = FALSE))
                skill$handler(args, ctx)
            }, error = function (e) {
                if (grepl("time limit|elapsed time", e$message, ignore.case = TRUE)) {
                    log_error(sprintf("Skill timed out after %d seconds", timeout),
                        error_type = "timeout", tool = skill$name)
                    err(sprintf("Skill timed out after %d seconds", timeout))
                } else {
                    log_error(e$message, error_type = "skill_error", tool = skill$name)
                    err(paste("Skill error:", e$message))
                }
            })
    } else {
        result <- tryCatch(
            skill$handler(args, ctx),
            error = function (e) {
                log_error(e$message, error_type = "skill_error", tool = skill$name)
                err(paste("Skill error:", e$message))
            }
        )
    }

    # Log result
    elapsed_ms <- as.numeric(difftime(Sys.time(), start_time, units = "secs")) * 1000
    success <- !is.null(result$isError) && !result$isError
    result_lines <- if (!is.null(result$content[[1]]$text)) {
        length(strsplit(result$content[[1]]$text, "\n") [[1]])
    } else {
        NULL
    }
    log_tool_result(skill$name, success = success, result_lines = result_lines,
        elapsed_ms = round(elapsed_ms))

    result
}

#' Register a skill in the global registry
#'
#' @param skill Skill spec from skill_spec()
#' @return Invisible skill name
#' @noRd
register_skill <- function (skill) {
    if (is.null(skill$name)) {
        stop("Skill must have a name")
    }
    .skill_registry[[skill$name]] <- skill
    invisible(skill$name)
}
#' Get a skill from the registry
#'
#' @param name Skill name
#' @return Skill spec or NULL if not found
#' @noRd
get_skill <- function (name) {
    if (exists(name, envir = .skill_registry, inherits = FALSE)) {
        .skill_registry[[name]]
    } else {
        NULL
    }
}

#' List all registered skills
#'
#' @return Character vector of skill names
#' @noRd
list_skills <- function () {
    ls(.skill_registry)
}

#' Clear all skills from registry
#'
#' @return Invisible NULL
#' @noRd
clear_skills <- function () {
    rm(list = ls(.skill_registry), envir = .skill_registry)
    invisible(NULL)
}

#' Load skills from a directory
#'
#' Sources all .R files in the directory. Each file should call
#' register_skill() to add skills to the registry.
#'
#' @param path Directory path containing skill files
#' @param pattern File pattern to match (default "*.R")
#' @return Character vector of loaded file names (invisible)
#' @noRd
load_skills <- function(path, pattern = "*.R") {
    path <- path.expand(path)
    if (!dir.exists(path)) {
        return(invisible(character()))
    }

    files <- Sys.glob(file.path(path, pattern))

    # Create environment with skill functions available
    skill_env <- new.env(parent = globalenv())
    skill_env$skill_spec <- skill_spec
    skill_env$register_skill <- register_skill
    skill_env$ok <- ok
    skill_env$err <- err

    for (f in files) {
        tryCatch(
            source(f, local = skill_env),
            error = function(e) {
                warning(sprintf("Failed to load skill from %s: %s", f, e$message))
            }
        )
    }

    invisible(basename(files))
}

#' Get all skills as MCP tool list
#'
#' Returns skills in the format expected by MCP tools/list.
#'
#' @return List of tool definitions (name, description, inputSchema)
#' @noRd
skills_as_tools <- function () {
    skill_names <- list_skills()
    lapply(skill_names, function (name) {
            skill <- get_skill(name)
            list(
                name = skill$name,
                description = skill$description,
                inputSchema = skill$inputSchema
            )
        })
}

#' Call a skill by name
#'
#' Looks up skill in registry and executes it.
#'
#' @param name Skill name
#' @param args Named list of arguments
#' @param ctx Context list
#' @param timeout Timeout in seconds
#' @return Result from skill handler
#' @noRd
call_skill <- function(name, args, ctx = list(), timeout = 30L) {
    skill <- get_skill(name)
    if (is.null(skill)) {
        return(err(paste("Unknown skill:", name)))
    }
    skill_run(skill, args, ctx, timeout)
}

# SKILL.md Support ----
# Isomorphic with openclaw - markdown files with YAML frontmatter

#' Parse a SKILL.md file
#'
#' Extracts YAML frontmatter and markdown body from a skill file.
#'
#' @param path Path to SKILL.md file
#' @return List with name, description, metadata, and body
#' @noRd
parse_skill_md <- function(path) {
    if (!file.exists(path)) {
        return(NULL)
    }

    lines <- readLines(path, warn = FALSE)
    if (length(lines) == 0) {
        return(NULL)
    }

    # Check for YAML frontmatter (starts with ---)
    if (!grepl("^---\\s*$", lines[1])) {
        # No frontmatter, treat entire file as body
        return(list(
            name = tools::file_path_sans_ext(basename(dirname(path))),
            description = "",
            metadata = list(),
            body = paste(lines, collapse = "\n"),
            path = path
        ))
    }

    # Find end of frontmatter
    end_idx <- which(grepl("^---\\s*$", lines[-1]))[1] + 1
    if (is.na(end_idx)) {
        # No closing ---, treat as no frontmatter
        return(list(
            name = tools::file_path_sans_ext(basename(dirname(path))),
            description = "",
            metadata = list(),
            body = paste(lines, collapse = "\n"),
            path = path
        ))
    }

    # Extract frontmatter and body
    frontmatter_lines <- lines[2:(end_idx - 1)]
    body_lines <- if (end_idx < length(lines)) lines[(end_idx + 1):length(lines)] else character()

    # Parse YAML frontmatter (simple key: value parsing)
    frontmatter <- parse_yaml_simple(frontmatter_lines)

    list(
        name = frontmatter$name %||% tools::file_path_sans_ext(basename(dirname(path))),
        description = frontmatter$description %||% "",
        metadata = frontmatter$metadata %||% list(),
        body = paste(body_lines, collapse = "\n"),
        path = path
    )
}

#' Simple YAML parser for frontmatter
#'
#' Parses basic YAML (key: value, no nesting beyond JSON in metadata).
#'
#' @param lines Character vector of YAML lines
#' @return Named list
#' @noRd
parse_yaml_simple <- function(lines) {
    result <- list()

    for (line in lines) {
        # Skip empty lines and comments
        if (grepl("^\\s*$", line) || grepl("^\\s*#", line)) next

        # Match key: value
        match <- regmatches(line, regexec("^([a-zA-Z_][a-zA-Z0-9_]*):\\s*(.*)$", line))[[1]]
        if (length(match) == 3) {
            key <- match[2]
            value <- match[3]

            # Remove surrounding quotes if present
            value <- gsub("^[\"']|[\"']$", "", value)

            # Try to parse JSON for metadata field
            if (key == "metadata" && grepl("^\\{", value)) {
                result[[key]] <- tryCatch(
                    jsonlite::fromJSON(value, simplifyVector = FALSE),
                    error = function(e) list()
                )
            } else {
                result[[key]] <- value
            }
        }
    }

    result
}

#' Load SKILL.md files from a directory
#'
#' Scans directory for SKILL.md files and loads them into the docs registry.
#' Supports both flat structure (skill.md files) and nested (skill/SKILL.md).
#'
#' @param path Directory path
#' @return Character vector of loaded skill names (invisible)
#' @noRd
load_skill_docs <- function(path) {
    path <- path.expand(path)
    if (!dir.exists(path)) {
        return(invisible(character()))
    }

    loaded <- character()

    # Pattern 1: path/skillname/SKILL.md (nested, like openclaw)
    subdirs <- list.dirs(path, recursive = FALSE, full.names = TRUE)
    for (d in subdirs) {
        skill_file <- file.path(d, "SKILL.md")
        if (file.exists(skill_file)) {
            skill <- parse_skill_md(skill_file)
            if (!is.null(skill)) {
                .skill_docs[[skill$name]] <- skill
                loaded <- c(loaded, skill$name)
            }
        }
    }

    # Pattern 2: path/*.md (flat, simple)
    md_files <- Sys.glob(file.path(path, "*.md"))
    for (f in md_files) {
        skill <- parse_skill_md(f)
        if (!is.null(skill)) {
            # Use filename as skill name for flat files
            skill$name <- tools::file_path_sans_ext(basename(f))
            .skill_docs[[skill$name]] <- skill
            loaded <- c(loaded, skill$name)
        }
    }

    invisible(loaded)
}

#' List loaded skill docs
#'
#' @return Character vector of skill doc names
#' @noRd
list_skill_docs <- function() {
    ls(.skill_docs)
}

#' Get a skill doc by name
#'
#' @param name Skill name
#' @return Skill doc list or NULL
#' @noRd
get_skill_doc <- function(name) {
    if (exists(name, envir = .skill_docs, inherits = FALSE)) {
        .skill_docs[[name]]
    } else {
        NULL
    }
}

#' Clear all skill docs
#'
#' @return Invisible NULL
#' @noRd
clear_skill_docs <- function() {
    rm(list = ls(.skill_docs), envir = .skill_docs)
    invisible(NULL)
}

#' Format skill docs for context injection
#'
#' Creates markdown text suitable for system prompt.
#'
#' @param names Optional character vector of skill names to include.
#'   If NULL, includes all loaded skills.
#' @return Character string with formatted skill docs
#' @noRd
format_skill_docs <- function(names = NULL) {
    if (is.null(names)) {
        names <- list_skill_docs()
    }

    if (length(names) == 0) {
        return("")
    }

    parts <- character()

    for (name in names) {
        skill <- get_skill_doc(name)
        if (is.null(skill)) next

        # Format as markdown section
        header <- sprintf("## Skill: %s", skill$name)
        if (nchar(skill$description) > 0) {
            header <- paste0(header, "\n\n", skill$description)
        }

        parts <- c(parts, header, "", skill$body, "")
    }

    paste(parts, collapse = "\n")
}

