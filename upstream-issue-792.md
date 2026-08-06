## Summary

Under `-p` (single-shot), the process exits at end of turn. Anything the harness
defers past the turn boundary is lost. Two consequences, one intermittent and
one consistent:

1. **`rlm()` subagents are silently discarded when the parent ends its turn
   after spawning** — which is exactly what `docs/rlm.md` instructs. The
   children are killed mid-execution, nothing is collected, no output file is
   written, and the run exits **0** with empty stderr and no error event in the
   `--mode json` stream. Observed in **2 of 3** runs of the same prompt.
2. **Auto-refine never fires under `-p`**, at any `turnInterval`. Consistent
   across every run tested.

Version 0.7.0, `node:22-bookworm-slim`, non-root, `--provider anthropic
--model claude-opus-5`.

## The subagent case

Same prompt each time (analyse four independent packages, one child per package
via `await rlm(...)`, assemble and write JSON). What differs is only whether the
parent ends its turn after spawning:

| Run | Parent turns | Events per child | `agent_message` | Output |
|---|---|---|---|---|
| A | 2 | 7 | few | none, exit 0 |
| B | 2 | 7 | few | none, exit 0 |
| C | 9 | 19–20 | 198 | written, correct |

In A and B the parent spawned four children and ended the turn, with a final
message of:

> Four children spawned. Ending turn to let them work.

That follows the documented contract — the call "returns immediately after task
admission… it never waits for or returns the child's answer", and "spawn
independent children in separate calls and end the turn instead of awaiting
completion". In a session that outlives the turn this is correct. Under `-p` the
process exits and the children die at ~7 events.

In C the model instead stayed in-turn and polled for results, and everything
worked. So the outcome depends on a model choice, not on the request — **the
documented pattern is the one that loses the work.**

Children are genuinely created in all cases, on disk under
`session-artifacts/<id>/sub-*/` at `rlmDepth: 1`.

For contrast, the same prompt in an interactive session scores 16/16 (children
reach 13 events, parent receives `agent_message` replies), and in a daemon
session with no client attached scores 15/16.

## The auto-refine case

With `{"autoRefine":{"enabled":true,"turnInterval":1,"cooldownMs":0}}` and a run
completing 4 assistant turns, `-p` produces no `harness/` directory in the
session artifacts. An interactive session with the identical settings file,
prompt and model produces one. `-p` sessions re-inspected hours later still show
`kernel-state.*` and no `harness/`, so this is not a timing artifact of when the
check ran.

## Why it matters

`-p` is the natural mode for scripts, cron and CI. In that setting an agent can
be told to delegate, do so exactly as documented, and exit 0 having written
nothing — no warning, no error, no non-zero status to branch on. The
intermittency makes it worse rather than better: the same pipeline can succeed
repeatedly and then silently produce nothing.

## Suggested direction

Not a patch, just where a fix might sit: before exiting under `-p`, either await
outstanding child admissions and the auto-refine pass, or exit non-zero with a
message when a turn ends with unresolved children. Alternatively, scope the
"end the turn" guidance in `docs/rlm.md` to session-backed modes. Silently
discarding the work is the part that costs users.

Happy to supply raw session transcripts, the child session dumps, or the
controlled interactive/daemon comparisons.
