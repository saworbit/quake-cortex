"""
PROJECT CORTEX - Brain Server (Phase 1: The Skeleton)

This server receives sensor data from Quake via a stream opened by QuakeC.

Depending on the engine build, the stream may be:
- raw TCP (newline-delimited JSON), or
- WebSocket-wrapped TCP (engine uses ws:// framing).

This logger auto-detects and supports both.
"""

import json
import logging
import socket
import ssl
import subprocess
import threading
import time
from datetime import datetime
from pathlib import Path

try:
    from cortex_ws import (
        WebSocketConn,
        accept_websocket,
        looks_like_http_websocket_handshake,
        looks_like_tls_client_hello,
        looks_like_websocket_frame,
    )
except ImportError:  # pragma: no cover
    # When imported as a package (python.cortex_brain), use absolute import.
    from python.cortex_ws import (  # type: ignore[no-redef]
        WebSocketConn,
        accept_websocket,
        looks_like_http_websocket_handshake,
        looks_like_tls_client_hello,
        looks_like_websocket_frame,
    )

logger = logging.getLogger("CortexBrainTCP")


def _setup_logging() -> None:
    if getattr(logger, "_cortex_configured", False):
        return
    logger.setLevel(logging.DEBUG)

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    logs_dir = _project_root() / ".cortex" / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    log_path = logs_dir / f"cortex_brain_tcp_{ts}.log"
    file_handler = logging.FileHandler(log_path, encoding="utf-8")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(
        logging.Formatter("%(asctime)s | %(levelname)s | %(message)s")
    )

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter("%(message)s"))

    logger.addHandler(file_handler)
    logger.addHandler(console)
    logger._cortex_configured = True  # type: ignore[attr-defined]
    logger.info(f"[CORTEX BRAIN] Logging to {log_path}")


def _close_socket(sock: socket.socket | None) -> None:
    if not sock:
        return
    try:
        sock.shutdown(socket.SHUT_RDWR)
    except OSError:
        pass
    try:
        sock.close()
    except OSError:
        pass


def _project_root() -> Path:
    return Path(__file__).resolve().parents[1]


def _tls_paths() -> tuple[Path, Path]:
    root = _project_root()
    tls_dir = root / ".cortex" / "tls"
    return tls_dir / "cortex_localhost.crt.pem", tls_dir / "cortex_localhost.key.pem"


def _generate_tls_cert(cert_path: Path, key_path: Path) -> None:
    cert_path.parent.mkdir(parents=True, exist_ok=True)
    script = _project_root() / "scripts" / "generate_cortex_tls_cert.ps1"
    if not script.exists():
        raise FileNotFoundError(f"Missing TLS cert generator script: {script}")

    try:
        subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(script),
                "-CertPath",
                str(cert_path),
                "-KeyPath",
                str(key_path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
    except subprocess.CalledProcessError as e:
        raise RuntimeError(
            f"TLS cert generation failed: {e.stderr or e.stdout or e}"
        ) from e


def _ensure_tls_cert(*, force: bool = False) -> tuple[Path, Path]:
    cert_path, key_path = _tls_paths()
    if not force and cert_path.exists() and key_path.exists():
        return cert_path, key_path

    _generate_tls_cert(cert_path, key_path)
    return cert_path, key_path


def _wrap_tls_server(sock: socket.socket) -> ssl.SSLSocket:
    cert_path, key_path = _ensure_tls_cert()

    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    try:
        ctx.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))
    except ssl.SSLError:
        # Old/bad certs can linger under `.cortex/tls/` from earlier builds.
        try:
            cert_path.unlink()
        except OSError:
            pass
        try:
            key_path.unlink()
        except OSError:
            pass

        cert_path, key_path = _ensure_tls_cert(force=True)
        ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        ctx.load_cert_chain(certfile=str(cert_path), keyfile=str(key_path))
    ssl_sock = ctx.wrap_socket(sock, server_side=True, do_handshake_on_connect=False)
    ssl_sock.do_handshake()
    return ssl_sock


