Minimal standalone repro, no fixtures beyond a prime-agent checkout. Save, `chmod +x`, run with `ANTHROPIC_API_KEY` set:

```bash
#!/usr/bin/env bash
# Usage: ./repro-792.sh [runs] [path-to-prime-agent-checkout]
set -u
N="${1:-3}"; REPO="${2:-$PWD}"; fail=0
[ -d "$REPO/packages" ] || { echo "expected a checkout at: $REPO" >&2; exit 2; }

for i in $(seq 1 "$N"); do
  W=$(mktemp -d); OUT="$W/counts.json"
  prime-agent --mode json --cwd "$REPO" --session-dir "$W/sd" -p \
"You MUST delegate this using subagents, one child per package. Spawn four \
children with \`await rlm(...)\`, one for each of packages/agent, packages/ai, \
packages/coding-agent and packages/tui. Each child must count the .ts files \
under its package's src/ directory and their total line count. Collect all four \
replies and write a single JSON object mapping package name to \
{\"files\":N,\"lines\":N} to $OUT" \
    > "$W/stream.jsonl" 2>"$W/stderr"
  rc=$?
  printf 'run %d: children=%s turns=%s exit=%s stderr=%sB output=%s\n' "$i" \
    "$(find "$W" -type d -name 'sub-*' | wc -l)" \
    "$(grep -c '"type":"turn_end"' "$W/stream.jsonl")" \
    "$rc" "$(wc -c < "$W/stderr")" \
    "$([ -f "$OUT" ] && echo written || echo MISSING)"
  [ -f "$OUT" ] || fail=$((fail+1)); rm -rf "$W"
done
echo "---"; echo "$fail of $N runs spawned children, exited 0, and wrote nothing."
```

Output here (0.7.0, `claude-opus-5`):

```
run 1: children=4 turns=7 exit=0 stderr=0B output=written
run 2: children=4 turns=7 exit=0 stderr=0B output=written
run 3: children=4 turns=2 exit=0 stderr=0B output=MISSING
run 4: children=4 turns=7 exit=0 stderr=0B output=written
---
1 of 4 runs spawned children, exited 0, and wrote nothing.
```

**`turns` is the discriminator.** `turns=2` means the parent spawned and ended its turn — output missing. `turns=7` means it stayed in-turn and polled — output written. `children=4` in every run, so the prompt is followed either way, and `exit=0` with empty stderr in every run including the failure.

Two notes that may save you time:

- **Toy children do not reproduce it.** An earlier version asked two children for a number each; 4/4 clean, `turns=5` every time. The parent only takes the end-turn path when the delegated work is substantial enough to be worth not blocking on. Whatever the fix, a test needs non-trivial children.
- **The rate varies.** 1/4 above; 2/3 on a larger four-package analysis task. Worth running with `N=6` or more before concluding either way.

Happy to add the raw `stream.jsonl` and child session dumps from a failing run if useful.
