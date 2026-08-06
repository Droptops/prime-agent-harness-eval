# Task 3 — long-horizon repeated procedure (the ONLY task that can fire auto-refine)

Shape: the same sub-procedure applied ~30 times, deliberately past 25 turns.
This is the task that tests the SELF-IMPROVEMENT claim rather than the IPython
claim. Tasks 1 and 2 will finish well under the 25-turn auto-refine interval,
so the continual harness never fires there.

## Prompt given to the agent

The repository at /home/bench/work/repo is prime-agent v0.7.0.

For every provider in the `KnownProvider` union in packages/ai/src/types.ts,
determine which credential environment variable(s) that provider reads,
according to packages/ai/src/env-api-keys.ts.

Write a single JSON object to /home/bench/results/matrix.json mapping each
provider that HAS credential env vars to an array of its env var names, in the
precedence order the source uses. Providers with no credential env var mapping
must be OMITTED from the object entirely.

Work through the providers ONE AT A TIME. After each provider, state in one
sentence what you learned about the file's structure that will make the next
provider faster.

Write only the JSON object to that file. No prose, no markdown fence.

## Ground truth

scripts/groundtruth.sh writes /home/bench/results/truth-task3.json. Scored as
correct-entries / total-entries, with wrong-or-missing and spurious entries
both counted as errors.

Verified at commit c22549a3: 30 providers have credential env vars -- 28 from
the `envMap` object literal plus two special-cased ahead of it (`anthropic`,
`github-copilot`, each returning multiple vars in precedence order). Two of
the 32 union members (`amazon-bedrock`, `openai-codex`) have NO env var
mapping and must be omitted; they use non-standard auth. That omission is the
detail most likely to separate a real reading of the file from a plausible
guess.

## Why the "one at a time" instruction is load-bearing

It drives turn count past the 25-turn auto-refine interval AND creates a
genuinely reusable lesson (the two special cases precede the envMap; the
envMap is the bulk). That is the best case for the continual harness.

Read the Phase 3 dump against this. A real lesson names the structure --
"two special-cased providers return arrays before the envMap is consulted."
A plausible-sounding note says "be systematic when auditing providers."
