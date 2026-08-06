#!/usr/bin/env bash
# #4 CONTAMINATION CONTROL: re-run tasks 1 and 3v2 with the answer keys
# physically absent from the container. Task 5 showed this matters (baseline
# usage doubled), so the earlier task-1/task-3 numbers cannot be trusted until
# reproduced under the same control.
#
# Keys are moved OUT before any run and restored only for scoring.
set -uo pipefail

N="${1:-2}"
R="$HOME/results"
STASH="$HOME/.keystash"
mkdir -p "$STASH"
PA="prime-agent --mode json --provider anthropic --model claude-opus-5 --thinking high --cwd $HOME/work/repo"

atok() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$1" 2>/dev/null; }
acost() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|(map(.cost.total)|add*10000|round/10000)' "$1" 2>/dev/null; }

# hide every answer key
for k in truth-task1.json truth-task3.json truth-task4.json truth-task5.json truth-task6.json; do
  [ -f "$R/$k" ] && mv "$R/$k" "$STASH/$k"
done
echo "keys hidden: $(ls "$STASH" | tr '\n' ' ')"
echo "keys still visible in results: $(ls "$R" | grep -c '^truth-')"

for i in $(seq 1 "$N"); do
  # ---- task 1 ----
  rm -f "$R/answer.json"
  ~/bvenv/bin/python ~/baseline.py "$HOME/prompts/task1-repo-nav.txt" "$R/B1c-r$i.json" >/dev/null 2>&1
  [ -f "$R/answer.json" ] && cp "$R/answer.json" "$R/B1c-r$i-out.json"
  echo "B task1 r$i: tok=$(jq -r '.total_tokens' "$R/B1c-r$i.json" 2>/dev/null) cost=$(jq -r '.cost_usd' "$R/B1c-r$i.json" 2>/dev/null)"

  rm -f "$R/answer.json"
  SD="$HOME/sessions/A1c-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$HOME/prompts/task1-repo-nav.txt")" > "$R/A1c-r$i.jsonl" 2>/dev/null
  [ -f "$R/answer.json" ] && cp "$R/answer.json" "$R/A1c-r$i-out.json"
  echo "A task1 r$i: tok=$(atok "$R/A1c-r$i.jsonl") cost=\$$(acost "$R/A1c-r$i.jsonl")"

  # ---- task 3 v2 ----
  rm -f "$R/matrix.json"
  ~/bvenv/bin/python ~/baseline.py "$HOME/prompts/task3v2-long-horizon.txt" "$R/B3c-r$i.json" >/dev/null 2>&1
  [ -f "$R/matrix.json" ] && cp "$R/matrix.json" "$R/B3c-r$i-out.json"
  echo "B task3 r$i: tok=$(jq -r '.total_tokens' "$R/B3c-r$i.json" 2>/dev/null) cost=$(jq -r '.cost_usd' "$R/B3c-r$i.json" 2>/dev/null)"

  rm -f "$R/matrix.json"
  SD="$HOME/sessions/A3c-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$HOME/prompts/task3v2-long-horizon.txt")" > "$R/A3c-r$i.jsonl" 2>/dev/null
  [ -f "$R/matrix.json" ] && cp "$R/matrix.json" "$R/A3c-r$i-out.json"
  echo "A task3 r$i: tok=$(atok "$R/A3c-r$i.jsonl") cost=\$$(acost "$R/A3c-r$i.jsonl")"
done

# restore keys
for k in "$STASH"/*.json; do [ -f "$k" ] && mv "$k" "$R/"; done
echo "keys restored: $(ls "$R" | grep -c '^truth-')"
echo "CLEAN RERUN COMPLETE"
