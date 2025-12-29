#!/usr/bin/env python3
"""
🧪 Project Cortex - Connection Test Harness
===========================================
Automated test suite for validating Quake → Python telemetry pipeline.

This script:
1. Starts the Cortex Brain server
2. Guides you through launching Quake
3. Monitors telemetry in real-time
4. Handles graceful shutdown and cleanup
"""

import subprocess
import sys
import time
import os
import signal
import threading
from pathlib import Path

# Fix Windows terminal encoding for emoji and color support
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except AttributeError:
        # Python < 3.7 fallback
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')
        sys.stderr = codecs.getwriter('utf-8')(sys.stderr.buffer, 'strict')

# ANSI color codes for pretty terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    END = '\033[0m'

class CortexTestHarness:
    def __init__(self):
        self.brain_process = None
        self.quake_process = None
        self.running = True
        self.connection_established = False
        self.telemetry_count = 0

    def print_banner(self):
        """Display the test harness banner."""
        print(f"\n{Colors.CYAN}{Colors.BOLD}")
        print("=" * 70)
        print("  🧪 PROJECT CORTEX - CONNECTION TEST HARNESS")
        print("=" * 70)
        print(f"{Colors.END}\n")

    def print_step(self, step_num, title, description):
        """Print a formatted test step."""
        print(f"\n{Colors.BOLD}{Colors.BLUE}[STEP {step_num}] {title}{Colors.END}")
        print(f"{Colors.CYAN}→ {description}{Colors.END}\n")

    def print_success(self, message):
        """Print a success message."""
        print(f"{Colors.GREEN}✅ {message}{Colors.END}")

    def print_error(self, message):
        """Print an error message."""
        print(f"{Colors.RED}❌ {message}{Colors.END}")

    def print_info(self, message):
        """Print an info message."""
        print(f"{Colors.YELLOW}ℹ️  {message}{Colors.END}")

    def print_telemetry(self, message):
        """Print telemetry data."""
        print(f"{Colors.CYAN}📡 {message}{Colors.END}")

    def check_prerequisites(self):
        """Verify all required files exist."""
        self.print_step(1, "Prerequisites Check", "Verifying project files...")

        required_files = [
            "cortex_brain.py",
            "quakec/progs.src",
            "Game/cortex/progs.dat"
        ]

        missing_files = []
        for file_path in required_files:
            if not Path(file_path).exists():
                missing_files.append(file_path)
                self.print_error(f"Missing: {file_path}")
            else:
                self.print_success(f"Found: {file_path}")

        if missing_files:
            self.print_error("Prerequisites check failed!")
            self.print_info("Please compile your QuakeC code first.")
            return False

        self.print_success("All prerequisites satisfied!")
        return True

    def start_brain_server(self):
        """Start the Cortex Brain server."""
        self.print_step(2, "Starting Brain Server", "Launching cortex_brain.py...")

        try:
            # Start brain server as subprocess
            self.brain_process = subprocess.Popen(
                [sys.executable, "cortex_brain.py"],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
                universal_newlines=True
            )

            # Give it a moment to start
            time.sleep(1)

            # Check if it's still running
            if self.brain_process.poll() is not None:
                stderr = self.brain_process.stderr.read()
                self.print_error(f"Brain server failed to start: {stderr}")
                return False

            self.print_success("Brain server started (PID: {})".format(self.brain_process.pid))

            # Start thread to monitor brain output
            threading.Thread(target=self.monitor_brain_output, daemon=True).start()

            return True

        except Exception as e:
            self.print_error(f"Failed to start brain server: {e}")
            return False

    def monitor_brain_output(self):
        """Monitor and display brain server output."""
        if not self.brain_process:
            return

        try:
            for line in iter(self.brain_process.stdout.readline, ''):
                if not self.running:
                    break

                line = line.strip()
                if not line:
                    continue

                # Detect file-based connection (telemetry file detected)
                if "Telemetry file detected" in line or "SESSION START" in line:
                    self.connection_established = True
                    self.print_success("Quake is writing telemetry!")

                # Count telemetry packets
                elif "Player Location" in line:
                    self.telemetry_count += 1
                    if self.telemetry_count % 10 == 0:  # Print every 10th packet
                        self.print_telemetry(line)
                    elif self.telemetry_count <= 3:  # Print first 3 packets
                        self.print_telemetry(line)

                # Print other important messages
                elif any(keyword in line for keyword in ["🧠", "⏳", "✅", "🚀", "📨"]):
                    print(f"  {line}")

        except Exception as e:
            if self.running:
                self.print_error(f"Brain monitoring error: {e}")

    def guide_quake_launch(self):
        """Launch Quake and guide manual setup."""
        self.print_step(3, "Launch Quake", "Starting fteqw.exe -game cortex...")

        try:
            # Search for Quake executable in multiple locations
            possible_paths = [
                Path("fteqw64.exe"),
                Path("fteqw.exe"),
                Path("Game/fteqw64.exe"),
                Path("Game/fteqw.exe"),
            ]

            quake_exe_path = None
            for path in possible_paths:
                if path.exists():
                    quake_exe_path = path
                    break

            if not quake_exe_path:
                self.print_error("Cannot find fteqw.exe or fteqw64.exe")
                self.print_info("Searched in: C:\\ProjectCortex and C:\\ProjectCortex\\Game")
                return False

            quake_exe = str(quake_exe_path)

            # Launch Quake with cortex mod
            # Note: sv_progsaccess cannot be set via command line, must be done in console
            self.quake_process = subprocess.Popen(
                [quake_exe, "-game", "cortex"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

            self.print_success(f"Quake launched (PID: {self.quake_process.pid})")
            time.sleep(2)  # Give Quake time to start

            # Check if it's still running
            if self.quake_process.poll() is not None:
                self.print_error("Quake failed to start")
                return False

            print(f"\n{Colors.BOLD}{Colors.YELLOW}⚠️  IMPORTANT: Manual Setup Required{Colors.END}")
            print(f"\n{Colors.BOLD}In the Quake console (press Shift+Esc):{Colors.END}")
            print(f"  1. Type: {Colors.GREEN}sv_progsaccess 2{Colors.END}")
            print(f"  2. Type: {Colors.GREEN}exec default.cfg{Colors.END}")
            print(f"  3. Press Esc to close console")
            print(f"\n{Colors.BOLD}Then in the game menu:{Colors.END}")
            print(f"  4. Click: {Colors.GREEN}Single Player → New Game{Colors.END}")
            print(f"  5. Move around with WASD to generate telemetry")
            print()
            print(f"{Colors.CYAN}Note: sv_progsaccess enables file access for AI telemetry{Colors.END}")
            print(f"{Colors.CYAN}      exec default.cfg restores WASD controls in new mod{Colors.END}")
            print()

            self.print_info("Waiting for you to complete setup and start a game...")
            print(f"{Colors.YELLOW}(This window will update when telemetry is detected){Colors.END}\n")

            return True

        except Exception as e:
            self.print_error(f"Failed to launch Quake: {e}")
            return False

    def wait_for_connection(self, timeout=60):
        """Wait for Quake to connect."""
        start_time = time.time()

        while time.time() - start_time < timeout and self.running:
            if self.connection_established:
                return True
            time.sleep(0.5)

        return False

    def monitor_telemetry(self):
        """Monitor telemetry and provide feedback."""
        self.print_step(4, "Telemetry Monitoring", "Observing data stream from Quake...")

        print(f"{Colors.BOLD}What to observe:{Colors.END}")
        print(f"  • {Colors.CYAN}Position coordinates{Colors.END} should update as you move")
        print(f"  • {Colors.CYAN}X/Y values{Colors.END} change when walking forward/backward/sideways")
        print(f"  • {Colors.CYAN}Z value{Colors.END} changes when jumping or falling")
        print()

        self.print_info("Move around in Quake and watch the coordinates change!")
        print(f"{Colors.YELLOW}Telemetry packets received: 0 (updating...){Colors.END}\n")

        # Wait for user to finish testing
        self.wait_for_user_input()

    def wait_for_user_input(self):
        """Wait for user to press Enter to finish testing."""
        print(f"\n{Colors.BOLD}{Colors.GREEN}Press ENTER when you're done testing...{Colors.END}")

        try:
            input()
        except (KeyboardInterrupt, EOFError):
            pass

    def cleanup(self):
        """Clean up all processes and resources."""
        self.print_step(5, "Cleanup", "Shutting down all processes...")

        self.running = False

        # Terminate Quake
        if self.quake_process:
            try:
                self.quake_process.terminate()
                self.quake_process.wait(timeout=5)
                self.print_success("Quake stopped")
            except subprocess.TimeoutExpired:
                self.quake_process.kill()
                self.print_info("Quake forcefully killed")
            except Exception as e:
                self.print_error(f"Error stopping Quake: {e}")

        # Terminate brain server
        if self.brain_process:
            try:
                self.brain_process.terminate()
                self.brain_process.wait(timeout=5)
                self.print_success("Brain server stopped")
            except subprocess.TimeoutExpired:
                self.brain_process.kill()
                self.print_info("Brain server forcefully killed")
            except Exception as e:
                self.print_error(f"Error stopping brain: {e}")

    def print_summary(self):
        """Print test summary."""
        print(f"\n{Colors.BOLD}{Colors.CYAN}")
        print("=" * 70)
        print("  📊 TEST SUMMARY")
        print("=" * 70)
        print(f"{Colors.END}")

        if self.connection_established:
            self.print_success(f"Connection: SUCCESSFUL")
            self.print_success(f"Telemetry packets received: {self.telemetry_count}")

            if self.telemetry_count > 0:
                print(f"\n{Colors.GREEN}{Colors.BOLD}🎉 SUCCESS! Your Quake → Python pipeline is working!{Colors.END}\n")
                print(f"{Colors.CYAN}Next steps:{Colors.END}")
                print(f"  • Phase 2: Add more sensors (health, ammo, enemy positions)")
                print(f"  • Phase 3: Implement AI decision-making")
                print(f"  • Phase 4: Send control commands back to Quake")
            else:
                self.print_info("Connection established but no telemetry received")
                self.print_info("Try moving around more in Quake")
        else:
            self.print_error("Connection: FAILED")
            print(f"\n{Colors.YELLOW}Troubleshooting:{Colors.END}")
            print(f"  • Did you set 'sv_progsaccess 2' in the console? (Shift+Esc to open)")
            print(f"  • Did you run 'exec default.cfg' to restore WASD controls?")
            print(f"  • Verify progs.dat was compiled successfully")
            print(f"  • Make sure you started a NEW game (not loaded a save)")
            print(f"  • Check Game/cortex/progs.dat exists (should be ~350KB)")
            print(f"  • Look for 'CORTEX: Initializing AI Bridge...' in console")

        print()

    def run(self):
        """Execute the full test sequence."""
        try:
            self.print_banner()

            # Step 1: Check prerequisites
            if not self.check_prerequisites():
                return 1

            time.sleep(1)

            # Step 2: Start brain server
            if not self.start_brain_server():
                return 1

            time.sleep(1)

            # Step 3: Launch Quake
            if not self.guide_quake_launch():
                self.cleanup()
                return 1

            # Wait for connection (60 second timeout)
            if not self.wait_for_connection(timeout=60):
                self.print_error("Connection timeout - Quake didn't connect within 60 seconds")
                self.cleanup()
                self.print_summary()
                return 1

            time.sleep(1)

            # Step 4: Monitor telemetry
            self.monitor_telemetry()

            # Step 5: Cleanup
            self.cleanup()

            # Summary
            self.print_summary()

            return 0

        except KeyboardInterrupt:
            print(f"\n\n{Colors.YELLOW}Test interrupted by user{Colors.END}")
            self.cleanup()
            return 130

        except Exception as e:
            self.print_error(f"Unexpected error: {e}")
            import traceback
            traceback.print_exc()
            self.cleanup()
            return 1

def main():
    """Entry point for the test harness."""
    harness = CortexTestHarness()
    exit_code = harness.run()
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
