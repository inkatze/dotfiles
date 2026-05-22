# Specs

This directory holds plan-only specifications for improvements to the dotfiles
repo. Each spec follows a four-file convention (requirements.md, design.md,
tasks.md, test-spec.md) borrowed from another project. A spec is plan-only
until its tasks.md is implemented. New sessions working on improvements start
from this README as the planning surface.

## Spec status lifecycle

Each spec declares its status in `requirements.md` as `**Status:** Draft|Active|Done`:

- `Draft` — being authored or revised. Mutable. Validator runs as warnings.
- `Active` — signed off (via `/spec-kickoff` when pair-flow ships) and under execution. Validator runs as errors that block dependent skills.
- `Done` — all tasks moved to `Completed`. Historical artifact; brief retained indefinitely.

## Task conventions

Tasks in `tasks.md` shall have a stable ID (e.g., `Task 3`, `Task 3.5`), explicit `Deliverables:`, `Done when:`, `Dependencies:`, `Citations:`, and `Estimated effort:`. Tasks that introduce measurable behavior shall also include a `Measurement plan:` line listing metric, source, and baseline comparison — same shape and discipline as `Citations:`.

| Spec | Status | Purpose | Cold-start next step |
|---|---|---|---|
| `claude-context/` | Done | Repo-root `CLAUDE.md` giving Claude Code the minimum non-obvious context to act correctly in this repo. | N/A |
| `metrics-baseline/` | Done | Structured baseline snapshot of Claude Code usage metrics for measuring improvement deltas. | N/A |
| `pair-flow/` | Draft | Spec-driven pipeline that pairs human and agent from comprehension through execution and orchestration. Defines `/spec-draft`, `/spec-kickoff`, `/execute-task`, `/orchestrate`, `/resume`, the new `Agent-resolvable` finding bucket, and the inbox + tmux dashboard substrate. | Read `pair-flow/requirements.md`, then `design.md`, then `tasks.md`. Implementation begins at Task 1 (panel-* underuse investigation) and Task 2 (file-path PreToolUse hook). |
