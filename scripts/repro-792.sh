#!/usr/bin/env bash
# Minimal repro for: -p exits before post-turn work completes.
#
# Usage:  ./repro-792.sh [runs] [path-to-prime-agent-checkout]
# Requires prime-agent on PATH and ANTHROPIC_API_KEY.
#
# The delegated work must be non-trivial. With toy children (ask two agents for
# a number) the parent stays in-turn and waits, and this never reproduces --
# verified, 4/4 clean. The failure needs children whose work is long enough that
# the parent chooses to end its turn instead of blocking, which is the path
# docs/rlm.md prescribes.
#
# The bug is intermittent, so this runs N times and reports a ratio. Per run it
# prints four fields, which together separate the failure from its lookalikes:
#   children - did rlm() spawn any (0 means the prompt was not followed)
#   turns    - a low count means the parent ended its turn after spawning
#   exit     - distinguishes "silently discarded" from "errored"
#   output   - the file the collected results were supposed to produce
set -u

N="${1:-3}"
REPO="${2:-$PWD}"
fail=0

if [ ! -d "$REPO/packages" ]; then
  echo "expected a prime-agent checkout at: $REPO" >&2
  echo "usage: $0 [runs] [path-to-checkout]" >&2
  exit 2
fi

for i in $(seq 1 "$N"); do
  W=$(mktemp -d)
  OUT="$W/counts.json"

  prime-agent --mode json --cwd "$REPO" --session-dir "$W/sd" -p \
"You MUST delegate this using subagents, one child per package. Spawn four \
children with \`await rlm(...)\`, one for each of packages/agent, packages/ai, \
packages/coding-agent and packages/tui. Each child must count the .ts files \
under its package's src/ directory and their total line count. Collect all four \
replies and write a single JSON object mapping package name to \
{\"files\":N,\"lines\":N} to $OUT" \
    > "$W/stream.jsonl" 2>"$W/stderr"
  rc=$?

  kids=$(find "$W" -type d -name 'sub-*' 2>/dev/null | wc -l)
  turns=$(grep -c '"type":"turn_end"' "$W/stream.jsonl" 2>/dev/null)
  errb=$(wc -c < "$W/stderr")
  if [ -f "$OUT" ]; then out="written"; else out="MISSING"; fi

  printf 'run %d: children=%s turns=%s exit=%s stderr=%sB output=%s\n' \
    "$i" "$kids" "$turns" "$rc" "$errb" "$out"

  [ -f "$OUT" ] || fail=$((fail+1))
  rm -rf "$W"
done

echo "---"
echo "$fail of $N runs spawned children, exited 0, and wrote nothing."
