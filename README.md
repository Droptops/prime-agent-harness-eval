# Does prime-agent's harness actually improve model performance?

An A/B evaluation of [PrimeIntellect-ai/prime-agent](https://github.com/PrimeIntellect-ai/prime-agent)
v0.7.0 (commit `c22549a3`) against a plain tool-calling baseline, same model, same tasks.

**TL;DR:** No demonstrated general advantage. The baseline won the repo-navigation
task outright on tokens and cost, tied the judgment task, and the one apparent
quality win for the harness dissolves on inspection into a single ambiguous
interpretive call. Separately, and more definitively: the "continual harness"
self-improvement feature **never fired once** across any run.

This document was adversarially verified before publication; the verification
overturned several of its own earlier conclusions. Those are marked below.

---

## Method

| | |
|---|---|
| Harness | prime-agent v0.7.0 (pinned release tarball) |
| Model | `claude-opus-5`, `--thinking high` (A) / `effort: high` (B) |
| Baseline | Direct Anthropic SDK, manual tool loop, prompt caching enabled |
| Environment | Docker, non-root, no volume mounts, no sudo binary, API key via env only |
| Scoring | Script-computed ground truth from the same checkout. **See the caveat in Result 2 — "mechanical" is not the same as "objective."** |

Three task shapes:

1. **Repo navigation** — large intermediate data, exactly-checkable answer.
   The shape prime-agent's IPython-first design targets.
2. **Judgment memo** — no bulky intermediate data. The control.
3. **Long-horizon repeated procedure** — the only task that could plausibly
   trigger auto-refine.

### The baseline was handicapped. Disclosed in full.

Post-hoc review found five defects in the baseline harness, **all running
against it**:

1. `write_file` was confined to `/home/bench/work`, but every task writes its
   deliverable to `/home/bench/results`. The tool could not write any required
   output. Each run discovered this by failing and fell back to a `bash`
   heredoc. Effectively 3 usable tools, not 4.
2. The `bash` tool used `shell=True`, i.e. `/bin/sh`, which is `dash` in this
   image. Any `[[ ]]`, process substitution, or array syntax fails with exit
   127. prime-agent's IPython kernel has no equivalent trap.
3. Baseline cwd was `/home/bench/work`; prime-agent's was `/home/bench/work/repo`.
   Glob patterns implied by the task text matched 0 files for the baseline and
   355 for the harness.
4. `is_error` was set on any nonzero exit, so a `grep` with no matches was
   reported to the model as an error, polluting context.
5. prime-agent ships `rg` and `fd`; the baseline had only `grep`/`find`.

**The baseline still won task 1 and tied task 2 under these conditions.** A
fairer baseline would widen those margins, not narrow them. Treat every number
below as a lower bound on baseline performance.

---

## Result 1: a caching artifact nearly produced a false 4x win

The first baseline did not enable prompt caching. That made prime-agent look
**4.25x cheaper** on task 2 ($0.54 vs $2.28).

That number was meaningless — it measured caching, not the harness. prime-agent
caches aggressively (~317k cache-read tokens on that task); the naive baseline
re-sent the full growing transcript at full price every turn.

With caching enabled on the baseline, task 2 became a dead heat ($0.5361 vs
$0.575) and task 1 **reversed**:

| Task 1 | prime-agent | baseline (cached) |
|---|---|---|
| Score | 4/4 | 4/4 |
| Tokens | 65,383 | **19,550** |
| Cost | $0.1415 | **$0.0679** |

**Anyone benchmarking an agent harness against a hand-rolled baseline should
check this first.** Much of a mature harness's apparent cost advantage can be
prompt caching the baseline didn't enable.

---

## Result 2: the apparent quality win is one ambiguous judgment call

Task 3 was run **4 times per condition**. The headline numbers:

| Run | prime-agent | baseline |
|---|---|---|
| original | 30/30 | 29/30 |
| r1 | 30/30 | 29/30 |
| r2 | 29/30 | 29/30 |
| r3 | 29/30 | 29/30 |
| **Perfect** | **2/4** | **0/4** |

**That table overstates the resolution of the experiment, and the "/30" should
not be read as 30 independent items.** Every imperfect run — in both conditions —
deviates in exactly the same two coupled places:

- adds a spurious `amazon-bedrock` key, **and**
- returns `google-vertex: ["GOOGLE_CLOUD_API_KEY", "GOOGLE_APPLICATION_CREDENTIALS"]`
  where the ground truth has one element.

There are **zero mixed cases**. Both deviations follow from one decision: read
`env-api-keys.ts` narrowly (the `envMap`/`findEnvKeys` path) or broadly
(`getEnvApiKey`, which genuinely does read the AWS and ADC variables). The real
experiment is **n=4 vs n=4 on a single binary variable**, not 240 scored items.

### The ground truth encodes one of two defensible readings

The task prompt asks which credential env vars each provider *"reads, according
to `packages/ai/src/env-api-keys.ts`."* Under a plain reading of that sentence,
`getEnvApiKey` **does** read six AWS variables for `amazon-bedrock` and
`GOOGLE_APPLICATION_CREDENTIALS` for `google-vertex`. The file's exclusion
comment (line 143) is attached to `findEnvKeys` and scopes itself to env-key
*reporting*, not to the file as a whole.

The grading script hardcodes the narrow reading — including two hand-typed
entries for `anthropic` and `github-copilot`. So "mechanical" describes the
automation, not the objectivity: a human interpretive choice is baked into the
answer key.

### The models were not trapped — they flagged it

Both conditions explicitly surfaced the ambiguity in their own output. One
baseline run wrote that *"the source is genuinely ambiguous about what counts
as a 'credential env var'."* prime-agent's own refinement memory recorded the
alternative reading and labelled it a judgment call.

**Conclusion for Result 2:** this does not show prime-agent producing more
correct output. It shows prime-agent selecting the narrow reading more often on
an ambiguous prompt whose answer key happens to encode the narrow reading —
2/4 vs 0/4, Fisher's exact p ≈ 0.43, not significant. A single run would have
shown "30/30 vs 29/30" and badly overstated it.

Cost of that non-result, averaged over 4 runs:

| | prime-agent | baseline |
|---|---|---|
| Tokens (mean) | 110,730 | 57,819 |
| Cost (mean) | $0.3346 | $0.2780 |
| Ratio | **1.92x tokens, 1.20x cost** | — |

---

## Result 3: the self-improvement feature never ran

This is the most solid finding in the document.

The "continual harness" — the persistent, self-modifiable state that
distinguishes prime-agent — is written by an auto-refine pass. Defaults, in
both source and the shipped bundle: **enabled, every 25 _assistant_ turns**, or
on compaction, with a 20-minute cooldown.

Observed assistant turns:

| Task | Turns |
|---|---|
| 1 repo-nav | 5 |
| 2 judgment | 11 |
| 3 long-horizon | 5 |

**No run came within a factor of two of the threshold.** After every run:

- exactly zero `harness_state.json` files existed anywhere on the filesystem
- zero refine activity in the logs
- no `settings.json` anywhere in the container, so every default applied

The cooldown is guarded by `_lastAutoRefineReviewAt > 0`, so it can only
throttle repeat refines and cannot explain a first refine never happening. The
turn threshold alone accounts for it.

There is a self-defeating loop here: the IPython kernel lets the agent do in one
turn what a tool-loop takes several to do, which **suppresses the very counter
that triggers learning**. A task explicitly designed to run long finished in 5
turns.

On realistic work, the continual harness is inert.

---

## Result 4: forced refinement writes accurate notes — at a scope that dies

Running `/refine` manually produced 2 memory entries. Falsifiable claims in
them were checked against source:

| Claim written by the harness | Verdict |
|---|---|
| `github-copilot` is the only 3-element env var list | ✅ count = 1 |
| Doc comment says ambient creds excluded from reporting | ✅ line 143 |
| `PRIME_TEAM_ID` is config, not a credential | ✅ lines 216–218 |
| Precedence is `envKeys?.[0]` | ✅ line 166 |
| `minimax-cn` does not share a key with `minimax` | ✅ lines 119–120 |

Specific, non-obvious, and correct — not plausible-sounding filler. The
observation that env var names don't derive mechanically from provider ids
(`huggingface` → `HF_TOKEN`) is exactly what's worth persisting.

Two limits:

1. One of the two entries is largely task bookkeeping (`"Status: DONE"`,
   artifact path) — session state, not a lesson.
2. **Both wrote at `scope: "local"`** — a per-session directory that dies with
   the session. Nothing was written globally.

The machinery works, writes accurate notes, almost never runs, and defaults to
a scope that does not survive.

---

## Incidental: `install.sh` assumes a writable npm prefix

With Node already present, the installer correctly skips its sudo path — the
only sudo callers are in `install_node_npm_interactive()`, reached only when the
Node preflight fails. But the install step is an unconditional `npm install -g`,
and the installer neither configures nor checks the npm prefix.

Observed in an early build of this evaluation's container (`build-eacces.log` in
this repo), before a user-owned prefix was configured:

