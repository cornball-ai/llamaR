% tinyrox says don't edit this manually, but it can't stop you!
\name{memory_import_claude}
\alias{memory_import_claude}
\title{Import Claude Code history into memory index}
\usage{
memory_import_claude(agent_id = "default", base_dir = NULL, verbose = TRUE)
}
\arguments{
\item{agent_id}{Agent identifier}

\item{base_dir}{Claude projects directory}

\item{verbose}{Print progress}
}
\value{
List with indexed count and skipped count
}
\description{
Import Claude Code history into memory index
}
