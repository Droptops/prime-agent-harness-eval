# Memo: Turn off auto-refine by default for the team (pilot first)

**To:** Engineering Director
**Re:** `autoRefine.enabled` default for our 20-engineer org
**Recommendation:** ship with `autoRefine.enabled: false` and pilot with 3 engineers. Today it defaults to `true` (`settings-manager.ts:839`).

## 1. The cadence is aggressive relative to what we get back

Auto-refine fires on two triggers - `"turn_interval"` and `"compact"` (`refinement.ts:110`). The interval default is **25 assistant turns** (`settings-manager.ts:842`, declared at `:25`), gated only by a 20-minute cooldown (`settings-manager.ts:846-848`), and compaction-triggered refine defaults on as well (`:844`). For an engineer in a long agent session that is a checkpoint every ~25 turns, all day, across 20 people.

## 2. The cost per checkpoint is two large frontier-model calls

Every checkpoint runs the review gate `reviewAutoRefine` (`refinement.ts:949-998`) on the **session's primary model**, not a cheap one (`agent-session.ts:7529, 7534-7544`). That call ships the last **40,000 characters** of serialized conversation (`refinement.ts:960`), a harness overview of up to 40 entries per kind at 240 chars each (`:527-541`), and 20 prior refinements (`:553`), with a 4,096-token output budget (`:194, :204`).

If the gate approves, `planRefinement` re-sends **80,000 characters** of conversation (`:892`) with a **32,000-token** output cap (`:193, :200`) - and the comment at `:187-192` says that budget is deliberately model-derived so large proposals are *not* truncated. An approved checkpoint is therefore ~120K characters of input plus up to ~36K output tokens across two calls. Multiply by 20 engineers.

## 3. The scope default means none of that spend compounds

Refinements are **local** by default: `scope: before?.scope ?? options.scope ?? "local"` (`:768`), `options.global ? "global" : "local"` (`:1015`, `:883`), reinforced by the policy prompts (`:141, :177, :895`). Local state lives under the session artifact dir (`:273-275`), and auto-refine only runs when that dir exists (`agent-session.ts:7172-7174`). Cross-session rollback history is written **only for global** refinements (`:372-379`). Net: we pay 20x for artifacts that die with the session and that you cannot audit fleet-wide. Failures are swallowed into a cooldown stamp (`agent-session.ts:7481-7487, 7511-7517`), so a persistently broken refiner stays silent.

## Fair credit, and my condition

The engineering is careful: atomic state writes (`:345-359`), corrupt-state degradation to empty (`:295-301`), a mid-plan conflict guard (`:727-740`), an immutable base prompt (`:671-673`), skill-contract validation (`:680-703`), and rollback (`:804-836`). I will flip this to "on" once a 3-person pilot reports tokens per approved refine and a measurable win - and once useful lessons can be promoted to the global store (`:374`) instead of dying locally.
