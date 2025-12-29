import sys
import time
import os
from pathlib import Path

# Fix Windows terminal encoding for emoji support
if sys.platform == 'win32':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except AttributeError:
        # Python < 3.7 fallback
        import codecs
        sys.stdout = codecs.getwriter('utf-8')(sys.stdout.buffer, 'strict')

# File path where QuakeC writes telemetry
TELEMETRY_FILE = Path("Game/cortex/cortex_telemetry.txt")

def run_server():
    print(f"🧠 CORTEX BRAIN: Monitoring file {TELEMETRY_FILE}...")
    print("⏳ Waiting for Quake to start writing data...")

    # Wait for file to be created
    while not TELEMETRY_FILE.exists():
        time.sleep(0.5)

    print("✅ Telemetry file detected!")
    print("🚀 Receiving Telemetry...\n")

    # Open file and seek to end (we'll tail it)
    with open(TELEMETRY_FILE, 'r', encoding='utf-8', errors='ignore') as f:
        # Seek to beginning to catch the session start marker
        f.seek(0)

        while True:
            line = f.readline()

            if line:
                # Process the line
                process_packet(line.strip())
            else:
                # No more data, wait a bit and try again (tail behavior)
                time.sleep(0.01)  # 10ms polling interval

def process_packet(line):
    # This is where the AI logic will eventually live.
    # For now, just prove we can see the game state.
    if line.startswith("POS:"):
        # Parse "POS: '100 200 50'"
        try:
            raw_coords = line.split("'")[1] # Get text between single quotes
            x, y, z = raw_coords.split(" ")
            print(f"📍 Player Location: X={x} Y={y} Z={z}")
        except:
            print(f"⚠️ Raw Data: {line}")
    else:
        print(f"📨 Log: {line}")

if __name__ == '__main__':
    run_server()
