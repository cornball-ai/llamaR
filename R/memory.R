# Memory Management
# Enhanced Markdown memory with tags and search

#' Get memory file path
#'
#' @param scope "project" or "global"
#' @param cwd Working directory for project scope
#' @return Path to MEMORY.md file
#' @noRd
memory_path <- function(scope = c("project", "global"), cwd = getwd()) {
    scope <- match.arg(scope)
    if (scope == "global") {
        file.path(get_workspace_dir(), "MEMORY.md")
    } else {
        file.path(cwd, ".llamar", "MEMORY.md")
    }
}

#' Parse tags from text
#'
#' Extracts hashtags from text (e.g., "#r #style #config")
#'
#' @param text Text to parse
#' @return Character vector of tags (without #)
#' @noRd
parse_tags <- function(text) {
    matches <- gregexpr("#[a-zA-Z0-9_-]+", text)
    tags <- regmatches(text, matches) [[1]]
    if (length(tags) == 0) return(character())
    # Remove # prefix
    gsub("^#", "", tags)
}

#' Remove tags from text
#'
#' @param text Text with tags
#' @return Text with tags removed
#' @noRd
strip_tags <- function(text) {
    trimws(gsub("#[a-zA-Z0-9_-]+", "", text))
}

#' Format a memory entry
#'
#' @param fact The fact to remember
#' @param tags Character vector of tags
#' @param timestamp POSIXct timestamp (default: now)
#' @return Formatted memory line
#' @noRd
format_memory_entry <- function(fact, tags = character(),
    timestamp = Sys.time()) {
    date_str <- format(timestamp, "%Y-%m-%d")
    tag_str <- if (length(tags) > 0) {
        paste0(" ", paste0("#", tags, collapse = " "))
    } else {
        ""
    }
    sprintf("- %s (%s)%s", fact, date_str, tag_str)
}

#' Auto-categorize a fact
#'
#' Attempts to determine the category based on content.
#'
#' @param fact The fact text
#' @return Category name: "Preferences", "Facts", "Context", or NULL
#' @noRd
auto_categorize <- function(fact) {
    fact_lower <- tolower(fact)

    # Preference patterns
    if (grepl("prefer|like|want|use|always|never|style", fact_lower)) {
        return("Preferences")
    }

    # Fact patterns
    if (grepl("is|are|has|stores|located|path|key|api|config", fact_lower)) {
        return("Facts")
    }

    # Context patterns
    if (grepl("working on|project|currently|building|developing", fact_lower)) {
        return("Context")
    }

    NULL
}

#' Store a memory entry
#'
#' Appends a fact to MEMORY.md with optional tags and auto-categorization.
#'
#' @param fact The fact to remember (may include #tags)
#' @param tags Additional tags (combined with parsed tags)
#' @param category Category to file under (auto-detected if NULL)
#' @param scope "project" or "global"
#' @param cwd Working directory
#' @return Invisible TRUE on success
#' @noRd
memory_store <- function(fact, tags = character(), category = NULL,
    scope = c("project", "global"), cwd = getwd()) {
    scope <- match.arg(scope)
    path <- memory_path(scope, cwd)

    # Parse tags from fact text
    parsed_tags <- parse_tags(fact)
    clean_fact <- strip_tags(fact)
    all_tags <- unique(c(tags, parsed_tags))

    # Auto-categorize if not specified
    if (is.null(category)) {
        category <- auto_categorize(clean_fact) %||% "Facts"
    }

    # Format the entry
    entry <- format_memory_entry(clean_fact, all_tags)

    # Read existing content
    if (file.exists(path)) {
        lines <- readLines(path, warn = FALSE)
    } else {
        # Create directory if needed
        dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
        lines <- c(
            "# Memory",
            "",
            "## Preferences",
            "",
            "## Facts",
            "",
            "## Context",
            ""
        )
    }

    # Find the category section
    section_pattern <- sprintf("^## %s", category)
    section_idx <- grep(section_pattern, lines, ignore.case = TRUE)

    if (length(section_idx) == 0) {
        # Category doesn't exist, add it
        lines <- c(lines, "", sprintf("## %s", category), entry)
    } else {
        # Find insertion point (after section header, before next section or EOF)
        insert_idx <- section_idx[1] + 1

        # Skip blank lines after header
        while (insert_idx <= length(lines) && lines[insert_idx] == "") {
            insert_idx <- insert_idx + 1
        }

        # Find end of section (next ## or EOF)
        end_idx <- insert_idx
        while (end_idx <= length(lines) && !grepl("^##", lines[end_idx])) {
            end_idx <- end_idx + 1
        }

        # Insert at end of section content
        if (end_idx > length(lines)) {
            lines <- c(lines, entry)
        } else {
            lines <- c(lines[1:(end_idx - 1)], entry, lines[end_idx:length(lines)])
        }
    }

    # Write back
    writeLines(lines, path)
    invisible(TRUE)
}

