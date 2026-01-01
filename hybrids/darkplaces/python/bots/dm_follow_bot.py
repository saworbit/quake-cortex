import argparse
import math
import re
import socket
import time
from dataclasses import dataclass
from typing import List, Optional, Tuple


RCON_PREFIX = b"\xff\xff\xff\xff"

_CHALLENGE_RE = re.compile(br"\bchallenge\b\s+(\d+)")
_FALLBACK_CHALLENGE_RE = re.compile(br"(\d+)")
_EDICT_HEADER_RE = re.compile(r"(?m)^edict\s+(\d+):\s*$")
_CLASSNAME_RE = re.compile(r'\bclassname\b\s*(?:=)?\s*"?([A-Za-z0-9_]+)"?')
_ORIGIN_RE = re.compile(
    r"\borigin\b\s*(?:=)?\s*(?:'|\")?\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)"
)


@dataclass(frozen=True)
class Edict:
    number: int
    classname: Optional[str]
    origin: Optional[Tuple[float, float, float]]


class RconClient:
    def __init__(self, host: str, port: int, password: str, *, timeout_s: float = 1.5) -> None:
        self._host = host
        self._port = port
        self._password = password
        self._timeout_s = timeout_s
        self._cached_challenge: Optional[str] = None
        self._cached_at = 0.0
        self._challenge_supported = True

    def _recv_all(self, sock: socket.socket) -> bytes:
        chunks: List[bytes] = []
        while True:
            try:
                data, _ = sock.recvfrom(1400)
            except socket.timeout:
                break
            except ConnectionResetError:
                break
            chunks.append(data)
            if len(data) < 1400:
                break
        return b"".join(chunks)

    def _get_challenge(self) -> Optional[str]:
        now = time.time()
        if self._cached_challenge and (now - self._cached_at) < 20:
            return self._cached_challenge

        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(self._timeout_s)
        try:
            sock.sendto(RCON_PREFIX + b"getchallenge\n", (self._host, self._port))
            data = self._recv_all(sock)
        finally:
            sock.close()

        if not data:
            return None

        match = _CHALLENGE_RE.search(data) or _FALLBACK_CHALLENGE_RE.search(data)
        if not match:
            return None

        challenge = match.group(1).decode("ascii", errors="ignore")
        self._cached_challenge = challenge
        self._cached_at = now
        return challenge

    def _send_payload(self, payload: bytes) -> str:
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(self._timeout_s)
        try:
            sock.sendto(RCON_PREFIX + payload, (self._host, self._port))
            data = self._recv_all(sock)
        finally:
            sock.close()

        if data.startswith(RCON_PREFIX):
            data = data[len(RCON_PREFIX) :]
        return data.replace(b"\x00", b"").decode("utf-8", errors="ignore")

    def command(self, command: str) -> str:
        if self._challenge_supported:
            try:
                challenge = self._get_challenge()
                if challenge:
                    payload = f"rcon {challenge} {self._password} {command}\n".encode("utf-8")
                    return self._send_payload(payload)
                self._challenge_supported = False
            except Exception:
                self._challenge_supported = False

        payload = f"rcon {self._password} {command}\n".encode("utf-8")
        return self._send_payload(payload)


def parse_edicts(text: str) -> List[Edict]:
    matches = list(_EDICT_HEADER_RE.finditer(text))
    if not matches:
        return []

    edicts: List[Edict] = []
    for idx, match in enumerate(matches):
        start = match.end()
        end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        block = text[start:end]

        classname_match = _CLASSNAME_RE.search(block)
        origin_match = _ORIGIN_RE.search(block)

        classname = classname_match.group(1) if classname_match else None
        origin = None
        if origin_match:
            origin = (
                float(origin_match.group(1)),
                float(origin_match.group(2)),
                float(origin_match.group(3)),
            )

        edicts.append(Edict(number=int(match.group(1)), classname=classname, origin=origin))

    return edicts


