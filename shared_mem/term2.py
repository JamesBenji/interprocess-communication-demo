"""Terminal 2: bare shared-memory demo (intentionally no synchronization)."""

import mmap
import select
import sys
from pathlib import Path

MAP_SIZE = 1024
PATH = Path(__file__).with_name(".ipc_demo.map")


def read_value(shared):
    return bytes(shared[:]).split(b"\0", 1)[0].decode("utf-8", errors="replace")


def write_value(shared, value):
    data = value.encode("utf-8")[: MAP_SIZE - 1]
    # This is deliberately an unprotected write to the one shared buffer.
    shared[: len(data)] = data
    shared[len(data)] = 0


try:
    with PATH.open("r+b") as backing_file:
        with mmap.mmap(backing_file.fileno(), MAP_SIZE, access=mmap.ACCESS_WRITE) as shared:
            print("Terminal 2 attached to the same bare shared buffer.")
            print("New shared value: ", end="", flush=True)
            last_value = read_value(shared)
            try:
                while True:
                    current_value = read_value(shared)
                    if current_value != last_value:
                        print(f"\nShared value is now: {current_value!r}")
                        print("New shared value: ", end="", flush=True)
                        last_value = current_value

                    if not select.select([sys.stdin], [], [], 0.05)[0]:
                        continue
                    value = sys.stdin.readline().rstrip("\n")
                    if not value or value.lower() in {"/quit", "/exit"}:
                        break
                    write_value(shared, value)
                    last_value = value
                    print("New shared value: ", end="", flush=True)
            except KeyboardInterrupt:
                pass
except FileNotFoundError:
    print("Start term1.py first and leave it running.")
