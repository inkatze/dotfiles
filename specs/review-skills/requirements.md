# Review Skills — Requirements

**Status:** Ready
**Last reviewed:** 2026-10-03
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Revamp the review skills tracked under the Claude role so that they run
faster, run side by side without stepping on each other, and drain the
hosted reviewer this operator actually uses. Three things change. The skills
stop re-running the same tooling and test suite for every pass and every
sibling: whichever skill runs first records the evidence, and every later
skill and iteration reuses it. The skills gain one lock namespace, a session
registry and a signal path, so read-only passes from several sessions run
concurrently while exactly one session applies fixes to a branch. And the
Copilot-specific drain skill is retired in favour of one generic hosted-bot
drain, configured per reviewer from a machine-local file, with cubic.dev as
the default reviewer and GitHub Copilot kept only as a second entry for
repositories that run it. The retrospective of recent work reviews adds a
fourth strand: the bot loop keeps its decisions, deferrals leave a trace, and
the stop decision stays with the operator.

The deliverable sits at **mechanism and local value**. The cross-session
capability it needs is specced here as a local stand-in shaped to planwright's
own signed-off review-effectiveness contract, and the capability itself is
seeded upstream; no doctrine is written here. *(Cites: D-1, D-6, D-7, the
invocation (Sources), altitude seed claims (Sources), the work review
retrospective (Sources).)*

## Scope

### In scope

- The review skills tracked under the Claude role in their post-conversion
  skills layout (`specs/claude-instructions` Task 2), their shared reference
  directory, the contract checker and the word-budget guard that gate them.
- One generic hosted-reviewer schema in the machine-local review config,
  rendered from 1Password, with cubic.dev as the default entry and GitHub
  Copilot as a second entry.
- Retiring the `/copilot-review` skill and the opt-in Copilot CLI backend of
  `/panel-review`, with their declarations and the stale Copilot credential.
- The cubic.dev CLI as a `reviewer:<name>` backend of `/panel-review`.
- A worktree-local evidence record for tooling and suite results, shared
  across skills and iterations, with a green CI run on a pushed head counting
  as evidence.
- One lock namespace, a session registry and an inbox-plus-message signal
  path for concurrent review sessions, and a worktree-free `/code-review`.
- A per-PR decision ledger, follow-up-linked deferrals, operator-owned stop,
  a per-push fix pass, staleness re-validation, and a machine-local
  sibling-repository map used as validation context.
- Registering the dotfiles review skills as planwright catalog steps through
  an Ansible-managed adopter catalog, and this repository's own step list.
- A pending note into the planwright repository carrying the planwright-owned
  items this bundle cannot change here.

### Out of scope

- **Changing planwright core from this repository.** Lens-list additions, the
  parallel-steps gate, and the evidence-contract convergence are seeded into
  planwright's pending notes (REQ-H) and decided there.
- **Adding lenses to the dotfiles skills.** The lens list is planwright's,
  pointed at and never copied (claude-instructions REQ-C1.9); a local doctrine
  shadow is a whole-document fork of a protected doc and is rejected (D-11).
- **Hosted Copilot review on repositories that do not run it.** The Copilot
  entry exists for repositories that already have the reviewer installed.
- **The retrospective's human-process habits** (what an approver reads, how
  the operator reviews drafted replies). Replies to humans are already gated
  by claude-instructions REQ-D1.1; the rest is practice, not skill text.
- **Moving the existing hand-written machine-local files** (the host alias,
  the Slack map, the egress consent record) to 1Password rendering, and the
  ssh renderer's own shape. Recorded as a Deferred generalization.
- **Merging the review skills into one.** They stay separate workflows, as
  claude-instructions decided.
- **The main checkout as a review session location.** `/code-review` runs
  from worktree sessions by design (REQ-E1.6); no rule here governs sessions
  in the primary checkout.

## REQ-A — Reviewer configuration

