# Test memory management

# Test parse_tags
expect_equal(llamaR:::parse_tags("hello #world"), "world")
expect_equal(llamaR:::parse_tags("#foo #bar #baz"), c("foo", "bar", "baz"))
expect_equal(llamaR:::parse_tags("no tags here"), character())
expect_equal(llamaR:::parse_tags("#with-dash #under_score"), c("with-dash", "under_score"))
expect_equal(llamaR:::parse_tags("#123numeric"), "123numeric")

# Test strip_tags
expect_equal(llamaR:::strip_tags("hello #world"), "hello")
expect_equal(llamaR:::strip_tags("#foo text #bar"), "text")
expect_equal(llamaR:::strip_tags("no tags"), "no tags")
expect_equal(llamaR:::strip_tags("#only #tags"), "")

# Test format_memory_entry
entry <- llamaR:::format_memory_entry("Test fact", c("tag1", "tag2"))
expect_true(grepl("^- Test fact", entry))
expect_true(grepl("#tag1", entry))
expect_true(grepl("#tag2", entry))
expect_true(grepl("\\([0-9]{4}-[0-9]{2}-[0-9]{2}\\)", entry))

# Test format_memory_entry without tags
entry <- llamaR:::format_memory_entry("No tags")
expect_true(grepl("^- No tags", entry))
expect_false(grepl("#", entry))

# Test auto_categorize
expect_equal(llamaR:::auto_categorize("I prefer vim over emacs"), "Preferences")
expect_equal(llamaR:::auto_categorize("Always use dark mode"), "Preferences")
expect_equal(llamaR:::auto_categorize("API key is stored in ~/.Renviron"), "Facts")
expect_equal(llamaR:::auto_categorize("The config path is ~/.llamar"), "Facts")
expect_equal(llamaR:::auto_categorize("Working on llamaR agent"), "Context")
expect_equal(llamaR:::auto_categorize("Currently building a CLI tool"), "Context")
expect_null(llamaR:::auto_categorize("Random text"))

# Test memory_path
global_path <- llamaR:::memory_path("global")
expect_true(grepl("workspace/MEMORY.md$", global_path))

# Test with temp directory for project path
tmp <- tempfile()
dir.create(tmp)
project_path <- llamaR:::memory_path("project", tmp)
expect_true(grepl(".llamar/MEMORY.md$", project_path))

# Test memory_store creates file
tmp <- tempfile()
dir.create(tmp)
llamaR:::memory_store("Test fact #test", scope = "project", cwd = tmp)
mem_path <- file.path(tmp, ".llamar", "MEMORY.md")
expect_true(file.exists(mem_path))

# Check content
content <- readLines(mem_path, warn = FALSE)
expect_true(any(grepl("Test fact", content)))
expect_true(any(grepl("#test", content)))

# Test memory_store adds to correct section
llamaR:::memory_store("I prefer base R #r", scope = "project", cwd = tmp)
content <- readLines(mem_path, warn = FALSE)
# Should be under Preferences
pref_idx <- grep("^## Preferences", content)
expect_true(length(pref_idx) > 0)

# Test memory_search
results <- llamaR:::memory_search("Test fact", scope = "project", cwd = tmp)
expect_true(length(results) > 0)
expect_equal(results[[1]]$text, "Test fact")
expect_true("test" %in% results[[1]]$tags)

# Test memory_search with no results
results <- llamaR:::memory_search("nonexistent query", scope = "project", cwd = tmp)
expect_equal(length(results), 0)

# Test memory_search_tag
results <- llamaR:::memory_search_tag("test", scope = "project", cwd = tmp)
expect_true(length(results) > 0)

# Test memory_list_tags
tags <- llamaR:::memory_list_tags(scope = "project", cwd = tmp)
expect_true("test" %in% tags)
expect_true("r" %in% tags)

# Test format_memory_results with results
results <- llamaR:::memory_search("fact", scope = "project", cwd = tmp)
formatted <- llamaR:::format_memory_results(results)
expect_true(grepl("\\[P\\]", formatted))  # Project marker
expect_true(nchar(formatted) > 0)

# Test format_memory_results with empty results
formatted <- llamaR:::format_memory_results(list())
expect_equal(formatted, "No matching memories found.")

# Cleanup
unlink(tmp, recursive = TRUE)

# ============================================================================
# Daily Memory Log Tests
# ============================================================================

# Test memory_log_path returns correct date format
log_path <- llamaR:::memory_log_path(as.Date("2025-06-15"))
expect_true(grepl("2025-06-15\\.md$", log_path))
expect_true(grepl("memory", log_path))

# Test daily log operations with temp directory
tmp_home <- tempfile()
dir.create(tmp_home, recursive = TRUE)
old_home <- Sys.getenv("HOME")
Sys.setenv(HOME = tmp_home)

