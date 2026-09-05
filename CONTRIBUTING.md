# Contributing

This repository is an evaluation artifact. Changes should make experiments more reproducible, not merely change the headline result.

## Principles

- Pin the prime-agent version/commit and model configuration for new runs.
- Keep treatment and baseline environments comparable; disclose asymmetries that remain.
- Preserve raw data needed to reproduce published tables.
- Distinguish mechanical scoring from human judgment and document ambiguous answer keys.
- Do not silently revise historical results after changing a scorer, prompt, task, or dependency.
- Never commit API keys, session URLs, private transcripts, or proprietary data.

## Before a pull request

For changes that touch runnable scripts, at minimum run syntax checks for the Python and shell files you changed. For experiment changes, include the exact command, environment assumptions, and output artifact needed to reproduce the result.
