# Configuration management for llamaR
# Handles global and project-level config

#' Default context files to load
#' @noRd
default_context_files <- function() {

  c("README.md", "PLAN.md", "fyi.md", "AGENTS.md")
}

#' Load configuration from JSON file
#'
#' @param path Path to config file
#' @return List with config, or empty list if not found
#' @noRd
load_config_file <- function(path) {
  if (!file.exists(path)) {
    return(list())
  }

  tryCatch({
    cfg <- jsonlite::fromJSON(path, simplifyVector = TRUE)
    # Ensure context_files is a character vector
    if (!is.null(cfg$context_files) && is.list(cfg$context_files)) {
      cfg$context_files <- unlist(cfg$context_files)
    }
    cfg
  }, error = function(e) {
    list()
  })
}

#' Load merged configuration (global + project)
#'
#' Merges global config (~/.llamar/config.json) with project config
#' (.llamar/config.json). Project config takes precedence.
#'
#' @param cwd Working directory for project config
#' @return List with merged configuration
#' @noRd
load_config <- function(cwd = getwd()) {
  # Global config
  global_path <- path.expand("~/.llamar/config.json")
  global <- load_config_file(global_path)

  # Project config

  project_path <- file.path(cwd, ".llamar", "config.json")
  project <- load_config_file(project_path)

  # Merge (project overrides global)
  config <- global
  for (name in names(project)) {
    config[[name]] <- project[[name]]
  }

  # Apply defaults
  if (is.null(config$context_files)) {
    config$context_files <- default_context_files()
  }
  if (is.null(config$provider)) {
    config$provider <- "anthropic"
  }
  # Context warning thresholds (percentage)
  # Hidden until warn_pct, then yellow -> orange -> red
  if (is.null(config$context_warn_pct)) {
    config$context_warn_pct <- 75L
  }
  if (is.null(config$context_high_pct)) {
    config$context_high_pct <- 90L
  }
  if (is.null(config$context_crit_pct)) {
    config$context_crit_pct <- 95L
  }
  # Auto-compaction threshold (percentage)
  if (is.null(config$context_compact_pct)) {
    config$context_compact_pct <- 80L
  }

  config
}

#' Get context files from config
#'
#' @param cwd Working directory
#' @return Character vector of context file names to look for
#' @noRd
get_context_files <- function(cwd = getwd()) {
  config <- load_config(cwd)
  config$context_files
}
