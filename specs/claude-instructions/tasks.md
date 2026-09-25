# Claude Instructions Audit — Tasks

**Status:** Draft
**Last reviewed:** 2026-09-25
**Format-version:** 2
**Execution:** derived — see the status render

Tasks 1 to 4 land in this repository. Tasks 5, 6 and 7 land elsewhere (the
project repo, the planwright repository, the work host) and are parked under
Deferred with a free-text gate so the orchestrator never dispatches them from
this checkout; the operator runs them by hand where they belong. A worktree of
this repository cannot exercise a changed skill through the Skill tool (the
materialized symlink follows the main checkout), so every "run it once"
condition below is met from the main checkout after the branch merges, or by
following the branch file by hand.

## Tasks

### Task 1 — Word-budget guard

- **Deliverables:** `roles/claude/files/scripts/instruction-budget.sh`
  counting words per instruction surface with warn and error thresholds
  declared in the script beside the REQ-G1.3 rule, a fixture suite in the
  style of the contract checker's, a lefthook entry with a glob over every
  surface it covers, and the CI job running it beside the contract checker.
  Initial thresholds equal each surface's current word count so the guard is
  green on arrival.
- **Done when:** `lefthook run pre-commit` and the CI workflow run the
  checker; the fixture suite fails on a planted overage, a planted unreadable
  surface and a threshold below the rule's floor; the checker exits 0 on the
  tree as merged; the repo-root `CLAUDE.md` names the guard in one line.
- **Dependencies:** none
- **Citations:** D-5 · REQ-G1.1, REQ-G1.2, REQ-G1.3, REQ-G1.4, REQ-G1.5,
  REQ-K1.1
- **Estimated effort:** half day

### Task 2 — Convert the review commands to skills with a shared directory

- **Deliverables:** `roles/claude/files/skills/<name>/SKILL.md` for every
  review command, plus `roles/claude/files/skills/review-shared/` holding the
  three-pass validation and solution-validation text as pointers to
  planwright's doctrine, the workflow-choice and handoff ritual, the GraphQL
  reply-and-resolve blocks, the backend resolver and probes, the push-hook
  failure handling, the Slack recipient-resolution and confirmation
  mechanics, and the single declaration of shared thresholds; a symlink task
  for the skills directory and retirement of the commands symlink in
  `roles/claude/tasks/main.yml`; the contract checker, its fixture suite and
  the lefthook globs moved to the new paths with the retired-bucket sweep
  removed and the doctrine-pointer pin added; every skill following four
  buckets and act-then-review by resolving planwright's docs; Maintenance
  sections removed; nested loops emitting the lens table on first and final
  iteration only; empty rows as one line in the turn; stale references and
  the codex flag fixed; external project names scrubbed; the three
  inter-skill contradictions resolved to one rule each in the shared
  directory; the repo-root "Adding a new Claude command" section rewritten
  for skills; the machine-local name denylist the checker's suite reads (D-8)
  added to the repo-root machine-local files table; each skill's budget
  thresholds lowered per REQ-G1.3.
- **Done when:** the contract checker and its suite pass on the new layout;
  the budget guard passes at the lowered thresholds; an Ansible run
  materializes `~/.claude/skills/` and removes `~/.claude/commands/`; each
  skill runs once from the main checkout against a real pull request and
  reaches its normal handoff; `grep -rn` over the tracked instruction files
  finds no external project or employer name; no file under the skills
  directory contains a Maintenance heading; every relative link from a
  SKILL.md resolves to a file in the shared directory.
- **Dependencies:** 1
- **Citations:** D-2, D-4, D-8, D-10, D-15 · REQ-B1.2, REQ-B1.3, REQ-C1.1,
  REQ-C1.2, REQ-C1.3, REQ-C1.4, REQ-C1.5, REQ-C1.6, REQ-C1.7, REQ-C1.8,
  REQ-C1.9, REQ-D1.3
- **Estimated effort:** 2 days

### Task 3 — Diet the user-global CLAUDE.md

- **Deliverables:** `roles/claude/files/CLAUDE.md` with the four doctrine
  sections replaced by pointers naming the planwright doc and the resolution
  script; the Review Workflows and pipeline sections as one-line pointers;
  the Slack section reduced to the outbound-message rule and its two
  exceptions, mechanics gone to the shared directory; the ready-flip
  condition as mergeable-only with the ritual removed; the kickoff exception
  clause; incident rules cut to their constraint; the three shell lines; the
  lifecycle vocabulary and the acting-on-specs invariant aligned to
  planwright's statuses; the stale MCP references and the `review_sequence`
  claim removed; the file's thresholds in the budget guard lowered per
  REQ-G1.3; the contract checker's pins updated for every reworded sentence
  in the same commit.
- **Done when:** the contract checker and the budget guard pass; the file
  carries no paragraph that also appears in a planwright doctrine doc (a
  diff of each former section against its doctrine doc shows only the
  pointer); a fresh session answers "what must be true before you mark a PR
  ready" with mergeable and CI green and nothing about being current;
  `grep -n` for `Draft → Active`, `non-Active`, `deepwiki`, and the
  `review_sequence` claim returns nothing; every incident rule is at most two
  lines.
