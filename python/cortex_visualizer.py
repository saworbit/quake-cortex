"""
PROJECT CORTEX - Sensor Visualizer

A simple real-time visualization of what the AI "sees".
Shows position, velocity, raycasts, and state in a debug window.
"""

import socket
import json
import time
import math
from datetime import datetime

try:
    import pygame

    PYGAME_AVAILABLE = True
except ImportError:
    PYGAME_AVAILABLE = False
    print("[WARNING] pygame not available. Running in text-only mode.")
    print("Install pygame with: pip install pygame")


class CortexVisualizer:
    def __init__(self, host="127.0.0.1", port=5000):
        self.host = host
        self.port = port
        self.socket = None
        self.client_socket = None
        self.running = False
        self.last_data = None

        if PYGAME_AVAILABLE:
            pygame.init()
            self.screen = pygame.display.set_mode((800, 600))
            pygame.display.set_caption("CORTEX - Sensor Visualizer")
            self.font = pygame.font.Font(None, 24)
            self.small_font = pygame.font.Font(None, 18)
            self.clock = pygame.time.Clock()

    def start(self):
        """Start the visualizer server"""
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)

        try:
            self.socket.bind((self.host, self.port))
            self.socket.listen(1)
            print(f"[VISUALIZER] Listening on {self.host}:{self.port}")
            print("[VISUALIZER] Waiting for Quake to connect...")

            self.running = True
            self.accept_connection()

        except Exception as e:
            print(f"[ERROR] Failed to start: {e}")
            self.cleanup()

    def accept_connection(self):
        """Accept Quake connection"""
        while self.running:
            try:
                self.client_socket, addr = self.socket.accept()
                print(f"[VISUALIZER] Connected to Quake at {addr}")
                self.handle_client()
            except KeyboardInterrupt:
                print("\n[VISUALIZER] Shutting down...")
                self.running = False
            except Exception as e:
                print(f"[ERROR] Connection error: {e}")
                time.sleep(1)

    def handle_client(self):
        """Process incoming sensor data"""
        buffer = ""

        while self.running:
            try:
                # Handle pygame events
                if PYGAME_AVAILABLE:
                    for event in pygame.event.get():
                        if event.type == pygame.QUIT:
                            self.running = False
                            return

                # Receive data
                data = self.client_socket.recv(4096).decode("utf-8")
                if not data:
                    print("[VISUALIZER] Client disconnected")
                    break

                buffer += data
                lines = buffer.split("\n")
                buffer = lines[-1]

                for line in lines[:-1]:
                    if line.strip():
                        self.process_packet(line.strip())

                # Render visualization
                if PYGAME_AVAILABLE:
                    self.render()
                    self.clock.tick(60)  # 60 FPS

            except Exception as e:
                print(f"[ERROR] {e}")
                break

        if self.client_socket:
            self.client_socket.close()
            self.client_socket = None

    def process_packet(self, packet):
        """Parse and store sensor data"""
        try:
            data = json.loads(packet)
            self.last_data = data

            # Print to console in text mode
            if not PYGAME_AVAILABLE:
                self.print_text_visualization(data)

        except json.JSONDecodeError:
            # Legacy format (just position string)
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            print(f"[{timestamp}] {packet}")

    def print_text_visualization(self, data):
        """Print text-based visualization"""
        print("\n" + "=" * 60)
        print(f"TIME: {data.get('time', 0):.2f}s")

        if "position" in data:
            pos = data["position"]
            print(f"POSITION: ({pos['x']:.1f}, {pos['y']:.1f}, {pos['z']:.1f})")
            print(f"ANGLES: Pitch={pos['pitch']:.1f}° Yaw={pos['yaw']:.1f}°")

        if "velocity" in data:
            vel = data["velocity"]
            print(f"VELOCITY: Speed={vel['speed']:.1f} u/s")

        if "state" in data:
            state = data["state"]
            print(f"HEALTH: {state['health']:.0f}  ARMOR: {state['armor']:.0f}")
            print(f"WEAPON: {state['weapon']:.0f}  AMMO: {state['ammo']:.0f}")
            print(f"GROUNDED: {bool(state['grounded'])}")

    def render(self):
        """Render pygame visualization"""
        self.screen.fill((10, 10, 20))

        if not self.last_data:
            text = self.font.render("Waiting for data...", True, (100, 100, 100))
            self.screen.blit(text, (300, 280))
            pygame.display.flip()
            return

        y_offset = 10

        # Title
        title = self.font.render("CORTEX SENSOR FEED", True, (0, 255, 100))
        self.screen.blit(title, (10, y_offset))
        y_offset += 40

        # Time
        time_text = f"Time: {self.last_data.get('time', 0):.2f}s"
        self.draw_text(time_text, 10, y_offset, (200, 200, 200))
        y_offset += 30

        # Position
        if "position" in self.last_data:
            pos = self.last_data["position"]
            self.draw_text("POSITION:", 10, y_offset, (100, 200, 255))
            y_offset += 25
            self.draw_text(
                f"  X: {pos['x']:.1f}", 10, y_offset, (200, 200, 200), self.small_font
            )
            y_offset += 20
            self.draw_text(
                f"  Y: {pos['y']:.1f}", 10, y_offset, (200, 200, 200), self.small_font
            )
            y_offset += 20
            self.draw_text(
                f"  Z: {pos['z']:.1f}", 10, y_offset, (200, 200, 200), self.small_font
            )
            y_offset += 25
            self.draw_text(
                f"  Yaw: {pos['yaw']:.1f}°",
                10,
                y_offset,
                (200, 200, 200),
                self.small_font,
            )
            y_offset += 30

        # Velocity
        if "velocity" in self.last_data:
            vel = self.last_data["velocity"]
            speed = vel["speed"]
            color = (100, 255, 100) if speed > 320 else (200, 200, 200)
            self.draw_text("VELOCITY:", 10, y_offset, (100, 200, 255))
            y_offset += 25
            self.draw_text(
                f"  Speed: {speed:.1f} u/s", 10, y_offset, color, self.small_font
            )
            y_offset += 30

        # State
        if "state" in self.last_data:
            state = self.last_data["state"]
            self.draw_text("STATE:", 10, y_offset, (100, 200, 255))
            y_offset += 25

            # Health bar
            health = state["health"]
            health_color = (100, 255, 100) if health > 50 else (255, 100, 100)
            self.draw_text(
                f"  Health: {health:.0f}", 10, y_offset, health_color, self.small_font
            )
            pygame.draw.rect(
                self.screen, health_color, (120, y_offset, int(health * 2), 15)
            )
            y_offset += 20

            self.draw_text(
                f"  Armor: {state['armor']:.0f}",
                10,
                y_offset,
                (200, 200, 200),
                self.small_font,
            )
            y_offset += 20
            self.draw_text(
                f"  Ammo: {state['ammo']:.0f}",
                10,
                y_offset,
                (200, 200, 200),
                self.small_font,
            )
            y_offset += 20
            grounded = "YES" if state["grounded"] else "NO"
            self.draw_text(
                f"  Grounded: {grounded}",
                10,
                y_offset,
                (200, 200, 200),
                self.small_font,
            )
            y_offset += 30

        # Raycasts visualization (top-down view)
        if "raycasts" in self.last_data:
            self.draw_raycasts(500, 300, 200)

        pygame.display.flip()

    def draw_text(self, text, x, y, color, font=None):
        """Helper to draw text"""
        if font is None:
            font = self.font
        surf = font.render(text, True, color)
        self.screen.blit(surf, (x, y))

    def draw_raycasts(self, cx, cy, radius):
        """Draw top-down raycast visualization"""
        if "raycasts" not in self.last_data:
            return

        raycasts = self.last_data["raycasts"]

        # Draw circle border
        pygame.draw.circle(self.screen, (50, 50, 50), (cx, cy), radius, 2)

        # Draw rays
        for i, ray in enumerate(raycasts):
            dist = ray["dist"]
            hit = ray["hit"]

            # Calculate angle (evenly distributed)
            angle = (i / len(raycasts)) * 2 * math.pi

            # Scale distance to fit in circle
            normalized_dist = min(dist / 1000.0, 1.0)
            ray_length = normalized_dist * radius

            # Calculate endpoint
            end_x = cx + math.cos(angle) * ray_length
            end_y = cy + math.sin(angle) * ray_length

            # Color based on surface type
            color = (100, 100, 100)
            if hit:
                surface = ray.get("surface", "solid")
                if surface == "lava":
                    color = (255, 100, 0)
                elif surface == "slime":
                    color = (100, 255, 0)
                elif surface == "water":
                    color = (0, 100, 255)
                else:
                    color = (150, 150, 150)

            # Draw ray
            pygame.draw.line(self.screen, color, (cx, cy), (end_x, end_y), 1)

        # Draw center dot
        pygame.draw.circle(self.screen, (255, 255, 255), (cx, cy), 3)

        # Label
        self.draw_text(
            "RAYCASTS (Top-Down)", cx - 80, cy - radius - 20, (100, 200, 255)
        )

    def cleanup(self):
        """Clean shutdown"""
        self.running = False
        if self.client_socket:
            self.client_socket.close()
        if self.socket:
            self.socket.close()
        if PYGAME_AVAILABLE:
            pygame.quit()


if __name__ == "__main__":
    print("=" * 60)
    print("PROJECT CORTEX - Sensor Visualizer")
    print("=" * 60)
    print()

    viz = CortexVisualizer()
    try:
        viz.start()
    except KeyboardInterrupt:
        print("\n[VISUALIZER] Interrupted by user")
    finally:
        viz.cleanup()
