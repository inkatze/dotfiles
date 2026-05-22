# Pair-Flow — Tasks

**Status:** Draft
**Last reviewed:** 2026-05-23 (no design change today; Task 8 and Task 9 implementation moved to Completed)

`repo-class` and other repo-level config are supplied by `~/.claude/pair-flow.yml` + `~/.claude/pair-flow.local.yml` per D-19, not in this file.

Tasks are ordered by dependency, not by feature. Tasks may be bundled per D-11 when both fall within the bundling rule.

## Forward plan

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

### Task 7 — `/spec-draft` skill

- **Deliverables:** `roles/osx/files/claude/commands/spec-draft.md`. Elicits a spec interactively per REQ-A1.1 through REQ-A1.7. Produces the four files in `specs/{feature-name}/` with status `Draft` (REQ-A3.1). Runs validator (Task 3.6) before declaring stakeholder-ready.
- **Done when:** Draft a real upcoming spec (candidate: a small spec for one of the deferred items in this bundle, e.g., handover-brief auto-write). The output meets the validator's structural bar without manual cleanup; status `Draft`.
- **Dependencies:** Task 3.6 (validator), Task 6 (the kickoff brief format is the contract; draft must produce compatible structure)
- **Citations:** REQ-A1.1 through REQ-A1.7, REQ-A3.1, REQ-A3.2
- **Estimated effort:** 2 days

### Task 10 — `/execute-task` skill

- **Deliverables:** `roles/osx/files/claude/commands/execute-task.md`. Implements REQ-B1.1 through REQ-B1.9: reads kickoff brief slice, writes verifying or regression test first, implements until green, runs project CI (derived command via inspection per D-19), classifies CI failures (transient vs logic per D-25), runs `/polish` internally, opens draft PR (always draft per D-21).
- **Done when:** Invoked on a real tecpan task with a signed-off kickoff brief, produces a draft PR that passes CI and aligns with the kickoff brief contract. Demonstrated end-to-end on at least one task. Adaptive retry exercised on an induced transient failure.
- **Dependencies:** Task 3.5 (config helper), Task 6 (needs kickoff briefs), Task 8 (uses Agent-resolvable bucket), Task 9 (uses internal polish)
- **Citations:** REQ-B1.1 through REQ-B1.9, D-19, D-21, D-25
- **Estimated effort:** 2 days

### Task 11 — `/orchestrate` v1

- **Deliverables:** `roles/osx/files/claude/commands/orchestrate.md`. Implements REQ-D1.1 through REQ-D12.1 (orchestration scope only; bookkeeping moves are Task 12): stateless step machine, reads `tasks.md`, picks ready task(s), creates worktrees per D-44, bundles per D-11 with sizing per D-24 and branch naming per D-32, dispatches via `/execute-task`, halts after draft PR open or `Awaiting input`. Uses advisory lockfile per D-17 (per-spec, allowing cross-spec concurrency per D-37). Halts cleanly when spec is not `Active` (D-33) or has no kickoff brief (D-36). Flips spec status to `Done` when last task moves to Completed (D-31). All PRs are drafts (D-21).
- **Done when:** Invoked twice on a spec with two ready independent tasks, the second invocation correctly identifies that the first task is in flight and either picks the second task or no-ops cleanly (depending on lock state). Both result in draft PRs. Bundle sizing logged for telemetry tuning. Invoked on a `Draft`-status spec, halts with the kickoff prompt.
- **Dependencies:** Task 3.5 (config helper), Task 3.6 (validator), Task 10
- **Citations:** REQ-D1.1 through REQ-D12.1, REQ-A3.3, D-5, D-11, D-15, D-17, D-19, D-21, D-24, D-31, D-32, D-33, D-36, D-37, D-44
- **Estimated effort:** 2 days

### Task 12 — Scheduled remote agent runner

- **Deliverables:** A routine configured via the `/schedule` skill that runs `/orchestrate` in bookkeeping mode (no implementation): poll GitHub PR state on its cadence (hourly default per D-29), reconcile merges into `tasks.md` Completed, advance pickups, post inbox entries. Documented in this repo.
- **Done when:** Routine runs on its schedule for at least one cycle, reconciles a real PR merge into `tasks.md` without human intervention.
- **Dependencies:** Task 11
- **Citations:** REQ-D2.1, D-14, D-29
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

