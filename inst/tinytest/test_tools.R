# Test tool definitions and implementations

# Test get_tools returns expected structure
tools <- llamaR:::get_tools()
expect_true(is.list(tools))
expect_true(length(tools) > 0)

# Check each tool has required fields
for (tool in tools) {
  expect_true("name" %in% names(tool))
  expect_true("description" %in% names(tool))
  expect_true("inputSchema" %in% names(tool))
}

# Test specific tools exist
tool_names <- sapply(tools, `[[`, "name")
expect_true("read_file" %in% tool_names)
expect_true("write_file" %in% tool_names)
expect_true("list_files" %in% tool_names)
expect_true("run_r" %in% tool_names)
expect_true("bash" %in% tool_names)
expect_true("r_help" %in% tool_names)
expect_true("git_status" %in% tool_names)

# Test ok/err helpers
ok_result <- llamaR:::ok("test")
expect_true(is.list(ok_result))
expect_true("content" %in% names(ok_result))
expect_equal(ok_result$content[[1]]$text, "test")

err_result <- llamaR:::err("error")
expect_true(is.list(err_result))
expect_true(err_result$isError)
expect_equal(err_result$content[[1]]$text, "error")
