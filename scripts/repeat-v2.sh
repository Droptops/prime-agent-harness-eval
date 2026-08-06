#!/usr/bin/env bash
# Task 3 v2 repeats. Distinct result prefixes and fresh session dirs so the v1
# artifacts (the evidence base for the published Result 2) are never touched.
set -uo pipefail

N="${1:-2}"
R="$HOME/results"
P="$HOME/prompts/task3v2-long-horizon.txt"

# refuse to run against the v1 prompt by accident
grep -q "getApiKeyEnvVars" "$P" || { echo "FATAL: $P is not the v2 prompt"; exit 1; }

for i in $(seq 1 "$N"); do
  rm -f "$R/matrix.json"
  ~/bvenv/bin/python ~/baseline.py "$P" "$R/Bv2-r$i.json" >/dev/null 2>&1
  [ -f "$R/matrix.json" ] && cp "$R/matrix.json" "$R/Bv2-r$i-matrix.json"
  echo "Bv2 r$i: $(jq -r '.total_tokens' "$R/Bv2-r$i.json" 2>/dev/null) tok  $(jq -r '.cost_usd' "$R/Bv2-r$i.json" 2>/dev/null) usd"

  rm -f "$R/matrix.json"
  SD="$HOME/sessions/Av2-r$i"; mkdir -p "$SD"
  prime-agent --mode json --provider anthropic --model claude-opus-5 \
    --thinking high --cwd "$HOME/work/repo" --session-dir "$SD" \
    -p "$(cat "$P")" > "$R/Av2-r$i.jsonl" 2>"$R/Av2-r$i.stderr"
  [ -f "$R/matrix.json" ] && cp "$R/matrix.json" "$R/Av2-r$i-matrix.json"
  echo "Av2 r$i: $(jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$R/Av2-r$i.jsonl" 2>/dev/null) tok"
done
echo "V2 REPEATS COMPLETE"
