#!/usr/bin/env bash
# TEST 6: subagents. The last untested headline feature.
#
# Three arms:
#   Bpar  baseline, neutral prompt        (no subagent capability at all)
#   Apar  prime-agent, neutral prompt     (does it fan out spontaneously?)
#   Asub  prime-agent, MUST use rlm()     (functional test of the mechanism)
#
# The answer key is NOT present in the container for any of these runs.
set -uo pipefail

N="${1:-2}"
R="$HOME/results"
PN="$HOME/prompts/task6-parallel.txt"
PS="$HOME/prompts/task6-subagent.txt"
PA="prime-agent --mode json --provider anthropic --model claude-opus-5 --thinking high --cwd $HOME/work/repo"

atok() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$1" 2>/dev/null; }
acost() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|(map(.cost.total)|add*10000|round/10000)' "$1" 2>/dev/null; }
aturns() { jq -s '[.[]|select(.type=="turn_end")]|length' "$1" 2>/dev/null; }

for i in $(seq 1 "$N"); do
  rm -f "$R/packages.json"
  ~/bvenv/bin/python ~/baseline.py "$PN" "$R/Bpar-r$i.json" >/dev/null 2>&1
  [ -f "$R/packages.json" ] && cp "$R/packages.json" "$R/Bpar-r$i-out.json"
  echo "Bpar r$i: tok=$(jq -r '.total_tokens' "$R/Bpar-r$i.json" 2>/dev/null) turns=$(jq -r '.turns' "$R/Bpar-r$i.json" 2>/dev/null) cost=$(jq -r '.cost_usd' "$R/Bpar-r$i.json" 2>/dev/null)"

  rm -f "$R/packages.json"
  SD="$HOME/sessions/Apar-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$PN")" > "$R/Apar-r$i.jsonl" 2>/dev/null
  [ -f "$R/packages.json" ] && cp "$R/packages.json" "$R/Apar-r$i-out.json"
  echo "Apar r$i: tok=$(atok "$R/Apar-r$i.jsonl") turns=$(aturns "$R/Apar-r$i.jsonl") cost=\$$(acost "$R/Apar-r$i.jsonl")"

  rm -f "$R/packages.json"
  SD="$HOME/sessions/Asub-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$PS")" > "$R/Asub-r$i.jsonl" 2>/dev/null
  [ -f "$R/packages.json" ] && cp "$R/packages.json" "$R/Asub-r$i-out.json"
  echo "Asub r$i: tok=$(atok "$R/Asub-r$i.jsonl") turns=$(aturns "$R/Asub-r$i.jsonl") cost=\$$(acost "$R/Asub-r$i.jsonl")"
done
echo "PARALLEL RUNS COMPLETE"
