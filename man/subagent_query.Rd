% tinyrox says don't edit this manually, but it can't stop you!
\name{subagent_query}
\alias{subagent_query}
\title{Query a subagent}
\usage{
subagent_query(id, prompt, timeout = 60L)
}
\arguments{
\item{id}{Subagent ID}

\item{prompt}{Prompt to send}

\item{timeout}{Timeout in seconds}
}
\value{
Response text
}
\description{
Sends a prompt to a running subagent and returns the response.
}
