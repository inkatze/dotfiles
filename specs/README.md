# Specs

This directory holds plan-only specifications for improvements to the dotfiles
repo. Each spec follows a four-file convention (requirements.md, design.md,
tasks.md, test-spec.md) borrowed from another project. A spec is plan-only
until its tasks.md is implemented. New sessions working on improvements start
from this README as the planning surface.

| Spec | Status | Purpose | Cold-start next step |
|---|---|---|---|
| `claude-context/` | Ready | Repo-root `CLAUDE.md` giving Claude Code the minimum non-obvious context to act correctly in this repo. | Implement the plan: write `CLAUDE.md` at the dotfiles repo root per `claude-context/requirements.md`. See `claude-context/tasks.md` for the ordered task list. |
| `metrics-baseline/` | Ready | Structured baseline snapshot of Claude Code usage metrics for measuring improvement deltas. | Produce the first encrypted snapshot per `metrics-baseline/tasks.md` §3. |
