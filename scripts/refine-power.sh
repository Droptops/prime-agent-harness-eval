#!/usr/bin/env bash
# The one place more n genuinely changes what can be said.
#
# Prior result: forced-refine run at 47,748 tokens vs a no-state condition
# spanning 46,382-80,080 (n=5, sd 13,743) -> z=-0.77, no detectable effect.
# With sd ~24% of mean, detecting a 20% effect needs roughly n=10 per arm.
#
# Each arm seeds a session with task 3, optionally forces /refine, then runs
# task 4 in the SAME session. Dependent variable: task-4 tokens.
set -uo pipefail

N="${1:-8}"
R="$HOME/results"
P1="$HOME/prompts/task3v2-long-horizon.txt"
P2="$HOME/prompts/task4-shared.txt"
STASH="$HOME/.keystash"; mkdir -p "$STASH"
PA="prime-agent --mode json --provider anthropic --model claude-opus-5 --thinking high --cwd $HOME/work/repo"

tok() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$1" 2>/dev/null; }

for k in "$R"/truth-*.json; do [ -f "$k" ] && mv "$k" "$STASH/"; done

for i in $(seq 1 "$N"); do
  for arm in refine noref; do
    SD="$HOME/sessions/pw-$arm-$i"; rm -rf "$SD"; mkdir -p "$SD"
    rm -f "$R/matrix.json" "$R/shared.json"

    $PA --session-dir "$SD" -p "$(cat "$P1")" > "$R/pw-$arm-$i-t1.jsonl" 2>/dev/null

    if [ "$arm" = "refine" ]; then
      $PA --session-dir "$SD" --continue -p "/refine" > "$R/pw-$arm-$i-ref.jsonl" 2>/dev/null
    fi

    $PA --session-dir "$SD" --continue -p "$(cat "$P2")" > "$R/pw-$arm-$i-t2.jsonl" 2>/dev/null
    [ -f "$R/shared.json" ] && cp "$R/shared.json" "$R/pw-$arm-$i-out.json"

    echo "$arm r$i: t2_tokens=$(tok "$R/pw-$arm-$i-t2.jsonl")"
  done
done

for k in "$STASH"/truth-*.json; do [ -f "$k" ] && mv "$k" "$R/"; done
echo "REFINE POWER COMPLETE"
