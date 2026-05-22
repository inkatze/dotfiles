# Pair-Flow — Tasks

**Status:** Draft
**Repo-class:** solo
**Last reviewed:** 2026-05-22

Tasks are ordered by dependency, not by feature. Tasks may be bundled per D-11 when both fall within the bundling rule.

## Forward plan

### Task 1 — Investigate `/panel-*` underuse

- **Deliverables:** Written diagnosis under `specs/pair-flow/research/panel-underuse.md` identifying why `/copilot-*` is invoked 29x while `/panel-*` is invoked 14x in the 30-day window ending 2026-05-21.
- **Done when:** Diagnosis names a primary cause (reflex, latency, low yield, quota, other), cites transcript evidence, and recommends one of: keep panel as default, demote to escalation-only, retire entirely.
- **Dependencies:** none
- **Citations:** REQ-G1.1, friction & time analysis 2026-05-22
- **Estimated effort:** 30 min

### Task 2 — File-path PreToolUse hook

- **Deliverables:** `roles/osx/files/claude/scripts/path-guard.sh` (PreToolUse hook) plus wiring in `roles/osx/files/claude/settings.json`. Hook validates file paths before `Read`, `Edit`, `Write` and surfaces a clean error message when the path does not exist or is outside the repo root.
- **Done when:** Hook is installed via Ansible, manually verified by attempting a known-bad path and observing the clean error. File-path-mistake count in the next 30-day usage analysis drops materially from the 82/month baseline.
- **Dependencies:** none
- **Citations:** REQ-G2.1, friction & time analysis 2026-05-22 (top remaining mechanical friction)
- **Estimated effort:** 2 hrs

### Task 3 — Cross-session inbox substrate + tmux dashboard

- **Deliverables:**
  - `~/.claude/inbox/` directory (Ansible-managed) with sync-readiness documentation.
  - `roles/osx/files/claude/scripts/inbox-write.sh` helper for writing inbox JSON entries.
  - tmux popup binding (in tmux config) for dashboard.
  - tmux status bar segment rendering `awaiting-input` count.
- **Done when:** Two concurrent Claude sessions on different worktrees write inbox entries; the tmux popup shows both; the status segment shows the correct count; macOS notification fires when one transitions to `awaiting-input`.
- **Dependencies:** none
- **Citations:** REQ-F1.1, REQ-F1.2, REQ-F2.1, REQ-F2.2, REQ-F3.1
- **Estimated effort:** 1 day

### Task 4 — `tasks.md` state conventions and auto-update hooks

- **Deliverables:**
  - Updated convention documentation under `specs/README.md` describing the required sections (Completed, In progress, Awaiting input, Deferred, Out of scope) and `In progress` annotation format.
  - Hook fragment(s) in `settings.json` that update `tasks.md` on PR open and PR merge (via `gh pr` events or PostToolUse on PR creation tooling).
- **Done when:** Opening a PR in a worktree with a tracked spec auto-updates the matching task to `PR #N draft`. Merging that PR auto-moves the task to `Completed: [PR #N]`.
- **Dependencies:** Task 3 (uses inbox for status reporting)
- **Citations:** REQ-E1.1, REQ-E1.2, REQ-E3.1, D-1, D-9
- **Estimated effort:** 1 day

### Task 5 — `/resume` skill

- **Deliverables:** `roles/osx/files/claude/commands/resume.md` invocable as `/resume`. Reads kickoff brief (if any), spec bundle `tasks.md`, recent git log on the current branch, and any open PR state. Produces a concise context-load summary.
- **Done when:** Invoked in a fresh session inside a worktree with an in-flight task, `/resume` produces a summary that the human verifies is sufficient to continue work. Verified on at least one real tecpan worktree.
- **Dependencies:** Task 4
- **Citations:** REQ-E2.1, REQ-E2.2
- **Estimated effort:** half day

### Task 6 — `/spec-kickoff` skill

- **Deliverables:** `roles/osx/files/claude/commands/spec-kickoff.md`. Reads a spec at `<spec-path>`, walks section by section, restates in the agent's own words, surfaces domain term definitions, poses Socratic checks, reconstructs task graph, builds risk register, produces `specs/{feature}/kickoff-brief.md`. Supports retrofit mode that adds missing structure (per D-15) on existing specs.
- **Done when:** Invoked on `tecpan/specs/settings`, produces a kickoff brief that the user signs off without major correction. Invoked on `tecpan/specs/org` in retrofit mode, surfaces at least three implicit decisions or assumptions the user agrees were under-specified.
- **Dependencies:** none (Task 4 helpful but not blocking)
- **Citations:** REQ-A2.1 through REQ-A2.7, D-7
- **Estimated effort:** 2 days

