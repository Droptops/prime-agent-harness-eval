#!/usr/bin/env bash
R="$HOME/results"
echo "=== was packages.json ever written by the Asub runs? ==="
ls -la "$R/packages.json" "$R/Asub-r1-out.json" "$R/Asub-r2-out.json" 2>&1 | head -4

echo
echo "=== parent's final assistant text, Asub-r1 (last 1200 chars) ==="
jq -r 'select(.type=="message_end" and .message.role=="assistant") | [.message.content[]? | select(.type=="text") | .text] | join("")' "$R/Asub-r1.jsonl" 2>/dev/null | tail -c 1200

echo
echo
echo "=== how did the parent turn end? ==="
jq -c 'select(.type=="agent_end") | {type}' "$R/Asub-r1.jsonl" 2>/dev/null | head -2
jq -r 'select(.type=="message_end" and .message.role=="assistant") | .message.stopReason // .message.stop_reason // empty' "$R/Asub-r1.jsonl" 2>/dev/null | tail -3

echo
echo "=== did the CHILDREN finish and produce answers? ==="
P=$(jq -r 'select(.type=="session")|.id' "$R/Asub-r1.jsonl" 2>/dev/null | head -1)
echo "parent session: $P"
for c in "$HOME/sessions/session-artifacts/$P"/sub-*/*.jsonl; do
  [ -f "$c" ] || continue
  n=$(wc -l < "$c")
  last=$(jq -r 'select(.type=="message_end" and .message.role=="assistant") | [.message.content[]? | select(.type=="text") | .text] | join("")' "$c" 2>/dev/null | tail -c 220)
  echo "--- child $(basename $(dirname $c)) : $n events"
  echo "    tail: $(echo "$last" | tr '\n' ' ' | head -c 200)"
done

echo
echo "=== agent_message traffic (how children report back) ==="
grep -c 'agent_message' "$R/Asub-r1.jsonl" 2>/dev/null
