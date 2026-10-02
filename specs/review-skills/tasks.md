# Review Skills — Tasks

**Status:** Draft
**Last reviewed:** 2026-10-02
**Format-version:** 2
**Execution:** derived — see the status render

Every task edits the tracked sources under the Claude role's skills tree and
shared reference directory as `specs/claude-instructions` Task 2 lays them
out, never the materialized files under the home directory. Every root task
that edits that tree is parked under Awaiting input until the conversion
merges (D-16); the planwright note is the one root with no such
precondition. The two performance tasks carry a measurement plan. Blocks are
listed in dependency order.

## Tasks

### Task 1 — Shared evidence record and lock namespace

- **Deliverables:** In the shared reference directory: the evidence record
  contract (location under the worktree's `.claude/` directory, the
  tree-hash key computed by `git write-tree` over a temporary index, one
  entry per command with exit status, times, source and output, the CI
  check-run source), the lock root and writer-lock contract (directory
  create, holder name, skill, worktree, epoch, the shared staleness
  threshold, reclaim notice), the session registry, the inbox layout, and
  the redirect-free write route every skill uses. A helper script under the
  Claude role's scripts directory implementing key, lookup, record, lock,
  register and inbox operations, with named locals only. Contract-checker
  pins on the sentences that make the contract safe (data-not-instructions,
  never committed, writes serialized) and a fixture per planted drift. Budget
  rows declared for the new shared file.
- **Done when:** On the branch: the helper's fixture suite passes (a tree
  hash that changes on an untracked edit and is stable across a no-op; a lock
  that refuses a second holder and is reclaimed past the threshold with the
  previous holder named; a registry entry removed on exit; an inbox write
  that uses no shell redirect); the contract checker and its suite pass with
  the new pins; the budget guard passes with the new row matching the
  formula; `shellcheck --severity=warning` is clean on the helper.
- **Dependencies:** none
- **Citations:** D-6, D-7, D-8, D-16 · REQ-D1.1, REQ-D1.2, REQ-D1.3,
  REQ-D1.5, REQ-D1.6, REQ-D1.7, REQ-E1.1, REQ-E1.2, REQ-E1.7
- **Estimated effort:** 1 day

### Task 2 — Reviewer config schema, templates and the generic renderer

- **Deliverables:** The generic hosted-reviewer schema (REQ-A1.1) documented
  in the `/bot-review` skill's config section, with the per-reviewer `cli`
  block unchanged. The tracked example config replaced by a committed
  template whose vendor-specific values are `op://` references, with the
  default pointing at the cubic.dev entry and a second entry for GitHub
  Copilot. A sibling-repository map template. A generic renderer under
  `scripts/` taking template, item and output, sourcing the shared token
  helper, writing atomically at 0600, printing `OK`/`CHANGED`/`FAILED:`, and
  validating the rendered review config against the schema rule. CI-guarded
  Ansible tasks in the Claude role rendering the review config, the sibling
  map and the adopter overlay config, each behind the existing `op` probe
  split. A fixture suite for the renderer. The contract checker validating
  the template's structure. The machine-local files table in the repo-root
  `CLAUDE.md` updated for the three rendered files. Operator steps recorded
  in the task PR: create the three items in the service-account vault with
  the field values the research found.
- **Done when:** On the branch: the renderer suite passes (a template with an
  unsubstituted expression fails, a rendered config missing a required field
  fails naming it, an unchanged output prints `OK`, a symlinked output path is
  refused); the contract checker accepts the template and rejects a fixture
  missing a required key; `ansible-playbook main.yml --syntax-check` passes
  and `--list-tasks --tags claude` lists the three render tasks; the
  identifier check reports zero hits over the templates. After merge: an
  Ansible run on a host with `op` signed in renders the three files at mode
  0600 and a second run prints `OK` for each.
- **Dependencies:** none
- **Citations:** D-2, D-13 · REQ-A1.1, REQ-A1.2, REQ-A1.3, REQ-I1.7
- **Estimated effort:** 1 day

### Task 3 — Generalize `/bot-review` and retire `/copilot-review`

