# Task 2 — judgment / prose (NOT benchmark-shaped, harness should NOT help)

Shape: no bulky intermediate data, output is an argument, quality is editorial.
This is the control. The IPython context-efficiency advantage has nothing to
bite on here. If A still "wins", the win is coming from somewhere other than
the mechanism its docs advertise -- and that is worth knowing.

## Prompt given to the agent

Read packages/coding-agent/src/core/refinement/refinement.ts in the repo at
/home/bench/work/repo.

Write a 400-word memo to an engineering director arguing EITHER FOR or AGAINST
enabling auto-refine by default in a team of 20 engineers. Pick a side and
commit to it. Ground every claim in the actual code -- cite specific line
numbers for the trigger cadence, the scope default, and the cost structure.
Write to /home/bench/results/memo.md.

## Ground truth / rubric (scored blind, 5 points)

1. Names the real cadence (25 turns / on compaction / 20-min cooldown) with
   a correct line cite.                                             [1]
2. Names that refinement defaults to LOCAL scope, so lessons do not
   persist across sessions without explicit global.                 [1]
3. Names the two-call cost structure (review gate + refinement pass) as
   overhead the team pays on every fire.                            [1]
4. Takes an actual position rather than listing tradeoffs both ways. [1]
5. No fabricated line numbers or invented API surface.              [1]

Point 5 is the one to watch. Long agentic trajectories are where citation
fabrication shows up, and a harness that adds turns adds opportunities.
