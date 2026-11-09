#!/usr/bin/env bash
# Live demo: message passing (pipes, sockets, message queues)
# Usage:  ./demo_message_passing.sh          interactive (press Enter to advance)
#         ./demo_message_passing.sh --auto   no pauses (dry run / rehearsal)

AUTO=0; [[ "$1" == "--auto" ]] && AUTO=1
FIFO=/tmp/ipc_demo_fifo
WORK=$(mktemp -d)
PORT=5000
QID=""

O=$'\e[1;38;5;214m'   # bright yellow-orange
B=$'\e[1m'; C=$'\e[36m'; G=$'\e[32m'; Y=$'\e[33m'; M=$'\e[35m'; D=$'\e[2m'; R=$'\e[0m'

cleanup() {
  [[ -n "$QID" ]] && ipcrm -q "$QID" 2>/dev/null
  rm -f "$FIFO"; rm -rf "$WORK"
  jobs -p | xargs kill 2>/dev/null
}
trap cleanup EXIT

# Section heading: big ASCII-art text if figlet is installed, else bold spaced text
title() {
  printf "\n${O}"
  if command -v figlet >/dev/null; then
    figlet -f big "$*" 2>/dev/null || figlet "$*"
  else
    printf "  %s\n" "$(printf '%s' "$*" | sed 's/./& /g')"
  fi
  printf "${R}"
}
say()    { printf "\n${B}${C}▶ %s${R}\n" "$*"; }
note()   { printf "  ${Y}%s${R}\n" "$*"; }
pause()  { (( AUTO )) && { sleep 1; return; }; read -rp "  ${D}[Enter to continue]${R} " _; }

# "types" the command like a live demo, then executes it for real
run() {
  local cmd="$1"
  printf "  ${G}\$ ${R}"
  for (( i=0; i<${#cmd}; i++ )); do printf "%s" "${cmd:$i:1}"; (( AUTO )) || sleep 0.02; done
  printf "\n"; sleep 0.4
  eval "$cmd"
}

# netcat differs between systems; build a listen command that works on both
nc_listen() { if nc -h 2>&1 | grep -q -- '-p '; then echo "nc -l -p $PORT -w 5"; else echo "nc -l $PORT -w 5"; fi; }

# ───────────────────────── INTRO: CAT ─────────────────────────
# If you put a picture named cat.jpg or cat.png next to this script and have
# chafa installed (sudo apt install chafa), it is shown as a real image.
# Otherwise the built-in ASCII cat is used.
show_cat() {
  local dir img=""; dir="$(cd "$(dirname "$0")" && pwd)"
  for f in "$dir/cat.jpg" "$dir/cat.png"; do [[ -f "$f" ]] && img="$f" && break; done
  printf "\n"
  if [[ -n "$img" ]] && command -v chafa >/dev/null; then
    chafa -s 60x30 "$img"
  else
    printf "${O}"
    cat <<'CAT'
          /\_____/\
         /  o   o  \
        ( ==  ^  == )
         )         (
        (           )
       ( (  )   (  ) )
      (__(__)___(__)__)
CAT
    printf "${R}"
  fi
  printf "\n  ${B}Inter-Process Communication: Message Passing${R}\n"
  note "Fun fact: the 'cat' command you're about to see is short for concatenate."
}
show_cat
pause

# ───────────────────────── 1. PIPES ─────────────────────────
title "1. PIPES"

say "Anonymous pipe: the shell connects two processes with a kernel buffer"
note "ls writes its output into the pipe; wc reads it from the other end."
pause
run "ls | wc -l"
note "Two separate processes cooperated. No file, no shared variable."
pause

say "Named pipe (FIFO): a pipe with a name in the filesystem"
run "mkfifo $FIFO && ls -l $FIFO"
note "The leading 'p' in the permissions marks a pipe. It holds no data on disk."
pause

say "Start a reader. Nobody has written yet, so it should BLOCK."
run "cat $FIFO &"
READER=$!
sleep 1
run "ps -o pid,stat,command -p $READER"
note "STAT 'S' = sleeping. The reader is stuck waiting for a writer (blocking call)."
pause

say "Now a second process writes into the FIFO"
run "echo 'hello through the pipe' > $FIFO"
wait $READER 2>/dev/null
note "The reader woke up, printed the message, and exited."
pause

# ───────────────────────── 2. SOCKETS ─────────────────────────
title "2. SOCKETS"

if command -v nc >/dev/null; then
  say "Two-way chat over a socket (server and client are separate processes)"
  note "Server listens on port $PORT and sends a greeting. Client connects and replies."
  pause
  run "echo 'hi client, from the server' | $(nc_listen) > $WORK/server_got.txt &"
  SRV=$!
  sleep 1
  say "Client connects, sends a message, and prints what the server sent back"
  run "echo 'hi server, from the client' | nc -w 2 localhost $PORT"
  wait $SRV 2>/dev/null
  say "What did the server receive?"
  run "cat $WORK/server_got.txt"
  note "Data flowed in BOTH directions over one connection (bidirectional)."
  pause
else
  note "netcat (nc) not found: skipping socket demo."
fi

# ───────────────────────── 3. MESSAGE QUEUES ─────────────────────────
title "3. MESSAGE QUEUES"

if command -v ipcmk >/dev/null; then
  say "Create a System V message queue in the kernel"
  run "ipcmk -Q"
  QID=$(ipcs -q | awk '$1 ~ /^0x/ {id=$2} END{print id}')
  say "Inspect it. It exists with no process attached to it."
  run "ipcs -q"
  note "Queue id $QID lives in the kernel, independent of any program."
  pause
  say "Clean it up"
  run "ipcrm -q $QID && QID=''"
  run "ipcs -q"
  pause
else
  note "ipcmk not available on this system: skipping System V demo."
fi

if python3 -c "import posix_ipc" 2>/dev/null; then
  say "Asynchronous delivery with a POSIX message queue"
  cat > "$WORK/sender.py" <<'EOF'
import posix_ipc
q = posix_ipc.MessageQueue("/demo_q", posix_ipc.O_CREAT)
q.send(b"message 1: sent while nobody is listening")
q.send(b"message 2: still waiting")
print("sender: 2 messages queued. Exiting now.")
EOF
  cat > "$WORK/receiver.py" <<'EOF'
import posix_ipc
q = posix_ipc.MessageQueue("/demo_q")
for _ in range(2):
    msg, _prio = q.receive()
    print("receiver got:", msg.decode())
q.close(); q.unlink()
EOF
  note "The sender will send, then EXIT. Only afterwards does the receiver start."
  pause
  run "python3 $WORK/sender.py"
  note "The sender process is gone. Are the messages lost?"
  sleep 1
  run "ls /dev/mqueue 2>/dev/null || echo '(queue is held by the kernel)'"
  pause
  say "Start the receiver later"
  run "python3 $WORK/receiver.py"
  note "Both messages were still waiting. Sender and receiver never ran at the same time."
else
  note "posix_ipc not installed (pip install posix_ipc): skipping async queue demo."
fi

title "DONE"
note "Pipes: byte stream.  Sockets: two-way, network-capable.  Queues: discrete, asynchronous messages."