- **Deliverables:** `/bot-review` driven by the schema: re-request by the
  configured method with the incremental form after a push, the reviewed-head
  extractor pinning the baseline, the draft-policy statement, the
  errored-review filter, the suppressed-findings ledger, the
  diminishing-returns exit as a handoff, and the never-mark-ready invariant
  kept. The per-PR decision ledger under the dotfiles config directory at
  0600 with the same-head and later-head re-raise rules, the tracker-link
  rule for resolved-without-change threads with CI cost rejected as a reason,
  convergence reported as a fact, and replies written as decision plus
  evidence. `/peer-review` routing every automated-reviewer thread to
  `/bot-review` with no vendor named. The `/copilot-review` skill directory
  deleted; every reference in the user-global file, the repo-root file, the
  contract checker, the budget guard and the sibling skills removed or
  retargeted; the checker's Copilot mark-ready pins replaced by the generic
  never-mark-ready pin; budget rows re-derived. Ledger fixtures.
- **Done when:** On the branch: the ledger fixtures pass (a same-head
  re-raise returns the recorded reply; a later-head re-raise of a declined
  finding routes to Needs sign-off with the decline attached; a resolve
  without a tracker link halts); the contract checker and suite pass with no
  reference to the retired skill; `grep -rn copilot-review roles/ CLAUDE.md`
  returns only changelog and spec lines; the budget guard passes with every
  touched row matching the formula. After merge: one `/bot-review --dry-run`
  on a real PR with the default reviewer fetches both endpoints, anchors
  every finding by its configured key, and names the reviewed head; one
  `--nested` run on a PR with findings ends in a handoff carrying the ledger.
- **Dependencies:** 1, 2
- **Citations:** D-3, D-9 · REQ-A1.4, REQ-A1.5, REQ-B1.1, REQ-B1.2,
  REQ-B1.3, REQ-B1.4, REQ-I1.1, REQ-I1.2, REQ-I1.3, REQ-I1.4, REQ-I1.8
- **Estimated effort:** 2 days

### Task 4 — Retire the Copilot CLI backend and remove the stale credential

- **Deliverables:** The `copilot` backend removed from `/panel-review`'s
  backend set and its sandbox block from the shared backends file; the cask
  removed from the Brewfile and the pin from the Linux mise config; the
  checker's anchors on that block removed and the retired-backend sweep
  extended to the name. A Claude role task removing the Copilot CLI
  credential directory where present, `changed_when` on removal only, with
  the GitHub-side revoke step documented in the repo-root `CLAUDE.md`.
  Budget rows re-derived.
- **Done when:** On the branch: the contract checker and suite pass, and a
  fixture planting the backend name in a skill file fails the sweep;
  `ansible-playbook main.yml --syntax-check` passes and `--list-tasks --tags
  claude` lists the removal task; the Brewfile parses. After merge: an
  Ansible run on a host holding the directory reports the task changed once
  and `OK` on the next run; a host without it reports no change.
- **Dependencies:** none
- **Citations:** D-4, D-14 · REQ-B1.5, REQ-G1.1, REQ-G1.2
- **Estimated effort:** half day

### Task 5 — The cubic.dev CLI as `reviewer:cubic`

- **Deliverables:** The CLI pinned through mise's npm backend in the tracked
  mise configuration for both platforms. A key sync script, or a mode of the
  Gemini key sync, writing the API key from its 1Password item to a 0600
  file, CI-guarded in the Claude role. The reviewer backend's invocation
  template for the entry's `cli` block carrying the vendor's auto-update and
  commit-tagger opt-outs and the key through `env_allow`, documented in the
  template's notes. The backend's `PATH` built by stripping mise shim
  directories and resolving tools from `HOME`, replacing the override list.
  Every helper in the backend snippet rewritten with named locals, and the
  contract checker refusing a bare positional parameter in any skill or
  shared file, with a fixture. Egress consent unchanged.
- **Done when:** On the branch: the contract checker rejects a fixture
  carrying `$1` and accepts the rewritten snippet; the pins and sweep pass;
  `mise ls --json` on the branch's config names the CLI with a version.
  After merge: on a host with the key file, `/panel-review --backends
  reviewer:cubic` asks consent once, runs under `env -i` with only the
  allowed variables, produces findings rows, and `git notes list` is empty
  afterwards; a second run reuses the consent.
