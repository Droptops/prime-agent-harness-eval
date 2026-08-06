#!/usr/bin/env bash
# Does the continual harness help when it ACTUALLY fires?
#
# Within-harness A/A contrast; no baseline arm. Both arms run prime-agent on the
# same two tasks in the same session. The only difference is whether auto-refine
# is allowed to run between them.
#
#   ARM ON  : autoRefine {enabled:true, turnInterval:3}  -> refine fires after task 1
#   ARM OFF : autoRefine {enabled:false}                 -> no refine
#
# Task 1 = task3 v2 (build the provider -> env var map)
# Task 2 = task4    (which env vars are shared by >1 provider) -- answerable
#          directly from the structural lesson refine wrote during task 1.
#
# Dependent variable: task 2 correctness, tokens, turns.
set -uo pipefail

R="$HOME/results"
SETTINGS="$HOME/.prime/agent/settings.json"
P1="$HOME/prompts/task3v2-long-horizon.txt"
P2="$HOME/prompts/task4-shared.txt"

run_arm() {
  local arm="$1" cfg="$2"
  local SD="$HOME/sessions/refine-$arm"
  rm -rf "$SD"; mkdir -p "$SD"
  printf '%s' "$cfg" > "$SETTINGS"
  echo "### ARM=$arm settings=$(cat $SETTINGS)"

  # --- task 1: seeds the session (and, in ARM ON, triggers refine) ---
  rm -f "$R/matrix.json"
  prime-agent --mode json --provider anthropic --model claude-opus-5 \
    --thinking high --cwd "$HOME/work/repo" --session-dir "$SD" \
    -p "$(cat "$P1")" > "$R/refine-$arm-t1.jsonl" 2>"$R/refine-$arm-t1.stderr"
  [ -f "$R/matrix.json" ] && cp "$R/matrix.json" "$R/refine-$arm-t1-matrix.json"

  # did refine actually run?
  local hs
  hs=$(find "$HOME/sessions" -name harness_state.json -newermt '-30 minutes' 2>/dev/null | wc -l)
  echo "    task1 turns=$(jq -s '[.[]|select(.type=="turn_end")]|length' "$R/refine-$arm-t1.jsonl" 2>/dev/null)  harness_state_files=$hs"

  # --- task 2: same session, continued ---
  rm -f "$R/shared.json"
  prime-agent --mode json --provider anthropic --model claude-opus-5 \
    --thinking high --cwd "$HOME/work/repo" --session-dir "$SD" --continue \
    -p "$(cat "$P2")" > "$R/refine-$arm-t2.jsonl" 2>"$R/refine-$arm-t2.stderr"
  [ -f "$R/shared.json" ] && cp "$R/shared.json" "$R/refine-$arm-t2-shared.json"

  echo "    task2 turns=$(jq -s '[.[]|select(.type=="turn_end")]|length' "$R/refine-$arm-t2.jsonl" 2>/dev/null)  tok=$(jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$R/refine-$arm-t2.jsonl" 2>/dev/null)"
}

run_arm on  '{"autoRefine":{"enabled":true,"turnInterval":3,"cooldownMs":0}}'
run_arm off '{"autoRefine":{"enabled":false}}'

rm -f "$SETTINGS"
echo "EXPERIMENT COMPLETE"