- **REQ-A1.1** The machine-local review config SHALL describe every hosted
  reviewer with one generic schema: a login pattern; a re-request method, one
  of reviewer request by login, PR comment command with an optional cheaper
  incremental form, or push only; a reviewed-head extractor over the
  reviewer's summary yielding the commit it reviewed; a stable finding-key
  extractor; a summary-marker extractor; a draft policy; an opt-out label;
  and, optionally, a feedback reaction and an errored-review pattern. A
  required field that is missing SHALL stop the run naming the field.
  *(Cites: D-2, research: cubic.dev documentation (Sources), the
  drafting-session survey of the review commands (Sources).)*
- **REQ-A1.2** The tracked example config SHALL become the committed template
  the 1Password renderer fills, every vendor-specific value an `op://`
  reference, and the schema SHALL be checked mechanically: the contract
  checker validates the template's structure, and the renderer validates the
  rendered file against the same rule before it lands.
  *(Cites: D-2, D-13.)*
- **REQ-A1.3** The default reviewer SHALL be the cubic.dev entry, and a GitHub
  Copilot entry SHALL exist for repositories that run that reviewer. No
  tracked file SHALL carry a reviewer's mechanics (login pattern, marker
  syntax, comment command, check name); those live in the 1Password item and
  the rendered machine-local file only.
  *(Cites: D-2, the invocation (Sources).)*
- **REQ-A1.4** When the PR is a draft and the reviewer's draft policy says it
  skips drafts, the skill SHALL say so and name the repository-side setting
  that changes it, and SHALL never wait on a review that cannot arrive; the
  threads already present are still drained.
  *(Cites: D-2, research: cubic.dev documentation (Sources).)*
- **REQ-A1.5** A re-request after a push SHALL use the reviewer's incremental
  form when it offers one; the full form is used on the first request of a
  run and when the operator asks for it.
  *(Cites: D-2, research: cubic.dev documentation (Sources).)*
- **REQ-A1.6** Exactly these machine-local files, the ones this bundle's own
  skills read, SHALL carry a version key: the review config, the
  sibling-repository map, the decision ledger, each evidence record entry,
  each registry entry, and the loop artifact. A reader SHALL refuse a file
  whose version it does not know, naming the file and the version. The
  rendered adopter overlay config is planwright's format and carries no key
  of ours.
  *(Cites: D-6, D-9, D-13, kickoff decision (2026-10-03).)*

## REQ-B — Retire `/copilot-review`

- **REQ-B1.1** The `/copilot-review` skill SHALL be removed, and every
  Copilot-only mechanic it carried that generalizes SHALL move into
  `/bot-review` as a generic step keyed on the reviewer config: the review
  baseline pinned to the reviewed head, the errored-review filter, finding
  suppression as a disposition in the decision ledger (REQ-I1.1), and the
  diminishing-returns exit.
  *(Cites: D-3, the drafting-session survey of the review commands
  (Sources), kickoff decision (2026-10-03).)*
- **REQ-B1.2** `/bot-review` SHALL never mark a PR ready, for any reviewer;
  the convergence-time ready offer the retired skill carried is not
  reproduced, and the contract checker's pin on that sentence stays.
  *(Cites: D-3, drafting-session decision (2026-10-02).)*
- **REQ-B1.3** `/peer-review` SHALL route every automated-reviewer thread, as
  claude-instructions REQ-D1.5 defines an automated reviewer, to `/bot-review`
  and SHALL name no vendor.
  *(Cites: D-3, specs/claude-instructions (Sources).)*
- **REQ-B1.4** Every reference to the retired skill in the user-global file,
  the repo-root file, the contract checker, the budget guard and the sibling
  skills SHALL be removed or retargeted, and every touched surface's budget
  row SHALL be re-derived by claude-instructions REQ-G1.3's rule.
  *(Cites: D-3, specs/claude-instructions (Sources).)*
- **REQ-B1.5** The opt-in Copilot CLI backend of `/panel-review`, its sandbox
  block, its Brewfile cask, its mise pin, its Linux package-list entry and
  its contract-checker anchors SHALL be removed. A run that names the retired
  backend or the retired skill SHALL stop naming the replacement. A Copilot
  CLI, if ever wanted again, enters as a reviewer entry's `cli` block like
  any other vendor.
  *(Cites: D-4, obs:cc322f22, kickoff decision (2026-10-03).)*

## REQ-C — The cubic.dev CLI as a reviewer backend