- **Dependencies:** 2
- **Citations:** D-5 · REQ-C1.1, REQ-C1.2, REQ-C1.3, REQ-C1.4, REQ-C1.5,
  REQ-C1.6
- **Estimated effort:** 1 day

### Task 6 — Concurrency and signalling in the nested loops

- **Deliverables:** `/panel-review --nested` and `/bot-review --nested`
  taking the writer lock only around apply, commit and push, registering
  their session, reading their inbox at every iteration boundary, and
  handing findings to a lock holder through the inbox plus a session message
  with the poll-window bound. The per-push scoped discovery pass over the fix
  diff with its lens table in the loop artifact. Head and merge-base recorded
  per iteration, with body re-validation and screenshot flags on movement.
  The old per-skill locks removed. Contract-checker pins and fixtures for the
  lock discipline and the data-not-instructions rule.
- **Done when:** On the branch: the contract checker and suite pass with the
  new pins; the lock fixtures from Task 1 cover the handoff path (a second
  session's inbox file lands under the holder's name and the sender exits
  within one poll window). After merge: two sessions on the same PR, one
  `/panel-review --nested` holding the lock and one `/bot-review`, end with
  the second's findings in the first's inbox, one commit stream, and the
  handoff naming the inbox path; a head rewrite mid-loop produces the
  re-validation notice.
- **Measurement plan:** metric: wall-clock of one nested iteration and the
  count of full-suite runs per iteration; source: the evidence record's
  timestamps and entries; baseline: one `/panel-review --nested` run on
  `main` before Task 1 merges, recorded in the task PR.
- **Dependencies:** 1, 3
- **Citations:** D-7, D-8, D-10 · REQ-E1.1, REQ-E1.3, REQ-E1.4, REQ-E1.5,
  REQ-E1.7, REQ-I1.5, REQ-I1.6
- **Estimated effort:** 2 days

### Task 7 — Evidence reuse across skills and a worktree-free `/code-review`

- **Deliverables:** Every review skill's tooling step reading the evidence
  record before running and recording after; the nested loops running the
  full suite once per iteration after fixes with diff-scoped checks per fix;
  a green pushed head recorded as full-suite evidence from its check runs.
  `/code-review` reading PR content through fetched refs against the
  session's repository, exporting the pinned head with `git archive` into a
  scratch directory for the tooling step, with the isolated-session stop and
  its pins removed and the same-PR lock moved onto the shared lock root. The
  sibling-repository map read by `/code-review` and `/panel-review`, with the
  producer's relevant code attached as validation-pass-2 context when the
  diff consumes a mapped producer's shape. Checker pins and budget rows
  updated.
- **Done when:** On the branch: the contract checker and suite pass, with
  the isolated-session pins gone and the archive-export sentence pinned;
  the evidence fixtures show a second skill's lookup hitting the first's
  record for the same tree. After merge: `/code-review` on a real PR from an
  isolated worktree session completes through the tooling step with no
  second worktree created; two such sessions on two PRs run at once; a
  `/panel-review` run after a `/bot-review` run on the same tree reports the
  tooling step as reused.
- **Measurement plan:** metric: full-suite runs per nested iteration and
  tooling runs per sequence of two skills on one tree; source: the evidence
  record; baseline: the same sequence on `main` before Task 1 merges,
  recorded in the task PR.
- **Dependencies:** 1
- **Citations:** D-6, D-11, D-15 · REQ-D1.1, REQ-D1.2, REQ-D1.3, REQ-D1.4,
  REQ-D1.5, REQ-E1.6, REQ-I1.7
- **Estimated effort:** 2 days

### Task 8 — planwright step registration

- **Deliverables:** A tracked catalog file under the Claude role declaring
  `panel-review` and `bot-review` as `--nested` skill steps; a role task
  linking it into the adopter overlay's catalogs directory, linking only when
  the destination is absent or already a link into this repository, and
  leaving the overlay's config file untouched; a fixture suite for the link
  task. The `.gitignore` negation for `.claude/planwright.yml` and that file
  naming `panel-review` at `convergence` and `bot-review` at `post-pr`. Every
  `review_sequence` mention in the dotfiles instruction surfaces replaced by
  the catalog-and-list vocabulary. The repo-root `CLAUDE.md` updated for the
  managed catalog.