# Create workspace dir
workspace <- file.path(tmp_home, ".llamar", "workspace", "memory")
dir.create(workspace, recursive = TRUE)

tryCatch({
    # Test memory_log_write creates file with header
    path <- llamaR:::memory_log_write("First entry\n", date = as.Date("2025-01-10"))
    expect_true(file.exists(path))
    content <- readLines(path, warn = FALSE)
    expect_true(any(grepl("^# Memory Log: 2025-01-10", content)))
    expect_true(any(grepl("First entry", content)))

    # Test memory_log_write appends content
    llamaR:::memory_log_write("Second entry\n", date = as.Date("2025-01-10"))
    content <- readLines(path, warn = FALSE)
    expect_true(any(grepl("Second entry", content)))

    # Create another day's log
    llamaR:::memory_log_write("Day two entry\n", date = as.Date("2025-01-11"))

    # Test memory_log_list returns sorted list (newest first)
    files <- llamaR:::memory_log_list()
    expect_equal(length(files), 2)
    expect_true(grepl("2025-01-11", files[1]))
    expect_true(grepl("2025-01-10", files[2]))

    # Test memory_log_load_all concatenates all logs
    all_logs <- llamaR:::memory_log_load_all()
    expect_true(!is.null(all_logs))
    expect_true(grepl("First entry", all_logs))
    expect_true(grepl("Day two entry", all_logs))
}, finally = {
    Sys.setenv(HOME = old_home)
    unlink(tmp_home, recursive = TRUE)
})

# ============================================================================
# SQLite Memory Index Tests
# ============================================================================

# Test memory_hash
if (requireNamespace("digest", quietly = TRUE)) {
    hash1 <- llamaR:::memory_hash("hello world")
    hash2 <- llamaR:::memory_hash("hello world")
    hash3 <- llamaR:::memory_hash("different text")
    expect_equal(hash1, hash2)
    expect_true(hash1 != hash3)
    expect_equal(nchar(hash1), 32)  # MD5 hash length
}

# Test memory_chunk_text
chunks <- llamaR:::memory_chunk_text(c("line1", "line2", "line3"), chunk_size = 2, overlap = 1)
expect_equal(length(chunks), 2)
expect_equal(chunks[[1]]$start_line, 1)
expect_equal(chunks[[1]]$end_line, 2)
expect_equal(chunks[[2]]$start_line, 2)
expect_equal(chunks[[2]]$end_line, 3)

# Test memory_chunk_text with empty input
chunks <- llamaR:::memory_chunk_text(character())
expect_equal(length(chunks), 0)

# Test memory_chunk_text with single line
chunks <- llamaR:::memory_chunk_text("single line", chunk_size = 10)
expect_equal(length(chunks), 1)
expect_equal(chunks[[1]]$text, "single line")

# Test claude_session_to_text
tmp_session <- tempfile(fileext = ".jsonl")
writeLines(c(
    '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Hello"}]}}',
    '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hi there"}]}}',
    '{"type":"file-history-snapshot","messageId":"abc"}',
    '{"type":"user","message":{"role":"user","content":"Simple string content"}}'
), tmp_session)

lines <- llamaR:::claude_session_to_text(tmp_session)
expect_equal(length(lines), 3)
expect_equal(lines[1], "User: Hello")
expect_equal(lines[2], "Assistant: Hi there")
expect_equal(lines[3], "User: Simple string content")
unlink(tmp_session)

# Test claude_session_to_text with openclaw format
tmp_session <- tempfile(fileext = ".jsonl")
writeLines(c(
    '{"type":"message","message":{"role":"user","content":[{"type":"text","text":"Openclaw user"}]}}',
    '{"type":"message","message":{"role":"assistant","content":[{"type":"text","text":"Openclaw assistant"}]}}'
), tmp_session)

lines <- llamaR:::claude_session_to_text(tmp_session)
expect_equal(length(lines), 2)
expect_equal(lines[1], "User: Openclaw user")
expect_equal(lines[2], "Assistant: Openclaw assistant")
unlink(tmp_session)

# Test claude_session_to_text with missing file
lines <- llamaR:::claude_session_to_text("/nonexistent/file.jsonl")
expect_equal(length(lines), 0)

# Test find_claude_sessions with nonexistent directory
sessions <- llamaR:::find_claude_sessions("/nonexistent/dir")
expect_equal(length(sessions), 0)