- **Task 9 — `/polish` opens draft PR on convergence (standalone mode).** Updated `roles/osx/files/claude/commands/polish.md`. New "Invocation mode" section at the top: the `--nested` literal in `$ARGUMENTS` switches Polish into nested mode (parent skill owns PR creation, no push, no PR); absence is standalone mode (default). The "After the loop" section now branches on exit reason × mode: normal exit (success or Human attention required) in standalone runs the new "Standalone-mode PR creation" section; normal exit in nested hands back to the parent with the final tables; safety stops suppress PR creation in both modes since the branch is in a known-broken state. The new "Standalone-mode PR creation" section mirrors `/self-review`'s shape: push, check for an existing PR via `gh pr view` and reuse it if present (never duplicate), otherwise check templates (`.github/pull_request_template.md` etc.) then convention (recent merged PRs), then `gh pr create --draft` with a heredoc body that includes a one-paragraph summary, a Polish-notes section listing per-iteration Auto-applicable and Agent-resolvable items applied (with test paths and kickoff-brief citations for the Agent-resolvable rows), and any unresolved Needs sign-off / Needs human judgment items the human needs to address before marking ready for review; falls back to `gh pr create --draft --fill` + `gh pr edit --body` when no template or convention exists. Auto-execution invariants split into in-loop (no push, no PR ever) and post-loop (standalone may push and create a draft PR; nested may not); force-push, amend, squash, and rebase remain forbidden at all times including the post-loop step. Iteration summary now logs the resolved invocation mode. Validator passes (0 errors, 0 warnings) on `specs/pair-flow/` after the change. **Verification deferred to user:** the Done-when requires a real standalone `/polish` invocation on a feature branch producing a draft PR, and a nested invocation not producing one; the nested-mode side waits on Task 10 (`/execute-task`) since that is the only skill that will pass `--nested`.
- **Task 8 — `Agent-resolvable` bucket in `/polish` and `/panel-pairing`.** New bucket added to user-global `roles/osx/files/CLAUDE.md` Finding Categorization, between Auto-applicable and Needs sign-off; predicate is REQ-C1.2's five conditions (failing regression test, test passes after the fix, full project CI passes, kickoff alignment, no hard disqualifier). Presentation contract updated from three tables to four tables (Auto-applicable, Agent-resolvable, Needs sign-off, Needs human judgment) and the audit-row evidence shape pinned (test path, before/after output, CI command + result, kickoff section cited). Batched-decision and Clustered-decision rules in `Code & PR Reviews` extended: Agent-resolvable in solo repos is auto-applied and does not surface as a decision; in multi-reviewer repos it uses the same `Apply / Skip / Modify` shape as Needs sign-off with the evidence in the row. Validation Rigor (Issue Identification) scoping note now folds Agent-resolvable into `/polish`'s hard-gate set (full three-pass for both action buckets; soft-floor spot-check for the two Needs-human buckets). Review Workflows entries for `/polish` and `/panel-pairing` updated. `/polish` (`roles/osx/files/claude/commands/polish.md`) and `/panel-pairing` (`roles/osx/files/claude/commands/panel-pairing.md`) gain a pre-flight step that resolves `repo-class` via `~/.claude/scripts/pair-flow-config.sh repo-class` (with `needs-confirmation:<value>` surfacing to the human before any `confirm-repo-class` write, per REQ-D9.1 / D-20) and locates the active kickoff brief (D-32 branch name first, then `specs/*/requirements.md` `Status: Active` fallback); on `solo` with brief, items in the bucket auto-apply through step (d-AR) (write failing test → confirm failure mode matches finding → fix → test passes → wider CI → verify kickoff alignment → record evidence); on `multi-reviewer` or no active brief, items route to surface-with-evidence (Needs sign-off path) and the loop counts them toward "Needs sign-off" for fate. Step (c) loop-fate becomes 4-bucket; iteration summary now logs `repo-class`, brief path, all four bucket counts, drops attributable to step (d.1) (Auto-applicable rule no longer fires) or step (d-AR.2/d-AR.4) (Agent-resolvable test did not fail/pass as required), and the per-item Agent-resolvable evidence. Auto-execution invariants extended with two new "never" rules covering the five-condition predicate and the bucket-availability gate. Per REQ-C1.5's contract surface, `/peer-review` (`roles/osx/files/claude/commands/peer-review.md`) updated to four tables with an Agent-resolvable thread table and per-bucket option semantics; `/code-review` (`roles/osx/files/claude/commands/code-review.md`) updated to reference the four-bucket categorization (it does not use the categorization itself; the reference is descriptive). `/copilot-pairing` left untouched; it inherits by reference from CLAUDE.md since the skill file has no contract surface tied to bucket count. Validator passes (0 errors, 0 warnings) on `specs/pair-flow/` after the change. **Verification deferred to user:** the Done-when requires a real `/polish` run on a solo repo demonstrating one finding auto-apply with the failing-then-passing test + CI evidence recorded; that needs an active kickoff brief on a real branch, which requires the bootstrap-test (REQ-A2.7) to flip `specs/pair-flow/` Status: Draft → Active first.
- **Task 3 — Cross-session inbox substrate + tmux dashboard.** Six scripts under `roles/osx/files/claude/scripts/` (materialized via the existing directory symlink in `roles/osx/tasks/osx.yml`): `inbox-write.sh` (subcommands `hook-event`, `tick`, `drop`, `summary`; captures host, session, worktree, repo, branch, state, first-seen, last-heartbeat, pid, tmux-target; fires the existing `notify-event.sh` chain on transitions into `awaiting-input` / `draft-pr-ready` per REQ-F3.1), `inbox-heartbeat.sh` (30s tick, exits when claude PID dead or entry removed, no cleanup hook needed), `inbox-sweep.sh` (D-23: 2-min heartbeat threshold, 24h legacy fallback, plus a same-host PID-liveness backstop for kill -9 leaks), `inbox-session-start.sh` (SessionStart wrapper: init entry then nohup-spawn the heartbeat detached, walks the process ancestry up to 6 levels looking for `claude`/`claude-code` so the heartbeat self-terminates on parent death), `inbox-status.sh` (triplet `⚠N ●N ◆N`, always visible, sleeps to match `status-interval` so dracula does not tight-loop), `inbox-dashboard.sh` (compact-table popup, ANSI 256-colour palette per D-22, per-worktree aggregation per D-34, sort weights `red→orange→blue→yellow→green→grey`, worktree+branch truncation so long names do not break alignment, remote-host rows tagged `[remote: hostname]`, blocks on a single keypress so the popup stays open). Hooks wired in `roles/osx/files/claude/settings.json`: SessionStart chains `inbox-session-start.sh`, Stop chains `inbox-write.sh hook-event idle`, Notification (both `permission_prompt` and `idle_prompt` matchers) chains `inbox-write.sh hook-event awaiting-input` next to the existing `notify-event.sh`. tmux.conf adds `bind i display-popup -E -w 80% -h 70% "$HOME/.claude/scripts/inbox-dashboard.sh"` (prefix `M-a` + `i`) and a second dracula `custom:` plugin (`custom:../../../scripts/inbox-status.sh`) with a `light_purple dark_gray` colour pair appended to `@dracula-custom-plugin-colors`; the tmux-side `roles/tmux/files/scripts/inbox-status.sh` is a one-line `exec` wrapper that preserves the existing `custom:../../../scripts/...` convention. Ansible adds an `Ensure Claude inbox directory exists` task at mode `0700`; sync mechanism (iCloud vs Syncthing) left to the user (still Awaiting input) because each entry is single-writer, atomic-rename, sub-1KB JSON so either works. Smoke-tested end-to-end: hook-event init + tick + transition + sweep all behave; dashboard renders 6 mixed states with correct colours, sort, and column truncation; status segment computes correct counts; heartbeat self-exits within 30s when its inbox file is removed (no orphan processes). v1 ships without row-jump per user pick on PR #28; the spec already captures `host` and `tmux-target` so the follow-up is additive. **Verification deferred to user:** the spec's `Done when` requires two concurrent live Claude sessions on different worktrees, a kill -9 to observe the 2-min sweep, and a real macOS notification firing on transition; all three need a fresh-session run with the new hooks loaded.
- **Task 6 — `/spec-kickoff` skill.** Skill at `roles/osx/files/claude/commands/spec-kickoff.md`. Walks the seven sections (Goal+glossary, Requirements, Design, Verification, Task graph, Risk register, Sign-off) using a per-section pattern (read → restate → surface implicit terms → Socratic checks → D-42 inconsistency gate → wait for sign-off → incremental append to `kickoff-brief.md`). Calls `~/.claude/scripts/spec-validate.sh` before walking and again after the status flip (D-45); calls `~/.claude/scripts/pair-flow-config.sh repo-class` with `needs-confirmation` semantics that never silently write (REQ-D9.1, D-20). Retrofit mode produces patches to `tasks.md` at the Task-graph step (each patch waits for user red-line). Partial-invalidation walk applies D-27 section scope plus D-51 wholesale-rewrite triggers; signed-off sections are preserved. Sign-off flips all four spec files `Status: Draft` → `Active` via `Edit` and bumps `Last reviewed:` (REQ-A2.9, D-40); validator failure post-flip reverts the four edits and halts. Stages files for the human to commit but does not commit or push (REQ-A2.11, D-49). The interactive bootstrap-test on `specs/pair-flow/` itself per REQ-A2.7 is the user's next move and the D-7 quality gate (the agent cannot honestly self-walk a Socratic walkthrough). Pre-flight stages traced cleanly: validator returns 0 errors/0 warnings, repo-class returns `solo`, no prior brief exists.
- **Task 1 — Investigate `/panel-*` underuse.** Diagnosis at `specs/pair-flow/research/panel-underuse.md`. Primary cause: `/panel-*` is newly available (shipped 2026-05-15, mid-window), not underused. Recommendation: keep panel as default; confirm D-6 (codex-only default, no longer provisional) and D-12 (`/panel-pairing` demoted to escalation, `/polish` as default convergence). LAN-Ollama auto-mode classifier denial recorded as follow-up.
- **Task 3.6 — Spec validator port and extension.** Validator at `roles/osx/files/claude/scripts/spec-validate.sh`. Materializes to `~/.claude/scripts/spec-validate.sh` via the existing directory symlink in `roles/osx/tasks/osx.yml` (lines 55-60); no per-file symlink needed. Runs cleanly on `tecpan/specs/settings` (0 errors, 0 warnings), emits 27 warnings on `tecpan/specs/org` (prose REQs + every task missing Done when/Dependencies/Citations), emits 0 errors and 0 warnings on this `specs/pair-flow` bundle. Status-aware Gherkin from REQ-G7.1 verified via synthetic fixture: same gap warns on Draft (exit 0), errors on Active (exit 1).
- **Task 3.5 — Pair-flow configuration helper.** Defaults at `roles/osx/files/claude/pair-flow.yml` (`panel-backends: [codex]`, `stale-lock-threshold: 1h`, `inbox-heartbeat-interval: 30s`). New symlink task in `roles/osx/tasks/osx.yml` materializes the file to `~/.claude/pair-flow.yml`. Helper at `roles/osx/files/claude/scripts/pair-flow-config.sh` with subcommands `repo`, `defaults`, `repo-class`, `confirm-repo-class <value>`, `show`. PR-history-based inference filters bots (`*[bot]`, `copilot-*`, `dependabot*`, `renovate*`, `github-actions*`) and PR-author self-reviews. Verified end-to-end on this repo: first `repo-class` call outputs `needs-confirmation:solo` (exit 2); `confirm-repo-class solo` writes `~/.claude/pair-flow.local.yml`; subsequent `repo-class` outputs `solo` (exit 0); deleting the file re-prompts.
- **Task 2 — File-path PreToolUse hook.** Hook at `roles/osx/files/claude/scripts/path-guard.sh`. Wired from `roles/osx/files/claude/settings.json` under `hooks.PreToolUse` with matcher `Read|Edit|Write`. Blocks Read/Edit when the path does not exist or is a directory (suggests an alternative); blocks Write when the parent directory does not exist; allows everything else. Smoke-tested via direct stdin invocation: seven cases (existing file → allow, nonexistent → deny, directory → deny, edit-nonexistent → deny, write-existing-parent → allow, write-missing-parent → deny, unrelated tool → allow) all pass. Real end-to-end verification needs a fresh Claude Code session because hooks load at session start; settings.json merged into the materialized `~/.claude/settings.json` for the next session. Measurement against the 82/month baseline tracked in the open `Measurement plan` for the next 30-day window per Task 2's plan.

