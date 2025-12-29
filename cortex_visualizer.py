import argparse
import sys
import time
from pathlib import Path


try:
    import pygame

    PYGAME_AVAILABLE = True
except ImportError:
    PYGAME_AVAILABLE = False


def _default_telemetry_paths(project_root: Path) -> list[Path]:
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
                    f.seek(0, 2)

                offset = f.tell()
                while True:
                    line = f.readline()
                    if line:
                        offset = f.tell()
                        yield line.rstrip("\r\n")
                        continue

                    try:
                        size = path.stat().st_size
                    except FileNotFoundError:
                        break
                    if size < offset:
                        break

                    time.sleep(poll_s)
        except OSError:
            time.sleep(0.25)


def _parse_pos(line: str):
    if not line.startswith("POS:"):
        return None
    try:
        raw_coords = line.split("'")[1]
        x_str, y_str, z_str = raw_coords.split(" ")
        return float(x_str), float(y_str), float(z_str)
    except Exception:
        return None


def run_text(path: Path, *, from_start: bool, poll_s: float):
    print(f"[CORTEX VIS] Tailing: {path}")
    print("[CORTEX VIS] Waiting for telemetry...")
    for line in _iter_telemetry_lines(path, from_start=from_start, poll_s=poll_s):
        pos = _parse_pos(line)
        if pos is not None:
            x, y, z = pos
            print(f"[POS] X={x:.1f} Y={y:.1f} Z={z:.1f}")


def run_pygame(path: Path, *, from_start: bool, poll_s: float):
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("CORTEX - Telemetry Visualizer (File IPC)")
    font = pygame.font.Font(None, 24)
    clock = pygame.time.Clock()

    last_pos = None
    trail: list[tuple[float, float]] = []

    def world_to_screen(x: float, y: float):
        # Arbitrary scale; this is just a relative motion debug view.
        scale = 0.25
        sx = 400 + x * scale
        sy = 300 - y * scale
        return int(sx), int(sy)

    lines = _iter_telemetry_lines(path, from_start=from_start, poll_s=poll_s)

    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return

        # Drain available telemetry quickly each frame.
        drained = 0
        while drained < 100:
            try:
                line = next(lines)
            except StopIteration:
                break
            pos = _parse_pos(line)
            if pos is None:
                continue
            last_pos = pos
            x, y, _z = pos
            trail.append((x, y))
            if len(trail) > 2000:
                trail = trail[-1000:]
            drained += 1

        screen.fill((20, 20, 24))

        if trail:
            pts = [world_to_screen(x, y) for (x, y) in trail[-500:]]
            if len(pts) >= 2:
                pygame.draw.lines(screen, (60, 140, 200), False, pts, 2)

        if last_pos is not None:
            x, y, z = last_pos
            sx, sy = world_to_screen(x, y)
            pygame.draw.circle(screen, (220, 220, 220), (sx, sy), 6)
            txt = font.render(f"X={x:.1f}  Y={y:.1f}  Z={z:.1f}", True, (240, 240, 240))
            screen.blit(txt, (20, 20))
        else:
            txt = font.render("Waiting for POS telemetry...", True, (240, 240, 240))
            screen.blit(txt, (20, 20))

        pygame.display.flip()
        clock.tick(60)


def main():
    parser = argparse.ArgumentParser(description="Project Cortex telemetry visualizer (file-based).")
    parser.add_argument("--telemetry-file", help="Path to telemetry file written by QuakeC.")
    parser.add_argument("--from-start", action="store_true", help="Read from start (default: tail).")
    parser.add_argument("--poll-ms", type=int, default=25, help="Tail polling interval in ms.")
    parser.add_argument("--text", action="store_true", help="Force text mode.")
    args = parser.parse_args()

    telemetry_file = _resolve_telemetry_file(args.telemetry_file)
    poll_s = max(1, args.poll_ms) / 1000.0

    if args.text or not PYGAME_AVAILABLE:
        run_text(telemetry_file, from_start=args.from_start, poll_s=poll_s)
        return

    run_pygame(telemetry_file, from_start=args.from_start, poll_s=poll_s)


if __name__ == "__main__":
    main()
