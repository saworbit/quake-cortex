"""
Deprecated wrapper for backwards compatibility.

The canonical file-IPC brain lives at `python/file_ipc/brain.py`.
"""

from python.file_ipc.brain import run_server


if __name__ == "__main__":
    run_server()

