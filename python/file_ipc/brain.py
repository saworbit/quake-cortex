import argparse
import json
import logging
import sys
import time
from pathlib import Path


# Fix Windows terminal encoding for unicode output
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except AttributeError:
        import codecs

        sys.stdout = codecs.getwriter("utf-8")(sys.stdout.buffer, "strict")
        sys.stderr = codecs.getwriter("utf-8")(sys.stderr.buffer, "strict")

logger = logging.getLogger("CortexBrain")


def _setup_logging() -> None:
    if getattr(logger, "_cortex_configured", False):
        return

    logger.setLevel(logging.DEBUG)

    # File Handler - writes detailed logs to a file for post-mortem analysis
    project_root = Path(__file__).resolve().parents[2]
    logs_dir = project_root / ".cortex" / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_path = (logs_dir / f"cortex_brain_{int(time.time())}.log").resolve()
    file_handler = logging.FileHandler(log_path, encoding="utf-8")
    file_handler.setLevel(logging.DEBUG)
    file_formatter = logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")
    file_handler.setFormatter(file_formatter)

    # Console Handler - prints mainly info/errors to your screen so you aren't overwhelmed
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)
    console_formatter = logging.Formatter("[BRAIN] %(message)s")
    console_handler.setFormatter(console_formatter)

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    logger._cortex_configured = True  # type: ignore[attr-defined]
    cortex_log(logging.INFO, "BOOT", "logger_initialized", {"log_file": str(log_path)})


def cortex_log(level: int, system: str, message: str, data: dict | None = None) -> None:
    """
    Structured log line (pipe-delimited) for quick parsing by humans and LLMs.

    Standard message payload format:
      SYSTEM | MESSAGE | OPTIONAL_DATA(JSON)
    """

    if data is None:
        payload = f"{system} | {message}"
    else:
        payload = f"{system} | {message} | {json.dumps(data, ensure_ascii=False, separators=(',', ':'))}"
    logger.log(level, payload)


def log_decision(decision_id, state, action, confidence) -> None:
    """
    Logs a structured decision packet.
    Ideal for pasting into an LLM for analysis.
    """

    data = {
        "event": "DECISION",
        "id": decision_id,
        "state_snapshot": state,
        "chosen_action": action,
        "confidence": confidence,
    }
    cortex_log(logging.DEBUG, "DECISION", "chosen_action", data)


def _default_telemetry_paths(project_root: Path) -> list[Path]:
    # FTEQW typically writes QuakeC files into the mod's `data/` folder.
    return [
        project_root / "Game" / "cortex" / "data" / "cortex_telemetry.txt",
        project_root / "Game" / "cortex" / "cortex_telemetry.txt",
    ]


def _resolve_telemetry_file(cli_path: str | None) -> Path:
    if cli_path:
        return Path(cli_path)

    project_root = Path(__file__).resolve().parents[2]
    for candidate in _default_telemetry_paths(project_root):
        if candidate.exists():
            return candidate
    return _default_telemetry_paths(project_root)[0]


def _iter_telemetry_lines(path: Path, *, from_start: bool, poll_s: float):
    while True:
        while not path.exists():
            time.sleep(0.25)

        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                if from_start:
                    f.seek(0)
                else:
                    f.seek(0, 2)  # tail from end

                offset = f.tell()
                while True:
                    line = f.readline()
                    if line:
                        offset = f.tell()
                        yield line.rstrip("\r\n")
                        continue

                    # Handle file rotation/truncation (or deletion).
                    try:
                        size = path.stat().st_size
                    except FileNotFoundError:
                        break
                    if size < offset:
                        break

                    time.sleep(poll_s)
        except OSError:
            time.sleep(0.25)


def process_packet(line: str):
    if line.startswith("--- CORTEX SESSION "):
        cortex_log(logging.INFO, "SESSION", "marker", {"line": line})
        return

    if line.startswith("{"):
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            cortex_log(logging.WARNING, "TELEM", "json_decode_failed", {"line": line})
            return

        pos = data.get("pos")
        if isinstance(pos, list) and len(pos) == 3:
            x, y, z = pos
            cortex_log(logging.DEBUG, "TELEM", "pos", {"x": x, "y": y, "z": z, "packet": data})
            return

        cortex_log(logging.DEBUG, "TELEM", "packet", data if isinstance(data, dict) else {"packet": data})
        return

    if line.startswith("POS:"):
        # Parse "POS: '100 200 50'"
        try:
            raw_coords = line.split("'")[1]
            x, y, z = raw_coords.split(" ")
            cortex_log(logging.DEBUG, "TELEM", "pos_legacy", {"x": x, "y": y, "z": z})
        except Exception:
            cortex_log(logging.WARNING, "TELEM", "pos_legacy_parse_failed", {"line": line})
        return

    cortex_log(logging.DEBUG, "TELEM", "line", {"line": line})


def run_server():
    _setup_logging()

    parser = argparse.ArgumentParser(description="Project Cortex brain (file-based telemetry).")
    parser.add_argument("--telemetry-file", help="Path to telemetry file written by QuakeC.")
    parser.add_argument(
        "--from-start",
        action="store_true",
        help="Read the telemetry file from the beginning (default: tail new lines).",
    )
    parser.add_argument(
        "--poll-ms",
        type=int,
        default=25,
        help="Polling interval for tailing the file (milliseconds).",
    )
    args = parser.parse_args()

    telemetry_file = _resolve_telemetry_file(args.telemetry_file)
    poll_s = max(1, args.poll_ms) / 1000.0

    cortex_log(logging.INFO, "IO", "monitoring_telemetry_file", {"path": str(telemetry_file), "from_start": args.from_start, "poll_s": poll_s})
    cortex_log(logging.INFO, "IO", "waiting_for_quake")

    for line in _iter_telemetry_lines(telemetry_file, from_start=args.from_start, poll_s=poll_s):
        if not line:
            continue
        process_packet(line)


if __name__ == "__main__":
    run_server()
