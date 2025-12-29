import argparse
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


def _default_telemetry_paths(project_root: Path) -> list[Path]:
    # FTEQW typically writes QuakeC files into the mod's `data/` folder.
    return [
        project_root / "Game" / "cortex" / "data" / "cortex_telemetry.txt",
        project_root / "Game" / "cortex" / "cortex_telemetry.txt",
    ]


def _resolve_telemetry_file(cli_path: str | None) -> Path:
    if cli_path:
        return Path(cli_path)

    project_root = Path(__file__).resolve().parent
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
        print(f"[CORTEX] {line}")
        return

    if line.startswith("POS:"):
        # Parse "POS: '100 200 50'"
        try:
            raw_coords = line.split("'")[1]
            x, y, z = raw_coords.split(" ")
            print(f"[POS] X={x} Y={y} Z={z}")
        except Exception:
            print(f"[RAW] {line}")
        return

    print(f"[LOG] {line}")


def run_server():
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

    print(f"[CORTEX BRAIN] Monitoring telemetry file: {telemetry_file}")
    print("[CORTEX BRAIN] Waiting for Quake to write data...")

    for line in _iter_telemetry_lines(telemetry_file, from_start=args.from_start, poll_s=poll_s):
        if not line:
            continue
        process_packet(line)


if __name__ == "__main__":
    run_server()
