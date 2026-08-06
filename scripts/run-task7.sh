#!/usr/bin/env bash
# TASK 7: the non-saturating task. Every prior task hit 100% for both
# conditions, so the eval measured cost but never capability. This one is a
# transitive-closure problem over 267 files with non-obvious resolution rules
# (0 direct importers vs 181 transitive -- the shortcut answer is visibly wrong).
#
# Answer key is NOT in the container for any run.
set -uo pipefail

N="${1:-3}"
R="$HOME/results"
P="$HOME/prompts/task7-closure.txt"
STASH="$HOME/.keystash"; mkdir -p "$STASH"
PA="prime-agent --mode json --provider anthropic --model claude-opus-5 --thinking high --cwd $HOME/work/repo"

atok() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$1" 2>/dev/null; }
acost() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|(map(.cost.total)|add*10000|round/10000)' "$1" 2>/dev/null; }

for k in "$R"/truth-*.json; do [ -f "$k" ] && mv "$k" "$STASH/"; done
echo "keys hidden; remaining in results: $(ls "$R" | grep -c '^truth-')"

for i in $(seq 1 "$N"); do
  rm -f "$R/closure.json"
  ~/bvenv/bin/python ~/baseline.py "$P" "$R/B7-r$i.json" >/dev/null 2>&1
  [ -f "$R/closure.json" ] && cp "$R/closure.json" "$R/B7-r$i-out.json"
  echo "B7 r$i: tok=$(jq -r '.total_tokens' "$R/B7-r$i.json" 2>/dev/null) turns=$(jq -r '.turns' "$R/B7-r$i.json" 2>/dev/null) cost=$(jq -r '.cost_usd' "$R/B7-r$i.json" 2>/dev/null)"

  rm -f "$R/closure.json"
  SD="$HOME/sessions/A7-r$i"; rm -rf "$SD"; mkdir -p "$SD"
  $PA --session-dir "$SD" -p "$(cat "$P")" > "$R/A7-r$i.jsonl" 2>/dev/null
  [ -f "$R/closure.json" ] && cp "$R/closure.json" "$R/A7-r$i-out.json"
  echo "A7 r$i: tok=$(atok "$R/A7-r$i.jsonl") cost=\$$(acost "$R/A7-r$i.jsonl")"
done

for k in "$STASH"/truth-*.json; do [ -f "$k" ] && mv "$k" "$R/"; done
echo "keys restored: $(ls "$R" | grep -c '^truth-')"
echo "TASK7 COMPLETE"
