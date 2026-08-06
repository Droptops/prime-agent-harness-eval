#!/usr/bin/env bash
# Verify the load-bearing claim in the bug report: does the -p subagent run
# actually exit 0 while writing nothing? Asserted earlier but never measured.
R="$HOME/results"
rm -f "$R/packages.json"
SD="$HOME/sessions/exitcheck"; rm -rf "$SD"; mkdir -p "$SD"

prime-agent --mode json --provider anthropic --model claude-opus-5 \
  --thinking high --cwd "$HOME/work/repo" --session-dir "$SD" \
  -p "$(cat "$HOME/prompts/task6-subagent.txt")" > "$R/exitcheck.jsonl" 2>"$R/exitcheck.stderr"
rc=$?

echo "EXIT CODE: $rc"
echo "packages.json written: $([ -f "$R/packages.json" ] && echo YES || echo NO)"
echo "stderr bytes: $(wc -c < "$R/exitcheck.stderr")"
echo "stderr content: $(head -c 200 "$R/exitcheck.stderr")"
echo "children spawned: $(find "$HOME/sessions/session-artifacts" -maxdepth 2 -type d -name 'sub-*' -newermt '-10 minutes' 2>/dev/null | wc -l)"
echo "any error event in stream: $(grep -c '"type":"error"' "$R/exitcheck.jsonl" 2>/dev/null)"
