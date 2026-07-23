# Specs

This directory holds plan-only specifications for improvements to the dotfiles
repo. Each spec follows a four-file convention (requirements.md, design.md,
tasks.md, test-spec.md) borrowed from another project. A spec is plan-only
until its tasks.md is implemented. New sessions working on improvements start
from this README as the planning surface.

## Spec status lifecycle

Each spec declares its status in `requirements.md` as `**Status:** Draft|Active|Done`:

- `Draft` — being authored or revised. Mutable. Validator runs task-structure checks as warnings.
- `Active` — signed off (via `/spec-kickoff` when pair-flow ships) and under execution. Validator runs task-structure checks as errors that block dependent skills.
- `Done` — all tasks moved to `Completed`. Historical artifact; brief retained indefinitely.

Status controls the severity of the task-structure checks only. The four-file presence check (`requirements.md`, `design.md`, `tasks.md`, `test-spec.md`) always errors and exits 1 regardless of status, since it runs before status is even detected.

## Task conventions

Tasks in `tasks.md` shall have a stable ID (e.g., `Task 3`, `Task 3.5`), explicit `Deliverables:`, `Done when:`, `Dependencies:`, `Citations:`, and `Estimated effort:`. Tasks that introduce measurable behavior shall also include a `Measurement plan:` line listing metric, source, and baseline comparison — same shape and discipline as `Citations:`.

## `tasks.md` state sections

`tasks.md` is the canonical state record for orchestration (REQ-E1.1 in `pair-flow/`). It shall use H2 section headers naming the queue and the five state sections below; the ordering is presentation choice, not contract. Additional sections (e.g., `Open questions`) are allowed:

| Section | Purpose | Convention |
|---|---|---|
| `Forward plan` | Dependency-ordered queue of tasks not yet picked up. | Full task block (`### Task <id> — <title>` with `Deliverables:`, `Done when:`, `Dependencies:`, `Citations:`, `Estimated effort:`, optional `Measurement plan:`). |
| `In progress` | Tasks currently being implemented (one branch + draft PR per task or bundle). | Same block form as Forward plan, plus two annotation lines right after the H3: `- **Status:** <phase>` and `- **Last activity:** <YYYY-MM-DD>`. The phase value tracks the current step: `implementing`, `polish iter N`, or `PR #M draft`. The auto-update hook below writes the `PR #M draft` phase; `/execute-task` (when shipped) writes the earlier phases. |
| `Completed` | Tasks that have shipped. | One-line bullet per task: `- **Task <id> — <title>.** <one-sentence summary>. Completed in PR #<N> (<URL or PR ref>). See PR description for details.` The auto-merge hook writes a stub; the human is free to flesh out the summary with what was actually built (e.g., paths, validation notes, "verification deferred to user"). |
| `Awaiting input` | Tasks blocked on a human decision. | Bullet per task, with the question stated. |
| `Deferred` | Tasks consciously postponed with an explicit gate. | Bullet per task, including `**Gate:**` (the condition that re-opens the task). |
| `Out of scope` | Tasks excluded by design. | Bullet per task. Permanent, not deferred. |

### `tasks.md` format versions

`tasks.md` declares a `**Format-version:**`. Version 1 bundles store execution state in the block itself: section placement (`Forward plan` / `In progress` / `Completed`) plus the `- **Status:**` and `- **Last activity:**` annotation lines described above. Version 2 bundles (e.g. `linux-migration/`) treat execution state as **derived, not stored**: task blocks stay under a single `## Tasks` heading, carry no Status or placement annotations, and Ready↔Active plus per-task progress are computed from git (task branches, the `Planwright-Task:` commit trailer) and open PRs by planwright's derivation engine. Do not hand-write a Status line or move blocks between state sections in a v2 bundle; the v1 `In progress` / `Completed` sections and the auto-update hook's block-move below apply to v1 bundles only.

## `tasks.md` auto-update hook

The PostToolUse `tasks.md` sync hook is supplied by the planwright plugin, not this repo. planwright installs as a Claude Code plugin (marketplace flow; see the install task in `roles/osx/tasks/osx.yml`), and the plugin wires this hook itself via its `hooks/hooks.json` resolved against `CLAUDE_PLUGIN_ROOT` (matcher `Bash` under `hooks.PostToolUse`); the tracked `settings.json` no longer wires it. It fires after every Bash tool call, filters to `gh pr create` / `gh pr merge`, and parses the current branch against planwright's convention (`planwright/<spec>/...`; the reserved `planwright/<spec>/spec` namespace no-ops).

- **On `gh pr create`**: the matching task block moves to `In progress`, annotated with the PR number.
- **On `gh pr merge`**: the block moves to `Completed`, annotated with the PR number and merge date.

Worker sessions resolve and write the canonical `tasks.md` in the primary checkout under the per-spec advisory lock. The hook is silent on no-op cases (non-Bash tool, non-`gh pr` command, branch not in planwright format, no matching task block, validation failure) and never commits; it leaves a `git status` diff for the next commit boundary. The exact transition format and branch grammar are owned by the planwright repo.

| Spec | Status | Purpose | Cold-start next step |
|---|---|---|---|
| `claude-context/` | Done | Repo-root `CLAUDE.md` giving Claude Code the minimum non-obvious context to act correctly in this repo. | N/A |
| `metrics-baseline/` | Done | Structured baseline snapshot of Claude Code usage metrics for measuring improvement deltas. | N/A |
| `pair-flow/` | Active | Origin spec and history for the spec-driven pipeline that pairs human and agent from comprehension through execution and orchestration. The pipeline skills it defined (`/spec-draft`, `/spec-kickoff`, `/execute-task`, `/orchestrate`, `/resume`) now ship as the **planwright plugin** (see `roles/osx/tasks/osx.yml`). The cross-session inbox/tmux dashboard substrate (Task 3) and the `repo-class`/Agent-resolvable bucket (Task 8) were both retired; see `tasks.md`. | Read `pair-flow/kickoff-brief.md` for the signed-off contract, then `tasks.md` for current state (Completed / In progress / Forward plan). `requirements.md` and `design.md` are the underlying spec. |
| `media-server-cleanup/` | Ready | Full teardown of the Stremio/zurg/autoheal/Plex media stack from the repo and the personal machine, with git history as the sole reference for a future re-add spec. | Read `media-server-cleanup/kickoff-brief.md` (the contract), then `tasks.md`; dispatch via `/orchestrate specs/media-server-cleanup` once the spec PR merges. |
| `linux-migration/` | Ready | Migrate the personal MacBook Pro (T2) from macOS to Linux (t2linux Ubuntu, whole-disk LUKS, eGPU) and bring it under Ansible via a new `linux` platform baseline, ending server-ready but service-free. Format-version 2 bundle. | Read `linux-migration/kickoff-brief.md` (the contract), then `tasks.md`; dispatch via `/orchestrate specs/linux-migration`. |