## In progress

(none yet)

## Awaiting input

- **Sync mechanism choice for inbox** (iCloud Drive vs Syncthing). User to decide based on existing tooling. Task 3 currently assumes "either works"; concrete pick affects only the documentation.

## Deferred

- **Handover brief auto-write conditions** (D-2). Build only if v1 surfaces specific gaps. **Gate:** end-to-end validation in Task 13 identifies at least one resumption case where `tasks.md` + git + PR alone is insufficient.
- **Headless `claude -p` resumption** (D-16). **Gate:** v1 stable for 30 days with positive telemetry; investigate reliability of headless mode on user's hosts.
- **`/orchestrate` v2 (auto-respond to peer review)**. **Gate:** v1 trusted; user explicitly opts in. (Note: auto-merge remains out of scope at every tier per D-21.)
- **Multi-spec concurrent orchestration.** **Gate:** single-spec orchestration validated and stable.
- **Phone push notifications.** **Gate:** user demonstrates a workflow where macOS + tmux dashboard is insufficient.
- **Migration of tecpan existing specs to kickoff briefs.** **Gate:** Task 6 lands and `/spec-kickoff` retrofit mode is verified.
- **Bundle-sizing fallback to author-hint S/M/L mode** (D-24). **Gate:** Task 13 retrospective shows the Citations-plus-git-history heuristic is consistently off by >2x.

