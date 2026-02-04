% tinyrox says don't edit this manually, but it can't stop you!
\name{scheduler_run_once}
\alias{scheduler_run_once}
\title{Run the scheduler once}
\usage{
scheduler_run_once(agent_id = "main", config = NULL, verbose = TRUE)
}
\arguments{
\item{agent_id}{Agent identifier}

\item{config}{Config list}

\item{verbose}{Print status messages}
}
\value{
Number of tasks executed
}
\description{
Checks for due tasks and executes them.
}