- **REQ-C1.1** The cubic.dev entry's `cli` block SHALL run through
  `/panel-review`'s `reviewer:<name>` backend; no new backend kind is added.
  *(Cites: D-5.)*
- **REQ-C1.2** The CLI SHALL be pinned through mise's npm backend in the
  tracked mise configuration on every platform, never through the vendor's
  install script, and the invocation SHALL set the vendor's auto-update and
  commit-tagger opt-outs so the backend never writes git notes or fetches a
  newer binary mid-review.
  *(Cites: D-5, research: cubic.dev documentation (Sources).)*
- **REQ-C1.3** The CLI's API key SHALL be synced from a 1Password item in the
  service-account vault to a 0600 file by the same token helper the Gemini
  key uses, and handed to the CLI only through the reviewer entry's
  `env_allow` at invocation; it SHALL never be exported into interactive
  shells.
  *(Cites: D-5, D-13, drafting-session decision (2026-10-02).)*
- **REQ-C1.4** The reviewer backend SHALL strip mise shim directories from the
  CLI's `PATH` and resolve the CLI's own tools from `HOME`, replacing the
  growing list of override variables.
  *(Cites: D-5, obs:4171e2a2.)*
- **REQ-C1.5** No shell snippet in any review skill or shared markdown file
  SHALL read a bare positional parameter, since Claude Code substitutes
  those literals into skill text; a snippet's helper takes named locals, and
  the contract checker SHALL refuse a bare `$1` through `$9` (any form,
  including an awk field reference) in any skill or shared markdown file.
  Helper scripts on disk are not substituted and take positionals normally.
  *(Cites: D-5, obs:f71ea90c, kickoff decision (2026-10-03).)*
- **REQ-C1.6** The per-repository egress consent SHALL apply to the cubic.dev
  CLI exactly as to any other reviewer binary.
  *(Cites: D-5, the drafting-session survey of the review commands
  (Sources).)*

## REQ-D — Shared evidence

- **REQ-D1.1** A review skill that runs project tooling or a test suite SHALL
  record the command, exit status, start and end times, source (a local run,
  or the CI check run that supplied it), and the captured output under the
  worktree's evidence directory, keyed by the tree hash of the working tree.
  *(Cites: D-6.)*
- **REQ-D1.2** Before running any tooling or suite, a skill SHALL look up the
  record for the current tree hash and command and reuse a hit. The key
  changes whenever tracked, staged, or untracked-and-not-ignored content
  changes, so no time-based staleness rule applies. The full suite's command
  key is the repository's declared test task, and CI evidence is recorded
  under that key. Two lookups that both miss on one tree both run; the
  first to finish records.
  *(Cites: D-6, kickoff decision (2026-10-03).)*
- **REQ-D1.3** A pushed head whose check runs include at least one that
  concluded success and none that concluded failure SHALL count as
  full-suite evidence for that head's tree hash, recorded with the check runs
  as its source. Runs that concluded skipped or neutral are ignored, as
  planwright's CI judge ignores them; a run not yet concluded, or concluded
  cancelled or timed out, is no evidence yet; a head with no check run, or
  with only ignored ones, is no evidence. This diverges from the bar
  planwright places on its own review loop (test-throughput REQ-B1.11,
  Sources); the seed note (REQ-H1.1) carries the divergence and the
  measurements so the upstream amendment decides once.
  *(Cites: D-6, planwright test-throughput D-5 and REQ-B1.11 (Sources),
  kickoff decision (2026-10-03).)*
- **REQ-D1.4** In a nested loop the full suite SHALL run at most once per
  iteration, after that iteration's fixes; each fix SHALL be validated by
  diff-scoped checks (the tests touching the changed files and the linters on
  them). A finding's reproduction never reads the record: validation pass 1
  reproduces.
  *(Cites: D-6, planwright review-effectiveness REQ-D1.3 (Sources).)*
- **REQ-D1.5** The record SHALL never be committed, pushed, or named by path
  in a PR body; it is a cache that dies with the worktree.
  *(Cites: D-6.)*
- **REQ-D1.6** Evidence and inbox writes SHALL use a write route that needs no
  shell redirect.
  *(Cites: D-6, obs:5e7b7107.)*
