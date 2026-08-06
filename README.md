# Does prime-agent's harness actually improve model performance?

An A/B evaluation of [PrimeIntellect-ai/prime-agent](https://github.com/PrimeIntellect-ai/prime-agent)
v0.7.0 (commit `c22549a3`) against a plain tool-calling baseline, same model, same tasks.

**TL;DR:** No demonstrated performance advantage. The baseline won the
repo-navigation task outright on tokens and cost, tied the judgment task, and the
one apparent quality win for the harness turned out to be an ambiguity in my own
prompt — when the prompt is disambiguated and rerun, **both conditions score
100%** and the difference disappears entirely.

Separately, and more definitively: the "continual harness" self-improvement
feature **never fired in any of five sessions**, including two configured to be
maximally eager (`turnInterval: 3`, `cooldownMs: 0`). A controlled ON/OFF
contrast found no difference in cost or correctness.

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

### Rerun with a disambiguated prompt: the difference vanishes

The task was rewritten to name the exact function whose return value is wanted
(`getApiKeyEnvVars`) and to state the exclusion explicitly. Ground truth was
independently re-verified to equal that function's return for all 32 union
members. Then both conditions were rerun.

| Run | Result |
|---|---|
| prime-agent v2 r1 | **30/30, exact match** |
| prime-agent v2 r2 | **30/30, exact match** |
| baseline v2 r1 | **30/30, exact match** |
| baseline v2 r2 | **30/30, exact match** |

All four runs produced byte-identical output equal to the answer key. Across all
12 task-3 runs (v1 and v2), the response space contains no within-reading
variance: a run is either exactly right or takes the one alternative reading.

**Conclusion for Result 2: there is no quality difference on this task.** The
v1 result measured which reading each condition picked on an ambiguous prompt
whose answer key encoded one of them. Removing the ambiguity removes the effect.
A single v1 run would have shown "30/30 vs 29/30" and I would have published a
capability claim that does not exist.

What survives is a cost difference for identical output:

| | prime-agent | baseline |
|---|---|---|
| v1 tokens (mean, n=4) | 110,730 | 57,819 |
| v2 tokens (mean, n=2) | 73,443 | 45,187 |
| Ratio | **~1.6–1.9x tokens** | — |

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

### It stays inert even when configured to be maximally eager

The obvious objection is that 25 turns is simply too high a default. So the
threshold was lowered and the feature given every chance to run.

A controlled within-harness contrast, no baseline arm. Both arms run prime-agent
on the same two tasks in the same continued session; the only difference is
whether auto-refine is permitted between them. Task 2 was chosen to be directly
answerable from the structural lesson refine writes during task 1.

| Arm | settings | task-1 turns | refine fired | task-2 tokens | task-2 result |
|---|---|---|---|---|---|
| ON | `{enabled:true, turnInterval:3, cooldownMs:0}` | 5 | **no** | 47,891 | exact match |
| OFF | `{enabled:false}` | 4 | no | 46,382 | exact match |

Session continuation was verified (identical session id across both tasks in
both arms), so the ON arm genuinely had a prior turn to refine from.

**Auto-refine did not fire with a threshold of 3 and a session of 5 assistant
turns and no cooldown.** No `harness_state.json` was created; the session's
artifact directory contains kernel state but no `harness/` directory at all.
Across five independent sessions — three at defaults, two maximally eager —
the pass ran zero times. Explicitly invoking `/refine` works and writes state,
so the machinery is functional; what does not happen is automatic invocation.

The ON arm cost *more* (95,040 vs 73,712 tokens on task 1) and produced the same
answer. Enabling the feature bought nothing.

I could not fully isolate the mechanism. `_autoRefineAllowedForSession()` gates
on `_rlmDepth === 0 && _localHarnessStateDir() !== undefined` and is evaluated
before the `enabled` flag, and the harness directory is created lazily by the
refine pass rather than provisioned at session start. That is consistent with
what was observed but not proven to be the cause. **The empirical claim — it
does not fire in non-interactive runs regardless of threshold — is solid; the
explanation is a hypothesis.**

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

### Global scope is not reachable from the `/refine` command

Local state dies with the session, so the cross-session claim rests entirely on
global-scope refinement. The API supports it (`refine({global: true})`) and the
refinement system prompt describes when to use it.

Both documented-looking invocations were tried:

| Invocation | Parsed as | Resulting scope |
|---|---|---|
| `/refine global` | `args:""` | `local` |
| `/refine --global` | `args:""`, `text:"/refine"` | `local` |

**The slash command discards its arguments.** In both cases the emitted event
shows `args:""` and the state was written to the session-scoped path. After
every refine run in this evaluation, `~/.prime/agent/harness/` does not exist,
and all three `harness_state.json` files that were produced contain only
`scope: "local"` entries.

So via the CLI, every lesson the harness writes is session-local and dies with
the session. Global refinement may be reachable programmatically through the
SDK — that path was not tested.

### Does the state help when it IS present?

The one remaining question: forced refinement demonstrably works, so is the
resulting state worth anything? Task 4 was written to be directly answerable
from the structural lesson refine writes during task 3.

| Condition | task-4 tokens | task-4 correct |
|---|---|---|
| **Local refine state present** | 47,748 | ✅ |
| No state (auto-refine on, never fired) | 47,891 | ✅ |
| No state (auto-refine off) | 46,382 | ✅ |
| No state (no refine) | 80,080 | ✅ |
| No state (fresh session) | 69,273 | ✅ |
| No state (fresh session) | 48,341 | ✅ |

**Every arm answered correctly, so correctness cannot discriminate.** On cost,
the no-state condition spans 46,382–80,080 tokens (n=5, mean 58,393, sd 13,743).
The refined run at 47,748 sits at **z = −0.77 — comfortably inside that range**.

A naive read of just the adjacent pair (47,748 vs 80,080) shows a 40% saving.
That is an artifact of comparing two draws from a distribution whose standard
deviation is ~24% of its mean. **No benefit is detectable at this sample size.**
Detecting a 20% effect against this variance would need roughly n≈10 per arm.

This is the third time in this evaluation that an n=1 comparison produced an
apparent effect that did not survive contact with more data.

---

## Result 5: on the task built to favour the harness, the baseline still won

Every task above was small-data. Task 1 — meant to be the IPython-favouring case
— saturated at 4/4 in five turns. So the fair objection to this whole evaluation
was that it never gave the harness a workload where its design could matter.

Task 5 was written to remove that objection: six aggregations over
`models.generated.ts` — **20,400 lines, 536KB, 1,162 model records across 32
providers** — requiring grouping, a max, a filtered mean, and a tie-break. A
tool-loop must page bulk text through its transcript; a persistent kernel need
not.

Honest framing: the baseline's `bash` tool can invoke `python3`, so this is not
a capability gap. It tests persistence and ergonomics, not what is possible.

| Run | Score | Turns | Tokens | Cost |
|---|---|---|---|---|
| prime-agent r1 | 6/6 | 7 | 101,678 | $0.1929 |
| prime-agent r2 | 6/6 | 6 | 85,092 | $0.1716 |
| **baseline r1** | 6/6 | 7 | **49,998** | **$0.1669** |
| **baseline r2** | 6/6 | 9 | **51,052** | **$0.1590** |

**Both conditions scored 6/6 on every run. The baseline used ~1.85x fewer
tokens.** prime-agent solved it entirely through its kernel (4–5 `ipython` calls
per run); the baseline stripped the TypeScript syntax and evaluated `MODELS` in
Node, then aggregated — keeping bulk data out of its context just as effectively.

On the task designed specifically to expose the harness's structural advantage,
that advantage did not appear.

### A contamination scare, and why these are the numbers reported

An earlier pass of this task recorded far lower baseline usage (30,883 and
19,036 tokens). That pass is **discarded**. The baseline's sandbox root had been
widened to `/home/bench` to fix an earlier handicap, and the answer key
(`truth-task5.json`) sat in `/home/bench/results` — readable, and `bash` is not
constrained by the sandbox check at all.

The baseline's own account described an independent derivation, and it reported
1,122 nonzero-cost models and 40 zero-cost — neither figure appears in the
answer key, which holds only the six result fields. So the narrative evidence
pointed to a genuine solve.

The numbers disagreed. With the answer key physically removed from the
container, baseline usage roughly doubled (≈25k → ≈50k mean). The runs reported
above are the clean ones. **Narrative plausibility is not evidence; removing the
artifact and re-running is.**

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
  modest: ~1.6–1.9x tokens, ~1.2x dollars.
- **No performance advantage was demonstrated on any task.** It lost task 1 on
  both tokens and cost, tied task 2, and on task 3 — once the prompt ambiguity
  that produced the apparent edge was removed — both conditions scored 100%.
- **Including on a task built specifically to favour it.** A 536KB / 20,400-line
  aggregation over 1,162 records: both conditions 6/6, baseline ~1.85x cheaper
  in tokens.
- **The self-improvement feature did not run at all**, at defaults or when
  configured to be maximally eager, and enabling it produced no measurable
  benefit in a controlled contrast.
- **When forced to run, its output produced no detectable benefit either** —
  correctness saturated and the cost difference was inside run-to-run noise.
- **Global scope is unreachable from the CLI**, so every lesson it writes dies
  with the session.

The IPython-first design is a real engineering idea and it plausibly explains
the low turn counts. But on this evidence it is not a general multiplier, and
the feature the project is named around did not run.

## Limitations

- n=4 on task 3; n=1 on tasks 1 and 2.
- Task 1 saturated (4/4 both) and could not show a quality difference.
- The baseline carried five disclosed handicaps, all against it.
- Task-3 scoring encodes a contested reading of an ambiguous prompt.
- Tasks were authored for this evaluation, not drawn from a public benchmark.
- n=2 per condition on task 5. Given the run-to-run variance measured elsewhere
  here (sd ≈24% of mean), the ~1.85x token gap is larger than that noise but the
  sample is still small.
- Answer keys lived inside the container's readable filesystem for most runs.
  This was caught and corrected for task 5 (see the contamination note) but the
  earlier tasks were not re-run under that control. Their scoring is
  exact-match against a key the agent could in principle have read; no evidence
  of that was found, but it was not excluded by construction.
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
