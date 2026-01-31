# Test session management

# Setup: create temp directory to simulate a project
tmpdir <- tempfile("llamar_test_")
dir.create(tmpdir)
old_wd <- setwd(tmpdir)
on.exit({
        setwd(old_wd)
        unlink(tmpdir, recursive = TRUE)
    }, add = TRUE)

# Test session_id generates expected format
id <- llamaR:::session_id()
expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}_[0-9a-f]{8}$", id))

# Test session_new creates proper structure
session <- llamaR:::session_new("ollama", "llama3.2", tmpdir)
expect_equal(session$provider, "ollama")
expect_equal(session$model, "llama3.2")
expect_equal(session$cwd, normalizePath(tmpdir, mustWork = FALSE))
expect_equal(length(session$messages), 0)
expect_true(nchar(session$id) > 0)
expect_true(nchar(session$created) > 0)

# Test session_save creates file
path <- llamaR:::session_save(session)
expect_true(file.exists(path))
expect_true(grepl("\\.json$", path))

# Test sessions directory was created
expect_true(dir.exists(file.path(tmpdir, ".llamar", "sessions")))

# Test session_load retrieves session
loaded <- llamaR:::session_load(session$id, tmpdir)
expect_equal(loaded$id, session$id)
expect_equal(loaded$provider, session$provider)
expect_equal(loaded$model, session$model)

# Test session_load returns NULL for missing session
missing <- llamaR:::session_load("nonexistent-id", tmpdir)
expect_null(missing)

# Test session_add_message
session <- llamaR:::session_add_message(session, "user", "Hello")
expect_equal(length(session$messages), 1)
expect_equal(session$messages[[1]]$role, "user")
expect_equal(session$messages[[1]]$content, "Hello")
expect_true(nchar(session$messages[[1]]$ts) > 0)

session <- llamaR:::session_add_message(session, "assistant", "Hi there")
expect_equal(length(session$messages), 2)
expect_equal(session$messages[[2]]$role, "assistant")

# Test session_list returns sessions
llamaR:::session_save(session) # Save with messages
sessions <- llamaR:::session_list(tmpdir)
expect_equal(length(sessions), 1)
expect_equal(sessions[[1]]$id, session$id)
expect_equal(sessions[[1]]$messages, 2)

# Test session_latest returns most recent
latest <- llamaR:::session_latest(tmpdir)
expect_equal(latest$id, session$id)

# Test session_list with empty directory
empty_dir <- tempfile("empty_")
dir.create(empty_dir)
empty_sessions <- llamaR:::session_list(empty_dir)
expect_equal(length(empty_sessions), 0)
unlink(empty_dir, recursive = TRUE)

# Test session_latest with no sessions
no_latest <- llamaR:::session_latest(empty_dir)
expect_null(no_latest)

# Test format_session_list
formatted <- llamaR:::format_session_list(sessions)
expect_true(grepl("Sessions:", formatted))
expect_true(grepl(session$id, formatted))
expect_true(grepl("2 msgs", formatted))

# Test format_session_list with empty
empty_formatted <- llamaR:::format_session_list(list())
expect_true(grepl("No sessions found", empty_formatted))

# Test multiple sessions are sorted by time
Sys.sleep(0.1) # Ensure different mtime
session2 <- llamaR:::session_new("anthropic", "claude-3", tmpdir)
session2 <- llamaR:::session_add_message(session2, "user", "Test 2")
llamaR:::session_save(session2)

sessions <- llamaR:::session_list(tmpdir)
expect_equal(length(sessions), 2)
# Most recent should be first
expect_equal(sessions[[1]]$id, session2$id)
expect_equal(sessions[[2]]$id, session$id)

