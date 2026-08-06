#!/usr/bin/env bash
R="$HOME/results"
echo "=== task4 correctness across every arm ==="
for f in val-forced-t2-shared val-none-t2-shared val-freshwith-shared val-freshwithout-shared refine-on-t2-shared refine-off-t2-shared; do
  p="$R/$f.json"
  if [ -f "$p" ]; then
    ok=$(jq -n --slurpfile g "$p" --slurpfile t "$R/truth-task4.json" '($g[0]==$t[0])' 2>/dev/null)
    printf "  %-28s exact=%s\n" "$f" "$ok"
  else
    printf "  %-28s MISSING\n" "$f"
  fi
done

echo
echo "=== task4 token cost: every run, labelled by whether usable state existed ==="
printf "  %-34s %-10s %s\n" RUN TOKENS STATE
for pair in \
  "refine-on-t2:none(autorefine never fired)" \
  "refine-off-t2:none" \
  "val-none-t2:none" \
  "val-freshwith-t2:none(global refine failed)" \
  "val-freshwithout-t2:none" \
  "val-forced-t2:LOCAL REFINE STATE PRESENT"; do
  f="${pair%%:*}"; label="${pair#*:}"
  t=$(jq -s '[.[]|select(.type=="message_end")|.message.usage|select(.!=null)]|map(.totalTokens)|add' "$R/$f.jsonl" 2>/dev/null)
  printf "  %-34s %-10s %s\n" "$f" "$t" "$label"
done

echo
echo "=== spread of the NO-STATE condition ==="
python3 - <<'PY'
import json,glob,os
R=os.path.expanduser("~/results")
def tok(f):
    tot=0
    for line in open(f,encoding="utf-8",errors="replace"):
        try: o=json.loads(line)
        except: continue
        if o.get("type")=="message_end":
            u=(o.get("message") or {}).get("usage")
            if u: tot+=u.get("totalTokens",0)
    return tot
no_state=["refine-on-t2","refine-off-t2","val-none-t2","val-freshwith-t2","val-freshwithout-t2"]
vals=[tok(f"{R}/{n}.jsonl") for n in no_state if os.path.exists(f"{R}/{n}.jsonl")]
vals=[v for v in vals if v]
if vals:
    m=sum(vals)/len(vals)
    sd=(sum((v-m)**2 for v in vals)/len(vals))**0.5
    print(f"  n={len(vals)} values={sorted(vals)}")
    print(f"  mean={m:.0f} sd={sd:.0f} min={min(vals)} max={max(vals)}")
    f=f"{R}/val-forced-t2.jsonl"
    if os.path.exists(f):
        fv=tok(f)
        z=(fv-m)/sd if sd else 0
        print(f"  forced-refine run = {fv}  -> z = {z:+.2f} vs the no-state distribution")
        print(f"  within no-state range? {'YES' if min(vals)<=fv<=max(vals) else 'NO'}")
PY