#' Search memory for matching entries
#'
#' Searches MEMORY.md files for entries matching a query.
#'
#' @param query Search query (supports simple keywords)
#' @param scope "project", "global", or "both"
#' @param cwd Working directory
#' @return List of matching entries with metadata
#' @noRd
memory_search <- function(query, scope = c("both", "project", "global"),
    cwd = getwd()) {
    scope <- match.arg(scope)

    paths <- character()
    if (scope %in% c("both", "global")) {
        paths <- c(paths, memory_path("global", cwd))
    }
    if (scope %in% c("both", "project")) {
        paths <- c(paths, memory_path("project", cwd))
    }

    results <- list()

    for (path in paths) {
        if (!file.exists(path)) next

        lines <- readLines(path, warn = FALSE)
        scope_name <- if (grepl("workspace", path)) "global" else "project"

        current_section <- NULL

        for (i in seq_along(lines)) {
            line <- lines[i]

            # Track current section
            if (grepl("^## ", line)) {
                current_section <- sub("^## ", "", line)
                next
            }

            # Skip non-entry lines
            if (!grepl("^- ", line)) next

            # Check if line matches query
            if (grepl(query, line, ignore.case = TRUE)) {
                # Parse the entry
                entry_text <- sub("^- ", "", line)

                # Extract date if present
                date_match <- regmatches(entry_text,
                    regexec("\\(([0-9]{4}-[0-9]{2}-[0-9]{2})\\)", entry_text)) [[1]]
                date <- if (length(date_match) > 1) date_match[2] else NULL

                # Extract tags
                tags <- parse_tags(entry_text)

                # Clean text (remove date and tags)
                clean_text <- gsub("\\([0-9]{4}-[0-9]{2}-[0-9]{2}\\)", "", entry_text)
                clean_text <- strip_tags(clean_text)
                clean_text <- trimws(clean_text)

                results <- c(results, list(list(
                            text = clean_text,
                            tags = tags,
                            date = date,
                            section = current_section,
                            scope = scope_name,
                            line = i,
                            raw = line
                        )))
            }
        }
    }

    results
}

#' Search memory by tag
#'
#' @param tag Tag to search for (without #)
#' @param scope "project", "global", or "both"
#' @param cwd Working directory
#' @return List of matching entries
#' @noRd
memory_search_tag <- function(tag, scope = c("both", "project", "global"),
    cwd = getwd()) {
    scope <- match.arg(scope)
    # Search for the hashtag pattern
    memory_search(sprintf("#%s", tag), scope, cwd)
}

#' List all tags in memory
#'
#' @param scope "project", "global", or "both"
#' @param cwd Working directory
#' @return Character vector of unique tags
#' @noRd
memory_list_tags <- function(scope = c("both", "project", "global"),
    cwd = getwd()) {
    scope <- match.arg(scope)

    paths <- character()
    if (scope %in% c("both", "global")) {
        paths <- c(paths, memory_path("global", cwd))
    }
    if (scope %in% c("both", "project")) {
        paths <- c(paths, memory_path("project", cwd))
    }

    all_tags <- character()

    for (path in paths) {
        if (!file.exists(path)) next
        content <- paste(readLines(path, warn = FALSE), collapse = "\n")
        all_tags <- c(all_tags, parse_tags(content))
    }

    sort(unique(all_tags))
}

#' Format search results for display
#'
#' @param results List from memory_search()
#' @return Character string for display
#' @noRd
format_memory_results <- function(results) {
    if (length(results) == 0) {
        return("No matching memories found.")
    }

    lines <- character()
    for (r in results) {
        scope_marker <- if (r$scope == "global") "[G]" else "[P]"
        section_marker <- if (!is.null(r$section)) sprintf("[%s]", r$section) else ""
        tag_str <- if (length(r$tags) > 0) {
            sprintf(" #%s", paste(r$tags, collapse = " #"))
        } else {
            ""
        }
        date_str <- if (!is.null(r$date)) sprintf(" (%s)", r$date) else ""

        lines <- c(lines, sprintf("%s%s %s%s%s",
                scope_marker, section_marker, r$text, date_str, tag_str))
    }

    paste(lines, collapse = "\n")
}

