# Task 1 — repo navigation (BENCHMARK-SHAPED, harness should win)

Shape: large intermediate data, mechanical, exactly-checkable answer.
This is the shape prime-agent's IPython-first design is built for. If the
harness does not win here, it does not win anywhere.

## Prompt given to the agent

The repository at /home/bench/work/repo is prime-agent v0.7.0.
Write a single JSON object to /home/bench/results/answer.json with exactly
these keys:

{
  "provider_count": <int>,
  "providers": [<the KnownProvider union members, sorted, as strings>],
  "models_generated_loc": <int, line count of packages/ai/src/models.generated.ts>,
  "largest_source_file": {"path": <str>, "loc": <int>}
}

"largest_source_file" considers only .ts files under packages/*/src/ and is
measured in lines. Paths are relative to the repository root.
Write only the JSON object to that file. No prose, no markdown fence.

## Ground truth

scripts/groundtruth.sh writes /home/bench/results/truth-task1.json from the
same checkout. Scored by exact match per key: 4 keys, 1 point each
(`providers` must match as a sorted set).

Verified values at commit c22549a3: provider_count = 32.

## Why this is the fair-to-A case

Answering requires walking hundreds of files and aggregating. In condition B
every file listing lands in context as tokens; in condition A it can stay as a
Python variable in the kernel. If the token-efficiency claim is real, A should
win on cost here, not just on quality.