- **REQ-D1.7** The record's layout SHALL match the tooling-output member of
  planwright's review-effectiveness handoff bundle, so that one can replace
  the other when that bundle lands; any divergence is recorded in the seed
  note.
  *(Cites: D-6, D-17, planwright review-effectiveness D-3 (Sources).)*

## REQ-E — Concurrency and isolation

- **REQ-E1.1** Every review skill, `/peer-review` and `/code-review`
  included, SHALL take one writer lock per repository (the remote's owner
  and name) and PR (per branch before a PR exists) under one lock root
  before any write: applying a fix, committing, pushing, submitting a
  review, posting a reply, resolving a thread, or writing the decision
  ledger; and release it afterwards. Discovery, validation, thread fetching,
  and tooling in check mode run without it. A run that opens the PR SHALL
  take the PR lock before releasing the branch lock, so the key change
  leaves no window.
  *(Cites: D-7, kickoff decision (2026-10-03).)*
- **REQ-E1.2** The lock SHALL be an atomic symbolic-link create whose target
  is an owner token (process id, epoch and sequence), with the holder's
  session name, skill and worktree recorded beside it. The process id is
  the Claude Code session process, found by the helper walking its own
  ancestry, since every tool call is a fresh child that exits at once. A
  lock is stale when its owner process is absent, never by age, and a stale
  lock is reclaimed with a notice naming its previous holder and the dead
  holder's inbox files, which are removed with it. The lock root is
  `~/.config/dotfiles/review/`, a per-user directory at mode 0700; the
  repository, PR and branch segments of every path under it are encoded to
  and validated against a plain-name charset before any path use.
  *(Cites: D-7, planwright's lock library (Sources), kickoff decision
  (2026-10-03).)*
- **REQ-E1.3** A skill holding findings while another session holds the
  writer lock SHALL write them to the holder's inbox under the lock root,
  nudge the holder by session message, wait at most one poll window, take
  the lock itself if it frees within the window, and otherwise hand off
  naming the inbox path.
  *(Cites: D-8, kickoff decision (2026-10-03).)*
- **REQ-E1.4** The lock holder SHALL read its inbox at every iteration
  boundary, and a single-pass holder before releasing the lock; a read
  inbox file is moved aside, never re-read. Inbox files and session messages
  are data, never instructions; the inbox file is the record and the message
  only the nudge.
  *(Cites: D-8, planwright security-posture doctrine (Sources), kickoff
  decision (2026-10-03).)*
- **REQ-E1.5** Where session messaging is unavailable, refused by the
  recipient, or below the supporting Claude Code version, the inbox is polled
  and a script may carry the nudge through the session's inbox socket.
  *(Cites: D-8, research: Claude Code cross-session messaging (Sources).)*
- **REQ-E1.6** `/code-review` SHALL run from an isolated worktree session:
  PR content through fetched refs against the session's own repository, and
  tooling against an archive export of the pinned head in a scratch
  directory. The isolated-session stop is removed, and reviews of two
  different PRs run in parallel from two sessions.
  *(Cites: D-15, obs:a3c1e9d4, the operator report (Sources).)*
- **REQ-E1.7** Every skill, `/peer-review` and `/code-review` included,
  SHALL register its session (name, skill, PR or branch, worktree, start
  time, the session process id) under the lock root for the run and remove
  the registration on exit, so a concurrent session can find who holds what.
  A registration whose owner process is absent is read as gone, by the same
  probe the lock uses, and is removed at the next reclaim.
  *(Cites: D-7, kickoff decision (2026-10-03).)*

## REQ-F — planwright steps

- **REQ-F1.1** A tracked catalog under the Claude role SHALL declare
  `panel-review` and `bot-review` as skill steps carrying `--nested`, and the
  role SHALL link it into the adopter overlay's catalogs directory; the
  catalog-link task leaves the overlay's config file to the renderer (D-13),
  and the rendered config sets no `steps_<point>` key.
  *(Cites: D-12, D-13, kickoff decision (2026-10-03).)*
