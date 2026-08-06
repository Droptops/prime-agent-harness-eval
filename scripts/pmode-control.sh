#!/usr/bin/env bash
# CONTROL for the interactive finding: identical settings (turnInterval 1,
# cooldown 0), identical prompt, identical model -- but -p single-shot mode
# instead of an interactive PTY session.
#
# If auto-refine fires here too, the interactive result is explained by the
# lower threshold, not by session mode. If it does not, session mode is the
# differentiator.
set -uo pipefail

R="$HOME/results"
before=$(find "$HOME" -name harness_state.json 2>/dev/null | wc -l)
echo "harness_state BEFORE: $before"
echo "settings: $(cat "$HOME/.prime/agent/settings.json" | tr -d '\n ')"

rm -rf "$HOME/sessions/pctl"; mkdir -p "$HOME/sessions/pctl"
rm -f "$R/matrix.json"

prime-agent --mode json --provider anthropic --model claude-opus-5 \
  --thinking high --cwd "$HOME/work/repo" --session-dir "$HOME/sessions/pctl" \
  -p "$(cat "$HOME/prompts/task3v2-long-horizon.txt")" \
  > "$R/pctl.jsonl" 2>"$R/pctl.stderr"

after=$(find "$HOME" -name harness_state.json 2>/dev/null | wc -l)
echo "harness_state AFTER:  $after"
echo "turns:   $(jq -s '[.[]|select(.type=="turn_end")]|length' "$R/pctl.jsonl" 2>/dev/null)"
echo "matrix:  $([ -f "$R/matrix.json" ] && echo WRITTEN || echo MISSING)"
SID=$(jq -r 'select(.type=="session")|.id' "$R/pctl.jsonl" 2>/dev/null | head -1)
echo "session: $SID"
echo "harness dir for that session: $(ls -d "$HOME/sessions/session-artifacts/$SID/harness" 2>/dev/null || echo NONE)"
if [ "$before" = "$after" ]; then
  echo "RESULT: auto-refine did NOT fire in -p mode at turnInterval=1"
else
  echo "RESULT: auto-refine DID fire in -p mode -- interactive was not the differentiator"
fi
