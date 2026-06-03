# Pair-Flow v1 — Retrospective

**Status:** Active
**Last reviewed:** 2026-06-03
**Spec:** `specs/pair-flow/`
**Task:** 13 (end-to-end validation)

## What this retrospective covers

Real e2e use of pair-flow across three repos between 2026-05-22 and 2026-06-03:

1. **dotfiles** (this repo) — the spec authoring + skill development environment. 13 tasks completed through PR #28.
2. **paycalc-services** (work project, multi-reviewer) — STEAI-748 STL API explain pipeline. 42 tasks completed via `/spec-draft` + `/spec-kickoff` + `/execute-task` direct invocation. Big-umbrella work; `/orchestrate` not used.
3. **tecpan** (personal project, solo) — 4 specs kicked off (`lfpdppp-consents`, `settings`, `subscriptions`, `timbrado`), all signed off and ready for `/orchestrate`. Execution not yet started.

Section 1 captures what worked. Section 2 captures what needed iteration during the run. Section 3 lists concrete tunings per Task 13's Done-when. Section 4 separates personal-preference from generalizable for the standalone-extraction gate. Section 5 names what v1 did not validate.

## 1. What worked

### Spec authoring carried multi-day context

The STEAI-748 spec is the strongest signal. A 943-line `requirements.md` with explicit in-scope / out-of-scope boundaries (Knowledge Base build-out out of scope but the probe in scope; SLM training out of scope but evaluating Brandon's completed checkpoint in scope; chat-side multi-turn out of scope; substring grader replacement out of scope; etc.) survived 7 days of execution without scope creep. The precision came from `/spec-draft`'s Phase 1 scope elicitation. Without it, "scope was full of holes" (the user's own words about the pre-pair-flow attempt) would have repeated.

### Kickoff brief was the durable contract, not the spec

767-line kickoff briefs are not summaries; they are the working contract. Multiple decisions in STEAI-748 traced back to the brief, not the spec:

- Task 25's "no `fe-state.lua` change owed" conclusion came from re-reading the brief's credit-narration framing.
- The 2026-05-28 "authorable-now queue" reframing (Tasks 47-50 are local-runnable now because local work was never blocked, only merge/rollout was gated) came from re-reading the brief's distinction between merge-path gating and local-authoring constraints.

Downstream skills consulted the brief, not the four-file bundle. This validates D-2 (kickoff brief as contract, handover brief as optional cache).

### Observations convention surfaced real production bugs

Task 13 added an observation convention to `/execute-task` and `/polish` (append one-liners to `specs/_observations/opportunities.md`). STEAI-748's observations file has 8 entries; 3 are resolved production bugs that would have shipped without the discipline:

1. **Model ID mapping in `narrative_verifier.call_narrative_verifier`** — passing the friendly model name (`claude-v4.5-haiku`) instead of the cross-region inference profile (`us.anthropic.claude-haiku-4-5-...`) caused live Bedrock rejection. Invisible to unit tests (they stub `call_converse_api`); surfaced live during the Task 47 inference-params probe. Resolved with two unit tests pinning the resolved id (commit `b30eb622`).

2. **FICA narrator id-2 cumulative YTD regression on the May golden pin** — the deterministic narrator template omitted two cumulative YTD figures (`$4,576.22` and `$71,810.00`) that the LLM-only path emitted as part of its YTD walk. Surfaced on re-pin re-validation. Resolved same-session: `FicaAutoAdjust` gained `wages_ytd_before_period`, narrator template updated, two golden cases flipped FAIL→PASS, unit test `test_auto_adjust_standard_renders_cumulative_ytd_figures` locked the figures.

3. **Multistate narrator `$0.00`-base / non-zero-tax contradiction** — rendering internally-contradictory prose on real prod NJ/NY interstate payloads ("New Jersey starts by computing what the tax would be if all $0.00 in combined wages were taxed there... produced $373.96"). Same regression class as GDS test-40 but firing on prod traffic, not just the one golden case. Narrator-side resolved with new `all_wages_tax_requires_nonzero_base` invariant; the engine-side `0.00`/non-zero defect remains open as a follow-up.

The observation chain provided context across days (find → investigate → resolve → verify live), not just within a single session.

### `/execute-task` autonomous loop on big-umbrella work

The 2026-05-28 `/execute-task` loop drained 42 tasks across STEAI-748's Phases 0-9, including Task 31 (GDS traversal + LLM-only baseline capture, 42 records / 79 captures), Task 32 (verdict population via Java `LayeredEvaluator`), and Task 25's credit-narration investigation (no `fe-state.lua` change owed, finding non-zero `tax_after_credit=$288.69` on the Branch-B interstate-SIT repro). This is the autonomous execution working at scale.

### Spec-draft and spec-kickoff produced a structurally clean bundle on the first attempt

Four tecpan specs (`lfpdppp-consents`, `settings`, `subscriptions`, `timbrado`) and the STEAI-748 spec were all drafted via `/spec-draft` and reached `Status: Active` via `/spec-kickoff` without validator errors. The validator is the structural gate; passing it on the first attempt across five real specs validates that the four-file format and the skill instructions are aligned.

### Cross-session continuity

The 7-day STEAI-748 timeline crossed at least 4 distinct Claude Code sessions (visible from commit cadence). `tasks.md` carried state through every transition. No information was lost. `/resume` was not needed because `tasks.md` + git log + PR state were sufficient (validating REQ-E2.1).

## 2. What needed iteration during the run

### `/polish` required more human attention than expected on the work project

The first `/polish` standalone run on a multi-reviewer paycalc branch surfaced 5 Needs sign-off items (all test coverage gaps) and 1 Needs human judgment item, and walked them one-by-one. This was correct per the categorization (all five test gaps had clear single fixes routing them to Needs sign-off), but the one-by-one presentation was tedious when 4 of the 5 items shared the same decision shape ("add this test, yes / no").

Two root causes:

1. **Missing kickoff brief tanked autonomy.** The branch was off-spec (a one-off feature branch, not a pair-flow worktree), so no kickoff brief was active. This disabled the Agent-resolvable bucket. The 4 test coverage gaps that would normally have routed to Agent-resolvable in a solo repo (and surface-with-evidence in a multi-reviewer repo) instead routed to Needs sign-off. Without a brief, `/polish` degraded to a glorified review tool that asked permission for everything.

2. **No clustered-decision presentation in `/polish`'s handoff.** CLAUDE.md's `Code & PR Reviews` rules already define clustered decisions ("Apply all / Skip all / Pick individually" for items sharing a decision axis), but `/polish`'s post-loop handoff didn't reference them. The agent defaulted to one-by-one.

Both fixed mid-run:
- `/polish` post-loop now includes an explicit "Handoff presentation" section that clusters shared-axis items and skips the workflow-choice prompt for the residual set (commit `d42bcbc`).
- Same fix applied to `/panel-pairing` (commit `4f10ebf`).

### `/orchestrate` didn't actually switch into the worktree

The orchestrate skill said "navigate to the new worktree" without specifying *how*. The Claude Code harness has `EnterWorktree` / `ExitWorktree` primitives, but the skill didn't reference them. Result: `/execute-task` invoked from inside `/orchestrate` ran in the original checkout, not the new worktree. The fix was a structural correction to the dispatch step (commit `15744e9`).

### `/self-review` used a stale base for the diff

`git diff main...HEAD` against a long-lived worktree's local `main` (which can be days or weeks behind `origin/main`) inflates the diff with already-merged commits. The fix was to `git fetch origin` first and diff against `origin/main...HEAD`, with the local fallback only when no remote exists (commit `c45c792`).

### Cross-skill drift on table count

`/self-review` and `/panel-review` still said "three findings tables" after CLAUDE.md's `Finding Categorization` was extended to four buckets (Agent-resolvable added by Task 8). The contract-consistency checker from Task 13 caught some drift but not this; the table-count invariant wasn't in the checker's coverage. Fixed mid-run (commit `1884c68`). The contract checker should be extended to catch "N findings tables" drift on the next pass.

### `/spec-draft` and `/spec-kickoff` were heavy reading

The user explicitly flagged this: "the information and walkthrough has been effective, but it's tiring, heavy, and requires a lot of discipline from the person doing it." The walls of text from Socratic restatement and open-ended questions, with no progress indicator and no progressive disclosure, taxed attention.

Fixed mid-run by adding "Interaction style" sections to both skills (commit `6c03c4e`):
- Persistent progress indicator at the top of every message
- Progressive disclosure (lead with summary or artifact, not reasoning)
- Visual aids (tables, ASCII graphs over prose)
- `AskUserQuestion` selectors with recommendations instead of open-ended questions
- Smart defaults ("I'd go with X because Y. OK?")
- Running summary at phase transitions
- Small bites (2-5 items per confirmation, not full lists)

## 3. Concrete tunings (per Task 13's Done-when)

### Agent-resolvable predicate

**Finding:** the bucket was disabled on every run that didn't have an active kickoff brief on the current branch. This is by design (D-3 condition d requires brief alignment), but the degradation is steep. Findings that are textbook Agent-resolvable candidates (failing test exists, fix is mechanical, no contract drift) route to Needs sign-off instead, requiring per-item human approval.

**Tuning recommendation:** none for v1. The predicate is correct. The friction comes from the lack of an active brief on ad-hoc branches, which is a workflow / discipline issue, not a predicate issue. The honest answer is "pair-flow needs a brief to be autonomous; ad-hoc branches accept the degraded `/polish` behavior."

**Validation:** the work project run did not auto-apply any Agent-resolvable items because the branch had no brief. This is a gap, but the test coverage gaps that would have qualified were applied via the `/polish` clustered-decision handoff after the fixes from Section 2. Net: the bucket needs real exercise on a branch *with* an active brief to validate the auto-apply path. Tecpan's settings spec is the natural next test.

### Bundling rule

**Finding:** not exercised in v1. STEAI-748 was a single big spec executed via direct `/execute-task` (no orchestrator). The 4 tecpan specs haven't been orchestrated yet.

**Tuning recommendation:** wait. The bundling heuristic (D-24: Citations + git history, ≤700 lines, with effort-based fallback for < 5 matching PRs) is grounded but unmeasured. The first 2-3 `/orchestrate` runs on tecpan will produce real data.

### Kickoff elicitation questions

**Finding:** Socratic questions worked when they were specific ("REQ-A1.1 says SHALL refresh every 30s. What happens on kill -9?"). They produced friction when they were soft ("Are there edge cases?"). The Interaction style update (Section 2) addressed the presentation problem; the question-quality problem is upstream.

**Tuning recommendation:** keep `/spec-kickoff`'s "questions should be specific" guidance front-and-center. The clustered-vs-batched presentation rules make answers cheap; the question itself must still earn its keep.

### Inbox transitions

**Finding:** not exercised in v1. The inbox substrate, heartbeats, tmux popup, and macOS notifications were validated at smoke-test level (Task 3) but not under real cross-session work. STEAI-748's 7-day timeline crossed sessions but the user did not report any inbox transitions firing because the work was all in-session execution, not multi-session handoff.

**Tuning recommendation:** wait for the first real `/orchestrate` run with multiple parallel sessions or for the scheduled bookkeeping runner (Task 12) to fire its first PR-merge reconciliation. The inbox is designed for the cases v1 has not exercised yet.

## 4. Personal preference vs generalizable

The standalone-project-extraction gate requires separating opinions that are personal preference (would not transfer to other developers) from opinions that are generalizable (the framework's contribution).

### Personal preference

- **Fish shell + mise + tmux** as the environment. Pair-flow works because Claude Code primitives don't depend on the shell, but the specific scripts assume fish.
- **One tmux session per host** as the cross-session model. The inbox dashboard is keyed against this.
- **Ansible + symlink-based config materialization** for shipping skills. Pair-flow's skill files live under `roles/osx/files/claude/commands/` because that's how this dotfiles repo manages Claude Code; an extracted project would ship skills differently (probably a Claude Code plugin manifest or a `~/.claude/commands/` writer).
- **Solo / multi-reviewer split keyed by `pair-flow-config.sh repo-class`** with PR-history-based inference. The inference is good but the file location (`~/.claude/pair-flow.local.yml`) and the helper script's shape are personal-workflow choices.
- **The specific repos targeted (tecpan, dotfiles, paycalc-services)** are the user's. The Active spec gate, the four-file format, and the categorization are not.

### Generalizable

- **The four-file format** (requirements / design / tasks / test-spec) with REQ-IDs, D-IDs, and the status lifecycle (Draft / Active / Done). This is the contract every downstream skill operates against.
- **Kickoff brief as durable contract** (D-2). The two-brief model (kickoff = contract, handover = optional cache) survived multi-day work in v1 without modification.
- **The four-bucket finding categorization** (Auto-applicable / Agent-resolvable / Needs sign-off / Needs human judgment) with solo / multi-reviewer behavior splits on Agent-resolvable. This is the framework's distinctive contribution per the 2026-05-26 landscape survey (nobody else has typed dispatch determining agent autonomy).
- **Stateless step-machine orchestration** (D-5) reading from a markdown dependency graph. The "tasks.md is the database" pattern with per-spec advisory locks (D-17, D-37) and one-task-per-invocation (D-52).
- **Test-first discipline in `/execute-task`** (REQ-B1.3, B1.4) plus adaptive CI retry (D-25).
- **Discovery Rigor + Validation Rigor + Refactor Instinct** from the user-global CLAUDE.md. Tool-grounded over vibes, three-pass validation, lens-coverage table, parallel fan-out for non-trivial diffs.
- **Observation convention** (`specs/_observations/opportunities.md` append-only one-liners as seed material). Validated as production-relevant; surfaced 3 real bugs in STEAI-748.
- **Composability-by-default design principle** at the domain/logic layer, framework conventions at the boundary. Added during the v1 run; stack-agnostic; carries to any Phoenix / Rails / Next.js / Go project.
- **Status-aware spec validation** (D-45) with warnings on Draft and errors on Active. Status-aware enforcement matches the lifecycle.
- **Interaction style rules for spec-authoring skills** (progress indicator, progressive disclosure, visual aids, selectors with recommendations, smart defaults, running summary, small bites). These are presentation-layer rules; they generalize to any skill that walks a structured artifact with a human.

## 5. What v1 did not validate

- **`/orchestrate` end-to-end.** The skill is fully implemented and the worktree-switch fix landed, but no `/orchestrate` invocation has produced a real draft PR yet. Tecpan's settings spec (or one of the other 3) is the validation target. Until that run completes, the orchestrator's task selection, worktree dispatch, `tasks.md` state updates, and lock release path are unproven end-to-end.
- **Multi-reviewer Agent-resolvable surface-for-review.** STEAI-748 bypassed `/orchestrate` (big-umbrella work, not orchestrator-shaped). The paycalc `/polish` run had no active brief, disabling Agent-resolvable entirely. Net: the multi-reviewer surface-with-evidence path (regression test + before/after + CI output + kickoff alignment shown to the human) was not exercised. A smaller-scope task run through `/orchestrate` on paycalc would close this gap.
- **Intra-spec parallelism (D-52) via multiple `/orchestrate` invocations.** Designed for but not exercised.
- **Cross-spec concurrent `/orchestrate` (D-37).** Same.
- **Scheduled bookkeeping runner (Task 12).** Documentation shipped; runner not yet scheduled against a real Active spec.
- **Inbox transitions to `awaiting-input` and `draft-pr-ready` under real workload.** Smoke-tested only.
- **Brief partial invalidation (D-27, D-35).** No spec underwent a section-scoped re-walkthrough in v1.
- **D-42 inconsistency escalation gate.** No spec surfaced a genuine inconsistency requiring path-(a) or path-(b) resolution.
- **Retrofit mode** (`/spec-kickoff` on a Draft-status spec with structural gaps). Pre-flight stages traced cleanly for `specs/pair-flow/` (no warnings to retrofit), but no real retrofit was exercised.

## Recommendation on the standalone-project-extraction gate

Per the gate in `tasks.md`'s Deferred section: "e2e validation on tecpan (solo), a work project (multi-reviewer), and dotfiles produces positive results; retrospective separates personal-preference decisions from generalizable ones."

**Status:** the dotfiles run is complete. The work project run is partial-positive (spec authoring + execution + observations validated; orchestrator and multi-reviewer Agent-resolvable not exercised). The tecpan run is staged but not started.

**Recommendation:** do not fire the extraction gate yet. Execute at least one `/orchestrate` → draft PR cycle on a tecpan spec to close the unproven-orchestration gap. After that, the gate has enough evidence to fire and a standalone extraction can be scoped.

**Predicted extraction shape (informational, not a commitment):** the personal-preference items in Section 4 would not ship. The generalizable items would. The format spec (deferred item) becomes the first deliverable. The skill set ships as either a Claude Code plugin or a `~/.claude/` writer script. The categorization rules and the discovery/validation/refactor rigor sections move from `CLAUDE.md` into the framework's own documentation.

## Open follow-ups (not gating Task 13)

- Extend the contract-consistency checker (`skill-contracts.sh`) to catch "N findings tables" drift and other prose-vs-CLAUDE.md sync gaps.
- The Phase 5b STEAI-748 engine-side `$0.00`-base / non-zero-tax defect is still open. Surfaced via the observation convention; resolution is outside pair-flow scope.
- Investigate Anthropic's Dynamic Workflows API (deferred in `tasks.md`) once published. Most natural integration: discovery rigor fan-out in `/panel-review` and `/execute-task` conditional fan-out for multi-file mechanical work.
- The `/orchestrate` "navigate to the worktree" gap was a real ambiguity; review the other skills for similar tool-name ambiguities (e.g., `/resume`'s instructions reference `git status` without naming the tool, which probably resolves fine but is worth a pass).

## Sources

- STEAI-748 spec bundle (`~/Desktop/steai-748/specs/stl-api-explain-pipeline/`) including the 8-entry observations log.
- Tecpan specs at `~/dev/tecpan/specs/` (`lfpdppp-consents`, `settings`, `subscriptions`, `timbrado`) all Active with signed-off kickoff briefs.
- Dotfiles PR #28 (`https://github.com/inkatze/dotfiles/pull/28`).
- Landscape survey conducted 2026-05-26 (memory: `project_pair_flow_steai_748_evidence.md`, `reference_ecosystem_tools.md`).
- User feedback during run: "spec was full of holes" (work project pre-pair-flow), "tiring, heavy, requires a lot of discipline" (spec-draft / spec-kickoff), "the LLM attributes our speed to everything but us or our spec" (STEAI-748 work session).
