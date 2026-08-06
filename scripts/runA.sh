#!/usr/bin/env bash
# Condition A: prime-agent harness. Same model, same effort, same task text.
# Usage: runA.sh <task-slug>
set -uo pipefail

T="$1"
P="$HOME/prompts/$T.txt"
SD="$HOME/sessions/A-$T"
RAW="$HOME/results/A-$T.jsonl"
mkdir -p "$SD" "$HOME/results"

start=$(date +%s.%N)
prime-agent \
  --mode json \
  --provider anthropic \
  --model claude-opus-5 \
  --thinking high \
  --cwd "$HOME/work/repo" \
  --session-dir "$SD" \
  -p "$(cat "$P")" > "$RAW" 2>"$HOME/results/A-$T.stderr"
rc=$?
end=$(date +%s.%N)

echo "exit=$rc wall=$(echo "$end - $start" | bc)s raw=$RAW"
echo "stderr tail:"; tail -5 "$HOME/results/A-$T.stderr"
echo "event types seen:"; jq -r '.type' "$RAW" 2>/dev/null | sort | uniq -c | sort -rn | head -15
echo "$(echo "$end - $start" | bc)" > "$HOME/results/A-$T.wall"
