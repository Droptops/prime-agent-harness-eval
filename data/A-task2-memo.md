# Memo: Enable auto-refine by default for the 20-engineer team

**Recommendation: enable it.** Source: `packages/coding-agent/src/core/refinement/refinement.ts`.

## Cadence is gated, not continuous

Auto-refine fires on two triggers only: `AutoRefineReason = "turn_interval" | "compact"` (line 110), carrying `turnsSinceLastReview` (line 114). The checkpoint does not refine; it calls `reviewAutoRefine` (lines 949-998), a cheap classifier whose system prompt explicitly instructs it to "Reject one-off noise, unsupported hypotheses, and transient tool outputs" (line 178) and returns a boolean `shouldRefine` (line 943). The expensive `planRefinement` pass (lines 863-934) runs only after that gate approves. Defaults that drive the cadence live in `settings-manager.ts` lines 835-849: 25 assistant turns, a 20-minute cooldown, compact-triggered review on. For a working engineer that is a handful of checkpoints per day, not per prompt.

## Scope default confines blast radius

The default write target is the session, not the org. `applyRefinementProposal` sets `scope: before?.scope ?? options.scope ?? "local"` (line 768), and `refineHarness` passes `options.global ? "global" : "local"` (line 1015). Local state is written under the session artifact dir (line 273-274); only global state touches the shared agent dir (lines 269-271). The planner prompt makes global entries read-only during a local refinement (line 895). So a bad inference by one engineer's agent cannot silently propagate to the other 19 unless someone explicitly asks for global scope.

## Cost is bounded and mostly the cheap half

Two hard output caps: the review pass is `Math.min(model.maxTokens, 4_096)` (lines 194, 203-205, 985); the full refinement is `Math.min(model.maxTokens, 32_000)` (lines 193, 199-201, 919). Input is capped too: the review sees a 40k-character trajectory slice (line 960), refinement an 80k-character slice (line 892), plus an overview truncated to 40 entries per kind at 240 characters (lines 527-543) and the last 20 history items (line 553). Both calls are forced non-reasoning (lines 912, 978), so no hidden thinking-token bill. Worst case per approved checkpoint is roughly 20k input / 32k output tokens; rejected checkpoints cost about an eighth of that.

## Failure modes are already handled

Corrupt state degrades to empty rather than throwing (lines 286-301). Saves are atomic via temp-file rename (lines 345-359). Concurrent edits are rejected with "entry changed during refinement planning" (lines 727-740). The base system prompt is unwritable (lines 671-673), and `rollbackProposal` (lines 804-836) reverts any bad refinement.

Enable globally; keep `global` scope behind explicit opt-in.