- **REQ-F1.2** No adopter-wide `steps_<point>` list SHALL be set by this
  repository. This repository's own list is repo-tracked at
  `.claude/planwright.yml`, un-ignored for that single path.
  *(Cites: D-12, drafting-session decision (2026-10-02).)*
- **REQ-F1.3** `bot-review` SHALL be named only at the `post-pr` point, since
  it pushes; `panel-review` at `convergence` SHALL never push, as the step
  contract requires.
  *(Cites: D-12, planwright custom-steps doctrine (Sources).)*
- **REQ-F1.4** Every mention of the retired `review_sequence` knob in the
  dotfiles instruction surfaces SHALL be replaced by the catalog-and-list
  vocabulary.
  *(Cites: D-12, the legacy nested-flag line (Sources).)*

## REQ-G — Credential cleanup

- **REQ-G1.1** The Claude role SHALL remove the GitHub Copilot CLI credential
  directory where it is present, and the role's documentation SHALL state the
  GitHub-side revoke step, since no role declares a Copilot consumer any more.
  *(Cites: D-14, obs:db963454.)*
- **REQ-G1.2** The removal SHALL report changed only when something was
  removed and SHALL touch no other credential directory.
  *(Cites: D-14.)*

## REQ-H — Seed for planwright

- **REQ-H1.1** A pending note SHALL be written into the planwright
  repository's pending-notes directory, in that repository's format,
  carrying at least: the cross-repository contract lens and the premise lens
  as lens-list candidates; the evidence record's shape and where it diverges
  from the review-effectiveness handoff bundle; a measured observation for the
  parallel-steps gate; session messaging as a signal between review passes;
  a structured result for external review steps; and the CI-as-evidence
  divergence from test-throughput REQ-B1.11 with the measurements behind it.
  *(Cites: D-17, the work review retrospective (Sources), kickoff decision
  (2026-10-03).)*
- **REQ-H1.2** The note SHALL carry no vendor mechanics, organization or
  repository names.
  *(Cites: D-2, D-17.)*

## REQ-I — Review-run discipline

- **REQ-I1.1** `/bot-review` SHALL keep a machine-local decision ledger per
  repository and PR: finding key, disposition (fixed, rejected, deferred, or
  suppressed with its reason), evidence summary, head, date, and the posted
  reply's link. It is the only store of finding dispositions, and it is never
  pruned automatically.
  *(Cites: D-9, the work review retrospective (Sources), kickoff decision
  (2026-10-03).)*
- **REQ-I1.2** A finding raised again on the same head with no new information
  (the same finding key and anchor) SHALL receive the recorded reply. A
  finding rejected earlier and raised again on a later head SHALL route to
  Needs sign-off with the earlier rejection attached and "fix" as the
  recommended disposition. A finding fixed earlier and raised again is
  validated afresh as a new finding.
  *(Cites: D-9, the work review retrospective (Sources), kickoff decision
  (2026-10-03).)*
- **REQ-I1.3** A thread resolved as deferred (a valid finding not fixed now)
  SHALL carry in its reply a link to a follow-up record that re-surfaces in
  context: a tracked issue or ticket, a spec task or gated deferral, or an
  Awaiting-input entry. A deferral without one halts the run, and CI cost is
  never an accepted deferral reason. A thread resolved as rejected needs no
  such record; its reply carries the decision and evidence (REQ-I1.8).
  *(Cites: D-9, planwright interaction-style doctrine (Sources), kickoff
  decision (2026-10-03).)*
