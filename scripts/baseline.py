"""Condition B: plain tool-calling baseline.

Deliberately boring. Four tools, a manual loop, no persistence between runs,
no self-modification. This is the thing prime-agent has to beat.

Direct Anthropic SDK. No agent framework -- the point of the comparison is
that the harness is the independent variable, so the baseline must not
smuggle in a second harness.

Usage:
    python baseline.py <task_file> <output_json> [--model claude-opus-5]

Emits a metrics JSON so A and B are scored by the same yardstick:
wall time, input/output/cache tokens, USD cost, turn count.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from pathlib import Path

import anthropic

MODEL = "claude-opus-5"

# Anthropic first-party rates, USD per million tokens.
# Opus 5: $5 in / $25 out. Cache read ~0.1x input, cache write 1.25x input.
PRICING = {
    "claude-opus-5": {"in": 5.00, "out": 25.00, "cache_read": 0.50, "cache_write": 6.25},
    "claude-sonnet-5": {"in": 3.00, "out": 15.00, "cache_read": 0.30, "cache_write": 3.75},
}

# cwd must match condition A's (`--cwd ~/work/repo`), or glob patterns implied
# by the task text resolve differently between conditions.
WORKDIR = Path(os.environ.get("BASELINE_WORKDIR", "/home/bench/work/repo"))
# Sandbox root is deliberately wider than cwd: every task writes its deliverable
# to /home/bench/results. Confining writes to cwd made write_file unable to
# produce any required output, which silently forced a bash fallback.
SANDBOX_ROOT = Path(os.environ.get("BASELINE_SANDBOX", "/home/bench"))

TOOLS = [
    {
        "name": "bash",
        "description": (
            "Run a bash command in the working directory and return combined "
            "stdout and stderr. Use for grep, find, wc, ls, and running project "
            "commands. Output is truncated at 30000 characters."
        ),
        "input_schema": {
            "type": "object",
            "properties": {"command": {"type": "string", "description": "The bash command to run."}},
            "required": ["command"],
        },
    },
    {
        "name": "read_file",
        "description": (
            "Read a UTF-8 text file and return its contents with 1-indexed line "
            "numbers. Prefer this over `cat` so line numbers are available for "
            "citation. Returns at most `limit` lines starting at `offset`."
        ),
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Path to the file, absolute or relative to the working directory."},
                "offset": {"type": "integer", "description": "1-indexed line to start at. Defaults to 1."},
                "limit": {"type": "integer", "description": "Maximum lines to return. Defaults to 2000."},
            },
            "required": ["path"],
        },
    },
    {
        "name": "write_file",
        "description": "Write text to a file, creating parent directories and overwriting any existing file.",
        "input_schema": {
            "type": "object",
            "properties": {
                "path": {"type": "string", "description": "Destination path."},
                "content": {"type": "string", "description": "Full file contents to write."},
            },
            "required": ["path", "content"],
        },
    },
    {
        "name": "list_files",
        "description": "List files matching a glob pattern, one path per line. Use to discover layout before reading.",
        "input_schema": {
            "type": "object",
            "properties": {"pattern": {"type": "string", "description": "Glob relative to the working directory, e.g. 'packages/*/src/**/*.ts'."}},
            "required": ["pattern"],
        },
    },
]

MAX_TOOL_OUTPUT = 30_000

# prime-agent ships rg and fd and puts them on its own PATH. Give the baseline
# the same binaries so the comparison is about the harness, not the toolbox.
RG_BIN = os.environ.get("RG_BIN_DIR", "/home/bench/.prime/agent/bin")


def _resolve(path_str: str) -> Path:
    """Confine file operations to SANDBOX_ROOT. `path` is untrusted model output."""
    candidate = Path(path_str)
    if not candidate.is_absolute():
        candidate = WORKDIR / candidate
    resolved = candidate.resolve()
    root = SANDBOX_ROOT.resolve()
    if resolved != root and root not in resolved.parents:
        raise ValueError(f"path escapes the sandbox root {root}: {path_str}")
    return resolved


def run_tool(name: str, args: dict) -> tuple[str, bool]:
    """Returns (result_text, is_error)."""
    try:
        if name == "bash":
            # executable=/bin/bash: shell=True alone runs /bin/sh, which is dash
            # here, so [[ ]], process substitution and arrays fail with exit 127.
            proc = subprocess.run(
                args["command"],
                shell=True,
                executable="/bin/bash",
                cwd=WORKDIR,
                capture_output=True,
                text=True,
                timeout=180,
                env={**os.environ, "PATH": f"{RG_BIN}:{os.environ.get('PATH','')}"},
            )
            out = (proc.stdout or "") + (proc.stderr or "")
            if proc.returncode != 0:
                out += f"\n[exit status {proc.returncode}]"
            # A nonzero exit is normal for grep/test and is NOT a tool error.
            # Flagging it as one pollutes context and invites pointless retries.
            return out[:MAX_TOOL_OUTPUT] or "(no output)", False

        if name == "read_file":
            target = _resolve(args["path"])
            offset = max(1, int(args.get("offset", 1)))
            limit = int(args.get("limit", 2000))
            lines = target.read_text(encoding="utf-8", errors="replace").splitlines()
            chunk = lines[offset - 1 : offset - 1 + limit]
            body = "\n".join(f"{offset + i}\t{line}" for i, line in enumerate(chunk))
            return body[:MAX_TOOL_OUTPUT] or "(empty file)", False

        if name == "write_file":
            target = _resolve(args["path"])
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(args["content"], encoding="utf-8")
            return f"wrote {len(args['content'])} bytes to {target}", False

        if name == "list_files":
            matches = sorted(str(p.relative_to(WORKDIR)) for p in WORKDIR.glob(args["pattern"]) if p.is_file())
            return "\n".join(matches)[:MAX_TOOL_OUTPUT] or "(no matches)", False

        return f"unknown tool: {name}", True
    except Exception as exc:  # surfaced to the model so it can adapt
        return f"{type(exc).__name__}: {exc}", True


def main() -> int:
    task_file, out_file = sys.argv[1], sys.argv[2]
    model = sys.argv[4] if len(sys.argv) > 4 and sys.argv[3] == "--model" else MODEL
    prompt = Path(task_file).read_text(encoding="utf-8")

    client = anthropic.Anthropic()  # ANTHROPIC_API_KEY from env, nothing else
    messages = [{"role": "user", "content": prompt}]

    totals = {"input": 0, "output": 0, "cache_read": 0, "cache_write": 0}
    turns = 0
    started = time.monotonic()
    stop_reason = None

    while True:
        turns += 1
        with client.messages.stream(
            model=model,
            max_tokens=64_000,
            thinking={"type": "adaptive"},
            output_config={"effort": "high"},
            # Auto-place a breakpoint on the last cacheable block. Without this
            # the loop re-sends the whole growing transcript at full price every
            # turn, which makes any cost comparison against a caching harness
            # meaningless -- it measures caching, not the harness.
            cache_control={"type": "ephemeral"},
            tools=TOOLS,
            messages=messages,
        ) as stream:
            response = stream.get_final_message()

        u = response.usage
        totals["input"] += u.input_tokens
        totals["output"] += u.output_tokens
        totals["cache_read"] += getattr(u, "cache_read_input_tokens", 0) or 0
        totals["cache_write"] += getattr(u, "cache_creation_input_tokens", 0) or 0
        stop_reason = response.stop_reason

        if response.stop_reason == "refusal":
            break

        # Append the full content -- tool_use blocks must be preserved.
        messages.append({"role": "assistant", "content": response.content})

        tool_uses = [b for b in response.content if b.type == "tool_use"]
        if not tool_uses:
            break

        # All results for one assistant turn go back in a SINGLE user message.
        results = []
        for block in tool_uses:
            text, is_error = run_tool(block.name, block.input)
            results.append(
                {"type": "tool_result", "tool_use_id": block.id, "content": text, "is_error": is_error}
            )
        messages.append({"role": "user", "content": results})

        if turns >= 200:  # runaway guard; recorded so it is never silent
            stop_reason = "turn_limit"
            break

    elapsed = time.monotonic() - started
    rates = PRICING.get(model, PRICING[MODEL])
    cost = (
        totals["input"] * rates["in"]
        + totals["output"] * rates["out"]
        + totals["cache_read"] * rates["cache_read"]
        + totals["cache_write"] * rates["cache_write"]
    ) / 1_000_000

    final_text = "\n".join(b.text for b in response.content if b.type == "text")

    metrics = {
        "condition": "B-baseline",
        "model": model,
        "task": task_file,
        "wall_seconds": round(elapsed, 2),
        "turns": turns,
        "tokens": totals,
        "total_tokens": sum(totals.values()),
        "cost_usd": round(cost, 4),
        "stop_reason": stop_reason,
        "final_text": final_text,
    }
    Path(out_file).write_text(json.dumps(metrics, indent=2), encoding="utf-8")
    print(json.dumps({k: v for k, v in metrics.items() if k != "final_text"}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