class CortexBrain:
    def __init__(self, host="127.0.0.1", port=26000):
        self.host = host
        self.port = port
        self.socket = None
        self.client_socket = None
        self.running = False
        self.accept_timeout_s = 0.5

    def _start_quit_watcher(self) -> None:
        def _watch() -> None:
            try:
                input()
            except (EOFError, KeyboardInterrupt):
                return
            logger.info("[CORTEX BRAIN] Quit requested (ENTER).")
            self.running = False
            _close_socket(self.client_socket)
            self.client_socket = None
            _close_socket(self.socket)
            self.socket = None

        t = threading.Thread(target=_watch, name="cortex-quit-watcher", daemon=True)
        t.start()

    def start(self):
        """Start the brain server and wait for Quake to connect"""
        _setup_logging()
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            self.socket.bind((self.host, self.port))
            self.socket.listen(1)
            self.socket.settimeout(self.accept_timeout_s)
            logger.info(f"[CORTEX BRAIN] Listening on {self.host}:{self.port}")
            logger.info("[CORTEX BRAIN] Waiting for Quake client to connect...")
            logger.info("[CORTEX BRAIN] Press ENTER to quit.")
            self._start_quit_watcher()

            self.running = True
            self.accept_connection()

        except Exception as e:
            logger.error(f"[ERROR] Failed to start server: {e}")
            self.cleanup()

    def accept_connection(self):
        """Accept incoming connection from Quake"""
        while self.running:
            try:
                try:
                    if not self.socket:
                        break
                    self.client_socket, addr = self.socket.accept()
                except socket.timeout:
                    continue
                try:
                    self.client_socket.setsockopt(
                        socket.IPPROTO_TCP, socket.TCP_NODELAY, 1
                    )
                except OSError:
                    pass
                try:
                    self.client_socket.settimeout(0.5)
                except OSError:
                    pass
                logger.info(f"[CORTEX BRAIN] Connected to Quake client at {addr}")
                self.handle_client()
            except KeyboardInterrupt:
                logger.info("\n[CORTEX BRAIN] Shutting down...")
                self.running = False
                break
            except OSError as e:
                # Expected when the quit watcher closes sockets while we're blocked in accept/recv.
                if not self.running:
                    break
                logger.error(f"[ERROR] Socket error: {e}")
                time.sleep(0.25)
            except Exception as e:
                if not self.running:
                    break
                logger.error(f"[ERROR] Connection error: {e}")
                time.sleep(0.5)

    def handle_client(self):
        """Process incoming data from Quake"""
        buffer = bytearray()
        ws: WebSocketConn | None = None

        while self.running:
            try:
                if ws is None and not buffer:
                    # First read: detect transport without consuming bytes (TLS needs the full handshake).
                    try:
                        peek = self.client_socket.recv(4096, socket.MSG_PEEK)
                    except OSError:
                        peek = b""

                    if not peek:
                        logger.info("[CORTEX BRAIN] Client disconnected")
                        break

                    if looks_like_tls_client_hello(peek):
                        logger.info(
                            "[CORTEX BRAIN] Detected TLS client hello (engine is negotiating TLS on this stream)."
                        )
                        try:
                            self.client_socket = _wrap_tls_server(self.client_socket)
                            self.client_socket.settimeout(0.5)
                            logger.info("[CORTEX BRAIN] TLS handshake complete")
                            continue
                        except Exception as e:
                            logger.error(f"[ERROR] TLS handshake failed: {e}")
                            logger.error(
                                "[CORTEX BRAIN] Fix: prefer `ws://127.0.0.1:26000/` for `cortex_tcp_uri` (default in scripts/run_quake_tcp.bat), or upgrade FTEQW."
                            )
                            break

                    chunk = self.client_socket.recv(4096)
                    if not chunk:
                        logger.info("[CORTEX BRAIN] Client disconnected")
                        break

                    if looks_like_http_websocket_handshake(chunk):
                        try:
                            ws = accept_websocket(self.client_socket, initial=chunk)
                            logger.info("[CORTEX BRAIN] WebSocket handshake complete")
                            continue
                        except Exception as e:
                            if "Sec-WebSocket-Key" in str(e):
                                logger.error(
                                    "[CORTEX BRAIN] Client sent an HTTP request, not a WebSocket upgrade."
                                )
                                logger.error(
                                    "[CORTEX BRAIN] Fix: set `cortex_tcp_uri tcp://127.0.0.1:26000` (raw TCP) and restart Quake."
                                )
                            else:
                                logger.error(f"[ERROR] WebSocket handshake failed: {e}")
                            break

                    if looks_like_websocket_frame(chunk):
                        ws = WebSocketConn(
                            sock=self.client_socket, _recv_buf=bytearray(chunk)
                        )
                        logger.info(
                            "[CORTEX BRAIN] Detected WebSocket frames without handshake; decoding anyway."
                        )
                        continue

                    buffer.extend(chunk)
                elif ws is not None:
                    payload = ws.recv_message()
                    if payload:
                        buffer.extend(payload)
                else:
                    chunk = self.client_socket.recv(4096)
                    if not chunk:
                        logger.info("[CORTEX BRAIN] Client disconnected")
                        break
                    buffer.extend(chunk)

                while True:
                    nl = buffer.find(b"\n")
                    if nl == -1:
                        break

                    line_bytes = buffer[:nl]
                    del buffer[: nl + 1]

                    line = line_bytes.decode("utf-8", errors="replace").strip()
                    if line:
                        self.process_packet(line)

            except socket.timeout:
                continue
            except OSError as e:
                if not self.running:
                    break
                logger.error(f"[ERROR] Socket error while processing data: {e}")
                break
            except Exception as e:
                logger.error(f"[ERROR] Failed to process data: {e}")
                break

        _close_socket(self.client_socket)
        self.client_socket = None

    def process_packet(self, packet):
        """
        Process a single data packet from Quake

        Phase 1: Just log it to verify the pipeline
        Phase 2+: Parse and process sensor data
        """
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        if packet.startswith("{"):
            try:
                data = json.loads(packet)
            except json.JSONDecodeError:
                logger.info(f"[{timestamp}] {packet}")
                return

            pos = data.get("pos")
            if isinstance(pos, list) and len(pos) == 3:
                x, y, z = pos
                logger.info(f"[{timestamp}] POS x={x} y={y} z={z}")
                return

            logger.info(f"[{timestamp}] JSON {data}")
            return

        logger.info(f"[{timestamp}] {packet}")

        # TODO Phase 2: Parse JSON sensor data and run through neural networks
        # TODO Phase 3: Generate control outputs and send back to Quake

    def cleanup(self):
        """Clean shutdown"""
        self.running = False
        _close_socket(self.client_socket)
        self.client_socket = None
        _close_socket(self.socket)
        self.socket = None


if __name__ == "__main__":
    _setup_logging()
    logger.info("=" * 60)
    logger.info("PROJECT CORTEX - Phase 1: The Skeleton")
    logger.info("=" * 60)
    logger.info("")

    brain = CortexBrain()
    try:
        brain.start()
    except KeyboardInterrupt:
        logger.info("\n[CORTEX BRAIN] Interrupted by user")
    finally:
        brain.cleanup()
