"""#1 INTERACTIVE MODE TEST.

Every conclusion so far is scoped to `-p` (single-shot). Both differentiating
features assume a long-lived session, so the honest question is whether they
work when there IS one.

Drives a real interactive prime-agent through a PTY: sends prompt 1, waits for
the agent to go idle, sends prompt 2, waits again, then exits cleanly. Auto-refine
is configured aggressively (turnInterval 3) so it has every chance to fire.

Idle detection is output-silence based: the TUI is ANSI-heavy and has no stable
machine-readable "done" marker, so we wait for N seconds of no output.
"""
import os
import pty
import re
import select
import subprocess
import sys
import time

PROMPT1 = open(os.path.expanduser("~/prompts/task3v2-long-horizon.txt")).read().strip()
PROMPT2 = open(os.path.expanduser("~/prompts/task4-shared.txt")).read().strip()

IDLE_SECONDS = float(os.environ.get("IDLE_SECONDS", "25"))
MAX_WAIT = float(os.environ.get("MAX_WAIT", "600"))
LOG = os.path.expanduser("~/results/pty-session.log")


def drain_until_idle(fd, log, idle=IDLE_SECONDS, max_wait=MAX_WAIT, label=""):
    """Read until no output for `idle` seconds, or max_wait elapses."""
    last = time.time()
    start = time.time()
    total = 0
    while True:
        if time.time() - start > max_wait:
            print(f"[{label}] MAX_WAIT hit after {total} bytes", flush=True)
            return total
        r, _, _ = select.select([fd], [], [], 1.0)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                print(f"[{label}] pty closed after {total} bytes", flush=True)
                return total
            if not chunk:
                return total
            log.write(chunk)
            log.flush()
            total += len(chunk)
            last = time.time()
        elif time.time() - last > idle:
            print(f"[{label}] idle {idle}s after {total} bytes", flush=True)
            return total


def send(fd, text):
    # Paste the prompt as one line; the TUI treats Enter as submit.
    flat = " ".join(text.split())
    os.write(fd, flat.encode() + b"\r")


def main():
    master, slave = pty.openpty()
    env = dict(os.environ)
    env["TERM"] = "xterm-256color"
    proc = subprocess.Popen(
        ["prime-agent", "--provider", "anthropic", "--model", "claude-opus-5",
         "--cwd", os.path.expanduser("~/work/repo"),
         "--session-dir", os.path.expanduser("~/sessions/pty-interactive")],
        stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True,
    )
    os.close(slave)

    with open(LOG, "wb") as log:
        print("[boot] waiting for startup...", flush=True)
        drain_until_idle(master, log, idle=12, max_wait=180, label="boot")

        print("[t1] sending prompt 1", flush=True)
        send(master, PROMPT1)
        drain_until_idle(master, log, label="t1")

        print("[t2] sending prompt 2", flush=True)
        send(master, PROMPT2)
        drain_until_idle(master, log, label="t2")

        print("[exit] sending /exit", flush=True)
        try:
            os.write(master, b"/exit\r")
            drain_until_idle(master, log, idle=8, max_wait=60, label="exit")
        except OSError:
            pass

    try:
        proc.wait(timeout=30)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
    print(f"[done] exit={proc.returncode} log={LOG}", flush=True)


if __name__ == "__main__":
    main()
