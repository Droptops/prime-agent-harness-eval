# Task 3 v2 — long-horizon repeated procedure, DISAMBIGUATED

v1 was unusable as a quality measure: it asked which env vars a provider
"reads", and the file has two functions with different answers
(`getApiKeyEnvVars` returns declared API-key vars; `getEnvApiKey` additionally
consults ambient AWS/ADC credentials). Both readings were defensible, the
answer key hardcoded one, and 6 of 8 runs picked the other. The scoring
measured interpretation, not accuracy.

v2 names the exact function whose behaviour is being asked about and states
the exclusion explicitly. The task is still non-trivial: the special cases
sit above the envMap, values don't derive from provider ids, and the two
unmapped providers still have to be identified and omitted.

## Prompt given to the agent

The repository at /home/bench/work/repo is prime-agent v0.7.0.

In packages/ai/src/env-api-keys.ts there is a function `getApiKeyEnvVars(provider)`.
For every member of the `KnownProvider` union in packages/ai/src/types.ts,
determine exactly what `getApiKeyEnvVars` returns for that provider.

Report ONLY what `getApiKeyEnvVars` itself returns. Do NOT include ambient
credential sources consulted elsewhere in the file (for example the AWS_* or
GOOGLE_APPLICATION_CREDENTIALS variables read inside `getEnvApiKey`) — those
are not part of `getApiKeyEnvVars`'s return value.

Write a single JSON object to /home/bench/results/matrix.json mapping each
provider for which `getApiKeyEnvVars` returns a non-undefined value to the
array of env var names it returns, preserving the order in the source.
Providers for which it returns undefined must be OMITTED from the object.

Work through the providers ONE AT A TIME. After each provider, state in one
sentence what you learned about the file's structure that will make the next
provider faster.

Write only the JSON object to that file. No prose, no markdown fence.

## Ground truth

Unchanged from v1 — `truth-task3.json` already encodes exactly
`getApiKeyEnvVars`'s return value (envMap plus the two special cases). v1's
defect was that the PROMPT didn't match the key; the key itself was a correct
description of that one function.

30 entries. `amazon-bedrock` and `openai-codex` are omitted because
`getApiKeyEnvVars` returns undefined for both.

## What this now measures

Whether the agent reads one named function accurately across 32 cases. A wrong
answer is now a reading error, not a defensible alternative interpretation.