def yaw_from_delta(dx: float, dy: float) -> float:
    return math.degrees(math.atan2(dy, dx))


def find_nearest(origin: Tuple[float, float, float], candidates: List[Edict]) -> Optional[Edict]:
    ox, oy, oz = origin
    best: Optional[Edict] = None
    best_dist = float("inf")
    for edict in candidates:
        if not edict.origin:
            continue
        ex, ey, ez = edict.origin
        dist = (ex - ox) ** 2 + (ey - oy) ** 2 + (ez - oz) ** 2
        if dist < best_dist:
            best = edict
            best_dist = dist
    return best


def build_control_command(vx: float, vy: float, vz: float, yaw: float, pitch: float) -> str:
    return (
        f"set bot_vel_x {vx:.2f};"
        f" set bot_vel_y {vy:.2f};"
        f" set bot_vel_z {vz:.2f};"
        f" set bot_yaw {yaw:.2f};"
        f" set bot_pitch {pitch:.2f};"
        " set bot_attack 0;"
        " set bot_jump 0"
    )


def run_follow(
    host: str,
    port: int,
    password: str,
    *,
    hz: float,
    speed: float,
    stop_radius: float,
    respawn_every_s: float,
) -> None:
    client = RconClient(host, port, password)

    warmup = client.command("status")
    if not warmup:
        print("RCON warning: no response to 'status' (check port/rcon_password).")

    last_spawn = 0.0
    last_warn = 0.0
    dt = 1.0 / max(hz, 1.0)
    while True:
        now = time.time()
        if now - last_spawn >= respawn_every_s:
            try:
                client.command("set cortex_spawn_bot 1")
            except Exception as exc:
                print(f"RCON error: {exc}")
            last_spawn = now

        try:
            output = client.command("prvm_edicts sv")
        except Exception as exc:
            print(f"RCON error: {exc}")
            time.sleep(1.0)
            continue
        edicts = parse_edicts(output)
        if not edicts and (now - last_warn) >= 5.0:
            print("RCON warning: no edicts received (is the server on this port?)")
            last_warn = now

        bot = next((e for e in edicts if e.classname == "cortex_bot" and e.origin), None)
        players = [e for e in edicts if e.classname == "player" and e.origin]

        if bot and bot.origin and players:
            target = find_nearest(bot.origin, players)
            if target and target.origin:
                bx, by, _ = bot.origin
                tx, ty, _ = target.origin
                dx = tx - bx
                dy = ty - by
                dist = math.hypot(dx, dy)

                yaw = yaw_from_delta(dx, dy)
                if dist <= stop_radius:
                    cmd = build_control_command(0.0, 0.0, 0.0, yaw, 0.0)
                else:
                    vx = (dx / dist) * speed
                    vy = (dy / dist) * speed
                    cmd = build_control_command(vx, vy, 0.0, yaw, 0.0)
                client.command(cmd)
        else:
            client.command(build_control_command(0.0, 0.0, 0.0, 0.0, 0.0))

        time.sleep(dt)


def main() -> None:
    parser = argparse.ArgumentParser(description="Basic DarkPlaces DM follow bot (RCON).")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=26000)
    parser.add_argument("--password", default="cortex_secret")
    parser.add_argument("--hz", type=float, default=20.0, help="Update rate (Hz).")
    parser.add_argument("--speed", type=float, default=300.0, help="Chase speed (units/sec).")
    parser.add_argument("--stop-radius", type=float, default=64.0, help="Stop within this range.")
    parser.add_argument("--respawn-every", type=float, default=5.0, help="Re-assert bot spawn interval (sec).")
    args = parser.parse_args()

    run_follow(
        args.host,
        args.port,
        args.password,
        hz=args.hz,
        speed=args.speed,
        stop_radius=args.stop_radius,
        respawn_every_s=args.respawn_every,
    )


if __name__ == "__main__":
    main()
