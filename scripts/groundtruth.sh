#!/usr/bin/env bash
# Compute ground truth mechanically, so scoring never depends on a model's
# opinion of its own output. Both conditions are graded against these files.
#
# Extraction is anchored on exact declarations (`export type KnownProvider`,
# `const envMap`) rather than loose ranges -- a sed range keyed on a bare
# "KnownProvider" restarts on every later mention and silently pulls in
# unrelated string literals.
set -uo pipefail

REPO="${1:-/home/bench/work/repo}"
OUT="${2:-/home/bench/results}"
mkdir -p "$OUT"
cd "$REPO" || exit 1

TYPES=packages/ai/src/types.ts
ENVK=packages/ai/src/env-api-keys.ts

# ---- providers: the KnownProvider union ------------------------------------
providers=$(awk '/^export type KnownProvider/,/;/' "$TYPES" \
  | grep -oE '"[a-z0-9-]+"' | tr -d '"' | sort -u)
provider_count=$(printf '%s\n' "$providers" | grep -c .)

# ---- task 1 ----------------------------------------------------------------
models_loc=$(wc -l < packages/ai/src/models.generated.ts)

largest_path=""; largest_loc=0
while IFS= read -r f; do
  n=$(wc -l < "$f")
  if [ "$n" -gt "$largest_loc" ]; then largest_loc=$n; largest_path=$f; fi
done < <(find packages/*/src -name '*.ts' -type f)

jq -n \
  --argjson pc "$provider_count" \
  --argjson ps "$(printf '%s\n' "$providers" | jq -R . | jq -s .)" \
  --argjson loc "$models_loc" \
  --arg lp "$largest_path" \
  --argjson ll "$largest_loc" \
  '{provider_count:$pc, providers:$ps, models_generated_loc:$loc,
    largest_source_file:{path:$lp, loc:$ll}}' > "$OUT/truth-task1.json"

# ---- task 3: provider -> credential env var --------------------------------
# Two hardcoded special cases return arrays before the envMap is consulted;
# everything else comes from the envMap object literal.
envmap=$(awk '/const envMap/,/^\t};/' "$ENVK" \
  | grep -oE '"?[a-z0-9-]+"?[[:space:]]*:[[:space:]]*"[A-Z_]+"' \
  | sed -E 's/"?([a-z0-9-]+)"?[[:space:]]*:[[:space:]]*"([A-Z_]+)"/\1 \2/')

matrix=$(jq -n '{}')
while read -r prov var; do
  [ -z "$prov" ] && continue
  matrix=$(printf '%s' "$matrix" | jq --arg p "$prov" --arg v "$var" '.[$p]=[$v]')
done <<< "$envmap"

# special cases, in precedence order as written in the source
matrix=$(printf '%s' "$matrix" | jq \
  '.["github-copilot"]=["COPILOT_GITHUB_TOKEN","GH_TOKEN","GITHUB_TOKEN"]
   | .["anthropic"]=["ANTHROPIC_OAUTH_TOKEN","ANTHROPIC_API_KEY"]')

printf '%s' "$matrix" | jq -S . > "$OUT/truth-task3.json"

echo "=== truth-task1.json ==="; cat "$OUT/truth-task1.json"
echo "=== truth-task3.json (providers with a credential env var) ==="
jq 'length as $n | {mapped_providers:$n}' "$OUT/truth-task3.json"
jq -S . "$OUT/truth-task3.json"
