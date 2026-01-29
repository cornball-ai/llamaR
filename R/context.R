# Context loading for llamaR
# Loads project context files to inject into the system prompt

#' Load context files from project directory
#'
#' Looks for context files in the current directory and assembles
#' them into a system prompt for the LLM.
#'
#' @param cwd Working directory to search
#' @return Character string with assembled context, or NULL if no files found
#' @noRd
load_context <- function(cwd = getwd()) {
  # Files to look for (in order)
  context_files <- c(
    file.path(cwd, "fyi.md"),            # Package/project introspection
    file.path(cwd, "LLAMAR.md"),         # Project instructions
    file.path(cwd, ".llamar", "LLAMAR.md"), # Alt location for instructions
    file.path(cwd, "AGENTS.md")          # Moltbot-style agent instructions
  )

  # Read existing files
  contents <- list()
  for (f in context_files) {
    if (file.exists(f)) {
      content <- paste(readLines(f, warn = FALSE), collapse = "\n")
      if (nchar(content) > 0) {
        name <- basename(f)
        contents[[name]] <- content
      }
    }
  }

  if (length(contents) == 0) {
    return(NULL)
  }

  # Assemble into system prompt
  parts <- c(
    "You are an AI assistant with access to tools for working with R and the file system.",
    "Below is context about the current project. Use it to inform your responses.",
    ""
  )

  for (name in names(contents)) {
    parts <- c(parts,
      sprintf("## %s", name),
      "",
      contents[[name]],
      ""
    )
  }

  paste(parts, collapse = "\n")
}

#' List context files that would be loaded
#'
#' @param cwd Working directory to search
#' @return Character vector of existing context file paths
#' @noRd
list_context_files <- function(cwd = getwd()) {
  context_files <- c(
    file.path(cwd, "fyi.md"),
    file.path(cwd, "LLAMAR.md"),
    file.path(cwd, ".llamar", "LLAMAR.md"),
    file.path(cwd, "AGENTS.md")
  )

  context_files[file.exists(context_files)]
}
