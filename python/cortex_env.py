from __future__ import annotations

import json
import socket
import time
from dataclasses import dataclass
from typing import Any

import gymnasium as gym
import numpy as np
from gymnasium import spaces

from .cortex_ws import (
    WebSocketConn,
    accept_websocket,
    looks_like_http_websocket_handshake,
    looks_like_tls_client_hello,
)


@dataclass
class QuakeCortexConfig:
    host: str = "127.0.0.1"
    port: int = 26000
    accept_timeout_s: float = 0.1
    step_timeout_s: float = 1.0


class QuakeCortexEnv(gym.Env[np.ndarray, np.ndarray]):
    metadata = {"render_modes": []}

    def __init__(self, *, host: str = "127.0.0.1", port: int = 26000):
        super().__init__()

        self.cfg = QuakeCortexConfig(host=host, port=port)

        # ACTION SPACE (SB3-friendly): [move_fwd, move_side, aim_yaw, aim_pitch, attack, jump]
        self.action_space = spaces.Box(low=-1, high=1, shape=(6,), dtype=np.float32)

        # OBSERVATION SPACE:
        # health (1), armor (1), ammo (4), lidar (5), velocity (3) => 14
        self.observation_space = spaces.Box(
            low=-np.inf, high=np.inf, shape=(14,), dtype=np.float32
        )

        self._server: socket.socket | None = None
        self._conn: socket.socket | None = None
        self._ws: WebSocketConn | None = None
        self._recv_buf = bytearray()

        self._prev_health: float | None = None
        self._t0 = time.monotonic()

        self._listen()

    def _listen(self) -> None:
        if self._server is not None:
            return
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind((self.cfg.host, self.cfg.port))
        server.listen(1)
        self._server = server

    def _accept_if_needed(self) -> None:
        if self._conn is not None:
            return
        if self._server is None:
            raise RuntimeError("Server socket not initialized.")

        while self._conn is None:
            self._server.settimeout(self.cfg.accept_timeout_s)
            try:
                conn, _addr = self._server.accept()
            except TimeoutError:
                continue

            try:
                conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
            except OSError:
                pass

            self._conn = conn
            self._ws = None
            self._recv_buf.clear()

            # Detect WS vs raw TCP on first bytes.
            self._conn.settimeout(self.cfg.step_timeout_s)
            first = self._conn.recv(4096)
            if not first:
                self._conn.close()
                self._conn = None
                continue

            if looks_like_tls_client_hello(first):
                raise RuntimeError(
                    "Quake connected using TLS handshake bytes. Use ws:// (not tcp://) for cortex_tcp_uri."
                )

            if looks_like_http_websocket_handshake(first):
                self._ws = accept_websocket(self._conn, initial=first)
            else:
                self._recv_buf.extend(first)

    def _readline(self, timeout_s: float) -> str:
        if self._conn is None:
            raise RuntimeError("No active Quake connection.")

        deadline = time.monotonic() + timeout_s
        while True:
            nl = self._recv_buf.find(b"\n")
            if nl != -1:
                line = self._recv_buf[:nl]
                del self._recv_buf[: nl + 1]
                return line.decode("utf-8", errors="replace").rstrip("\r")

            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError("Timed out waiting for telemetry line.")

            if self._ws is not None:
                self._conn.settimeout(min(0.25, remaining))
                payload = self._ws.recv_message()
                if not payload:
                    raise ConnectionError("Quake disconnected.")
                self._recv_buf.extend(payload)
            else:
                self._conn.settimeout(min(0.25, remaining))
                chunk = self._conn.recv(4096)
                if not chunk:
                    raise ConnectionError("Quake disconnected.")
                self._recv_buf.extend(chunk)

    def _send_action(self, action: np.ndarray) -> None:
        if self._conn is None:
            raise RuntimeError("No active Quake connection.")

        a = np.asarray(action, dtype=np.float32).reshape(-1)
        if a.shape != (6,):
            raise ValueError(f"Expected action shape (6,), got {a.shape}.")

        move_fwd = float(a[0] * 400.0)
        move_side = float(a[1] * 400.0)
        aim_yaw = float(a[2] * 10.0)
        aim_pitch = float(a[3] * 10.0)
        attack = 1 if float(a[4]) > 0 else 0
        jump = 1 if float(a[5]) > 0 else 0

        cmd = {
            "aim": [aim_yaw, aim_pitch],
            "move": [move_fwd, move_side],
            "buttons": (attack * 1) + (jump * 2),
        }

        payload = (json.dumps(cmd) + "\n").encode("utf-8")
        if self._ws is not None:
            self._ws.send_message(payload, opcode=0x1)
        else:
            self._conn.sendall(payload)

    def _parse_obs(self, data: dict[str, Any]) -> np.ndarray:
        health = float(data.get("health", 0.0))
        armor = float(data.get("armor", 0.0))

        ammo_shells = float(data.get("ammo_shells", 0.0))
        ammo_nails = float(data.get("ammo_nails", 0.0))
        ammo_rockets = float(data.get("ammo_rockets", 0.0))
        ammo_cells = float(data.get("ammo_cells", 0.0))

        lidar = data.get("lidar", [0, 0, 0, 0, 0])
        if not isinstance(lidar, list) or len(lidar) != 5:
            lidar = [0, 0, 0, 0, 0]
        lidar_0, lidar_1, lidar_2, lidar_3, lidar_4 = (float(x) for x in lidar)

        vel = data.get("vel", [0, 0, 0])
        if not isinstance(vel, list) or len(vel) != 3:
            vel = [0, 0, 0]
        vel_x, vel_y, vel_z = (float(x) for x in vel)

        obs = np.array(
            [
                health,
                armor,
                ammo_shells,
                ammo_nails,
                ammo_rockets,
                ammo_cells,
                lidar_0,
                lidar_1,
                lidar_2,
                lidar_3,
                lidar_4,
                vel_x,
                vel_y,
                vel_z,
            ],
            dtype=np.float32,
        )
        return obs

    def reset(self, *, seed: int | None = None, options: dict[str, Any] | None = None):
        super().reset(seed=seed)

        self._accept_if_needed()

        # Wait for first telemetry packet.
        while True:
            line = self._readline(self.cfg.step_timeout_s)
            if not line or line.startswith("---"):
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            obs = self._parse_obs(data)
            self._prev_health = float(data.get("health", 0.0))
            return obs, {}

    def step(self, action: np.ndarray):
        self._accept_if_needed()

        self._send_action(action)

        data: dict[str, Any] = {}
        while True:
            line = self._readline(self.cfg.step_timeout_s)
            if not line or line.startswith("---"):
                continue
            if not line.startswith("{"):
                continue
            try:
                data = json.loads(line)
            except json.JSONDecodeError:
                continue
            break

        obs = self._parse_obs(data)

        # Reward: simple survival + health delta shaping.
        reward = 0.01
        health = float(data.get("health", 0.0))
        if self._prev_health is not None:
            reward += (health - self._prev_health) * 0.001
        self._prev_health = health

        terminated = health <= 0
        truncated = False
        info: dict[str, Any] = {
            "uptime_s": time.monotonic() - self._t0,
        }
        return obs, float(reward), terminated, truncated, info

    def close(self):
        if self._conn is not None:
            try:
                self._conn.close()
            finally:
                self._conn = None
                self._ws = None
        if self._server is not None:
            try:
                self._server.close()
            finally:
                self._server = None
