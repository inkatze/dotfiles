# Review Skills — Tasks

**Status:** Ready
**Last reviewed:** 2026-10-07
**Format-version:** 2
**Execution:** derived — see the status render

Every task edits the tracked sources under the Claude role's skills tree and
shared reference directory as `specs/claude-instructions` Task 2 lays them
out, never the materialized files under the home directory. Every root task
that edits that tree is parked under Awaiting input until the conversion
merges (D-16); the planwright note is the one root with no such
precondition. The two performance tasks carry a measurement plan. Each
Done-when splits into branch conditions, which gate the task PR and run from
the worktree, and post-merge conditions, which run after the merge and an
Ansible run and are recorded as a comment on the merged pull request. Every
fixture suite a task creates is wired into the CI workflow and `lefthook.yml`
by that task. Blocks are listed in dependency order.

## Tasks

### Task 1 — Shared evidence record and lock namespace

- **Deliverables:** In the shared reference directory: the evidence record
  contract (location under the worktree's `.claude/` directory, the
  tree-hash key computed by `git write-tree` over a temporary index, one
  entry per command with exit status, times, source and output, the CI
  check-run source, the full-suite command key as the repository's declared
  test task, the upstream handoff-bundle member it mirrors with each
  divergence listed), the lock root and writer-lock contract (the root path,
  the atomic symlink create, the owner token naming the session process
  found by ancestry walk, holder name, skill and worktree beside it,
  owner-liveness staleness, the reclaim notice that also removes the dead
  holder's inbox files and registration, the branch-to-PR handover, the
  write set the lock covers, the plain-name encoding of repository, PR and
  branch path segments), the session registry, the inbox layout with its
  consumed-once rule, the poll window constant, the loop artifact's location
  and shape with iteration markers, the version key every entry carries, and
  the redirect-free write route every skill uses. The lock root's row in the
  repo-root `CLAUDE.md` machine-local files table. A helper script under the
  Claude role's scripts directory implementing key, lookup, record, lock,
  register and inbox operations, with named locals only. Contract-checker
  pins on the sentences that make the contract safe (data-not-instructions,
  never committed, writes serialized) and a fixture per planted drift. Budget
  rows declared for the new shared file.
- **Done when:** On the branch: the helper's fixture suite passes (a tree
  hash that changes on an untracked edit and is stable across a no-op; a
  check-run list with a skipped run beside a success hits and one with a
  failed run misses; a lock that refuses a second holder, is reclaimed with
  the previous holder named once that holder's process is gone, and is kept
  while the holder lives whatever its age; the ancestry walk finds the
  session process from a child shell; a path segment outside the plain-name
  charset is encoded before use; a registry entry removed on exit and read
  as gone when its owner is absent; an inbox write that uses no shell
  redirect; an entry with an unknown version refused by name); `git status
  --porcelain` after a recorded run shows nothing under `.claude/`; the
  contract checker and its suite pass with the new pins; the budget guard
  passes with the new row matching the formula; `shellcheck
  --severity=warning` is clean on the helper; the suite is wired into the
  workflow and `lefthook.yml`.
- **Dependencies:** none
- **Citations:** D-6, D-7, D-8, D-16 · REQ-A1.6, REQ-D1.1, REQ-D1.2,
  REQ-D1.3, REQ-D1.5, REQ-D1.6, REQ-D1.7, REQ-E1.1, REQ-E1.2, REQ-E1.3,
  REQ-E1.4, REQ-E1.7
- **Estimated effort:** 1 day

### Task 2 — Reviewer config schema, templates and the generic renderer

- **Deliverables:** The generic hosted-reviewer schema (REQ-A1.1) documented
  in the `/bot-review` skill's config section, with the per-reviewer `cli`
  block unchanged. The tracked example config replaced by a committed
  template whose vendor-specific values are `op://` references, with the
  default pointing at the cubic.dev entry and a second entry for GitHub
  Copilot. The no-vendor-name sentence in the user-global file and the
  repo-root `CLAUDE.md` narrowed to vendor mechanics, since the template's
  default names an entry. A sibling-repository map template. A generic renderer under
  `scripts/` taking template, item and output, sourcing the shared token
  helper, writing atomically at 0600, printing `OK`/`CHANGED`/`FAILED:`, and
  validating the rendered review config against the schema rule. CI-guarded
  Ansible tasks in the Claude role rendering the review config, the sibling
  map and the adopter overlay config, each behind the existing `op` probe
  split. A fixture suite for the renderer. The contract checker validating
  the template's structure. The machine-local files table in the repo-root
  `CLAUDE.md` updated for the three rendered files. Operator steps recorded
  in the task PR: review the hand-written review config on each host and
  carry anything worth keeping into the item before the first render, then
  create the three items in the service-account vault with the field values
  the research found. Every rendered file carries a version key the renderer
  and the skills check.
