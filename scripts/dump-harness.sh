#!/usr/bin/env bash
# PHASE 3: dump the accumulated continual-harness state RAW.
#
# No summarizing, no filtering, no "here are the highlights". The whole point
# is to judge whether the lessons are reusable, and that judgement is worthless
# if this script pre-digests them.
#
# Two scopes, per harness.py:
#   local  -> $RLM_SESSION_DIR/harness/harness_state.json  (dies with the session)
#   global -> ~/.prime/agent/harness/harness_state.json    (survives)
set -uo pipefail

AGENT_DIR="${PRIME_AGENT_CODING_AGENT_DIR:-$HOME/.prime/agent}"
GLOBAL="$AGENT_DIR/harness/harness_state.json"

echo "=============================================================="
echo "GLOBAL HARNESS STATE"
echo "path: $GLOBAL"
echo "=============================================================="
if [ -f "$GLOBAL" ]; then
  echo "--- size: $(wc -c < "$GLOBAL") bytes ---"
  echo "--- entry counts by kind ---"
  jq '{prompt:(.entries.prompt|length), memory:(.entries.memory|length),
       skill:(.entries.skill|length), subagent:(.entries.subagent|length),
       refinements:(.refinements|length)}' "$GLOBAL" 2>/dev/null || echo "(unparseable)"
  echo "--- RAW FILE, VERBATIM ---"
  cat "$GLOBAL"
else
  echo "NO GLOBAL HARNESS STATE FILE."
  echo "This is a finding, not an error: it means no refinement ever ran with"
  echo "global scope. The 'lessons persist across sessions' claim is untested"
  echo "by this run because the feature never fired."
fi

echo
echo "=============================================================="
echo "LOCAL (PER-SESSION) HARNESS STATE"
echo "=============================================================="
found=0
while IFS= read -r f; do
  found=1
  echo "--------------------------------------------------------------"
  echo "path: $f   ($(wc -c < "$f") bytes)"
  echo "--------------------------------------------------------------"
  cat "$f"
  echo
done < <(find "$AGENT_DIR" -name harness_state.json -not -path "$GLOBAL" 2>/dev/null)

if [ "$found" -eq 0 ]; then
  echo "NO LOCAL HARNESS STATE FILES FOUND under $AGENT_DIR."
  echo "Auto-refine fires every 25 turns or on compaction (20-min cooldown)."
  echo "If the runs finished under 25 turns, refinement never triggered and"
  echo "there is nothing to judge -- report that plainly rather than implying"
  echo "the feature was evaluated."
fi

echo
echo "=============================================================="
echo "REFINEMENT EVENTS ACROSS ALL SCOPES (trigger / changes / evidence)"
echo "=============================================================="
find "$AGENT_DIR" -name harness_state.json 2>/dev/null | while IFS= read -r f; do
  echo "### $f"
  jq -r '.refinements[]? | "trigger: \(.trigger)\nchanges: \(.changes|join("; "))\nevidence: \(.evidence)\noutcome: \(.outcome)\n---"' \
    "$f" 2>/dev/null || echo "(none or unparseable)"
done
