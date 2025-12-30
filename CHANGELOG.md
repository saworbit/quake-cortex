# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Cortex Black Box logging guide (`docs/LOGGING.md`).
- Mode B “idiot-proof” launchers (`scripts\\run_mode_b_debug.bat`, `scripts\\run_mode_b_train.bat`).
- Log tail helper: `scripts\\check_logs.bat`.
- Optional visualizer deps split out: `python\\requirements-visualizer.txt`.
- QuakeC structured logging + dump-state snapshot (`impulse 199`) for in-engine state capture.
- TCP brain TLS auto-detection and automatic localhost dev cert generation (`scripts/generate_cortex_tls_cert.ps1`).

### Changed

- Stream mode defaults to `ws://127.0.0.1:26000/` (avoids TLS-on-`tcp://` behavior on some FTE builds).
- Brain log files now land under `.cortex\\logs\\` (instead of repo root).
- Docs updated to call out the TCP-mode “black screen then exit” troubleshooting path (check `Game\\cortex\\qconsole.log` + `.cortex\\logs\\cortex_brain_tcp_*.log`).

### Fixed

- TCP brain shutdown behavior (clean exit via ENTER / fewer WinSock errors).
- Stream mode guidance updated for engine builds that attempt TLS on `tcp://` (prefer `ws://` or upgrade FTEQW).
