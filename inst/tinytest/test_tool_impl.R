# Test tool implementations

# Test read_file
tmp <- tempfile()
writeLines(c("line1", "line2", "line3"), tmp)

result <- llamaR:::tool_read_file(list(path = tmp))
expect_false(isTRUE(result$isError))
expect_true(grepl("line1", result$content[[1]]$text))

# Test read_file with line limit
result <- llamaR:::tool_read_file(list(path = tmp, lines = 2))
expect_true(grepl("line1", result$content[[1]]$text))
expect_true(grepl("line2", result$content[[1]]$text))
expect_false(grepl("line3", result$content[[1]]$text))

# Test read_file with missing file
result <- llamaR:::tool_read_file(list(path = "/nonexistent/file.txt"))
expect_true(result$isError)

unlink(tmp)

# Test list_files
result <- llamaR:::tool_list_files(list(path = "."))
expect_false(isTRUE(result$isError))

# Test list_files with bad path
result <- llamaR:::tool_list_files(list(path = "/nonexistent/dir"))
expect_true(result$isError)

# Test run_r
result <- llamaR:::tool_run_r(list(code = "1 + 1"))
expect_false(isTRUE(result$isError))
expect_true(grepl("2", result$content[[1]]$text))

# Test run_r with error
result <- llamaR:::tool_run_r(list(code = "stop('test error')"))
expect_true(grepl("Error", result$content[[1]]$text))

# Test installed_packages
result <- llamaR:::tool_installed_packages(list())
expect_false(isTRUE(result$isError))
expect_true(grepl("base", result$content[[1]]$text))

# Test installed_packages with filter
result <- llamaR:::tool_installed_packages(list(pattern = "^base$"))
expect_true(grepl("base", result$content[[1]]$text))

# Test bash
result <- llamaR:::tool_bash(list(command = "echo hello"))
expect_false(isTRUE(result$isError))
expect_true(grepl("hello", result$content[[1]]$text))

# Test git_status (may fail if not in git repo, that's ok)
result <- llamaR:::tool_git_status(list(path = "."))
# Just check it returns something
expect_true(is.list(result))

