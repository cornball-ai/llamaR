# Signal Transport
# Connects to signal-cli daemon via HTTP JSON-RPC + SSE

#' Signal transport
#'
#' Requires signal-cli running in daemon mode:
#'   signal-cli -a +1234567890 daemon --http 127.0.0.1:8080
#'
#' @param config List with (matches openclaw channels.signal.*):
#'   - httpHost: Daemon host (default: "127.0.0.1")
#'   - httpPort: Daemon port (default: 8080)
#'   - httpUrl: Full URL (overrides httpHost/httpPort)
#'   - account: Signal account phone number (required)
#'   - allowFrom: Vector of allowed sender numbers (optional)
#' @return Transport object
#' @noRd
transport_signal <- function (config = list()) {
    # Resolve base URL (httpUrl overrides httpHost/httpPort)
    if (!is.null(config$httpUrl) && nchar(trimws(config$httpUrl)) > 0) {
        base_url <- trimws(config$httpUrl)
        # Remove trailing slash
        base_url <- sub("/+$", "", base_url)
    } else {
        host <- config$httpHost %||% "127.0.0.1"
        port <- config$httpPort %||% 8080L
        base_url <- sprintf("http://%s:%d", host, port)
    }

    account <- config$account
    allow_from <- config$allowFrom %||% character()

    if (is.null(account)) {
        stop("Signal transport requires 'account' (phone number)", call. = FALSE)
    }

    # Message queue for received messages
    msg_queue <- new.env(parent = emptyenv())
    msg_queue$messages <- list()
    msg_queue$running <- FALSE
    msg_queue$handle <- NULL

    # Check if daemon is running
    check_daemon <- function () {
        url <- sprintf("%s/api/v1/check", base_url)
        tryCatch({
                h <- curl::new_handle()
                curl::handle_setopt(h, timeout = 5)
                resp <- curl::curl_fetch_memory(url, handle = h)
                resp$status_code == 200
            }, error = function (e) FALSE)
    }

    # Send JSON-RPC request
    rpc_request <- function(method, params = list()) {
        url <- sprintf("%s/api/v1/rpc", base_url)
        body <- jsonlite::toJSON(list(
                jsonrpc = "2.0",
                method = method,
                params = params,
                id = as.character(as.integer(Sys.time() * 1000))
            ), auto_unbox = TRUE, null = "null")

        h <- curl::new_handle()
        curl::handle_setopt(h,
            customrequest = "POST",
            postfields = body,
            timeout = 30
        )
        curl::handle_setheaders(h, "Content-Type" = "application/json")

        resp <- curl::curl_fetch_memory(url, handle = h)

        if (resp$status_code >= 400) {
            stop("Signal RPC error: HTTP ", resp$status_code, call. = FALSE)
        }

        if (resp$status_code == 201) {
            return(NULL) # No content
        }

        result <- jsonlite::fromJSON(rawToChar(resp$content), simplifyVector = FALSE)
        if (!is.null(result$error)) {
            stop("Signal RPC error: ", result$error$message %||% "Unknown", call. = FALSE)
        }
        result$result
    }

    # Parse SSE event data
    parse_signal_event <- function(data_json) {
        tryCatch({
                event <- jsonlite::fromJSON(data_json, simplifyVector = FALSE)

                # Handle envelope (incoming message)
                envelope <- event$envelope
                if (is.null(envelope)) return(NULL)

                # Get message content
                dm <- envelope$dataMessage
                if (is.null(dm)) return(NULL)

                sender <- envelope$source %||% envelope$sourceNumber
                if (is.null(sender)) return(NULL)

                # Check allowlist
                if (length(allow_from) > 0 && !sender %in% allow_from) {
                    log_msg("Signal: ignoring message from", sender, "(not in allow_from)")
                    return(NULL)
                }

                text <- dm$message
                if (is.null(text) || nchar(text) == 0) return(NULL)

                timestamp <- envelope$timestamp %||% as.integer(Sys.time() * 1000)

                message_normalize(
                    text = text,
                    sender = sender,
                    channel = "signal",
                    id = as.character(timestamp),
                    metadata = list(
                        group_id = dm$groupInfo$groupId,
                        timestamp = timestamp
                    )
                )
            }, error = function(e) {
                log_msg("Signal: failed to parse event:", e$message)
                NULL
            })
    }

    # Start SSE listener (runs in background)
    start_sse <- function() {
        if (msg_queue$running) return(invisible(NULL))
        msg_queue$running <- TRUE

        url <- sprintf("%s/api/v1/events?account=%s", base_url, utils::URLencode(account, reserved = TRUE))

        # Buffer for SSE parsing
        buffer <- ""
        current_event <- list()

        # Callback for streaming data
        callback <- function(data) {
            if (!msg_queue$running) return(FALSE) # Stop streaming

            chunk <- rawToChar(data)
            buffer <<- paste0(buffer, chunk)

            # Process complete lines
            while (grepl("\n", buffer)) {
                newline_pos <- regexpr("\n", buffer)[1]
                line <- substr(buffer, 1, newline_pos - 1)
                buffer <<- substr(buffer, newline_pos + 1, nchar(buffer))

                # Remove trailing \r
                line <- sub("\r$", "", line)

                if (line == "") {
                    # Empty line = end of event
                    if (!is.null(current_event$data)) {
                        msg <- parse_signal_event(current_event$data)
                        if (!is.null(msg)) {
                            msg_queue$messages <- c(msg_queue$messages, list(msg))
                        }
                    }
                    current_event <<- list()
                } else if (startsWith(line, "data:")) {
                    data_value <- sub("^data: ?", "", line)
                    current_event$data <<- if (is.null(current_event$data)) {
                        data_value
                    } else {
                        paste0(current_event$data, "\n", data_value)
                    }
                } else if (startsWith(line, "event:")) {
                    current_event$event <<- sub("^event: ?", "", line)
                } else if (startsWith(line, "id:")) {
                    current_event$id <<- sub("^id: ?", "", line)
                }
                # Ignore comment lines (starting with :)
            }

            TRUE# Continue streaming
        }

        # Start streaming in a separate R process would be ideal,
        # but for now we'll use blocking mode with timeout
        h <- curl::new_handle()
        curl::handle_setheaders(h, "Accept" = "text/event-stream")

        # Store handle for cleanup
        msg_queue$handle <- h
        msg_queue$url <- url
    }

    # Poll for new messages (blocking with timeout)
    poll_messages <- function(timeout_secs = 1) {
        if (!msg_queue$running) {
            start_sse()
        }

        # Use curl_fetch_stream with timeout
        h <- curl::new_handle()
        curl::handle_setopt(h, timeout = timeout_secs)
        curl::handle_setheaders(h, "Accept" = "text/event-stream")

        buffer <- ""
        current_event <- list()

        tryCatch({
                curl::curl_fetch_stream(msg_queue$url, function(data) {
                        chunk <- rawToChar(data)
                        buffer <<- paste0(buffer, chunk)

                        # Process complete lines
                        while (grepl("\n", buffer)) {
                            newline_pos <- regexpr("\n", buffer)[1]
                            line <- substr(buffer, 1, newline_pos - 1)
                            buffer <<- substr(buffer, newline_pos + 1, nchar(buffer))
                            line <- sub("\r$", "", line)

                            if (line == "") {
                                if (!is.null(current_event$data)) {
                                    msg <- parse_signal_event(current_event$data)
                                    if (!is.null(msg)) {
                                        msg_queue$messages <- c(msg_queue$messages, list(msg))
                                    }
                                }
                                current_event <<- list()
                            } else if (startsWith(line, "data:")) {
                                data_value <- sub("^data: ?", "", line)
                                current_event$data <<- if (is.null(current_event$data)) {
                                    data_value
                                } else {
                                    paste0(current_event$data, "\n", data_value)
                                }
                            }
                        }

                        TRUE
                    }, handle = h)
            }, error = function(e) {
                # Timeout or connection error - that's ok
                if (!grepl("Timeout|timed out", e$message, ignore.case = TRUE)) {
                    log_msg("Signal SSE error:", e$message)
                }
            })

        # Return queued messages
        if (length(msg_queue$messages) > 0) {
            msgs <- msg_queue$messages
            msg_queue$messages <- list()
            msgs
        } else {
            list()
        }
    }

    list(
        type = "signal",
        config = config,

        # Check if daemon is available
        check = check_daemon,

        # Receive messages (polls SSE, returns list of messages)
        receive = function(timeout = 1) {
            poll_messages(timeout)
        },

        # Receive one message (blocking)
        receive_one = function(timeout = 30) {
            start_time <- Sys.time()
            while (difftime(Sys.time(), start_time, units = "secs") < timeout) {
                msgs <- poll_messages(1)
                if (length(msgs) > 0) {
                    return(msgs[[1]])
                }
            }
            NULL
        },

        # Send a message
        send = function(msg) {
            # Determine recipient
            recipient <- msg$metadata$reply_to %||% msg$sender
            if (is.null(recipient)) {
                stop("Signal send: no recipient", call. = FALSE)
            }

            params <- list(
                message = msg$text,
                account = account
            )

            # Check if group message
            group_id <- msg$metadata$group_id
            if (!is.null(group_id)) {
                params$groupId <- group_id
            } else {
                params$recipient <- list(recipient)
            }

            result <- rpc_request("send", params)
            invisible(result)
        },

        # Send typing indicator
        send_typing = function(recipient, group_id = NULL, stop = FALSE) {
            params <- list(account = account)
            if (!is.null(group_id)) {
                params$groupId <- group_id
            } else {
                params$recipient <- list(recipient)
            }
            if (stop) params$stop <- TRUE

            tryCatch(
                rpc_request("sendTyping", params),
                error = function(e) NULL
            )
            invisible(NULL)
        },

        # Close transport
        close = function() {
            msg_queue$running <- FALSE
            invisible(NULL)
        }
    )
}

