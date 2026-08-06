"""Do rlm() subagents get collected in INTERACTIVE mode?

In -p mode the parent spawned four children, said "Ending turn to let them
work", and the process exited before any child reported -- no output at all.
An interactive session does not exit at end of turn, so the children should
have somewhere to report back to.

Sends the must-delegate prompt, waits a long time for children to finish, then
nudges once ("are the results in?") before exiting.
"""
import os
import pty
import select
import subprocess
import time

PROMPT = open(os.path.expanduser("~/prompts/task6-subagent.txt")).read().strip()
NUDGE = ("Have the child agents reported back yet? If you have all four results, "
         "assemble them and write /home/bench/results/packages.json now.")
LOG = os.path.expanduser("~/results/pty-subagent.log")


def drain(fd, log, idle, max_wait, label):
    last = start = time.time()
    total = 0
    while True:
        if time.time() - start > max_wait:
            print(f"[{label}] max_wait after {total}B", flush=True); return total
        r, _, _ = select.select([fd], [], [], 1.0)
        if r:
            try:
                c = os.read(fd, 65536)
            except OSError:
                print(f"[{label}] closed after {total}B", flush=True); return total
            if not c:
                return total
            log.write(c); log.flush(); total += len(c); last = time.time()
        elif time.time() - last > idle:
            print(f"[{label}] idle {idle}s after {total}B", flush=True); return total


def send(fd, text):
    os.write(fd, " ".join(text.split()).encode() + b"\r")


master, slave = pty.openpty()
env = dict(os.environ); env["TERM"] = "xterm-256color"
p = subprocess.Popen(
    ["prime-agent", "--provider", "anthropic", "--model", "claude-opus-5",
     "--cwd", os.path.expanduser("~/work/repo"),
     "--session-dir", os.path.expanduser("~/sessions/pty-subagent")],
    stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True)
os.close(slave)

with open(LOG, "wb") as log:
    drain(master, log, 12, 180, "boot")
    print("[t1] sending must-delegate prompt", flush=True)
    send(master, PROMPT)
    # generous: children need time to run AND report back
    drain(master, log, 60, 900, "t1")
    print("[nudge] asking whether children reported", flush=True)
    send(master, NUDGE)
    drain(master, log, 45, 600, "nudge")
    try:
        os.write(master, b"/exit\r"); drain(master, log, 8, 60, "exit")
    except OSError:
        pass

try:
    p.wait(timeout=30)
except subprocess.TimeoutExpired:
    p.terminate()
    try: p.wait(timeout=10)
    except subprocess.TimeoutExpired: p.kill()
print(f"[done] exit={p.returncode}", flush=True)