- **Done when:** On the branch: the renderer suite passes (a template with an
  unsubstituted expression fails, a rendered config missing a required field
  fails naming it, an unchanged output prints `OK`, a symlinked output path is
  refused); the contract checker accepts the template and rejects a fixture
  missing a required key; the renderer suite refuses a rendered file with an
  unknown version by name and asserts the overlay template sets no
  `steps_<point>` key; `ansible-playbook main.yml --syntax-check` passes and
  `--list-tasks --tags claude` lists the three render tasks; the suite is
  wired into the workflow and `lefthook.yml`. After merge: an Ansible run on
  a host with `op` signed in renders the three files at mode 0600 and a
  second run prints `OK` for each; the identifier check, on the host that
  holds the identifier file, reports zero hits over the templates.
- **Dependencies:** none
- **Citations:** D-2, D-13 · REQ-A1.1, REQ-A1.2, REQ-A1.3, REQ-A1.6,
  REQ-I1.7
- **Estimated effort:** 1 day

### Task 3 — Generalize `/bot-review` and retire `/copilot-review`

- **Deliverables:** `/bot-review` driven by the schema: re-request by the
  configured method with the incremental form after a push, the reviewed-head
  extractor pinning the baseline, the draft-policy statement, the
  errored-review filter, suppression as a ledger disposition, the
  diminishing-returns exit as a handoff, and the never-mark-ready invariant
  kept; a run naming the retired skill stops naming `/bot-review`. The
  per-PR decision ledger under the dotfiles config directory at 0600, with
  its version key, the same-head and later-head re-raise rules, the
  follow-up-record rule for deferred threads with CI cost rejected as a
  reason, convergence (no unresolved thread and reviewed head equal to head)
  reported as a fact, and replies written as decision plus evidence.
  `/peer-review` routing every automated-reviewer thread to
  `/bot-review` with no vendor named. The `/copilot-review` skill directory
  deleted; every reference in the user-global file, the repo-root file, the
  contract checker, the budget guard and the sibling skills removed or
  retargeted; the checker's Copilot mark-ready pins replaced by the generic
  never-mark-ready pin; budget rows re-derived. Ledger fixtures.
- **Done when:** On the branch: the ledger fixtures pass (a same-head
  re-raise returns the recorded reply; a later-head re-raise of a rejected
  finding routes to Needs sign-off with the rejection attached; a deferral
  without a follow-up link halts and a rejection without one does not; a
  ledger with an unknown version is refused by name); the contract checker
  and suite pass with no reference to the retired skill; `grep -rn
  copilot-review roles/ CLAUDE.md` returns only lines recording the
  retirement; the budget guard passes with every touched row matching the
  formula; the fixtures are wired into the workflow and `lefthook.yml`.
  After merge: one `/bot-review --dry-run` on a real PR with the default
  reviewer fetches both the issue-comment and the review-comment endpoints,
  anchors every finding by its configured key, and names the reviewed head;
  one `--nested` run on a PR with findings ends in a handoff carrying the
  ledger.
- **Dependencies:** 1, 2
- **Citations:** D-3, D-9 · REQ-A1.4, REQ-A1.5, REQ-A1.6, REQ-B1.1,
  REQ-B1.2, REQ-B1.3, REQ-B1.4, REQ-I1.1, REQ-I1.2, REQ-I1.3, REQ-I1.4,
  REQ-I1.8
- **Estimated effort:** 2 days

### Task 4 — Retire the Copilot CLI backend and remove the stale credential

- **Deliverables:** The `copilot` backend removed from `/panel-review`'s
  backend set and its sandbox block from the shared backends file, with
  `--backends copilot` stopping and naming the `reviewer:<name>` path; the
  cask removed from the Brewfile, the pin from the Linux mise config and the
  entry from the Linux package list; the checker's anchors on that block
  removed and the retired-backend sweep extended to the name. A Claude role
  task removing the Copilot CLI credential directory where present,
  `changed_when` on removal only, with the GitHub-side revoke step documented
  in the repo-root `CLAUDE.md`, and a fixture running it against a scratch
  home. Budget rows re-derived.
