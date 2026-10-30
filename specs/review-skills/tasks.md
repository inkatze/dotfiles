# Review Skills — Tasks

**Status:** Ready
**Last reviewed:** 2026-10-23
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
  `panel-review` and `bot-review` as `--nested` skill steps, its first line
  the role's marker comment; a role task, with no `CI` guard, installing a
  byte-for-byte copy at the adopter overlay's `catalogs/steps.yaml` per
  REQ-F1.5 (creating a missing `catalogs/`, failing the run on a foreign
  destination, removing its own copy when the source is gone) and leaving
  the overlay's config file to Task 2's renderer; a fixture suite for the
  copy task. The root `.gitignore`'s `.claude/` rule replaced by
  `**/.claude/*` plus `!/.claude/planwright.yml` (git never re-includes a
  file under an excluded directory, so the directory rule becomes a contents
  rule plus a negation) and that file naming `panel-review` at `convergence`
  and `bot-review` at `post-pr`. Every `review_sequence` mention in the
  dotfiles instruction surfaces replaced by the catalog-and-list vocabulary.
  The repo-root `CLAUDE.md` updated for the managed catalog, and
  `docs/claude-config.md`'s sentence on ignoring `.claude/` updated for the
  contents rule and the tracked file.
- **Done when:** On the branch: the copy fixture suite passes (writes when
  the destination and `catalogs/` are absent; reports no change on an
  identical marked copy; rewrites a marked copy whose source changed; fails
  the run naming the path on an unmarked file, on a symlink to a marked
  file, and on a `catalogs/` that is a symlink or a regular file, writing
  nothing through them; makes the same decisions under check mode without
  writing; removes its own copy when the source is gone; leaves an unmarked
  file in place when the source is gone); `grep -rn review_sequence roles/
  CLAUDE.md` returns only lines recording the knob's retirement; `git
  check-ignore --no-index .claude/planwright.yml` exits non-zero and the
  file is tracked, while `git check-ignore .claude/worktrees` exits zero;
  `ansible-playbook main.yml --syntax-check` passes; the suite is wired into
  the workflow job that has Ansible and into `lefthook.yml`. After merge:
  planwright's step resolver, run unattended with its explain flag for
  `convergence` and `post-pr` in this repository, prints `run` for each
  named step with the adopter layer as the catalog source.
- **Dependencies:** 3
- **Citations:** D-20 · REQ-F1.5, REQ-F1.2, REQ-F1.3, REQ-F1.4
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
  requirement one of this task's dependencies implements cites a row (the
  planwright note's entry is verified in that repository; later tasks
  verify their own manual entries in their after-merge Done-when).
- **Dependencies:** 3, 4, 5, 6, 7, 8
- **Citations:** D-18 · REQ-A1.1, REQ-A1.3, REQ-A1.4, REQ-B1.1,
  REQ-C1.1, REQ-C1.2, REQ-C1.3, REQ-C1.6, REQ-D1.3, REQ-D1.4, REQ-E1.1,
  REQ-E1.3, REQ-E1.6, REQ-E1.8, REQ-F1.5, REQ-G1.1, REQ-I1.4, REQ-I1.5,
  REQ-I1.6, REQ-I1.7
- **Estimated effort:** 1 day

### Task 11 — Request discipline from recorded state and complete handoffs

- **Deliverables:** In `review-state.sh`: `ledger request record`
  (refusing a `full` row unless `decide` would print it), `ledger review
  record`, `ledger request decide` (the arms D-21 names, the reviewer's
  latest comment on stdin, `--window <seconds>` from the shared thresholds,
  printing the decision and its reason), `ledger owed` (owed threads by link
  and anchor from the fetched thread JSON on stdin), and the ledger's own
  version key (split from the helper's shared one, every shipped ledger
  version read, the current one stamped on the next locked append). In
  `/bot-review`: "Requesting a review" taking each request from `decide`;
  every run's first fetch and each poll recording completed reviews and
  unrecorded requests, each write under the writer lock taken and released
  around it; a `--full` flag in the argument hint, the Invocation modes
  line and the contract checker's `expected_hint`; the new optional
  `incremental_refusal_regex` field in the review template's entries for
  both 1Password items, the schema and the config documentation, the
  review-config version unchanged (the field is optional); every stop's
  handoff listing `ledger owed`'s output, convergence declared from the
  enumerated unresolved threads, and the Writer lock held row using the
  owed-thread term; under a planwright step with no operator present, the
  stop after a push waiting for the final head's review per REQ-I1.10 and
  handing off with the unreviewed head first, then the owed threads, as a
  stop the step runner classifies as halted. In the shared reference
  directory: `state.md`'s Version key and Decision ledger sections, and
  `limits.md`'s review-poll window row naming the pending-request expiry.
  Contract checker pins for each rule with a fixture per pin; helper
  fixtures for every `decide` arm (no review recorded, a completed review,
  a refusal newer than the last full request and one older, the flag, a
  pending request, a pending request ended by a refusal, an expired one,
  method `request` and a `comment` reviewer without `incremental_command`),
  for `request record --form full` refused, for a version-1 ledger read and
  upgraded, and for `ledger owed` (an owed thread listed; resolved-unreplied
  and replied threads not); budget rows re-derived for every grown surface.
- **Done when:** On the branch: the helper and checker fixtures pass; the
  suites are wired into the CI workflow and `lefthook.yml`; the renderer
  suite accepts the new optional field and a template without it; the
  instruction-budget and contract suites pass. After merge, each recorded as
  a comment on the merged PR: a `--nested` run on a fresh PR shows exactly
  one `full` request row, review rows, and `incremental` rows after it; a
  second run on the same PR opens with the incremental form; a `--nested`
  run that stops with an owed thread names it in its handoff's first line;
  under a planwright step, one run drains a review of the final head within
  the window, and one with the reviewer silent past the window hands off
  with the unreviewed head first and is classified halted.
- **Dependencies:** none
- **Citations:** D-21, D-22 · REQ-A1.7, REQ-A1.9, REQ-I1.9, REQ-I1.10
- **Estimated effort:** 1.5 days

### Task 12 — Standing rules: render, triage, proposals and the dashboard hash

- **Deliverables:** `review-rules.json.tpl` under the shared reference
  directory in planwright's standing-rules format (the rules list a `| json`
  field), its validation rule in `scripts/op-render.sh` (planwright's
  `review-rules.sh` validator when the install root resolves, else the
  rule's own jq shape check of that format, never unchecked), the render
  task in `roles/claude/tasks/op-render.yml` with its failure and skip
  reporting; the machine-local file documentation in
  `docs/machine-local-files.md` and `CLAUDE.md`'s table (the rules file, and
  the `review/` row naming the paste record) within `CLAUDE.md`'s line
  ceiling, folded into existing rows or offset by a trim in the same
  commit. In `review-state.sh`: `rules read` (reading the rendered file,
  reporting absence, refusing an unreadable file or an unknown version,
  printing the rules), `ledger record --rule <id>`, `rules paste --repo
  <o/r> --hash <h>` and `rules paste show --repo <o/r>` over the
  repository's file under `~/.config/dotfiles/review/rules-paste/` (the
  ledger's layout, path encoding, symlink refusal and file lock, version
  stamped per REQ-A1.9), and the drift check comparing it with planwright's
  exporter output through an exporter seam the fixtures stub, reporting no
  paste once and an absent or refusing exporter as unverified. In
  `/bot-review`, `/panel-review` and `/code-review`: triage through `rules
  read` under planwright's semantics per REQ-I1.11 (in `/bot-review` the
  rule id in the ledger row and the reply, a rule-decided reply posting
  unattended like any drained reply; in the other two the rule id in the
  finding's handoff row; new evidence to the skill's human-judgment bucket
  naming the rule), and a proposed entry drafted in the handoff for a
  rule-stating rejection or deferral the file lacks; `/bot-review`'s
  pre-flight drift report and paste confirmation. Contract checker pins and
  fixtures; the renderer suite's cases for the new template (a conforming
  item, a template or item-supplied version that is unknown, a rule missing
  a field); budget rows re-derived for every grown surface.
- **Done when:** planwright's standing-rules format and exporter are merged
  on that repository's main (review-effectiveness Task 6.1). On the branch:
  the renderer, helper and checker fixtures pass (`rules read` reports an
  absent file and refuses an unknown version; `ledger record --rule` keeps
  the id; the paste record refuses an unknown version and a symlinked path
  and serializes concurrent writes; the drift check reports a changed hash,
  no paste, and a stubbed refusing exporter as unverified); the suites are
  wired into CI and `lefthook.yml`; the instruction-budget suite passes.
  After merge, each recorded as a comment on the merged PR: the role renders
  the file from the item on one host and the identifier check over it
  reports no vendor names; one `--nested` run on a PR with a finding a rule
  decides shows the rule id in the reply, and a rejection whose reply
  states a rule the file lacks shows a drafted entry in the handoff; the
  exported block is pasted into the reviewer's dashboard for this
  repository and its hash recorded, and after an edit to the item and a
  role re-run, pre-flight reports drift.
- **Dependencies:** 11
- **Citations:** D-13, D-23 · REQ-A1.8, REQ-A1.9, REQ-I1.11, REQ-I1.12
- **Estimated effort:** 2 days

### Task 13 — Lockdown suite per host platform

- **Deliverables:** `scripts/cubic-lockdown-test.sh` reading the version
  from `roles/environments/files/mise.toml` and naming the platform package
  from the host's OS and architecture against the reviewed umbrella
  package's optional dependencies (held with the integrity pins, never
  guessed), reading that one, its cache keyed by platform; every platform
  package's integrity pinned in tracked configuration the suite verifies
  before reading (its reviewed values or a committed checksum file), with an
  override seam for the pin source; a fixture suite planting a changed
  integrity value, wired into the CI workflow and `lefthook.yml`; the suite
  added to the macOS CI job beside the Linux one; `docs/review-backends.md`
  describing the per-platform read; obs:35b6e190 consumed.
- **Done when:** On the branch: the Linux and macOS CI jobs each pass the
  suite and their logs name different platform packages; the fixture suite's
  changed integrity value fails the pin before any read; the lint and syntax
  checks pass. After merge: `mise run environments` on a Mac installs the
  pinned package and the suite passes there by hand, recorded as a comment
  on the merged PR.
- **Dependencies:** none
- **Citations:** D-24 · REQ-C1.7
- **Estimated effort:** 1 day

## Awaiting input

- **Spec PR ready-flip** — pending (2026-10-23): the extension re-sign-off's
  spec PR stays draft; the CI wait expired before the head commit's checks
  completed. Re-run the ready-flip once CI is green.

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
- **Adopter-wide step lists.** Per-repository only (D-20).
- **Hosted Copilot on repositories that do not run it.** The entry exists;
  nothing requests Copilot where it is not installed (D-3).
- **The retrospective's human-process habits.** Practice, not skill text.
- **Behavioural eval suites for the skills.** Manual runs plus fixtures
  (D-18).