# SQLite tests (only if RSQLite available)
if (requireNamespace("RSQLite", quietly = TRUE) &&
    requireNamespace("DBI", quietly = TRUE) &&
    requireNamespace("digest", quietly = TRUE)) {

    # Test memory_db_path
    path <- llamaR:::memory_db_path("test-agent")
    expect_true(grepl("test-agent.sqlite$", path))

    # Test database operations with temp directory
    tmp_db_dir <- tempfile()
    dir.create(tmp_db_dir, recursive = TRUE)
    old_home <- Sys.getenv("HOME")
    Sys.setenv(HOME = tmp_db_dir)

    # Create workspace dir
    workspace <- file.path(tmp_db_dir, ".llamar", "workspace", "memory")
    dir.create(workspace, recursive = TRUE)

    tryCatch({
        # Test open/close
        con <- llamaR:::memory_db_open("test")
        expect_true(DBI::dbIsValid(con))

        # Test schema exists
        tables <- DBI::dbListTables(con)
        expect_true("meta" %in% tables)
        expect_true("files" %in% tables)
        expect_true("chunks" %in% tables)
        expect_true("chunks_fts" %in% tables)

        # Test indexing a file
        tmp_file <- tempfile(fileext = ".md")
        writeLines(c("# Test", "", "Some content here", "More content"), tmp_file)

        chunks_indexed <- llamaR:::memory_index_file(con, tmp_file, source = "test")
        expect_true(chunks_indexed > 0)

        # Verify file is tracked
        files <- DBI::dbGetQuery(con, "SELECT * FROM files WHERE source = 'test'")
        expect_equal(nrow(files), 1)

        # Verify chunks exist
        chunks <- DBI::dbGetQuery(con, "SELECT * FROM chunks WHERE source = 'test'")
        expect_true(nrow(chunks) > 0)

        # Test FTS search returns results
        fts_results <- DBI::dbGetQuery(con,
            "SELECT id, rank FROM chunks_fts WHERE chunks_fts MATCH 'content'")
        expect_true(nrow(fts_results) > 0)

        # Test re-indexing unchanged file returns 0
        chunks_indexed <- llamaR:::memory_index_file(con, tmp_file, source = "test")
        expect_equal(chunks_indexed, 0)

        # Test force re-index
        chunks_indexed <- llamaR:::memory_index_file(con, tmp_file, source = "test", force = TRUE)
        expect_true(chunks_indexed > 0)

        unlink(tmp_file)
        llamaR:::memory_db_close(con)

    }, finally = {
        Sys.setenv(HOME = old_home)
        unlink(tmp_db_dir, recursive = TRUE)
    })
}

# ============================================================================
# memory_get Tool Tests
# ============================================================================

# Test memory_get security: reject paths outside workspace
tmp_home <- tempfile()
dir.create(tmp_home, recursive = TRUE)
old_home <- Sys.getenv("HOME")
Sys.setenv(HOME = tmp_home)

workspace <- file.path(tmp_home, ".llamar", "workspace")
dir.create(file.path(workspace, "memory"), recursive = TRUE)

get_text <- function(result) result$content[[1]]$text

tryCatch({
    # Create test files
    writeLines("Global memory content", file.path(workspace, "MEMORY.md"))
    writeLines("Daily log content", file.path(workspace, "memory", "2025-01-15.md"))

    # Security: reject paths with traversal
    result <- llamaR:::tool_memory_get(list(path = "../../etc/passwd"))
    expect_true(grepl("Access denied", get_text(result)))

    # Security: reject paths not in memory/ or MEMORY.md
    result <- llamaR:::tool_memory_get(list(path = "SOUL.md"))
    expect_true(grepl("Access denied", get_text(result)))

    # Success: read MEMORY.md
    result <- llamaR:::tool_memory_get(list(path = "MEMORY.md"))
    expect_true(grepl("Global memory content", get_text(result)))

    # Success: read memory/*.md
    result <- llamaR:::tool_memory_get(list(path = "memory/2025-01-15.md"))
    expect_true(grepl("Daily log content", get_text(result)))

    # Line range: from/lines parameters
    writeLines(c("line1", "line2", "line3", "line4", "line5"),
        file.path(workspace, "MEMORY.md"))
    result <- llamaR:::tool_memory_get(list(path = "MEMORY.md", from = 2L, lines = 2L))
    expect_true(grepl("line2", get_text(result)))
    expect_true(grepl("line3", get_text(result)))
    expect_false(grepl("line1", get_text(result)))
    expect_false(grepl("line4", get_text(result)))

    # File not found
    result <- llamaR:::tool_memory_get(list(path = "memory/nonexistent.md"))
    expect_true(grepl("not found", get_text(result)))

    # Empty path
    result <- llamaR:::tool_memory_get(list(path = ""))
    expect_true(grepl("required", get_text(result)))
}, finally = {
    Sys.setenv(HOME = old_home)
    unlink(tmp_home, recursive = TRUE)
})
