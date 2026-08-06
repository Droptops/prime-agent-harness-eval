"""DAEMON MODE test — the third arm of the session-mode comparison.

-p          : single-shot, process exits at end of turn      -> features fail
interactive : PTY session, client attached                   -> features work
daemon      : session lives in the background, NO client     -> this test

Method: boot a session through a PTY, then kill the CLIENT so the session is
daemon-backed with zero clients attached. Drive it from there with
`prime-agent send` only. Same prompts, same settings (turnInterval 1), same
model as the other two arms.
"""
import json
import os
import pty
import select
import signal
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
P1 = open(f"{HOME}/prompts/task3v2-long-horizon.txt").read().strip()
P2 = open(f"{HOME}/prompts/task4-shared.txt").read().strip()
SD = f"{HOME}/sessions/daemon-test"


def sh(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True).stdout.strip()


def agents():
    try:
        return json.loads(sh("prime-agent list --all --json")).get("sessions", [])
    except Exception:
        return []


def boot_then_detach():
    """Start a session in a PTY, wait for it to register, then kill the client."""
    before = {a["id"] for a in agents()}
    master, slave = pty.openpty()
    env = dict(os.environ); env["TERM"] = "xterm-256color"
    p = subprocess.Popen(
        ["prime-agent", "--provider", "anthropic", "--model", "claude-opus-5",
         "--cwd", f"{HOME}/work/repo", "--session-dir", SD],
        stdin=slave, stdout=slave, stderr=slave, env=env, close_fds=True,
        start_new_session=True)
    os.close(slave)
    # let it boot and register with the daemon
    deadline = time.time() + 120
    new = None
    while time.time() < deadline:
        r, _, _ = select.select([master], [], [], 1.0)
        if r:
            try: os.read(master, 65536)
            except OSError: break
        cur = {a["id"] for a in agents()}
        fresh = cur - before
        if fresh:
            new = fresh.pop(); break
    if not new:
        print("[boot] FAILED to register a new agent"); p.kill(); return None
    print(f"[boot] agent registered: {new}", flush=True)
    time.sleep(5)
    # kill the client; the daemon session should survive
    os.killpg(os.getpgid(p.pid), signal.SIGKILL)
    time.sleep(6)
    os.close(master)
    live = [a for a in agents() if a["id"] == new]
    if not live:
        print("[detach] session did NOT survive client kill"); return None
    print(f"[detach] survived. clients={live[0].get('clientCount','?')} "
          f"activity={live[0].get('activity')}", flush=True)
    return new


def wait_idle(aid, max_wait=900, label=""):
    start = time.time()
    time.sleep(8)
    while time.time() - start < max_wait:
        a = [x for x in agents() if x["id"] == aid]
        if a and a[0].get("activity") == "idle" and not a[0].get("isStreaming"):
            print(f"[{label}] idle after {int(time.time()-start)}s", flush=True)
            return True
        time.sleep(10)
    print(f"[{label}] TIMEOUT", flush=True)
    return False


def send(aid, text):
    flat = " ".join(text.split())
    r = subprocess.run(["prime-agent", "send", aid, flat],
                       capture_output=True, text=True)
    print(f"[send] rc={r.returncode} {r.stdout.strip()[:120]}{r.stderr.strip()[:120]}", flush=True)


def hcount():
    return len(sh(f"find {HOME} -name harness_state.json").splitlines())


aid = boot_then_detach()
if not aid:
    sys.exit(1)

print(f"[state] harness_state before: {hcount()}", flush=True)
for f in ("matrix.json", "shared.json"):
    try: os.remove(f"{HOME}/results/{f}")
    except OSError: pass

print("[t1] sending task 3", flush=True)
send(aid, P1); wait_idle(aid, label="t1")
print(f"[state] harness_state after t1: {hcount()}", flush=True)

print("[t2] sending task 4", flush=True)
send(aid, P2); wait_idle(aid, label="t2")
print(f"[state] harness_state after t2: {hcount()}", flush=True)

print(f"[artifacts] matrix={os.path.exists(f'{HOME}/results/matrix.json')} "
      f"shared={os.path.exists(f'{HOME}/results/shared.json')}", flush=True)
subprocess.run(["prime-agent", "stop", aid], capture_output=True)
print("[done]", flush=True)