- **Done when:** On the branch: the contract checker and suite pass, and a
  fixture planting the backend name in a skill file fails the sweep;
  `ansible-playbook main.yml --syntax-check` passes and `--list-tasks --tags
  claude` lists the removal task; the scratch-home fixture reports changed
  only when the directory existed and leaves a sibling credential directory
  untouched; no Brewfile, mise file or package list names the cask, pin or
  package; the fixture is wired into the workflow job that has Ansible and
  into `lefthook.yml`. After merge: an Ansible run on a host holding the
  directory reports the task changed once and `OK` on the next run; a host
  without it reports no change.
- **Dependencies:** none
- **Citations:** D-4, D-14 · REQ-B1.5, REQ-G1.1, REQ-G1.2
- **Estimated effort:** half day

### Task 5 — The cubic.dev CLI as `reviewer:cubic`

- **Deliverables:** The CLI pinned through mise's npm backend in the
  cross-platform tracked mise configuration, so every platform gets it. A
  key sync script, or a mode of the Gemini key sync, writing the API key
  from its 1Password item to a 0600 file, CI-guarded in the Claude role,
  with a fixture suite. The reviewer backend's invocation
  template for the entry's `cli` block carrying the vendor's auto-update and
  commit-tagger opt-outs and the key through `env_allow`, documented in the
  template's notes. The backend's `PATH` built by stripping mise shim
  directories and resolving tools from `HOME`, replacing the override list,
  with a fixture. Every helper in the backend snippet rewritten with named
  locals, and the contract checker refusing a bare positional parameter in
  any skill or shared markdown file, with a fixture. Egress consent
  unchanged.
