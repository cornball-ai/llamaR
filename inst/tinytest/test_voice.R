# Tests for voice mode (R/audio.R, R/voice.R)

# ============================================================================
# Config tests
# ============================================================================

# Test voice config defaults
cfg <- llamaR:::load_config(tempdir())
expect_true(!is.null(cfg$voice), info = "voice config section exists")
expect_equal(cfg$voice$enabled, FALSE, info = "voice disabled by default")
expect_equal(cfg$voice$tts$backend, "qwen3", info = "default TTS backend is qwen3")
expect_equal(cfg$voice$tts$port, 7812L, info = "default TTS port is 7812 (qwen3-tts-api)")
expect_equal(cfg$voice$stt$backend, "whisper", info = "default STT backend is whisper")
expect_equal(cfg$voice$stt$model, "base", info = "default whisper model is base")
expect_equal(cfg$voice$audio$sample_rate, 16000L, info = "default sample rate is 16000")

# Test config with voice overrides
tmp_dir <- tempfile()
dir.create(file.path(tmp_dir, ".llamar"), recursive = TRUE)
writeLines(
    '{"voice": {"enabled": true, "tts": {"backend": "chatterbox", "port": 7810}}}',
    file.path(tmp_dir, ".llamar", "config.json")
)
cfg <- llamaR:::load_config(tmp_dir)
expect_equal(cfg$voice$enabled, TRUE, info = "voice enabled from config")
expect_equal(cfg$voice$tts$backend, "chatterbox", info = "TTS backend from config")
expect_equal(cfg$voice$tts$port, 7810L, info = "TTS port from config")
# Defaults still apply for unspecified
expect_equal(cfg$voice$stt$backend, "whisper", info = "STT backend default preserved")
unlink(tmp_dir, recursive = TRUE)

# ============================================================================
# Audio availability tests
# ============================================================================

# Test audio_available structure
audio <- llamaR:::audio_available()
expect_true(is.list(audio), info = "audio_available returns list")
expect_true("available" %in% names(audio), info = "audio has 'available' field")
expect_true("record" %in% names(audio), info = "audio has 'record' field")
expect_true("play" %in% names(audio), info = "audio has 'play' field")
expect_true("reason" %in% names(audio), info = "audio has 'reason' field")

# On most Linux systems, arecord/aplay should be available
if (Sys.which("arecord") != "") {
    expect_equal(audio$record, "arecord", info = "arecord detected")
}
if (Sys.which("aplay") != "") {
    expect_equal(audio$play, "aplay", info = "aplay detected")
}

# ============================================================================
# Voice availability tests
# ============================================================================

# Test voice_available structure
voice <- llamaR:::voice_available(list())
expect_true(is.list(voice), info = "voice_available returns list")
expect_true("tts" %in% names(voice), info = "voice has 'tts' field")
expect_true("stt" %in% names(voice), info = "voice has 'stt' field")
expect_true("audio" %in% names(voice), info = "voice has 'audio' field")
expect_true("reason" %in% names(voice), info = "voice has 'reason' field")

# Test voice_status format
status <- llamaR:::voice_status(list())
expect_true(is.character(status), info = "voice_status returns character")
expect_true(grepl("audio:", status), info = "status includes audio")
expect_true(grepl("tts:", status), info = "status includes tts")
expect_true(grepl("stt:", status), info = "status includes stt")

# Test voice_can_enable (depends on system setup)
can_enable <- llamaR:::voice_can_enable(list())
expect_true(is.logical(can_enable), info = "voice_can_enable returns logical")

# ============================================================================
# Audio recording tests (only run at home, need audio device)
# ============================================================================

if (at_home()) {
    audio <- llamaR:::audio_available()

    if (audio$available) {
        # Test that audio_record creates a file (short recording)
        tmp_file <- tempfile(fileext = ".wav")
        on.exit(unlink(tmp_file), add = TRUE)

        # Record 0.5 seconds of silence
        result <- tryCatch({
            llamaR:::audio_record(tmp_file, duration = 0.5)
            TRUE
        }, error = function(e) {
            # May fail if no audio device - that's ok
            FALSE
        })

        if (result) {
            expect_true(file.exists(tmp_file), info = "audio_record creates file")
            expect_true(file.size(tmp_file) > 0, info = "audio file has content")
        }
    }
}
