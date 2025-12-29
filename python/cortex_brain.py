"""
PROJECT CORTEX - Brain Server (Phase 1: The Skeleton)

This server receives sensor data from the Quake client via TCP.
In Phase 1, we simply log the data to verify the pipeline works.
"""

import socket
import time
from datetime import datetime


class CortexBrain:
    def __init__(self, host="127.0.0.1", port=5000):
        self.host = host
        self.port = port
        self.socket = None
        self.client_socket = None
        self.running = False

    def start(self):
        """Start the brain server and wait for Quake to connect"""
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            self.socket.bind((self.host, self.port))
            self.socket.listen(1)
            print(f"[CORTEX BRAIN] Listening on {self.host}:{self.port}")
            print("[CORTEX BRAIN] Waiting for Quake client to connect...")

            self.running = True
            self.accept_connection()

        except Exception as e:
            print(f"[ERROR] Failed to start server: {e}")
            self.cleanup()

    def accept_connection(self):
        """Accept incoming connection from Quake"""
        while self.running:
            try:
                self.client_socket, addr = self.socket.accept()
                print(f"[CORTEX BRAIN] Connected to Quake client at {addr}")
                self.handle_client()
            except KeyboardInterrupt:
                print("\n[CORTEX BRAIN] Shutting down...")
                self.running = False
            except Exception as e:
                print(f"[ERROR] Connection error: {e}")
                time.sleep(1)

    def handle_client(self):
        """Process incoming data from Quake"""
        buffer = ""

        while self.running:
            try:
                # Receive data in chunks
                data = self.client_socket.recv(4096).decode("utf-8")

                if not data:
                    print("[CORTEX BRAIN] Client disconnected")
                    break

                # Add to buffer and process line by line
                buffer += data
                lines = buffer.split("\n")
                buffer = lines[-1]  # Keep incomplete line in buffer

                for line in lines[:-1]:
                    if line.strip():
                        self.process_packet(line.strip())

            except Exception as e:
                print(f"[ERROR] Failed to process data: {e}")
                break

        if self.client_socket:
            self.client_socket.close()
            self.client_socket = None

    def process_packet(self, packet):
        """
        Process a single data packet from Quake

        Phase 1: Just log it to verify the pipeline
        Phase 2+: Parse and process sensor data
        """
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{timestamp}] {packet}")

        # TODO Phase 2: Parse JSON sensor data and run through neural networks
        # TODO Phase 3: Generate control outputs and send back to Quake

    def cleanup(self):
        """Clean shutdown"""
        self.running = False
        if self.client_socket:
            self.client_socket.close()
        if self.socket:
            self.socket.close()


if __name__ == "__main__":
    print("=" * 60)
    print("PROJECT CORTEX - Phase 1: The Skeleton")
    print("=" * 60)
    print()

    brain = CortexBrain()
    try:
        brain.start()
    except KeyboardInterrupt:
        print("\n[CORTEX BRAIN] Interrupted by user")
    finally:
        brain.cleanup()