- **Done when:** On the branch: the contract checker rejects a fixture
  carrying `$1` and accepts the rewritten snippet; the pins and sweep pass;
  the key-sync fixture refuses a key file at a loose mode and a blank value;
  the PATH fixture asserts a planted shims directory and repo-steered mise
  config are absent from the resolved `PATH`; `grep -rn CUBIC roles/fish`
  returns nothing; the cross-platform tracked mise file names the CLI with a
  version; the fixtures are wired into the workflow and `lefthook.yml`.
  After merge: on a host with the key file, `/panel-review --backends
  reviewer:cubic` asks consent once, runs under `env -i` with only the
  allowed variables, produces findings rows, and the repository's `git
  notes list` is unchanged by the run; a second run reuses the consent.
- **Dependencies:** 2
- **Citations:** D-5 · REQ-C1.1, REQ-C1.2, REQ-C1.3, REQ-C1.4, REQ-C1.5,
  REQ-C1.6
- **Estimated effort:** 1 day

### Task 6 — Concurrency and signalling in the nested loops

- **Deliverables:** `/panel-review --nested` and `/bot-review --nested`
  taking the writer lock only around their writes (apply and commit for
  both; push, reply, resolve and ledger writes for `/bot-review`),
  registering their session, reading their inbox at every iteration
  boundary, and handing findings to a lock holder through the inbox plus a
  session message with the poll-window bound, taking the lock themselves if
  it frees within the window. A sender that cannot send a session message
  posts the nudge through the holder's inbox socket by a new nudge operation
  in the review helper (registration recording the socket path, posting only
  to a socket the user owns, the line's format kept in one place in the shared
  state reference), reporting a failed post in its handoff; a holder that
  refused or held the message, a "Not sent" result naming its inbound
  controls included, gets no socket nudge. The per-push scoped
  discovery pass over the fix diff with its lens table in the loop artifact.
  Head and merge-base recorded per iteration, with body re-validation and
  screenshot flags on movement. The old per-skill locks removed.
  Contract-checker pins and fixtures for the lock discipline, the
  data-not-instructions rule and the no-socket-nudge-after-refusal rule,
  extending Task 1's fixture suite with the handoff path and the nudge
  operation's owner check.
- **Done when:** On the branch: the contract checker and suite pass with the
  new pins; the nudge operation posts only to a socket the user owns; the
  extended fixture suite covers the handoff path (a second
  session's inbox file lands under the holder's name and the sender exits
  within one poll window or takes a freed lock). After merge: two sessions
  on the same PR, one `/panel-review --nested` holding the lock and one
  `/bot-review`, end with the second's findings in the first's inbox, one
  commit stream, and the handoff naming the inbox path; a head rewrite
  mid-loop produces the re-validation notice (together, the two-session
  drill); a sender without the SendMessage tool nudges a holder that accepts
  messages through the holder's inbox socket and the nudge arrives (the
  socket-nudge drill); a sender that can send messages, to a holder whose
  `crossSessionInbound` is `refuse`, sends no socket nudge and says so in its
  handoff, and the inbox file is still read at the holder's next boundary
  (the refused-messaging drill), as the REQ-E1.8 test-spec entry details.
- **Measurement plan:** metric: wall-clock of one nested iteration and the
  count of full-suite runs per iteration; source: the loop artifact's
  iteration markers and the evidence record's entries after the change, and
  wall-clock plus a count of suite invocations taken by hand from one
  `/panel-review --nested` run on `main` before Task 1 merges, as the
  baseline; both recorded in the task PR.
- **Dependencies:** 1, 3
- **Citations:** D-7, D-10, D-19 · REQ-E1.1, REQ-E1.3, REQ-E1.4, REQ-E1.7,
  REQ-E1.8, REQ-I1.5, REQ-I1.6
- **Estimated effort:** 2 days

### Task 7 — Evidence reuse across skills and a worktree-free `/code-review`

- **Deliverables:** Every review skill's tooling step reading the evidence
  record before running and recording after; the nested loops running the
  full suite once per iteration after fixes with diff-scoped checks per fix;
  a green pushed head recorded as full-suite evidence from its check runs.
  `/code-review` reading PR content through fetched refs against the
  session's repository, exporting the pinned head with `git archive` into a
  scratch directory for the tooling step, with the isolated-session stop and
  its pins removed and its same-PR lock replaced by the shared writer lock
  around review submission; `/code-review` and `/peer-review` registering
  their session, and `/peer-review` taking the writer lock around its
  replies. The sibling-repository map read by `/code-review` and
  `/panel-review`, with the producer's relevant code attached as
  validation-pass-2 context when the diff consumes a mapped producer's
  shape. Checker pins and budget rows updated.
- **Done when:** On the branch: the contract checker and suite pass, with
  the isolated-session pins gone and the archive-export sentence pinned;
  Task 1's evidence fixtures, extended here, show a second skill's lookup
  hitting the first's record for the same tree. After merge: `/code-review`
  on a real PR from an isolated worktree session completes through the
  tooling step with `git worktree list` unchanged; two such sessions on two
  PRs both complete with no lock conflict and no new worktree; a
  `/panel-review` run after a `/bot-review` run on the same tree reports the
  tooling step as reused.
- **Measurement plan:** metric: full-suite runs per nested iteration and
  tooling runs per sequence of two skills on one tree; source: the evidence
  record after the change, and a hand count of tooling invocations from the
  same sequence on `main` before Task 1 merges as the baseline; both
  recorded in the task PR.
- **Dependencies:** 1
- **Citations:** D-6, D-11, D-15 · REQ-D1.1, REQ-D1.2, REQ-D1.3, REQ-D1.4,
  REQ-D1.5, REQ-E1.1, REQ-E1.6, REQ-E1.7, REQ-I1.7
- **Estimated effort:** 2 days

### Task 8 — planwright step registration

- **Deliverables:** A tracked catalog file under the Claude role declaring
  `panel-review` and `bot-review` as `--nested` skill steps; a role task
  linking it into the adopter overlay's catalogs directory, linking only when
  the destination is absent or already a link into this repository, and
  leaving the overlay's config file to Task 2's renderer; a fixture suite for
  the link task. The root `.gitignore` reworked so `.claude/planwright.yml` can be
  re-included (git never re-includes a file under an excluded directory, so
  the directory rule becomes a contents rule plus a negation) and that file
  naming `panel-review` at `convergence` and `bot-review` at `post-pr`. Every
  `review_sequence` mention in the dotfiles instruction surfaces replaced by
  the catalog-and-list vocabulary. The repo-root `CLAUDE.md` updated for the
  managed catalog.
- **Done when:** On the branch: the link fixture suite passes (links when
  absent, keeps a foreign file and reports it, prunes its own dangling
  link); `grep -rn review_sequence roles/ CLAUDE.md` returns only lines
  recording the knob's retirement; `git check-ignore .claude/planwright.yml`
  exits non-zero and the file is tracked; `ansible-playbook main.yml
  --syntax-check` passes; the suite is wired into the workflow job that has
  Ansible and into `lefthook.yml`. After merge: planwright's step resolver,
  run unattended with its explain flag for `convergence` and `post-pr` in
  this repository, prints `run` for each named step with the adopter layer
  as the catalog source.
- **Dependencies:** 3
- **Citations:** D-12 · REQ-F1.1, REQ-F1.2, REQ-F1.3, REQ-F1.4
- **Estimated effort:** half day

### Task 9 — Seed the planwright note

- **Deliverables:** One pending note in the planwright repository's
  pending-notes directory, in that repository's format, carrying the lens
  candidates, the evidence record's shape and divergences, the parallel-steps
  gate observation with the measurement from Task 6 or Task 7 where
  available, session messaging as a signal between passes, structured
  results for external review steps, and the CI-as-evidence divergence from
  planwright's bar with its measurements, with no vendor mechanics or
  private names. A paste-ready `/spec-draft` prompt for the planwright
  repository naming the note as its seed, recorded in the task PR.
- **Done when:** The note exists on a planwright branch or in its main
  history, is accepted by that repository's pre-commit hooks, and names each
  item with the dotfiles decision it came from; the task PR carries the
  prompt.
- **Dependencies:** none
- **Citations:** D-11, D-17 · REQ-D1.3, REQ-D1.7, REQ-H1.1, REQ-H1.2
- **Estimated effort:** half day

### Task 10 — Verification sweep and measurement

- **Deliverables:** Each review skill run once from a worktree session,
  against a real PR, up to its first outbound post or its local handoff,
  recorded as manual verification in the task PR; the two-session drill,
  the socket-nudge drill and the refused-messaging drill from Task 6 and the
  parallel `/code-review` drill from Task 7 recorded; the before-and-after
  measurements from Tasks 6 and 7 compared in one table in the task PR; any
  defect found filed as an observation rather than fixed in this task.
- **Done when:** The task PR carries one row per skill with the run's
  outcome, the drills' outcomes, and the measurement table with the baseline
  and the post-change values; every `[manual]` entry of `test-spec.md` whose
  requirement a task in this repository implements cites a row (the
  planwright note's entry is verified in that repository).
- **Dependencies:** 3, 4, 5, 6, 7, 8
- **Citations:** D-18 · REQ-A1.1, REQ-A1.3, REQ-A1.4, REQ-A1.5, REQ-B1.1,
  REQ-C1.1, REQ-C1.2, REQ-C1.3, REQ-C1.6, REQ-D1.3, REQ-D1.4, REQ-E1.1,
  REQ-E1.3, REQ-E1.6, REQ-E1.8, REQ-F1.1, REQ-G1.1, REQ-I1.4, REQ-I1.5,
  REQ-I1.6, REQ-I1.7
- **Estimated effort:** 1 day

## Awaiting input

- **Task 8** — Contract drift, halted before implementation (2026-10-07):
  REQ-F1.1 and D-12 have the role symlink the tracked steps catalog into the
  adopter overlay's catalogs directory, but planwright's catalog resolver
  canonicalizes each overlay file and drops one resolving outside its overlay
  root, so a linked catalog never reaches the adopter layer and the after-merge
  Done-when cannot pass. Remedy chosen by the operator: a `/spec-kickoff`
  delta re-walkthrough replacing the link with a managed copy (written when
  absent or carrying the role's marker, a foreign file kept and reported, the
  role's own copy removed when its source goes), then re-dispatch.

## Deferred

- **Task 9** — Lands in the planwright repository; executed by hand there
  rather than dispatched here. Confidence: high. **Gate:** when the note is
  written in that repository. Citations: D-17, REQ-H1.1.
- **Generalizing 1Password rendering to the older machine-local files** (the
  host alias, the Slack map, the egress consent record) and migrating the
  ssh renderer onto the generic script. Confidence: medium. **Gate:** when a
  fresh host has to re-author one of those files by hand. Citations: D-13.
- **Removing the Copilot credential cleanup.** The role task that deletes
  the stale credential directory is a one-off: once every host has run it,
  nothing this repository declares writes there, so the task, its fixture,
  the fixture's lefthook and workflow wiring, and the prose naming the task
  in `docs/review-backends.md` go; the revoke step in the repo-root
  `CLAUDE.md` stays. Confidence: high. **Gate:** when every host (work,
  personal, alt, server) has run the claude role after the cleanup merged.
  Citations: D-14.
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
