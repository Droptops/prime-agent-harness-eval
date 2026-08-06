#!/usr/bin/env bash
# TEST 4: the large-data task. 536KB / 20,400 lines, six aggregations over the
# whole file. This is the shape prime-agent's IPython-first design targets: the
# tool-loop must page bulk text through the transcript, the kernel need not.
#
# Honest caveat baked into the design: the baseline's bash tool can invoke
# python3, so this is not a capability gap -- it tests persistence and
# ergonomics, not what is possible.
set -uo pipefail

N="${1:-2}"
R="$HOME/results"
P="$HOME/prompts/task5-bigdata.txt"
PA="prime-agent --mode json --provider anthropic --model claude-opus-5 --thinking high --cwd $HOME/work/repo"

for i in $(seq 1 "$N"); do
  rm -f "$R/bigdata.json"
  ~/bvenv/bin/python ~/baseline.py "$P" "$R/Bbig-r$i.json" >/dev/null 2>&1
  [ -f "$R/bigdata.json" ] && cp "$R/bigdata.json" "$R/Bbig-r$i-out.json"
  echo "Bbig r$i: tok=$(jq -r '.total_tokens' "$R/Bbig-r$i.json" 2>/dev/null) turns=$(jq -r '.turns' "$R/Bbig-r$i.json" 2>/dev/null) cost=$(jq -r '.cost_usd' "$R/Bbig-r$i.json" 2>/dev/null)"

  rm -f "$R/bigdata.json"
  SD="$HOME/sessions/Abig-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$P")" > "$R/Abig-r$i.jsonl" 2>/dev/null
  [ -f "$R/bigdata.json" ] && cp "$R/bigdata.json" "$R/Abig-r$i-out.json"
  tok=$(jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$R/Abig-r$i.jsonl" 2>/dev/null)
  cost=$(jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|(map(.cost.total)|add*10000|round/10000)' "$R/Abig-r$i.jsonl" 2>/dev/null)
  turns=$(jq -s '[.[]|select(.type=="turn_end")]|length' "$R/Abig-r$i.jsonl" 2>/dev/null)
  echo "Abig r$i: tok=$tok turns=$turns cost=\$$cost"
done
echo "BIGDATA RUNS COMPLETE"
