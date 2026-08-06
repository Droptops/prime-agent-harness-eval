#!/usr/bin/env bash
# #2 WEAKER-MODEL ARM. The standard argument for a harness is that scaffolding
# matters most when the model is weaker. Everything so far ran on the strongest
# available model, which is the least favourable case for the harness.
#
# Same three tasks, same prompts, claude-sonnet-5 on both sides.
# Answer keys hidden for every run.
set -uo pipefail

N="${1:-2}"
R="$HOME/results"
STASH="$HOME/.keystash"; mkdir -p "$STASH"
M="claude-sonnet-5"
PA="prime-agent --mode json --provider anthropic --model $M --thinking high --cwd $HOME/work/repo"

atok() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$1" 2>/dev/null; }
acost() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|(map(.cost.total)|add*10000|round/10000)' "$1" 2>/dev/null; }

for k in truth-task1.json truth-task3.json truth-task4.json truth-task5.json truth-task6.json; do
  [ -f "$R/$k" ] && mv "$R/$k" "$STASH/$k"
done
echo "keys hidden ($(ls "$STASH" | wc -l))"

run_pair() {
  local tag="$1" prompt="$2" artifact="$3" i="$4"
  rm -f "$R/$artifact"
  ~/bvenv/bin/python ~/baseline.py "$prompt" "$R/Bs-$tag-r$i.json" --model "$M" >/dev/null 2>&1
  [ -f "$R/$artifact" ] && cp "$R/$artifact" "$R/Bs-$tag-r$i-out.json"
  echo "  B $tag r$i: tok=$(jq -r '.total_tokens' "$R/Bs-$tag-r$i.json" 2>/dev/null) cost=$(jq -r '.cost_usd' "$R/Bs-$tag-r$i.json" 2>/dev/null)"

  rm -f "$R/$artifact"
  local SD="$HOME/sessions/As-$tag-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$prompt")" > "$R/As-$tag-r$i.jsonl" 2>/dev/null
  [ -f "$R/$artifact" ] && cp "$R/$artifact" "$R/As-$tag-r$i-out.json"
  echo "  A $tag r$i: tok=$(atok "$R/As-$tag-r$i.jsonl") cost=\$$(acost "$R/As-$tag-r$i.jsonl")"
}

for i in $(seq 1 "$N"); do
  run_pair t1  "$HOME/prompts/task1-repo-nav.txt"    answer.json   "$i"
  run_pair t5  "$HOME/prompts/task5-bigdata.txt"     bigdata.json  "$i"
  run_pair t6  "$HOME/prompts/task6-parallel.txt"    packages.json "$i"
done

for k in "$STASH"/*.json; do [ -f "$k" ] && mv "$k" "$R/"; done
echo "keys restored ($(ls "$R" | grep -c '^truth-'))"
echo "SONNET ARM COMPLETE"
