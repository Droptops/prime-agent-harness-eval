#!/usr/bin/env bash
# Repeat task 3 N times per condition, identical invocation each time.
# Sequential on purpose: parallel runs would contend on the hardcoded
# matrix.json output path and could hit shared rate limits, both of which
# would show up in the numbers as if they were harness properties.
set -uo pipefail

N="${1:-3}"
R="$HOME/results"
P="$HOME/prompts/task3-long-horizon.txt"

for i in $(seq 1 "$N"); do
  # ---- B: cached baseline -------------------------------------------------
  rm -f "$R/matrix.json"          # never score a stale artifact
  ~/bvenv/bin/python ~/baseline.py "$P" "$R/B-r$i.json" >/dev/null 2>&1
  if [ -f "$R/matrix.json" ]; then cp "$R/matrix.json" "$R/B-r$i-matrix.json"; fi
  echo "B r$i done: $(jq -r '.total_tokens' "$R/B-r$i.json" 2>/dev/null) tok"

  # ---- A: prime-agent harness --------------------------------------------
  rm -f "$R/matrix.json"
  SD="$HOME/sessions/A-r$i"
  mkdir -p "$SD"
  prime-agent --mode json --provider anthropic --model claude-opus-5 \
    --thinking high --cwd "$HOME/work/repo" --session-dir "$SD" \
    -p "$(cat "$P")" > "$R/A-r$i.jsonl" 2>"$R/A-r$i.stderr"
  if [ -f "$R/matrix.json" ]; then cp "$R/matrix.json" "$R/A-r$i-matrix.json"; fi
  echo "A r$i done: $(jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$R/A-r$i.jsonl" 2>/dev/null) tok"
done
echo "ALL REPEATS COMPLETE"
