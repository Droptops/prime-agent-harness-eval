#!/usr/bin/env bash
# TEST 1: does harness state help WITHIN a session, when refine actually runs?
# TEST 2: does GLOBAL state help a BRAND NEW session? (the cross-session claim)
#
# Refine is invoked EXPLICITLY here. The prior experiment showed auto-refine
# never fires, so "enable it and hope" measures nothing; forcing it is the only
# way to test whether the state is worth having.
set -uo pipefail

R="$HOME/results"
P1="$HOME/prompts/task3v2-long-horizon.txt"
P2="$HOME/prompts/task4-shared.txt"
GLOBALDIR="$HOME/.prime/agent/harness"
PA="prime-agent --mode json --provider anthropic --model claude-opus-5 --thinking high --cwd $HOME/work/repo"

tok() { jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$1" 2>/dev/null; }
turns() { jq -s '[.[]|select(.type=="turn_end")]|length' "$1" 2>/dev/null; }

# =====================================================================
# TEST 1 — within-session, forced refine vs none
# =====================================================================
for arm in forced none; do
  SD="$HOME/sessions/val-$arm"; rm -rf "$SD"; mkdir -p "$SD"
  rm -f "$R/matrix.json" "$R/shared.json"

  $PA --session-dir "$SD" -p "$(cat "$P1")" > "$R/val-$arm-t1.jsonl" 2>/dev/null

  if [ "$arm" = "forced" ]; then
    $PA --session-dir "$SD" --continue -p "/refine" > "$R/val-$arm-refine.jsonl" 2>/dev/null
    echo "  [$arm] refine scope=$(jq -r 'select(.type=="refine_complete")|.result.scope' "$R/val-$arm-refine.jsonl" 2>/dev/null | head -1) edits=$(jq -r 'select(.type=="refine_complete")|.result.appliedEdits|length' "$R/val-$arm-refine.jsonl" 2>/dev/null | head -1)"
  fi

  $PA --session-dir "$SD" --continue -p "$(cat "$P2")" > "$R/val-$arm-t2.jsonl" 2>/dev/null
  [ -f "$R/shared.json" ] && cp "$R/shared.json" "$R/val-$arm-t2-shared.json"
  echo "TEST1 $arm: t2_tokens=$(tok "$R/val-$arm-t2.jsonl") t2_turns=$(turns "$R/val-$arm-t2.jsonl")"
done

# =====================================================================
# TEST 2 — cross-session, GLOBAL state vs none
# =====================================================================
rm -rf "$GLOBALDIR"
SD="$HOME/sessions/val-globalseed"; rm -rf "$SD"; mkdir -p "$SD"
rm -f "$R/matrix.json"
$PA --session-dir "$SD" -p "$(cat "$P1")" > "$R/val-globalseed-t1.jsonl" 2>/dev/null
$PA --session-dir "$SD" --continue -p "/refine global" > "$R/val-globalseed-refine.jsonl" 2>/dev/null
echo "  [globalseed] scope=$(jq -r 'select(.type=="refine_complete")|.result.scope' "$R/val-globalseed-refine.jsonl" 2>/dev/null | head -1) path=$(jq -r 'select(.type=="refine_complete")|.result.harnessStatePath' "$R/val-globalseed-refine.jsonl" 2>/dev/null | head -1)"
echo "  [globalseed] global file exists: $([ -f "$GLOBALDIR/harness_state.json" ] && echo YES || echo NO)"

# ARM: fresh session WITH global state present
SD="$HOME/sessions/val-freshwith"; rm -rf "$SD"; mkdir -p "$SD"
rm -f "$R/shared.json"
$PA --session-dir "$SD" -p "$(cat "$P2")" > "$R/val-freshwith-t2.jsonl" 2>/dev/null
[ -f "$R/shared.json" ] && cp "$R/shared.json" "$R/val-freshwith-shared.json"
echo "TEST2 fresh-WITH-global: tokens=$(tok "$R/val-freshwith-t2.jsonl") turns=$(turns "$R/val-freshwith-t2.jsonl")"

# ARM: fresh session WITHOUT global state
mv "$GLOBALDIR" "$GLOBALDIR.disabled" 2>/dev/null
SD="$HOME/sessions/val-freshwithout"; rm -rf "$SD"; mkdir -p "$SD"
rm -f "$R/shared.json"
$PA --session-dir "$SD" -p "$(cat "$P2")" > "$R/val-freshwithout-t2.jsonl" 2>/dev/null
[ -f "$R/shared.json" ] && cp "$R/shared.json" "$R/val-freshwithout-shared.json"
echo "TEST2 fresh-WITHOUT-global: tokens=$(tok "$R/val-freshwithout-t2.jsonl") turns=$(turns "$R/val-freshwithout-t2.jsonl")"
mv "$GLOBALDIR.disabled" "$GLOBALDIR" 2>/dev/null

echo "VALUE EXPERIMENTS COMPLETE"