- **REQ-I1.4** The nested loop SHALL report convergence (no unresolved thread,
  and the reviewer's reviewed head equal to the current head) as a fact and
  hand off every other stop with the
  ledger; it SHALL never declare the PR done, and unattended it parks per the
  pause protocol.
  *(Cites: D-9, the work review retrospective (Sources).)*
- **REQ-I1.5** Before any push carrying fixes made in response to findings,
  the loop SHALL run one scoped discovery pass over the iteration's fix diff
  and record its lens table in the loop artifact; its Auto-applicable
  findings are applied before the push and the rest routed as the loop's
  buckets require.
  *(Cites: D-10, the work review retrospective (Sources), kickoff decision
  (2026-10-03).)*
- **REQ-I1.6** The loop SHALL record the head and merge-base it reviewed
  against; when either moves it SHALL re-validate the PR body's claims and
  flag every screenshot for refresh before calling any evidence current.
  *(Cites: D-10, the work review retrospective (Sources).)*
- **REQ-I1.7** A machine-local sibling-repository map, rendered from
  1Password, SHALL map a consuming repository to its producers' clone paths;
  `/code-review` and `/panel-review` SHALL attach the producer's relevant code
  as context for validation pass 2 whenever the diff consumes a shape from a
  mapped producer, that is, imports, calls, or parses a type, schema,
  endpoint or message the producer defines.
  *(Cites: D-11, D-13, the work review retrospective (Sources), kickoff
  decision (2026-10-03).)*
- **REQ-I1.8** A reply posted to an automated reviewer SHALL state the
  decision and its evidence in one paragraph, so a reviewer that learns from
  replies records the rule rather than the instance.
  *(Cites: D-9, research: cubic.dev documentation (Sources).)*

## Changelog

- 2026-10-03 — Kickoff sign-off lens pass: the writer lock covers every
  write (fix, commit, push, review submission, reply, resolve, ledger) and
  names the session process as owner; the suppressed-findings list folds
  into the decision ledger as a disposition; CI-as-evidence records its
  divergence from planwright's bar; retention decided (ledgers kept,
  dead inboxes and registrations pruned at reclaim); stragglers,
  ambiguities, citation labels and Done-when gaps the lenses found are
  reconciled across all four files.
- 2026-10-03 — Kickoff walkthrough edits: the writer lock becomes an atomic
  symlink create with owner-liveness staleness and a named root (REQ-E1.2,
  D-7); a run opening the PR hands its branch lock over (REQ-E1.1); CI
  evidence follows planwright's judge on skipped and neutral runs
  (REQ-D1.3, D-6); the follow-up-record rule applies to deferrals only
  (REQ-I1.3, D-9); task deliverables gain the lock-root table row, the loop
  artifact, the vendor-mechanics sentence, the ignore-rule rework and the
  planwright `/spec-draft` prompt; `test-spec.md` states verification
  ownership (suites wired into CI by their task, command-shaped entries as
  branch Done-whens, the identifier check manual) and retags REQ-A1.3 and
  REQ-H1.2 accordingly. The decision-domains gap check added REQ-A1.6 (a
  version key on every rendered file and machine-local record) and the
  renderer's overwrite rule with its operator review step (D-13, Task 2).
- 2026-10-02 — Bundle drafted via `/spec-draft`. Fold-detection found
  `specs/claude-instructions` overlapping on the review skills; the spin-new
  triggers fired (a new external interface, orthogonal decisions) and the
  bundle depends on that spec's Task 2 instead of extending it.

## Sources

- **The invocation (2026-10-02).** The request to revamp the review skills
  for performance, let them communicate across sessions so they can run in
  parallel and share test results while each keeps its own context, drop
  `/copilot-review` into the existing skills, and adopt cubic.dev, keeping
  Copilot only for repositories that run it.
- **Altitude seed claims (2026-10-02).** The invocation's framing of
  isolation-with-communication as a capability and of the rest as a revamp.
  Pinned during seed gathering; resolved in D-1.
- **The work review retrospective (2026-10-02).** A retrospective over about
  a dozen recent work PRs, offered by the operator with specifics removed:
  the three uncovered holes (cross-repository truth, the premise, time), the
  run-discipline failures (a loop that never settles, positions shifting
  under repetition, fixes shipped unreviewed, deferrals without trace), and
  its pipeline proposals. Organization and repository names are not
  recorded here.
- **The operator report (2026-10-02).** A session transcript showing
  `/code-review` stopping at pre-flight in an isolated worktree session on a
  work repository, and the operator's workaround of checking the PR out in
  that worktree. Path, organization and repository are not recorded here.
- **The drafting-session survey of the review commands (2026-10-02).** A
  read-only survey of the review command files, the contract checker and the
  budget guard: phases, duplicated contract text, every tooling run and its
  lack of caching, isolation mechanics, Copilot references, the config
  schema's gaps, and the absence of any artifact handoff between commands.