# ============================================================================
# DuckDB-based Memory Index
# ============================================================================

#' Get path to memory database
#'
#' @param agent_id Agent identifier (default: "default")
#' @return Path to DuckDB file
#' @noRd
memory_db_path <- function(agent_id = "default") {
    dir <- file.path(get_workspace_dir(), "memory")
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    file.path(dir, sprintf("%s.duckdb", agent_id))
}

#' Initialize memory database schema
#'
#' Creates tables if they don't exist.
#'
#' @param con DuckDB connection
#' @return Invisible NULL
#' @noRd
memory_db_init_schema <- function(con) {
    # Metadata table
    DBI::dbExecute(con, "
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    ")

    # Files table - tracks what's indexed
    DBI::dbExecute(con, "
        CREATE TABLE IF NOT EXISTS files (
            path TEXT PRIMARY KEY,
            source TEXT NOT NULL DEFAULT 'memory',
            hash TEXT NOT NULL,
            mtime BIGINT NOT NULL,
            size BIGINT NOT NULL,
            indexed_at BIGINT NOT NULL
        )
    ")

    # Chunks table - text chunks with optional embeddings
    DBI::dbExecute(con, "
        CREATE TABLE IF NOT EXISTS chunks (
            id TEXT PRIMARY KEY,
            path TEXT NOT NULL,
            source TEXT NOT NULL DEFAULT 'memory',
            start_line INTEGER NOT NULL,
            end_line INTEGER NOT NULL,
            hash TEXT NOT NULL,
            text TEXT NOT NULL,
            embedding DOUBLE[],
            embedding_model TEXT,
            updated_at BIGINT NOT NULL
        )
    ")

    # Create FTS index if not exists
    tryCatch({
        DBI::dbExecute(con, "INSTALL fts")
        DBI::dbExecute(con, "LOAD fts")
        DBI::dbExecute(con, "
            PRAGMA create_fts_index('chunks', 'id', 'text',
                stemmer = 'english',
                stopwords = 'english',
                overwrite = 1)
        ")
    }, error = function(e) {
        log_msg("FTS index creation failed:", e$message)
    })

    invisible(NULL)
}

#' Open memory database connection
#'
#' @param agent_id Agent identifier
#' @param read_only Open in read-only mode
#' @return DuckDB connection
#' @noRd
memory_db_open <- function(agent_id = "default", read_only = FALSE) {
    if (!requireNamespace("duckdb", quietly = TRUE)) {
        stop("duckdb package required for memory indexing", call. = FALSE)
    }

    path <- memory_db_path(agent_id)
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path, read_only = read_only)

    if (!read_only) {
        memory_db_init_schema(con)
    }

    con
}

#' Close memory database connection
#'
#' @param con DuckDB connection
#' @noRd
memory_db_close <- function(con) {
    DBI::dbDisconnect(con, shutdown = TRUE)
}

#' Compute hash of text content
#'
#' @param text Text to hash
#' @return MD5 hash string
#' @noRd
memory_hash <- function(text) {
    if (!requireNamespace("digest", quietly = TRUE)) {
        stop("digest package required for memory hashing", call. = FALSE)
    }
    digest::digest(text, algo = "md5", serialize = FALSE)
}

#' Chunk text into segments
#'
#' Splits text into overlapping chunks for indexing.
#'
#' @param text Character vector of lines
#' @param chunk_size Target lines per chunk
#' @param overlap Lines of overlap between chunks
#' @return List of chunk objects with start_line, end_line, text
#' @noRd
memory_chunk_text <- function(text, chunk_size = 50, overlap = 10) {
    if (length(text) == 0) return(list())

    chunks <- list()
    start <- 1

    while (start <= length(text)) {
        end <- min(start + chunk_size - 1, length(text))
        chunk_text <- paste(text[start:end], collapse = "\n")

        chunks <- c(chunks, list(list(
                    start_line = start,
                    end_line = end,
                    text = chunk_text
                )))

        if (end >= length(text)) break
        start <- end - overlap + 1
    }

    chunks
}

#' Index a single file into memory database
#'
#' @param con DuckDB connection
#' @param path Path to file
#' @param source Source identifier (e.g., "memory", "session", "claude")
#' @param force Re-index even if unchanged
#' @return Number of chunks indexed
#' @noRd
memory_index_file <- function(con, path, source = "memory", force = FALSE) {
    if (!file.exists(path)) return(0)

    info <- file.info(path)
    mtime <- as.integer(info$mtime)
    size <- info$size

    # Check if already indexed and unchanged
    if (!force) {
        existing <- DBI::dbGetQuery(con,
            "SELECT hash, mtime FROM files WHERE path = ?",
            params = list(path))

        if (nrow(existing) > 0 && existing$mtime >= mtime) {
            return(0) # Already up to date
        }
    }

    # Read and hash content
    lines <- readLines(path, warn = FALSE)
    content <- paste(lines, collapse = "\n")
    hash <- memory_hash(content)

    # Check hash (content might be same even if mtime changed)
    if (!force) {
        existing <- DBI::dbGetQuery(con,
            "SELECT hash FROM files WHERE path = ?",
            params = list(path))
        if (nrow(existing) > 0 && existing$hash == hash) {
            # Update mtime but skip re-indexing
            DBI::dbExecute(con,
                "UPDATE files SET mtime = ?, indexed_at = ? WHERE path = ?",
                params = list(mtime, as.integer(Sys.time()), path))
            return(0)
        }
    }

    # Delete old chunks for this file
    DBI::dbExecute(con, "DELETE FROM chunks WHERE path = ?", params = list(path))

    # Chunk and index
    chunks <- memory_chunk_text(lines)
    now <- as.integer(Sys.time())

    for (chunk in chunks) {
        chunk_id <- sprintf("%s:%d-%d", basename(path), chunk$start_line, chunk$end_line)
        chunk_hash <- memory_hash(chunk$text)

        DBI::dbExecute(con, "
            INSERT OR REPLACE INTO chunks
            (id, path, source, start_line, end_line, hash, text, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ", params = list(
            chunk_id, path, source,
            chunk$start_line, chunk$end_line,
            chunk_hash, chunk$text, now
        ))
    }

    # Update files table
    DBI::dbExecute(con, "
        INSERT OR REPLACE INTO files (path, source, hash, mtime, size, indexed_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ", params = list(path, source, hash, mtime, size, now))

    length(chunks)
}

#' Extract text from Claude Code JSONL session
#'
#' @param path Path to JSONL file
#' @return Character vector of "Role: text" lines
#' @noRd
claude_session_to_text <- function(path) {
    if (!file.exists(path)) return(character())

    lines <- readLines(path, warn = FALSE)
    result <- character()

    for (line in lines) {
        if (nchar(trimws(line)) == 0) next

        record <- tryCatch(
            jsonlite::fromJSON(line, simplifyVector = FALSE),
            error = function(e) NULL
        )
        if (is.null(record)) next

        # Claude Code format: type is "user" or "assistant"
        # openclaw format: type is "message" with message.role
        msg_type <- record$type
        message <- record$message

        if (is.null(message)) next

        role <- NULL
        if (msg_type %in% c("user", "assistant")) {
            role <- msg_type
        } else if (msg_type == "message" && !is.null(message$role)) {
            role <- message$role
        }

        if (is.null(role) || !role %in% c("user", "assistant")) next

        # Extract text content
        content <- message$content
        if (is.null(content)) next

        text_parts <- character()
        if (is.character(content)) {
            text_parts <- content
        } else if (is.list(content)) {
            for (block in content) {
                if (is.list(block) && block$type == "text" && !is.null(block$text)) {
                    text_parts <- c(text_parts, block$text)
                }
            }
        }

        if (length(text_parts) > 0) {
            label <- if (role == "user") "User" else "Assistant"
            result <- c(result, sprintf("%s: %s", label, paste(text_parts, collapse = " ")))
        }
    }

    result
}

#' Index Claude Code session into memory database
#'
#' @param con DuckDB connection
#' @param path Path to JSONL session file
#' @param force Re-index even if unchanged
#' @return Number of chunks indexed
#' @noRd
memory_index_claude_session <- function(con, path, force = FALSE) {
    if (!file.exists(path)) return(0)

    info <- file.info(path)
    mtime <- as.integer(info$mtime)
    size <- info$size

    # Check if already indexed
    if (!force) {
        existing <- DBI::dbGetQuery(con,
            "SELECT mtime FROM files WHERE path = ?",
            params = list(path))
        if (nrow(existing) > 0 && existing$mtime >= mtime) {
            return(0)
        }
    }

    # Extract text
    lines <- claude_session_to_text(path)
    if (length(lines) == 0) return(0)

    content <- paste(lines, collapse = "\n")
    hash <- memory_hash(content)

    # Delete old chunks
    DBI::dbExecute(con, "DELETE FROM chunks WHERE path = ?", params = list(path))

    # Chunk and index
    chunks <- memory_chunk_text(lines, chunk_size = 30, overlap = 5)
    now <- as.integer(Sys.time())

    for (chunk in chunks) {
        chunk_id <- sprintf("%s:%d-%d", basename(path), chunk$start_line, chunk$end_line)
        chunk_hash <- memory_hash(chunk$text)

        DBI::dbExecute(con, "
            INSERT OR REPLACE INTO chunks
            (id, path, source, start_line, end_line, hash, text, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ", params = list(
            chunk_id, path, "claude",
            chunk$start_line, chunk$end_line,
            chunk_hash, chunk$text, now
        ))
    }

    # Update files table
    DBI::dbExecute(con, "
        INSERT OR REPLACE INTO files (path, source, hash, mtime, size, indexed_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ", params = list(path, "claude", hash, mtime, size, now))

    length(chunks)
}

#' Find all Claude Code session files
#'
#' @param base_dir Base directory (default: ~/.claude/projects)
#' @return Character vector of JSONL file paths
#' @noRd
find_claude_sessions <- function(base_dir = NULL) {
    if (is.null(base_dir)) {
        base_dir <- file.path(Sys.getenv("HOME"), ".claude", "projects")
    }
    if (!dir.exists(base_dir)) return(character())

    list.files(base_dir, pattern = "\\.jsonl$", recursive = TRUE, full.names = TRUE)
}

#' Import Claude Code history into memory index
#'
#' @param agent_id Agent identifier
#' @param base_dir Claude projects directory
#' @param verbose Print progress
#' @return List with indexed count and skipped count
#' @export
memory_import_claude <- function(agent_id = "default", base_dir = NULL,
    verbose = TRUE) {
    sessions <- find_claude_sessions(base_dir)
    if (length(sessions) == 0) {
        if (verbose) message("No Claude Code sessions found")
        return(list(indexed = 0, skipped = 0, total = 0))
    }

    if (verbose) message(sprintf("Found %d Claude Code session files", length(sessions)))

    con <- memory_db_open(agent_id)
    on.exit(memory_db_close(con))

    indexed <- 0
    skipped <- 0

    for (i in seq_along(sessions)) {
        path <- sessions[i]
        if (verbose && i %% 50 == 0) {
            message(sprintf("  Processing %d/%d...", i, length(sessions)))
        }

        chunks <- tryCatch(
            memory_index_claude_session(con, path),
            error = function(e) {
                if (verbose) message(sprintf("  Error indexing %s: %s", basename(path), e$message))
                0
            }
        )

        if (chunks > 0) {
            indexed <- indexed + 1
        } else {
            skipped <- skipped + 1
        }
    }

    if (verbose) {
        message(sprintf("Indexed %d sessions (%d skipped/unchanged)", indexed, skipped))
    }

    list(indexed = indexed, skipped = skipped, total = length(sessions))
}

#' Search memory using full-text search
#'
#' @param query Search query
#' @param agent_id Agent identifier
#' @param limit Maximum results
#' @param source Filter by source (NULL for all)
#' @return Data frame of matching chunks
#' @export
memory_search_fts <- function(query, agent_id = "default", limit = 20,
    source = NULL) {
    con <- memory_db_open(agent_id, read_only = TRUE)
    on.exit(memory_db_close(con))

    # Load FTS extension
    DBI::dbExecute(con, "LOAD fts")

    # Build query with optional source filter
    source_filter <- if (!is.null(source)) {
        sprintf("AND source = '%s'", source)
    } else {
        ""
    }

    sql <- sprintf("
        SELECT id, path, source, start_line, end_line, text,
               fts_main_chunks.match_bm25(id, ?) AS score
        FROM chunks
        WHERE score IS NOT NULL %s
        ORDER BY score DESC
        LIMIT ?
    ", source_filter)

    DBI::dbGetQuery(con, sql, params = list(query, limit))
}

#' Get memory index statistics
#'
#' @param agent_id Agent identifier
#' @return List with file counts, chunk counts, etc.
#' @export
memory_stats <- function(agent_id = "default") {
    con <- memory_db_open(agent_id, read_only = TRUE)
    on.exit(memory_db_close(con))

    files <- DBI::dbGetQuery(con, "
        SELECT source, COUNT(*) as count, SUM(size) as total_size
        FROM files GROUP BY source
    ")

    chunks <- DBI::dbGetQuery(con, "
        SELECT source, COUNT(*) as count
        FROM chunks GROUP BY source
    ")

    list(
        files = files,
        chunks = chunks,
        total_files = sum(files$count),
        total_chunks = sum(chunks$count)
    )
}

