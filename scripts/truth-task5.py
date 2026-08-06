"""Ground truth for task 5 (large-data aggregation), computed mechanically.

models.generated.ts is TypeScript, not JSON, so parse structurally: split into
per-provider sections on the top-level keys of MODELS, then per-model blocks.
"""
import json
import re
import sys

SRC = sys.argv[1] if len(sys.argv) > 1 else \
    "/home/bench/work/repo/packages/ai/src/models.generated.ts"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/home/bench/results/truth-task5.json"

text = open(SRC, encoding="utf-8").read()

# Top-level provider keys sit at exactly one tab of indentation.
provider_starts = [(m.group(1), m.start())
                   for m in re.finditer(r'^\t"([a-z0-9-]+)": \{$', text, re.M)]
provider_starts.append((None, len(text)))

models = []
for i in range(len(provider_starts) - 1):
    prov, start = provider_starts[i]
    end = provider_starts[i + 1][1]
    section = text[start:end]
    # Each model block ends with `} satisfies Model<...>`
    for blk in re.finditer(r'\n\t\t"([^"]+)": \{(.*?)\n\t\t\} satisfies Model<', section, re.S):
        mid, body = blk.group(1), blk.group(2)
        def num(field):
            m = re.search(rf'\b{field}:\s*([0-9.]+)', body)
            return float(m.group(1)) if m else None
        def boolean(field):
            m = re.search(rf'\b{field}:\s*(true|false)', body)
            return m.group(1) == "true" if m else None
        cost = re.search(r'cost:\s*\{(.*?)\}', body, re.S)
        cbody = cost.group(1) if cost else ""
        def cnum(field):
            m = re.search(rf'\b{field}:\s*([0-9.]+)', cbody)
            return float(m.group(1)) if m else None
        models.append({
            "provider": prov,
            "id": mid,
            "reasoning": boolean("reasoning"),
            "contextWindow": num("contextWindow"),
            "cost_input": cnum("input"),
            "cost_output": cnum("output"),
        })

by_prov = {}
for m in models:
    by_prov.setdefault(m["provider"], []).append(m)

top_prov = max(by_prov.items(), key=lambda kv: (len(kv[1]), kv[0]))
widest = max(models, key=lambda m: (m["contextWindow"] or 0, m["id"]))
outs = [m["cost_output"] for m in models if m["cost_output"]]

truth = {
    "total_models": len(models),
    "providers_with_models": len(by_prov),
    "provider_with_most_models": {"provider": top_prov[0], "count": len(top_prov[1])},
    "largest_context_window": {"id": widest["id"], "contextWindow": int(widest["contextWindow"])},
    "reasoning_true_count": sum(1 for m in models if m["reasoning"]),
    "mean_output_cost": round(sum(outs) / len(outs), 4),
}

json.dump(truth, open(OUT, "w"), indent=2, sort_keys=True)
print(json.dumps(truth, indent=2, sort_keys=True))
print(f"\n[sanity] providers parsed: {sorted(by_prov)[:6]} ... ({len(by_prov)} total)")
print(f"[sanity] models with no contextWindow: {sum(1 for m in models if m['contextWindow'] is None)}")
print(f"[sanity] models with no output cost:   {sum(1 for m in models if m['cost_output'] is None)}")