```
prime-agent-0.7.0.tgz: OK
npm error code EACCES
npm error path /usr/local/lib/node_modules/prime-agent
```

The failure lands *after* download and SHA-256 verification succeed. Setting
`npm config set prefix ~/.npm-global` before running the installer resolves it,
and the published Dockerfile does exactly that — so the shipped build succeeds
and does not reproduce the error.

---

## Verdict

- **The harness's 5–10x-token failure mode did not occur.** Its costs are
  modest: ~1.9x tokens, ~1.2x dollars.
- **No general performance advantage was demonstrated.** It lost task 1 on both
  tokens and cost, tied task 2, and its task-3 edge reduces to one ambiguous
  interpretive call that is not statistically significant.
- **The self-improvement claim is untested by normal use**, because normal use
  never triggers it.

The IPython-first design is a real engineering idea and it plausibly explains
the low turn counts. But on this evidence it is not a general multiplier, and
the feature the project is named around did not run.

## Limitations

- n=4 on task 3; n=1 on tasks 1 and 2.
- Task 1 saturated (4/4 both) and could not show a quality difference.
- The baseline carried five disclosed handicaps, all against it.
- Task-3 scoring encodes a contested reading of an ambiguous prompt.
- Tasks were authored for this evaluation, not drawn from a public benchmark.
- **The repository makes no agent-capability or benchmark-score claims.**
  Nothing in the README or `packages/coding-agent/docs/` names a benchmark suite
  or reports a task-performance number, so there was no published figure to
  reproduce. (The repo is not claim-free in general: `docs/daemon.md` has a
  `## Benchmarks` section for daemon fanout/RSS timing, several `*bench*`
  scripts ship in-tree, and `packages/tui/CHANGELOG.md:946` carries an inherited
  claim of "10x faster on Bun" for `visibleWidth()` — all local runtime
  engineering, not agent quality.) The README cites an RLM blog post and
  [arXiv 2605.09998](https://arxiv.org/abs/2605.09998) as conceptual references;
  **neither was reviewed here.** This evaluates the harness, not the paper.

---

*Raw artifacts, task specs, grading scripts, container definition, and the
harness state dump are in this repository. Every number above is reproducible
from `data/`.*
