"""
Deprecated wrapper for backwards compatibility.

The canonical file-IPC brain lives at `python/streams/file/brain.py`.
"""

from python.streams.file.brain import run_server


if __name__ == "__main__":
    run_server()

