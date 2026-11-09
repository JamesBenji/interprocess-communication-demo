"""Terminal 1: bare shared-memory demo (intentionally no synchronization)."""

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


with PATH.open("w+b") as backing_file:
    backing_file.truncate(MAP_SIZE)
    with mmap.mmap(backing_file.fileno(), MAP_SIZE, access=mmap.ACCESS_WRITE) as shared:
        print("Terminal 1 created one bare shared buffer. Start term2.py.")
        print("New shared value: ", end="", flush=True)
        last_value = ""
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

PATH.unlink(missing_ok=True)
