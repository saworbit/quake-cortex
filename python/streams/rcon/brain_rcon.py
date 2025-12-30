import argparse
import math
import re
import socket
import time
from dataclasses import dataclass


RCON_PREFIX = b"\xff\xff\xff\xff"


@dataclass(frozen=True)
class Edict:
    number: int
    classname: str | None
    origin: tuple[float, float, float] | None
    health: float | None


_EDICT_SPLIT_RE = re.compile(r"(?m)^(?:edict)\s+(\d+):\s*$")
_ORIGIN_RE = re.compile(
    r"\borigin\b\s*(?:=)?\s*(?:'|\")?\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)",
    re.IGNORECASE,
)
_HEALTH_RE = re.compile(r"\bhealth\b\s*(?:=)?\s*(-?\d+(?:\.\d+)?)", re.IGNORECASE)
_CLASSNAME_RE = re.compile(r'\bclassname\b\s*(?:=)?\s*"?([A-Za-z0-9_]+)"?', re.IGNORECASE)


def _parse_prvm_edicts(output: str) -> list[Edict]:
    """
    Parses DarkPlaces `prvm_edicts sv` output into a lightweight list.

    Format varies across versions/configs; this parser is intentionally permissive.
    """

    matches = list(_EDICT_SPLIT_RE.finditer(output))
    if not matches:
        return []

    edicts: list[Edict] = []
    for idx, match in enumerate(matches):
        start = match.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(output)
        block = output[start:end]

        number = int(match.group(1))
        classname_match = _CLASSNAME_RE.search(block)
        origin_match = _ORIGIN_RE.search(block)
        health_match = _HEALTH_RE.search(block)

        classname = classname_match.group(1) if classname_match else None
        origin = None
        if origin_match:
            origin = (float(origin_match.group(1)), float(origin_match.group(2)), float(origin_match.group(3)))
        health = float(health_match.group(1)) if health_match else None

        edicts.append(Edict(number=number, classname=classname, origin=origin, health=health))

    return edicts


class RconClient:
    def __init__(self, host: str, port: int, password: str, *, timeout_s: float = 1.5) -> None:
        self._host = host
        self._port = port
        self._password = password
        self._timeout_s = timeout_s
        self._cached_challenge: str | None = None
        self._cached_challenge_time: float = 0.0

    def _recv_all(self, sock: socket.socket) -> bytes:
        chunks: list[bytes] = []
        while True:
            try:
                data, _ = sock.recvfrom(1400)
            except socket.timeout:
                break
            chunks.append(data)
            if len(data) < 1400:
                break
        return b"".join(chunks)

    def get_challenge(self) -> str:
        now = time.time()
        if self._cached_challenge and (now - self._cached_challenge_time) < 20:
            return self._cached_challenge

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(self._timeout_s)
        try:
            sock.sendto(RCON_PREFIX + b"getchallenge\n", (self._host, self._port))
            data = self._recv_all(sock)
        finally:
            sock.close()

        # DarkPlaces typically replies with: "challenge <number>"
        match = re.search(br"\bchallenge\b\s+(\d+)", data)
        if not match:
            # Fallback: first digit run.
            match = re.search(br"(\d+)", data)
        if not match:
            raise RuntimeError(f"Unable to parse getchallenge response: {data[:200]!r}")

        challenge = match.group(1).decode("ascii", errors="ignore")
        self._cached_challenge = challenge
        self._cached_challenge_time = now
        return challenge

    def command(self, command: str) -> str:
        challenge = self.get_challenge()
        packet = f"rcon {challenge} {self._password} {command}\n".encode("utf-8", errors="strict")

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(self._timeout_s)
        try:
            sock.sendto(RCON_PREFIX + packet, (self._host, self._port))
            data = self._recv_all(sock)
        finally:
            sock.close()

        # Many replies are `\xff\xff\xff\xffprint\n...`
        if data.startswith(RCON_PREFIX):
            data = data[len(RCON_PREFIX) :]
        data = data.replace(b"\x00", b"")
        return data.decode("utf-8", errors="ignore")


def _yaw_from_delta(dx: float, dy: float) -> float:
    # Quake yaw: 0 = east, 90 = north (roughly). atan2(y,x) in degrees.
    return math.degrees(math.atan2(dy, dx))


def run_brain_loop(host: str, port: int, password: str, *, hz: float, speed: float) -> None:
    client = RconClient(host, port, password)

    # Ensure bot exists and telemetry is aimed at it (optional file/tcp path fallback).
    client.command("set cortex_spawn_bot 1")
    client.command("set cortex_track_bot 1")

    dt = 1.0 / max(1.0, hz)
    while True:
        output = client.command("prvm_edicts sv")
        edicts = _parse_prvm_edicts(output)

        bot = next((e for e in edicts if e.classname == "cortex_bot" and e.origin), None)
        players = [e for e in edicts if e.classname == "player" and e.origin]

        if bot and players:
            bx, by, bz = bot.origin  # type: ignore[misc]
            # Nearest player target.
            target = min(players, key=lambda e: (e.origin[0] - bx) ** 2 + (e.origin[1] - by) ** 2 + (e.origin[2] - bz) ** 2)  # type: ignore[index]
            tx, ty, tz = target.origin  # type: ignore[misc]

            dx = tx - bx
            dy = ty - by
            dist = math.hypot(dx, dy)
            if dist > 1e-3:
                vx = (dx / dist) * speed
                vy = (dy / dist) * speed
            else:
                vx = 0.0
                vy = 0.0

            yaw = _yaw_from_delta(dx, dy)
            client.command(f"set bot_vel_x {vx:.2f}")
            client.command(f"set bot_vel_y {vy:.2f}")
            client.command("set bot_vel_z 0")
            client.command(f"set bot_yaw {yaw:.2f}")
            client.command("set bot_pitch 0")
        else:
            # Idle: stop the bot.
            client.command("set bot_vel_x 0")
            client.command("set bot_vel_y 0")
            client.command("set bot_vel_z 0")

        time.sleep(dt)


def main() -> None:
    parser = argparse.ArgumentParser(description="Project Cortex RCON client (DarkPlaces).")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=26000)
    parser.add_argument("--password", default="cortex_secret")
    parser.add_argument("--hz", type=float, default=20.0, help="Control loop frequency.")
    parser.add_argument("--speed", type=float, default=300.0, help="Chase speed in Quake units/sec.")
    args = parser.parse_args()

    run_brain_loop(args.host, args.port, args.password, hz=args.hz, speed=args.speed)


if __name__ == "__main__":
    main()

