#!/usr/bin/env bash
R="$HOME/results"; T="$R/truth-task5.json"
echo "=== TASK 5 (large-data) SCORING: 6 fields each ==="
for f in Abig-r1-out Abig-r2-out Bbig-r1-out Bbig-r2-out; do
  p="$R/$f.json"
  if [ ! -f "$p" ]; then printf "  %-16s NO OUTPUT FILE\n" "$f"; continue; fi
  ok=0; detail=""
  for k in total_models providers_with_models reasoning_true_count mean_output_cost; do
    a=$(jq -c ".$k" "$p" 2>/dev/null); t=$(jq -c ".$k" "$T")
    if [ "$a" = "$t" ]; then ok=$((ok+1)); else detail="$detail $k(got=$a want=$t)"; fi
  done
  for k in provider_with_most_models largest_context_window; do
    a=$(jq -cS ".$k" "$p" 2>/dev/null); t=$(jq -cS ".$k" "$T")
    if [ "$a" = "$t" ]; then ok=$((ok+1)); else detail="$detail $k(got=$a want=$t)"; fi
  done
  printf "  %-16s %d/6%s\n" "$f" "$ok" "$detail"
done
echo
echo "=== truth ==="
jq -cS . "$T"
echo
echo "=== did each condition read the file in bulk or aggregate in code? ==="
for i in 1 2; do
  b=$(grep -oE '"name":"(bash|read_file)"' "$R/Bbig-r$i.json" 2>/dev/null | sort | uniq -c | tr '\n' ' ')
  echo "  Bbig-r$i tool mix: ${b:-n/a}"
  a=$(jq -r 'select(.type=="tool_execution_start")|.toolName' "$R/Abig-r$i.jsonl" 2>/dev/null | sort | uniq -c | tr '\n' ' ')
  echo "  Abig-r$i tool mix: ${a:-n/a}"
done