- **Done when:** On the branch: the link fixture suite passes (links when
  absent, keeps a foreign file and reports it, prunes its own dangling
  link); `grep -rn review_sequence roles/ CLAUDE.md` returns only changelog
  and spec lines; `ansible-playbook main.yml --syntax-check` passes. After
  merge: planwright's step resolver run for `convergence` and `post-pr` in
  this repository prints `run` for each named step with the adopter layer as
  the catalog source.
- **Dependencies:** 3
- **Citations:** D-12 · REQ-F1.1, REQ-F1.2, REQ-F1.3, REQ-F1.4
- **Estimated effort:** half day

### Task 9 — Seed the planwright note

- **Deliverables:** One pending note in the planwright repository's
  pending-notes directory, in that repository's format, carrying the lens
  candidates, the evidence record's shape and divergences, the parallel-steps
  gate observation with the measurement from Task 6 or Task 7 where
  available, session messaging as a signal between passes, and structured
  results for external review steps, with no vendor mechanics or private
  names.
- **Done when:** The note exists on a planwright branch or in its main
  history, passes that repository's pending-note checks, and names each item
  with the dotfiles decision it came from.
- **Dependencies:** none
- **Citations:** D-11, D-17 · REQ-H1.1, REQ-H1.2
- **Estimated effort:** half day

### Task 10 — Verification sweep and measurement

- **Deliverables:** Each review skill run once from the main checkout or a
  worktree session as its contract says, against a real PR, up to its first
  outbound post or its local handoff, recorded as manual verification in the
  task PR; the two-session drill from Task 6 and the parallel `/code-review`
  drill from Task 7 recorded; the before-and-after measurements from Tasks 6
  and 7 compared in one table in the task PR; any defect found filed as an
  observation rather than fixed in this task.
- **Done when:** The task PR carries one row per skill with the run's
  outcome, the two drills' outcomes, and the measurement table with the
  baseline and the post-change values; every `[manual]` entry of
  `test-spec.md` cites a row.
- **Dependencies:** 3, 5, 6, 7, 8
- **Citations:** D-18 · REQ-A1.4, REQ-A1.5, REQ-B1.1, REQ-C1.6, REQ-E1.3,
  REQ-E1.6, REQ-I1.4
- **Estimated effort:** 1 day

## Awaiting input

- **Task 1** — Parked until `specs/claude-instructions` Task 2 (the skills
  conversion) merges to `main`; the shared reference directory it extends
  does not exist on `main` yet. Unpark by removing this bullet once that PR
  merges. Citations: D-16.
- **Task 2** — Parked on the same merge: its config section lands in the
  `/bot-review` skill directory that conversion creates. Unpark with Task 1.
  Citations: D-16.
- **Task 4** — Parked on the same merge: the backend set it edits lives in
  the shared backends file that conversion creates. Unpark with Task 1.
  Citations: D-16.

## Deferred

- **Task 9** — Lands in the planwright repository; executed by hand there
  rather than dispatched here. Confidence: high. **Gate:** when the note is
  written in that repository. Citations: D-17, REQ-H1.1.
- **Generalizing 1Password rendering to the older machine-local files** (the
  host alias, the Slack map, the egress consent record) and migrating the
  ssh renderer onto the generic script. Confidence: medium. **Gate:** when a
  fresh host has to re-author one of those files by hand. Citations: D-13.
- **Replacing the evidence record with planwright's handoff bundle.**
  Confidence: medium. **Gate:** spec review-effectiveness done, in the
  planwright repository, and its output contract read by the dotfiles
  skills. Citations: D-1, D-6, REQ-D1.7.

## Out of scope

- **Lens-list additions in the dotfiles skills.** Seeded upstream (D-11,
  D-17).
- **Adopter-wide step lists.** Per-repository only (D-12).
- **Hosted Copilot on repositories that do not run it.** The entry exists;
  nothing requests Copilot where it is not installed (D-3).
- **The retrospective's human-process habits.** Practice, not skill text.
- **Behavioural eval suites for the skills.** Manual runs plus fixtures
  (D-18).
