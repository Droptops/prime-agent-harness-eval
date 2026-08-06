#!/usr/bin/env bash
R="$HOME/results"; T="$R/truth-task6.json"
PKGS="agent ai coding-agent tui"

echo "=== TASK 6 SCORING (16 fields: 4 packages x 4 metrics) ==="
if [ ! -f "$T" ]; then echo "  (truth not restored yet)"; else
for f in Bpar-r1-out Bpar-r2-out Apar-r1-out Apar-r2-out Asub-r1-out Asub-r2-out; do
  p="$R/$f.json"
  [ -f "$p" ] || { printf "  %-14s NO OUTPUT\n" "$f"; continue; }
  ok=0; bad=""
  for pkg in $PKGS; do
    for m in ts_files total_lines exported_functions; do
      a=$(jq -c ".\"$pkg\".$m" "$p" 2>/dev/null); t=$(jq -c ".\"$pkg\".$m" "$T")
      if [ "$a" = "$t" ]; then ok=$((ok+1)); else bad="$bad $pkg.$m(got=$a want=$t)"; fi
    done
    a=$(jq -cS ".\"$pkg\".largest_file" "$p" 2>/dev/null); t=$(jq -cS ".\"$pkg\".largest_file" "$T")
    if [ "$a" = "$t" ]; then ok=$((ok+1)); else bad="$bad $pkg.largest_file"; fi
  done
  printf "  %-14s %2d/16%s\n" "$f" "$ok" "$bad"
done
fi

echo
echo "=== DID SUBAGENTS ACTUALLY SPAWN? ==="
for f in Asub-r1 Asub-r2 Apar-r1 Apar-r2; do
  j="$R/$f.jsonl"
  [ -f "$j" ] || continue
  rlm=$(grep -c 'rlm_child_id' "$j" 2>/dev/null)
  awaits=$(grep -oc 'await rlm(' "$j" 2>/dev/null)
  depth=$(jq -r 'select(.type=="session")|.rlmDepth' "$j" 2>/dev/null | head -1)
  tools=$(jq -r 'select(.type=="tool_execution_start")|.toolName' "$j" 2>/dev/null | sort | uniq -c | tr '\n' ' ')
  printf "  %-10s rlm_child_id=%s  'await rlm('=%s  rlmDepth=%s  tools: %s\n" "$f" "$rlm" "$awaits" "$depth" "$tools"
done

echo
echo "=== child sessions on disk? (rlmDepth > 0) ==="
find "$HOME/sessions" -name '*.jsonl' -newermt '-40 minutes' 2>/dev/null | while read -r s; do
  d=$(jq -r 'select(.type=="session")|.rlmDepth' "$s" 2>/dev/null | head -1)
  [ "$d" != "0" ] && [ -n "$d" ] && echo "  CHILD: $s depth=$d"
done
echo "  (no CHILD lines above = no child sessions were created)"
