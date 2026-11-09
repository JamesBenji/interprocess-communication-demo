# Interprocess Communication Demo

Small, hands-on demonstrations of two interprocess communication (IPC) approaches.

## Shared memory

The `shared_mem` directory contains a two-terminal Python demo backed by one memory-mapped file. It intentionally has no synchronization, making the shared buffer easy to inspect.

In separate terminals, run:

```sh
python3 shared_mem/term1.py
python3 shared_mem/term2.py
```

Start `term1.py` first. Enter text in either terminal to write it to the shared buffer; the other terminal reports changes. Enter `/quit`, `/exit`, or an empty line to stop.

Shared memory was tested on macOS.

## Message passing

`message-passing/script.sh` is an interactive shell demo covering anonymous pipes, named pipes (FIFOs), sockets, and message queues.

```sh
chmod +x message-passing/script.sh
./message-passing/script.sh
```

Use `--auto` to run through the demo without prompts:

```sh
./message-passing/script.sh --auto
```

Some optional parts depend on locally installed tools: `nc` for the socket demo, `ipcmk`/`ipcrm` for the System V message-queue demo, and Python's `posix_ipc` package for the POSIX queue demo.

Message passing was tested on Linux.
