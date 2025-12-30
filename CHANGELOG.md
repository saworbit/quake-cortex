# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Cortex Black Box logging guide (`docs/LOGGING.md`).
- Mode B “idiot-proof” launchers (`scripts\\run_mode_b_debug.bat`, `scripts\\run_mode_b_train.bat`).
- QuakeC structured logging + dump-state snapshot (`impulse 199`) for in-engine state capture.
- TCP brain TLS auto-detection and automatic localhost dev cert generation (`scripts/generate_cortex_tls_cert.ps1`).

### Changed

- Stream mode defaults to `tcp://127.0.0.1:26000` and uses explicit stream/file open wrappers in QuakeC.
- Docs updated to call out the TCP-mode “black screen then exit” troubleshooting path (check `Game\\cortex\\qconsole.log` + `cortex_brain_tcp_*.log`).

### Fixed

- TCP brain shutdown behavior (clean exit via ENTER / fewer WinSock errors).