### Task 7 — `/spec-draft` skill

- **Deliverables:** `roles/osx/files/claude/commands/spec-draft.md`. Elicits a spec interactively per REQ-A1.1 through REQ-A1.7. Produces the four files in `specs/{feature-name}/`.
- **Done when:** Draft a real upcoming spec (candidate: a small spec for one of the deferred items in this bundle, e.g., handover-brief auto-write). The output meets the validator's structural bar without manual cleanup.
- **Dependencies:** Task 6 (the kickoff brief format is the contract; draft must produce compatible structure)
- **Citations:** REQ-A1.1 through REQ-A1.7
- **Estimated effort:** 2 days

### Task 8 — `Agent-resolvable` bucket in `/polish` and `/panel-pairing`

- **Deliverables:** Updates to `roles/osx/files/claude/commands/polish.md` and `panel-pairing.md` (and the user-global CLAUDE.md's Finding Categorization section) introducing the `Agent-resolvable` bucket per REQ-C1.2. Updates the presentation contract (three tables → four tables).
- **Done when:** A test run of `/polish` on a real change demonstrates that a finding meeting the predicate is auto-applied in a solo repo, with the failing-then-passing test and CI evidence recorded in the bucket entry.
- **Dependencies:** Task 1 (conclusions affect panel changes), Task 6 (kickoff-aligned predicate requires kickoff briefs to exist for the test)
- **Citations:** REQ-C1.1 through REQ-C1.6, D-3, D-4
- **Estimated effort:** 1 day

### Task 9 — `/polish` opens draft PR on convergence (standalone mode)

- **Deliverables:** Update `polish.md` so that when invoked standalone, after convergence, it pushes the branch and opens a draft PR with a body referencing the changes. No change when nested inside `/execute-task`.
- **Done when:** Standalone `/polish` invocation on a feature branch produces a draft PR. Nested invocation does not.
- **Dependencies:** Task 8
- **Citations:** D-13
- **Estimated effort:** 2 hrs

### Task 10 — `/execute-task` skill

- **Deliverables:** `roles/osx/files/claude/commands/execute-task.md`. Implements REQ-B1.1 through REQ-B1.8: reads kickoff brief slice, writes verifying or regression test first, implements until green, runs project CI, runs `/polish` internally, opens draft PR.
- **Done when:** Invoked on a real tecpan task with a signed-off kickoff brief, produces a draft PR that passes CI and aligns with the kickoff brief contract. Demonstrated end-to-end on at least one task.
- **Dependencies:** Task 6 (needs kickoff briefs), Task 8 (uses Agent-resolvable bucket), Task 9 (uses internal polish)
- **Citations:** REQ-B1.1 through REQ-B1.8
- **Estimated effort:** 2 days

### Task 11 — `/orchestrate` v1

- **Deliverables:** `roles/osx/files/claude/commands/orchestrate.md`. Implements REQ-D1.1 through REQ-D8.1 except REQ-D6.1 v2 extensions: stateless step machine, reads `tasks.md`, picks ready task(s), bundles per D-11, dispatches via `/execute-task`, halts after PR open or `Awaiting input`. Uses advisory lockfile per D-17.
- **Done when:** Invoked twice on a spec with two ready independent tasks, the second invocation correctly identifies that the first task is in flight and either picks the second task or no-ops cleanly (depending on lock state). Both result in draft PRs.
- **Dependencies:** Task 10
- **Citations:** REQ-D1.1 through REQ-D8.1, D-5, D-11, D-15, D-17
- **Estimated effort:** 2 days

### Task 12 — Scheduled remote agent runner

- **Deliverables:** A routine configured via the `/schedule` skill that runs `/orchestrate` in bookkeeping mode (no implementation): reconcile PR statuses with `tasks.md`, advance pickups, post inbox entries. Documented in this repo.
- **Done when:** Routine runs on its schedule for at least one cycle, reconciles a real PR merge into `tasks.md` without human intervention.
- **Dependencies:** Task 11
- **Citations:** REQ-D2.1, D-14
- **Estimated effort:** 1 day

### Task 13 — End-to-end validation on a real tecpan spec

- **Deliverables:** A short retrospective at `specs/pair-flow/research/v1-retrospective.md` documenting an end-to-end run from `/spec-draft` (or `/spec-kickoff` retrofit on existing) through `/orchestrate` shipping at least one task as a draft PR. Catalog issues, surprises, calibration needed.
- **Done when:** At least one tecpan task is shipped via the full pipeline. The retrospective identifies concrete tunings for `Agent-resolvable` predicate, bundling rule, kickoff elicitation questions, or inbox transitions.
- **Dependencies:** Tasks 1–12
- **Citations:** D-3 open calibration, D-7 quality gate
- **Estimated effort:** 2 days

### Task 14 — Documentation update for project CLAUDE.md

- **Deliverables:** Update `roles/osx/files/CLAUDE.md` (project CLAUDE.md for dotfiles) with a section describing the autonomy pipeline at the same level of detail as the existing `/panel-*` and `/copilot-*` sections. Concise, decision-oriented per the existing repo's CLAUDE.md style.
- **Done when:** Section is present, fits within the file's size budget, and a cold-read by the user finds nothing missing.
- **Dependencies:** Task 13
- **Citations:** REQ-G6.1
- **Estimated effort:** half day

## Completed

(none yet)

## In progress

(none yet)

## Awaiting input

- **Repo-class assignment for paycalc and other work projects.** v1 explicitly defers; revisit before any rollout beyond tecpan and dotfiles.
- **Sync mechanism choice for inbox** (iCloud Drive vs Syncthing). User to decide based on existing tooling. Task 3 currently assumes "either works"; concrete pick affects only the documentation.

## Deferred

- **Handover brief auto-write conditions** (D-2). Build only if v1 surfaces specific gaps. **Gate:** end-to-end validation in Task 13 identifies at least one resumption case where `tasks.md` + git + PR alone is insufficient.
- **Headless `claude -p` resumption** (D-16). **Gate:** v1 stable for 30 days with positive telemetry; investigate reliability of headless mode on user's hosts.
- **`/orchestrate` v2 (auto-respond to peer review)**. **Gate:** v1 trusted; user explicitly opts in.
- **`/orchestrate` v3 (auto-merge)**. **Gate:** v2 trusted; multi-reviewer repo policy clarified.
- **Multi-spec concurrent orchestration.** **Gate:** single-spec orchestration validated and stable.
- **Phone push notifications.** **Gate:** user demonstrates a workflow where macOS + tmux dashboard is insufficient.
- **Migration of tecpan existing specs to kickoff briefs.** **Gate:** Task 6 lands and `/spec-kickoff` retrofit mode is verified.

## Out of scope

- Replacement or absorption of `/copilot-pairing` and `/copilot-review`. User-global CLAUDE.md already marks these transitional; that retirement is a separate spec.
- Migration of work-project (paycalc, paycalc-infra, qa-suites) workflows. Multi-reviewer support is designed for, but proving ground is tecpan/dotfiles.
- Replacement of the `/code-review` skill (someone-else's PR review).
- Cross-repo task graphs (one spec spanning multiple repos).
- Multi-user / team collaboration features.

## Open questions

Captured here so the next reviewer can see what is undecided. Each should be resolved before the affected task is implemented or explicitly accepted as remaining open.

1. **Spec-config location** (D-15): repo-class declared per spec in `requirements.md` frontmatter, or in a single `specs/spec-config.yml`? Current default in this bundle: `Repo-class:` line at the top of `tasks.md`. Subject to change.
2. **Hook trigger for PR merge** (Task 4): a webhook from GitHub, a poll by the scheduled runner (Task 12), or a manual `/sync-tasks` invocation? Lowest-friction is the scheduled runner; gating on Task 12.
3. **Validator reuse** (REQ-A1.6): use tecpan's existing spec validator, port it into dotfiles, or write a lighter one for the autonomy spec's own needs? Recommend port + extend.
4. **Bundle sizing in `/orchestrate`** (D-11): how does the agent estimate "likely under 700 lines" before any code is written? Heuristic: spec citations + similar past PRs from git log. May need calibration.
5. **Stale-lock detection** (D-17): what threshold? Initial guess: 1 hour. Will be calibrated in Task 13.
6. **`/spec-kickoff` re-signoff scope** (REQ-A2.6): if `tasks.md` changes (which happens often during execution), does that invalidate the whole brief or just the tasks section? Proposal: section-scoped invalidation. Confirm in Task 6.
7. **Inbox cleanup**: when does an inbox entry get deleted? On session exit clean? On a TTL? Proposal: on session exit clean, plus a sweep for entries older than 24h with no active session.
8. **Telemetry capture**: where does the 30-day post-implementation analysis live? In `specs/autonomy/research/` or in the existing `specs/metrics-baseline/`? Recommend the latter for consistency.
9. **Codex availability on personal/alt** (D-6): is codex actually working on those profiles, or will Task 1's investigation reveal that codex-only is a non-starter on non-work hosts?
10. **`/execute-task` behavior on tasks that fail CI repeatedly** (REQ-B1.6): retry budget? Backoff? Hand off to human after N failures? Needs a policy before Task 10.