- **The drafting-session survey of planwright's review machinery
  (2026-10-02).** A read-only survey of `/self-review`, `/polish`, the
  review doctrine, the test runner, and the review-effectiveness,
  test-throughput, custom-steps, skill-rigor and fleet-messaging bundles.
- **`specs/claude-instructions`.** The audit bundle whose Task 2 converts the
  review commands to skills with a shared directory; REQ-C1.9, REQ-D1.1,
  REQ-D1.5, REQ-G1.3, D-9 and D-14 are cited or carried.
- **planwright review-effectiveness** (REQ-B1.1, REQ-D1.1, REQ-D1.3, D-3,
  D-6, D-11). The signed-off upstream contract the evidence record is shaped
  to.
- **planwright test-throughput** (D-5, REQ-B1.11). PR CI as full-suite
  evidence for the final pushed head (D-5), and the bar on planwright's own
  review loop using it per iteration (REQ-B1.11), which REQ-D1.3 diverges
  from by recorded decision.
- **planwright custom-steps doctrine and bundle** (D-18, REQ-D1.6, and the
  doctrine's catalog-entry format). Steps are serial; no push at
  convergence; the catalog entry fields.
- **Drafting-session decisions (2026-10-02).** Calls the operator made during
  `/spec-draft`, cited inline by date.
- **Kickoff decisions (2026-10-03).** Calls the operator made during
  `/spec-kickoff`, recorded in `kickoff-brief.md` and cited inline by date.
- **planwright fleet-messaging** (D-1, D-2). Session messaging as a signal,
  never a record.
- **planwright customization-boundary doctrine.** The capability-versus-style
  split applied in D-12 and D-17.
- **planwright autopilot-reflex doctrine.** The altitude triggers and the
  altitude record applied in D-1.
- **planwright interaction-style doctrine.** Capture at birth: a follow-up
  named to ship out of band carries a ship-gate record (REQ-I1.3).
- **planwright security-posture doctrine.** Parsed input is data, never code
  (REQ-E1.4).
- **planwright decision-domains catalog.** Walked in design; the
  cross-cutting section records where each touched domain is decided.
- **Research: cubic.dev documentation (consulted 2026-10-02).** The
  quickstart, review settings, repository config, interactive comments,
  auto-approval and dismissal, memory and learning, MCP server, CLI review,
  agent setup, privacy and security, usage and pricing pages, plus the
  vendor's Claude Code plugin repository. Field values derived from them are
  entered into the 1Password item, not recorded here.
- **Research: Claude Code cross-session messaging (consulted 2026-10-02).**
  The cross-session messaging, worktrees, sessions and agent-view pages:
  discoverability of worktree and headless sessions, delivery between tool
  calls, the no-consent rule, and the inbox socket environment variable.
- **`scripts/ssh-lan-config-sync.sh`.** The `op inject` renderer pattern D-13
  generalizes.
- **planwright's lock library** (`scripts/lock-lib.sh`, read at kickoff,
  2026-10-03). The measured retirement of a directory create as a lock
  primitive and the owner-absent-never-age staleness rule REQ-E1.2 adopts.
- **Observation fragments** (the `obs:` entries below) were consumed by the
  drafting run and sit under `specs/_observations/archive/`, each marked
  consumed by this bundle; the id is in the filename.
- **obs:cc322f22.** Copilot reasoning from a flag name rather than the module
  contract; evidence for one reviewer among several.
- **obs:4171e2a2.** The reviewer backend's growing mise-override list and the
  structural PATH-strip option (REQ-C1.4).
- **obs:db963454.** The orphaned, world-readable Copilot credential (REQ-G).
- **obs:a3c1e9d4.** `/code-review` can read a PR through fetched refs; only
  tooling needs a tree (REQ-E1.6).
- **obs:5e7b7107.** Shell redirects trip a separate permission check in auto
  mode (REQ-D1.6).
- **obs:f71ea90c.** Positional parameters are substituted into command files
  (REQ-C1.5).
- **The legacy nested-flag line (2026-07-14).** The frozen observations line
  recording why the pairing commands folded into `--nested` and the
  `review_sequence` claim that knob's retirement makes stale (REQ-F1.4).
