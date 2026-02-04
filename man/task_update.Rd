% tinyrox says don't edit this manually, but it can't stop you!
\name{task_update}
\alias{task_update}
\title{Update a task}
\usage{
task_update(task_id, ..., agent_id = "main")
}
\arguments{
\item{task_id}{Task ID}

\item{...}{Fields to update (name, description, schedule, prompt, status, notification_sink)}

\item{agent_id}{Agent identifier}
}
\value{
Invisible TRUE on success
}
\description{
Update a task
}
