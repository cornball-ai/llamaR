% tinyrox says don't edit this manually, but it can't stop you!
\name{memory_search_fts}
\alias{memory_search_fts}
\title{Search memory using full-text search}
\usage{
memory_search_fts(query, agent_id = "default", limit = 20, source = NULL)
}
\arguments{
\item{query}{Search query}

\item{agent_id}{Agent identifier}

\item{limit}{Maximum results}

\item{source}{Filter by source (NULL for all)}
}
\value{
Data frame of matching chunks
}
\description{
Search memory using full-text search
}
