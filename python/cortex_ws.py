from __future__ import annotations

import base64
import hashlib
from dataclasses import dataclass


_WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def looks_like_tls_client_hello(data: bytes) -> bool:
    # TLS record header:
    #   ContentType(0x16=handshake) Version(0x03 0x01/0x03/0x04) Length(2)
    return len(data) >= 3 and data[0] == 0x16 and data[1] == 0x03


def looks_like_http_websocket_handshake(data: bytes) -> bool:
    # WebSocket handshake starts with an HTTP request line.
    return data.startswith(b"GET ") or data.startswith(b"OPTIONS ") or data.startswith(b"HEAD ")


def _read_until(sock, buf: bytearray, marker: bytes, *, max_bytes: int = 16_384) -> None:
    while marker not in buf:
        chunk = sock.recv(4096)
        if not chunk:
            raise ConnectionError("Socket closed while waiting for handshake.")
        buf.extend(chunk)
        if len(buf) > max_bytes:
            raise ValueError("Handshake too large.")


def _parse_http_headers(raw: bytes) -> tuple[str, dict[str, str]]:
    text = raw.decode("iso-8859-1", errors="replace")
    lines = text.splitlines()
    request_line = lines[0] if lines else ""
    headers: dict[str, str] = {}
    for line in lines[1:]:
        if not line.strip():
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        headers[k.strip().lower()] = v.strip()
    return request_line, headers


def accept_websocket(sock, initial: bytes = b"") -> "WebSocketConn":
    buf = bytearray(initial)
    _read_until(sock, buf, b"\r\n\r\n")
    header_blob, rest = buf.split(b"\r\n\r\n", 1)

    _req, headers = _parse_http_headers(header_blob)
    key = headers.get("sec-websocket-key")
    if not key:
        raise ValueError("Missing Sec-WebSocket-Key.")

    accept_src = (key + _WS_GUID).encode("ascii", errors="strict")
    accept_val = base64.b64encode(hashlib.sha1(accept_src).digest()).decode("ascii")

    protocol = headers.get("sec-websocket-protocol")
    resp = (
        "HTTP/1.1 101 Switching Protocols\r\n"
        "Upgrade: websocket\r\n"
        "Connection: Upgrade\r\n"
        f"Sec-WebSocket-Accept: {accept_val}\r\n"
    )
    if protocol:
        resp += f"Sec-WebSocket-Protocol: {protocol}\r\n"
    resp += "\r\n"

    sock.sendall(resp.encode("ascii", errors="strict"))
    return WebSocketConn(sock=sock, _recv_buf=bytearray(rest))


@dataclass
class WebSocketConn:
    sock: any
    _recv_buf: bytearray

    def recv_message(self) -> bytes:
        """
        Receives a single WebSocket message (text/binary) and returns raw payload bytes.
        """

        buf = self._recv_buf
        while len(buf) < 2:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("WebSocket disconnected.")
            buf.extend(chunk)

        b0 = buf[0]
        b1 = buf[1]
        fin = (b0 & 0x80) != 0
        opcode = b0 & 0x0F
        masked = (b1 & 0x80) != 0
        length = b1 & 0x7F
        idx = 2

        if length == 126:
            while len(buf) < idx + 2:
                buf.extend(self.sock.recv(4096))
            length = int.from_bytes(buf[idx : idx + 2], "big")
            idx += 2
        elif length == 127:
            while len(buf) < idx + 8:
                buf.extend(self.sock.recv(4096))
            length = int.from_bytes(buf[idx : idx + 8], "big")
            idx += 8

        mask = b""
        if masked:
            while len(buf) < idx + 4:
                buf.extend(self.sock.recv(4096))
            mask = bytes(buf[idx : idx + 4])
            idx += 4

        while len(buf) < idx + length:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise ConnectionError("WebSocket disconnected mid-frame.")
            buf.extend(chunk)

        payload = bytes(buf[idx : idx + length])
        del buf[: idx + length]

        if masked:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))

        if opcode == 0x8:
            raise ConnectionError("WebSocket close frame received.")
        if opcode == 0x9:
            # ping -> pong
            self.send_message(payload, opcode=0xA)
            return self.recv_message()
        if opcode == 0xA:
            return self.recv_message()
        if opcode in (0x1, 0x2, 0x0):
            if fin:
                return payload
            # Continuations: accumulate until fin.
            parts = [payload]
            while True:
                part = self.recv_message()
                parts.append(part)
                # recv_message() above only returns on fin=true frames; good enough.
                return b"".join(parts)

        return payload

    def send_message(self, payload: bytes, *, opcode: int = 0x1) -> None:
        """
        Sends a single unmasked server->client WebSocket message.
        """

        if opcode not in (0x1, 0x2):
            opcode = 0x1

        header = bytearray()
        header.append(0x80 | (opcode & 0x0F))  # FIN + opcode
        length = len(payload)
        if length < 126:
            header.append(length)
        elif length < (1 << 16):
            header.append(126)
            header.extend(length.to_bytes(2, "big"))
        else:
            header.append(127)
            header.extend(length.to_bytes(8, "big"))

        self.sock.sendall(bytes(header) + payload)

