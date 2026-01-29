# Test context loading

# Setup: use a fresh temp directory
tmpdir <- tempdir()
testdir <- file.path(tmpdir, paste0("ctx_test_", Sys.getpid()))
if (dir.exists(testdir)) unlink(testdir, recursive = TRUE)
dir.create(testdir, recursive = TRUE)

# Test list_context_files with no files
files <- llamaR:::list_context_files(testdir)
expect_equal(length(files), 0)

# Test load_context with no files
ctx <- llamaR:::load_context(testdir)
expect_null(ctx)

# Create fyi.md
writeLines(c("# fyi: mypackage", "", "This is package info."), file.path(testdir, "fyi.md"))

# Test list_context_files finds fyi.md
files <- llamaR:::list_context_files(testdir)
expect_equal(length(files), 1)
expect_true(grepl("fyi.md", files[1]))

# Test load_context includes fyi.md content
ctx <- llamaR:::load_context(testdir)
expect_true(grepl("fyi.md", ctx))
expect_true(grepl("mypackage", ctx))
expect_true(grepl("package info", ctx))

# Create LLAMAR.md
writeLines(c("# Project Instructions", "", "Do this, not that."), file.path(testdir, "LLAMAR.md"))

# Test both files are found
files <- llamaR:::list_context_files(testdir)
expect_equal(length(files), 2)

# Test both are included in context
ctx <- llamaR:::load_context(testdir)
expect_true(grepl("fyi.md", ctx))
expect_true(grepl("LLAMAR.md", ctx))
expect_true(grepl("Project Instructions", ctx))

# Create .llamar/LLAMAR.md (should be found too)
dir.create(file.path(testdir, ".llamar"), showWarnings = FALSE)
writeLines("# Alt Instructions", file.path(testdir, ".llamar", "LLAMAR.md"))

files <- llamaR:::list_context_files(testdir)
expect_equal(length(files), 3)

# Create AGENTS.md
writeLines("# Agent Guidelines", file.path(testdir, "AGENTS.md"))

files <- llamaR:::list_context_files(testdir)
expect_equal(length(files), 4)

ctx <- llamaR:::load_context(testdir)
expect_true(grepl("Agent Guidelines", ctx))

# Test system prompt structure
expect_true(grepl("You are an AI assistant", ctx))
expect_true(grepl("context about the current project", ctx))

# Cleanup
unlink(testdir, recursive = TRUE)
