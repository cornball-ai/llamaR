# Test configuration loading

# Test default context files
defaults <- llamaR:::default_context_files()
expect_true("README.md" %in% defaults)
expect_true("PLAN.md" %in% defaults)
expect_true("fyi.md" %in% defaults)
expect_true("AGENTS.md" %in% defaults)

# Setup: use a fresh temp directory
tmpdir <- tempdir()
testdir <- file.path(tmpdir, paste0("cfg_test_", Sys.getpid()))
if (dir.exists(testdir)) unlink(testdir, recursive = TRUE)
dir.create(testdir, recursive = TRUE)

# Test load_config with no config file
config <- llamaR:::load_config(testdir)
expect_equal(config$provider, "anthropic")
expect_equal(config$context_files, defaults)

# Create project config
dir.create(file.path(testdir, ".llamar"), showWarnings = FALSE)
writeLines('{"provider": "ollama", "model": "llama3.2"}',
           file.path(testdir, ".llamar", "config.json"))

# Test project config is loaded
config <- llamaR:::load_config(testdir)
expect_equal(config$provider, "ollama")
expect_equal(config$model, "llama3.2")

# Test custom context_files
writeLines('{"context_files": ["README.md", "CUSTOM.md"]}',
           file.path(testdir, ".llamar", "config.json"))

config <- llamaR:::load_config(testdir)
expect_equal(config$context_files, c("README.md", "CUSTOM.md"))

# Test get_context_files uses config
files <- llamaR:::get_context_files(testdir)
expect_equal(files, c("README.md", "CUSTOM.md"))

# Test invalid JSON is handled gracefully
writeLines('not valid json', file.path(testdir, ".llamar", "config.json"))
config <- llamaR:::load_config(testdir)
expect_equal(config$context_files, defaults)  # Falls back to defaults

# Cleanup
unlink(testdir, recursive = TRUE)