## Out of scope

- **Auto-merge at any tier** (D-21). Pair-flow never merges PRs. Merge is a reserved human action. This is permanent, not deferred.
- **Ansible managing `~/.claude/pair-flow.local.yml`.** File is per-host and agent-maintained; Ansible touching it would risk losing local overrides on playbook runs.
- Replacement or absorption of `/copilot-pairing` and `/copilot-review`. User-global CLAUDE.md already marks these transitional; that retirement is a separate spec.
- Migration of work-project (paycalc, paycalc-infra, qa-suites) workflows. Multi-reviewer support is designed for, but proving ground is tecpan/dotfiles.
- Replacement of the `/code-review` skill (someone-else's PR review).
- Cross-repo task graphs (one spec spanning multiple repos).
- Multi-user / team collaboration features.

## Open questions

All original open questions resolved as of 2026-05-22. Recorded here for traceability; full reasoning in `design.md`:

- *Spec-config location.* Resolved by D-19: two-file split (`~/.claude/pair-flow.yml` defaults + `~/.claude/pair-flow.local.yml` agent-maintained).
- *PR-merge detection trigger.* Resolved by D-29: scheduled runner polls, no webhook.
- *Validator reuse.* Resolved by D-28: port tecpan's validator into dotfiles, both repos symlink.
- *Bundle sizing heuristic.* Resolved by D-24: Citations + git history; provisional, falls back to author-hint S/M/L if Task 13 shows >2x error.
- *Stale-lock threshold.* Resolved by D-17: 1 hour default; configurable in `~/.claude/pair-flow.yml`.
- *Brief invalidation scope.* Resolved by D-27: section-scoped, not whole-brief.
- *Inbox cleanup.* Resolved by D-23: 30s heartbeat, 2-minute stale sweep, 24h legacy fallback.
- *Telemetry layout.* Resolved by D-30: `snapshots/` + `deltas/` + `data/` under existing `specs/metrics-baseline/`, age-encrypted.
- *CI retry policy.* Resolved by D-25: adaptive (transient retry up to 2x, logic escalate immediately).
- *File-path hook scope.* Resolved by D-26: Read/Edit/Write only.
- *Codex availability on personal/alt.* Resolved 2026-05-22: codex is available on both work (business account) and personal (personal account) profiles. D-6 (codex-only default) stands.