- **Dependencies:** 1, 2
- **Citations:** D-2, D-3, D-6, D-10, D-11, D-12 · REQ-A1.1, REQ-A1.2,
  REQ-A1.3, REQ-B1.1, REQ-B1.4, REQ-B1.5, REQ-D1.1, REQ-D1.2, REQ-D1.3,
  REQ-E1.1, REQ-E1.2, REQ-E1.3, REQ-E1.4, REQ-E1.5
- **Estimated effort:** 1 day

### Task 4 — Diet the repo-root CLAUDE.md and amend claude-context

- **Deliverables:** the root `CLAUDE.md` within the claude-context ceiling,
  every narrative section collapsed to its rules plus a pointer; a new
  `docs/` directory with one note per relocated topic; the verified stale
  claims corrected and the two incomplete tables completed; the misfiled
  machine-local block moved under its heading; sections duplicating the
  global file reduced to the repo-specific fact; `specs/claude-context` with
  its role paths corrected, a `Format-version:` line added and a dated
  changelog entry marked expression-only; the file's budget thresholds
  lowered per REQ-G1.3.
- **Done when:** `wc -l CLAUDE.md` is at or under the claude-context
  ceiling; the budget guard passes at the lowered thresholds; every pointer
  in the file resolves to an existing `docs/` note, script header or spec
  section; `specs/claude-context` passes `spec-validate.sh` with no error
  about a missing format line; a fresh session in this repo can still answer
  where the tracked Claude sources live, how settings are merged, and how to
  add a skill, from the file alone.
- **Dependencies:** 1
- **Citations:** D-7, D-10 · REQ-F1.1, REQ-F1.2, REQ-F1.3, REQ-F1.4, REQ-F1.5
- **Estimated effort:** 1 day

### Task 5 — Clean the project repo's instruction files

- **Deliverables:** in the project repo: the two convention-contradicting
  skills rewritten to the repo's current conventions and the generic one
  deleted; the worker-fleet checkpoint directory under `.claude/` deleted;
  the dead local permission rule removed; the route-helper block trimmed to
  its rule; the stale phase claim corrected in `CLAUDE.md` and the design
  document that repeats it.
- **Done when:** a pull request in the project repo carries the tracked
  changes and its CI is green; the checkpoint directory and the dead rule are
  gone from the working copy; each remaining skill is exercised once on a
  scaffold and produces code matching the repo's conventions.
- **Dependencies:** none
- **Citations:** D-8, D-10 · REQ-H1.1, REQ-H1.2, REQ-H1.3, REQ-H1.4
- **Estimated effort:** half day

### Task 6 — Seed the planwright note

- **Deliverables:** one pending note in the planwright repository's
  pending-notes directory, in that repository's own note format, carrying
  every item REQ-I1.2 lists with the evidence from the inventory and the
  consumed observations, worded without any external project name.
- **Done when:** the note exists on a planwright branch or in its main
  checkout and planwright's own checks accept it; every item in REQ-I1.2
  appears in it with a one-line rationale.
- **Dependencies:** none
- **Citations:** D-9 · REQ-A1.4, REQ-I1.1, REQ-I1.2
- **Estimated effort:** half day

### Task 7 — Audit the work repos

- **Deliverables:** on the work host: the same extraction method (read-only
  workers, one table per surface, held machine-locally) run over each work
  repo's instruction files; cluster verdicts taken with the operator; edits
  landed in those repos through their own review flows.
- **Done when:** each work repo's instruction surfaces have a dated table on
  the work host; every verdict is either applied or recorded there as
  declined; nothing about them is committed to this repository.
- **Dependencies:** 2, 3
- **Citations:** D-8, D-10 · REQ-J1.1, REQ-J1.2, REQ-K1.1, REQ-K1.2
- **Estimated effort:** 1 day

## Awaiting input

(none yet)

## Deferred

- **Task 5** — Lands in the project repo, not here; executed by hand from
  that repository's own checkout. Confidence: high.
  **Gate:** run by hand in the project repo; not dispatchable from this
  checkout.
  Citations: D-8, REQ-H1.1.
- **Task 6** — Lands in the planwright repository; executed by hand there.
  Confidence: high.
  **Gate:** run by hand in the planwright checkout; not dispatchable from
  this checkout.
  Citations: D-9, REQ-I1.1.
- **Task 7** — Runs on the work host after the skills conversion and the
  global diet have merged, so the work repos see the new shape. Confidence:
  high.
  **Gate:** run from the work host after Task 2 and Task 3 have merged.
  Citations: D-8, REQ-J1.1.

## Out of scope

- Editing planwright core, its plugin cache, or adding a doctrine shadow or
  config overlay in this repository; the items go through Task 6 (D-9).
- Rewriting the frozen spec bundles that name the project repo or a work
  project (D-8).
- Merging the review skills into one skill.
- Any change to the spec-content freshness gate.
- Removing the planwright ready-guard hook on any host.
- The machine-local memory files.
