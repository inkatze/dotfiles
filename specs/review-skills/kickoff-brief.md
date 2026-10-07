# Review Skills — Kickoff Brief

## 1. Header

- **Spec path:** `specs/review-skills`
- **Spec commit at walkthrough start:** `206481e`
- **Walkthrough date:** 2026-10-02
- **Mode:** first activation (Status Draft, no prior brief)
- **Validator outcome (pre-flight):** `spec-validate.sh` reported 0 errors,
  0 warnings on the Draft bundle.
- **Config:** `commit_on_kickoff` true, `mark_spec_pr_ready_on_kickoff` true,
  `kickoff_ready_ci_wait` 10m (all defaults; no repo-local override file).
- **Working location:** branch `planwright/review-skills/spec`, in the
  worktree `/spec-review` under the repo's worktrees directory. The D-37 name
  would be `review-skills-spec`; the branch is the spec branch and the tree
  was clean at start, so the walk proceeds here. The naming drift was
  already recorded by the drafting run.
- **External precondition at start:** `specs/claude-instructions` Task 2
  (the skills conversion) has no PR yet, so the three Awaiting-input parks in
  `tasks.md` are current.
- **Decision/transcript log:** run-local JSON Lines in the session
  scratchpad; not committed.

## 2. Goal & glossary

**Restatement.** Four strands over the review skills tracked under the Claude
role, after they convert to the skills layout:

1. *Evidence once per tree state.* Whichever skill runs tooling or the suite
   first records it under the worktree, keyed by an exact tree hash; later
   skills and iterations reuse it. A green pushed head counts as suite
   evidence.
2. *Concurrent read, single writer.* One lock root, one writer lock per
   repository and PR, a session registry, and an inbox file plus a
   session-message nudge so a finder hands findings to the writer.
   `/code-review` stops needing a second worktree.
3. *One hosted-bot drain.* `/copilot-review` and the Copilot CLI backend go
   away; `/bot-review` is driven by a generic per-reviewer schema rendered
   from 1Password, cubic.dev default, Copilot as a second entry; cubic's CLI
   runs as a `reviewer:<name>` backend.
4. *Run discipline from the retrospective.* A per-PR decision ledger,
   tracker-linked deferrals, operator-owned stop, one scoped lens pass per
   push, staleness re-validation, and a sibling-repository map for
   cross-repository validation.

**What it rules out.** Touching planwright core from here; adding lenses to
the dotfiles skills; hosted Copilot where a repository does not run it; the
retrospective's human habits; migrating the older hand-written machine-local
files; merging the skills; rules for sessions in the primary checkout.

**What it assumes.** `specs/claude-instructions` Task 2 merges first (the
skills tree and shared reference directory exist on `main`); Claude Code
session messaging is available at the version D-8 names; the 1Password
service-account vault holds the new items; planwright's handoff bundle and
custom-steps catalog are the upstream seams the local stand-ins mirror.

**How planwright is handled** (operator asked). The bundle keeps planwright
core untouched and does three things: ships local stand-ins shaped to
planwright's signed-off contracts (D-1, D-6, D-8), registers the dotfiles
skills as planwright steps through the adopter catalog (D-12), and seeds the
planwright-owned items (two lens candidates, the evidence-contract
convergence, the parallel-steps gate, messaging between passes, structured
external-step results) as one pending note in planwright's repository (D-17,
Task 9). Replacing the evidence record with planwright's handoff bundle is a
gated Deferred item.

**Implicit terms and resolutions.**

| Term | Where used | Resolution |
| --- | --- | --- |
| lock root | REQ-E1.1, E1.2, E1.3, E1.7, D-7 | `~/.config/dotfiles/review/`, beside the D-9 ledger; a row in the machine-local files table. Operator decision. |
| "the shared staleness threshold" | REQ-E1.2, D-7 | No referent: planwright's lock library retired `mkdir` after measuring exclusion loss on reacquire and defines stale as the owner process being absent, never an age. Operator decision: the lock is an atomic symlink create whose target is an owner token; stale means the owner is gone. REQ-E1.2 and D-7 amended (edit list, section 3). |
| poll window | REQ-E1.3 | A constant defined once in Task 1's shared reference file, cited by the skills, never copied. |
| pause protocol | REQ-I1.4 | planwright gate-wiring's pause protocol; applies when `/bot-review` runs as a planwright step. A standalone unattended run hands off instead. |
| loop artifact | REQ-I1.5, I1.6, test-spec | A worktree-local file under `.claude/`, beside the evidence record, defined in Task 1's shared file. Today's nested loops write no re-readable record. |
| shared reference directory, skills tree | throughout | Whatever `specs/claude-instructions` Task 2 lays out; not re-defined here. |
| identifier check | test-spec REQ-A1.3, H1.2 | The retired identifier-rules generator, run by hand on the host holding the identifier file; never wired into a hook (repo-root `CLAUDE.md`). |
| reviewed head | REQ-A1.1, B1.1 | The commit a hosted reviewer's summary says it reviewed. |

**Operator's note on the restatement:** matches, with the planwright
question answered above.

Signed off: 2026-10-03

## 3. Requirements walkthrough

Per-group outcomes. Edits were applied in place (Draft bundle) and are
listed once at the end of this section.

| Group | Intent (restated) | Outcome |
| --- | --- | --- |
| A — Reviewer configuration | One schema describes any hosted reviewer; values live in 1Password and the rendered file, never in a tracked file; cubic.dev default, Copilot second. | Confirmed. The reviewed-head extractor stays required (both adopted vendors expose the reviewed commit). The template's default names an entry, so the existing "no vendor name is committed" sentence narrows to vendor *mechanics* (edit 5). |
| B — Retire `/copilot-review` | Its generalizable mechanics move into `/bot-review` as config-driven steps; its mark-ready offer dies with it; every reference retargeted. | Confirmed, no edit. |
| C — cubic.dev CLI backend | Runs through the existing `reviewer:<name>` path, mise-pinned, key from 1Password via the shared token helper, shim-stripped PATH, no bare positionals. | Confirmed. "Every platform" resolves to the cross-platform mise file under the environments role. The positional rule reaches awk: Claude Code substitutes `$1` literals in skill files, so awk fields take the `$(1)` form. |
| D — Shared evidence | Tooling and suite results recorded once per exact tree state and reused; green CI counts. | Operator decision: CI evidence follows planwright's judge, ignoring skipped and neutral runs (edit 3). Tool-version staleness under an exact tree key is an accepted risk (register). |
| E — Concurrency and isolation | Reads run concurrently; one writer lock per repository and PR; inbox plus nudge; registry; worktree-free `/code-review`. | Operator decisions: lock root `~/.config/dotfiles/review/`; atomic symlink lock with owner-liveness staleness (edit 1); branch-to-PR lock handover (edit 2); a dead session's registration reads as gone (edit 7). |
| F — planwright steps | Catalog under the Claude role, linked into the adopter overlay; per-repository list only; `bot-review` at post-pr only. | Confirmed. Constraint recorded: the root ignore rule excludes the whole `.claude/` directory and git never re-includes a file under an excluded directory, so the rule becomes a contents rule plus a negation (edit 8). |
| G — Credential cleanup | Role task removes the Copilot credential directory, changed only on removal, revoke step documented. | Confirmed, no edit. |
| H — Seed for planwright | One pending note in planwright's format, no vendor mechanics or private names. | Confirmed. Operator asked for a paste-ready `/spec-draft` prompt; added as a Task 9 deliverable (edit 9). |
| I — Review-run discipline | Ledger, re-raise rules, follow-up-linked deferrals, operator-owned stop, per-push lens pass, staleness re-validation, sibling map, decision-plus-evidence replies. | Operator decision: the follow-up-record rule applies to deferrals only, and the record may be a ticket, a spec task or gated deferral, or an Awaiting-input entry; rejections carry decision plus evidence (edit 4). A producer clone at a stale commit is a register row. |

**Consolidated spec edits (applied 2026-10-03):**

1. REQ-E1.2, D-7: the writer lock is an atomic symlink create whose target is
   an owner token; stale means the owner process is absent, never an age;
   the lock root is named; path segments are encoded before validation.
   `requirements.md` Sources gains planwright's lock library.
2. REQ-E1.1, D-7: a run that opens the PR takes the PR lock before releasing
   the branch lock; test-spec REQ-E1.1 pins the sentence.
3. REQ-D1.3, D-6: at least one success and no failure; skipped and neutral
   ignored; test-spec REQ-D1.3 gains the skipped-beside-success and
   failed-run cases.
4. REQ-I1.3, D-9 (title and decision): deferrals carry a follow-up record of
   any ship-gate kind; rejections carry decision plus evidence; test-spec
   REQ-I1.3 and Task 3's Done-when updated.
5. Task 2 deliverables: the no-vendor-name sentence in both instruction files
   narrows to vendor mechanics.
6. Task 1 deliverables and Done-when: the lock contract's new terms, the lock
   root's table row, the poll window constant, the loop artifact's location
   and shape; liveness-based reclaim in the fixture.
7. REQ-E1.7 and its test-spec entry: a registration whose owner is absent
   reads as gone.
8. Task 8 deliverables: the ignore-rule rework stated.
9. Task 9 deliverables and Done-when: the paste-ready `/spec-draft` prompt.
10. `requirements.md` Changelog entry for the above.
11. (From section 5.) `test-spec.md` preamble: verification ownership rules;
    REQ-A1.3 and REQ-H1.2 retagged.
12. (From section 7.) REQ-A1.6 minted with its test-spec entry and task
    citations; D-13 gains the overwrite rule and the version-key sentence;
    Task 2 gains the operator review step; the design's cross-cutting walk
    now decides versioning; Changelog extended.

**Mid-walk delta-scoped lens pass** (inline; the delta is nine localized
edits, so no fan-out). Walked all nine lenses over the delta and its
dependents. Findings: cross-file consistency surfaced that REQ-E1.7's
registry had no liveness rule after the lock gained one (applied as edit 7);
naming surfaced D-9's title still saying "tracker-linked" (applied in edit
4). Error-handling note for Task 1, no spec change: the liveness probe reads
a permission error on the signal as alive, as planwright's library does.
The remaining lenses returned no finding on the delta. Validator after the
edits: 0 errors, 0 warnings. Stale-reference sweep for the replaced terms
(directory create, staleness threshold, tracker link, every-run-success)
found only the rejected alternative that names them on purpose.

Signed off: 2026-10-03

## 4. Design walkthrough

Every decision in `design.md` accounted for. No decision contradicts a
walked requirement; no inconsistency halt was raised.

| D-ID | Disposition | Note |
| --- | --- | --- |
| D-1 | confirmed | The altitude record; cited from the goal. Checked again at sign-off. |
| D-2 | confirmed | The "no vendor name" sentence in the instruction files narrows to mechanics (section 3, edit 5); the decision text already says so. |
| D-3 | confirmed | Mark-ready offer not carried; consistent with REQ-B1.2. |
| D-4 | confirmed | |
| D-5 | confirmed | License confirmed at pin time stays a Task 5 step. |
| D-6 | amended | CI evidence rule follows planwright's judge (skipped and neutral ignored). |
| D-7 | amended | Atomic symlink lock, owner token, liveness staleness, named root, branch-to-PR handover; new rejected alternative records the directory-create-plus-age rule. |
| D-8 | confirmed | Names a Claude Code version floor; the host walking this spec runs a later version, so the floor is met here and is a Task 6 pre-flight check elsewhere. |
| D-9 | amended | Title and decision: follow-up-linked deferrals of any ship-gate kind; rejections carry decision plus evidence. |
| D-10 | confirmed | |
| D-11 | confirmed | |
| D-12 | confirmed | |
| D-13 | confirmed | |
| D-14 | confirmed | |
| D-15 | confirmed | The archive export's tree is the pinned head's own tree, so the evidence key for `/code-review` needs no temporary index. Implementation note for Task 7. |
| D-16 | confirmed | The parks are current: the conversion task has no PR yet. |
| D-17 | confirmed | Carried from claude-instructions D-9, which resolves. |
| D-18 | confirmed | Carried from claude-instructions D-14, which resolves. |

Reconciled ledger: three amended, the rest confirmed, none superseded. The
cross-cutting decision-domains walk in `design.md` stays accurate after the
amendments (concurrency still D-7 and D-8; caching still D-6).

Signed off: 2026-10-03

## 5. Verification approach

**Coverage mix.** The tag mix is derived from `test-spec.md`'s entry
headings (counted at the walk, not copied here): most entries are `[test]`
or `[test + manual]`, a handful are `[manual]` only (real PR, real reviewer,
second session, 1Password host), and the planwright note and the upstream
layout match are `[design-level]`.

**Ownership.** `[test]` fixture suites and contract-checker pins run in the
repository's CI workflow (the `lint` and `skill-contracts` jobs name each
suite explicitly) and under lefthook before each commit; the Ansible task
fixture for the credential removal runs where the `test` matrix already
runs the playbook. `[manual]` entries are swept into Task 10's verification
table and by planwright's drain pass manual inventory afterwards.

**Dead paths found and fixed.** Three verification paths named something CI
cannot run as written:

- the identifier check (REQ-A1.3, REQ-H1.2) is the retired generator, run
  by hand on one host; both entries retagged so the manual half is explicit;
- `[test]` entries that name a command rather than a fixture (a `grep`, a
  `git check-ignore`, a `mise ls`) had no stated runner; they are now the
  owning task's branch Done-when, run from the worktree and recorded in the
  task PR;
- new fixture suites are not picked up by CI automatically, since the
  workflow lists each suite; the task that creates a suite now wires it in.

All three are recorded as rules in the test-spec preamble (edit 11 of the
consolidated list; the Changelog entry names it). No requirement is left
without a runnable path.

Signed off: 2026-10-03

## 6. Task graph

Reconstructed from the `Dependencies:` lines by planwright's graph script;
the lines are authoritative and any drawing is derived.

- **Roots (no dependencies):** Tasks 1, 2, 4, 9.
- **Second wave:** Task 3 (after 1 and 2), Task 5 (after 2), Task 7 (after 1).
- **Third wave:** Task 6 (after 1 and 3), Task 8 (after 3).
- **Terminal:** Task 10 (after 3, 5, 6, 7, 8).

**Critical path** (effort-weighted, per the `Estimated effort:` lines):
Task 1 → Task 3 → Task 6 → Task 10. The graph script reports the same
chain. Tasks 2, 4 and 9 run beside Task 1; Tasks 5 and 7 beside Task 3;
Task 8 beside Task 6.

**Parks and the external gate.** Tasks 1, 2 and 4 sit under Awaiting input
until the skills conversion merges; Task 9 is Deferred to the planwright
repository. Since every other task descends from 1 or 2 (or is Task 9), the
whole bundle effectively waits on that merge; the operator unparks by
removing the three bullets.

**Deliberate non-edges**, so nobody adds them later:

- Task 4 (retire the Copilot CLI backend) does not depend on Task 3 (retire
  `/copilot-review`): they remove different things and merge in either order.
- Task 5 (cubic CLI) does not depend on Task 4 though both edit the shared
  backends file: no logical dependency, only a merge-conflict risk the
  second to land resolves.
- Task 7 (evidence reuse, worktree-free `/code-review`) depends on Task 1
  only, not Task 3: it moves `/code-review`'s lock onto the shared root,
  which Task 1 provides.
- Task 9 (planwright note) has no dependency on Tasks 6 or 7 although it
  cites their measurements "where available": the note is written early and
  amended, by design (D-17).
- Task 2 does not depend on Task 1: the renderer and the evidence helper
  share nothing.
- No cross-bundle edge to claude-instructions Task 2: the grammar has no
  foreign-task atom, so the Awaiting-input park carries it (D-16).

Signed off: 2026-10-03

## 7. Risk register

**Decision-domains gap check.** The merged catalog (core seed, no overlay
additions resolved on this host) was walked against the bundle. The
design's cross-cutting walk decides every domain it names. Two domains the
bundle touches were undecided and are now decided by spec edit: versioning
(REQ-A1.6, a version key on every rendered file and machine-local record)
and deploy-and-migration of the existing hand-written review config (D-13's
overwrite rule with the operator review step in Task 2). Existing-seam
reuse: the lock root is minted under the dotfiles config directory rather
than planwright's machine-local state home; the nearest seam was considered
and not used because the skills are dotfiles-owned and the decision ledger
already lives there (row 9 records it).

| # | Risk | Mitigation / early signal |
| --- | --- | --- |
| 1 | The evidence key is the exact tree, so a tool upgrade (a new linter version, a changed Ansible collection) can make a recorded hit stale without the key moving. | Each entry records the tool's version string where cheap to obtain; the operator clears the worktree's evidence directory on a tool change. Signal: a reused hit reports a result a fresh run no longer reproduces. |
| 2 | A producer clone named in the sibling map sits at a stale commit, so pass-2 context contradicts the producer's current main. | The validation record names the producer's HEAD; Task 7 notes when the clone is behind its remote. Signal: a validation cites producer code that differs from the producer's default branch. |
| 3 | Session messaging is unavailable, refused by the recipient, or below the supporting version on a host. | The inbox file is the record; polling and the socket nudge are the fallback (REQ-E1.5). Signal: the handoff reports the nudge undelivered. |
| 4 | The cubic.dev CLI renames its auto-update or commit-tagger opt-outs, or writes git notes despite them. | The reviewer backend's existing worktree-cleanliness guard runs after every reviewer CLI; `git notes list` after a run is a manual check in Task 5. Signal: a non-empty notes list, or a binary version that changed mid-run. |
| 5 | Reworking the root ignore rule to re-include one file changes what `git status` reports under `.claude/`. | The contents rule keeps everything else ignored; REQ-D1.5's porcelain check asserts it. Signal: any `.claude/` path besides the planwright list in `git status`. |
| 6 | Claude Code's worktree-isolation guard refuses compound shell commands that invoke git, and skills run from worktree sessions by design. Observed in this very run. | Helpers are invoked by absolute path with literal arguments, one git call per command, no computed command names. Signal: the guard's refusal text appearing in a skill run. |
| 7 | Process ids are recycled, so an owner token can name a live but unrelated process and a dead lock stands. | The token's epoch is compared to the process start time where the platform allows, as planwright's library does; an unverifiable case errs to alive. Signal: a lock held by a process whose name is not a Claude session. |
| 8 | A lock holder dies with findings in its inbox, and nobody reads them. | The sender's handoff names the inbox path; the reclaim notice lists the dead holder's inbox files. Signal: inbox files older than their registry entry. |
| 9 | The lock root is a new machine-local surface beside planwright's own state home; two places to look. | Recorded here as the deliberate mint (existing-seam reuse); the machine-local files table carries the row. Signal: a planwright skill needing the same lock. |
| 10 | The skills conversion this bundle is parked on lands with a layout different from the one the deliverables assume. | Unparking is the moment to compare; a changed layout is a delta re-walkthrough, not a silent adjustment. Signal: unpark finds paths the brief does not name. |
| 11 | Dependency adoption: the cubic.dev CLI is a vendor npm package whose license the docs do not state. | D-5's checklist: license confirmed at pin time, diff sent under the existing egress consent, active release cadence checked. Signal: a license field absent from the package at pin time. |

No open question remains; every question raised during the walk was
resolved into a decision or one of the rows above.

Signed off: 2026-10-03

## 8. Sign-off

**Session note.** The session restarted between section 7 and the lens
dispositions; the brief and spec edits on disk were unaffected, the
run-local decision log was restarted from that point, and the operator's
cluster decision given just before the restart was carried forward.

### Lens review pass (first activation, full bundle)

Artifact class: **spec**; lens set per `artifact-lenses` (the code set's
performance, concurrency and error-handling lenses do not apply to prose and
are marked n/a). Fan-out: one read-only sub-agent per lens, eight agents,
each briefed to be exhaustive within its lens with severity pruning
forbidden; the coordinator merged and deduped (a finding under two lenses
is one row with both labels), then ran the self-critique pass. Tooling
grounding: `spec-validate.sh` (0 errors, 0 warnings before and after),
`gitleaks dir` over the bundle (no leaks), `spec-graph.sh` (critical path).

| Lens (spec set) | Findings | Notes |
| --- | --- | --- |
| Contract correctness and internal consistency | 11 | Task 3 deliverable vs amended REQ-I1.3; a tracked sweep for login patterns would violate REQ-A1.3; overlay config both rendered and "untouched"; the F1.2 fixture scope; command checks absent from Done-whens; Task 10's manual rule unsatisfiable for deferred Task 9; `/panel-review --nested` lock "around push"; D-7 title; REQ-A1.6 scope; `/code-review`'s same-PR lock vs D-7; stale `Last reviewed` (handled by the flip). All applied. |
| Ambiguity and interpretation forks | 18 | "Declined" vs rejected; halt scope; any-green-check counts; the full-suite command key; repository identity; which pid; sender behaviour on a freed lock; single-pass inbox read; convergence needs reviewed head; pre-push pass findings; version-key list completeness; REQ-C1.5 vs helper scripts; "consumes a shape"; F1.2 "tracked sources"; grep "only changelog lines"; A1.4 keeps draining. 16 applied by stating the intended reading; 2 declined (below). |
| Citation and coverage integrity | 8 | Every REQ has a test entry and a task citation; every D-ID cited; foreign citations resolve. Applied: `obs:` fragments live in the archive (Sources note); "kickoff decision" and "drafting-session decision" gain Sources entries; REQ-D1.3 now cites test-throughput REQ-B1.11 as the bar it diverges from (operator decision); custom-steps attribution corrected; cited-but-undelivered and delivered-but-uncited items reconciled in Tasks 1, 3, 6, 7, 9, 10; `/peer-review` and `/code-review` gain lock and registration deliverables. |
| Dead verification paths | 8 | Applied: the CI job is "the job able to run it" and lefthook wiring has an owner; the login-pattern sweep is replaced by the manual identifier check plus a template `op://` check; key-sync and PATH fixtures named in Task 5; the Brewfile check becomes a grep over every Brewfile, mise file and package list; `mise ls` replaced by a check of the tracked file; the identifier check moved to post-merge; the step resolver invoked unattended with its explain flag. |
| Decision-domain gaps | 10 | Decided by operator: concurrency (lock covers every write), two finding stores (one ledger, suppression a disposition), retention (ledgers kept, dead inboxes and registrations pruned at reclaim). Applied as stated rules: inbox consumed once; stampede accepted; key rotation is the Gemini pattern; retired names stop naming the replacement; license check at pin time. Declined: captured-output sensitivity (below), handoff comprehension (below). Old-lock coexistence became risk row 12. |
| Testability | 11 | Applied: measurement baselines taken by hand before Task 1, loop artifact gains iteration markers; post-merge results recorded as a PR comment (intro rule); endpoints named; two-PR drill criterion; Tasks 6 and 7 extend Task 1's fixtures; Task 10 depends on Task 4 and scopes its manual rule; pending-note checks become the repository's pre-commit hooks; missing command checks added to Done-whens; `git notes list` compared to its pre-run state. |
| Cross-file consistency | 14 | Applied: the stragglers from the walk's edits; D-7's description of today's locks corrected; the Linux package-list entry added to Task 4; D-5's gemini claim scoped to the Linux host; REQ-E1.5's drill owned by Task 6; Task 10 runs from worktree sessions. |
| Documentation and glossary drift | 9 | Applied: REQ-A1.6's list made exact; "overlay config" disambiguated; the survey's "largest file" claim dated; the Sources id list corrected; "both platforms" removed. Declined: "the five command files" in a dated Sources entry (reworded to drop the count anyway); the `CUBIC` grep revealing an env-var prefix (not a mechanic on REQ-A1.3's list; the vendor name is already committed). No secrets, hostnames, private repository or employer names found. |
| Rendered-content safety | n/a | Nothing in the bundle is rendered into an executing or markup context. |

**Kickoff-specific checks (REQ-H1.3, REQ-L1.4).** Altitude: the Sources pin
an altitude seed claim; D-1 exists, is cited from the goal, and the task
decomposition is mechanism and local value as D-1 claims (skill text,
scripts, role tasks, one operator's config), with the capability seeded
upstream through Task 9: consistent. Ship-gate: every out-of-band item
carries a record (Task 9 a gated Deferred entry; the two generalizations
gated Deferred entries; the three parks Awaiting-input bullets); the
operator steps in Task 2 are task deliverables. No finding.

**Validation.** Each finding took three passes in the spec-class form:
re-reading the cited lines as each consumer (pass 1), convergence across
lenses (pass 2: the eleven items two or more lenses raised independently
were kept without exception), and outside-in checks against the repository
and upstream (pass 3: the CI workflow, lefthook, the command files, the
observations archive, planwright's lock library, test-throughput and
review-effectiveness bundles, the step resolver's usage). The adversarial
pass refuted none of the keep set and resurrected none of the declines.

**Declined findings** (with rationale): merge-base movement vs an unchanged
tree hash (evidence is tree-keyed by design; staleness governs PR-body
claims, not evidence); a version key on inbox files and lock metadata
(consumed-once ephemera and the helper's own files; the exact list is now
stated); captured tooling output holding sensitive data (it stays in the
gitignored worktree directory and is never named in a PR body, per
REQ-D1.5); handoff comprehension (the handoff follows the shared workflow
file's projection rules; nothing novel is rendered).

**Deferred to a named backlog:** none.

### Pre-flip verification

- **Lint.** The repository ships no markdown linter; the applicable gates
  ran: `spec-validate.sh` 0 errors, 0 warnings; `gitleaks dir` over the
  bundle, no leaks; lefthook's pre-commit set runs at commit.
- **Recorded claims re-derived.** D-ID count in the section 4 ledger
  matches `design.md`'s decision headings; every requirement has a
  test-spec entry (counts match); the critical path in section 6 matches
  `spec-graph.sh`'s output after the edits; validator outcome re-run.
- **Enumeration cross-check (REQ-E1.2).** The bundle's remaining counts
  name its own deliverables (the three rendered files and items, the two
  vendors, the two drills) and are owned here; the one count over an
  outside surface (the survey's file count) was converted to a rule-free
  description.

### Risk register addendum

| # | Risk | Mitigation / early signal |
| --- | --- | --- |
| 12 | During rollout a session that loaded the pre-change skill text still takes its old per-skill lock while a new session takes the shared one; neither excludes the other for one session lifetime. | Skills are read at session start, so the window closes at the next restart; Task 6 removes the old locks in the same change. Signal: two commit streams on one PR right after the merge. |

### Sign-off record

First activation signed off 2026-10-03. Draft→Ready flipped and
`Last reviewed:` bumped on all four spec files; validator at Ready: 0
errors, 0 warnings. The operator approved the flip and the terminal
ready-flip of the spec PR.

Class: meaning
Lens-pass: the lens review pass recorded in this section (section 8, spec
lens set, eight-agent fan-out, every finding dispositioned)
Anchor: `9fb5e69210cfe7c3eb3df7c17f04be5d238bdd63` — computed as
`scripts/spec-anchor.sh specs/review-skills`

## 9. Amendment log

### 2026-10-05 — REQ-C1.3 manual check (execute-task review (Task 5))

`test-spec.md`'s manual check for REQ-C1.3 described the key on the
backend's `env -i` line; the implementation keeps it off every argv and hands
it to the CLI on a pipe, which REQ-C1.3's "only through `env_allow` at
invocation" still holds, since the name stays listed there. The check now
verifies the pipe and the absence from every argv. Cites the `requirements.md`
Changelog entry dated 2026-10-05. Requested by the operator during the task's
review.

Class: expression-only
Anchor: `43d79d1bf515c0ea9ee9bc357663e29657506d72` — computed as
`scripts/spec-anchor.sh specs/review-skills`

### 2026-10-06 — Event name made consistent (execute-task review (Task 5))

The REQ-C1.3 amendment's annotation, its Changelog entry and the record
above now name the event the same way, execute-task review (Task 5), so
each is findable from the others. No requirement or check changed. Cites the
`requirements.md` Changelog entry dated 2026-10-05.

Class: expression-only
Anchor: `0f4b82e59484248b93394e552258d3dc4b3d7890` — computed as
`scripts/spec-anchor.sh specs/review-skills`

### 2026-10-06 — Changelog entry for the event-name edit (execute-task review (Task 5))

The event-name edit recorded above changed anchored content without a
Changelog entry of its own; it now has one. Cites the `requirements.md`
Changelog entry dated 2026-10-06.

Class: expression-only
Anchor: `bae5a69b9b609fc8b0a9c8dc095e96797b922356` — computed as
`scripts/spec-anchor.sh specs/review-skills`

### 2026-10-07 — Socket-nudge fallback narrowed (delta re-walkthrough)

**Scope and mode.** Operator-requested delta re-walkthrough. The anchor
matched at pre-flight (no stale content) and the validator reported no
findings; the bundle derives Active (Task 6 in progress), so the
post-merge supersede ritual applies, chosen by the operator over an in-place
amendment. Walked: REQ-E1.5, D-8, the REQ-E1.5 test-spec entry, Task 6 and
Task 10. Worked from the spec branch only; no task branch was touched.

**Trigger.** Task 6's execution research (its risk 13, recorded on the
Task 6 branch) found that Claude Code applies a session's inbound controls
to posts on its inbox socket, so a holder that refuses messages drops the
socket nudge that REQ-E1.5, D-8, the REQ-E1.5 manual check and Task 6's
after-merge Done-when relied on.

**Decision (operator).** Keep the socket nudge, narrowed to a sender that
cannot send a session message; when the holder refused or held the session
message, no socket nudge follows and the holder's inbox read carries the
handoff alone. The lens pass refined the operator's "a send that came back
'Not sent'" trigger: Claude Code's docs return a "Not sent" result that
names the reason, including the recipient's inbound setting, so a "Not
sent" naming the holder's inbound controls is a refusal, not an inability
to send.

**Spec edits.** REQ-E1.5 superseded by REQ-E1.8 and D-8 by D-19, each with
its pointer; REQ-E1.3, REQ-E1.4, D-1 (annotated) and the decision-domains
walk point at D-19; the fleet-messaging Sources entry cites that bundle's
live D-7 and D-16; a Sources entry records the inbound-controls research;
the REQ-E1.8 test-spec entry replaces REQ-E1.5's and is `[test + manual]`;
Task 6's deliverables, Done-whens and citations and Task 10's drills and
citations follow; `Last reviewed:` bumped on all four files. The full list
is the `requirements.md` Changelog entry dated 2026-10-07.

**Re-pointed brief records** (the sections above stay as signed; read them
through this entry):

- Section 2's assumption that messaging is available "at the version D-8
  names", and its D-8 stand-in pointer: now D-19, which carries the 2.1.224
  floor; the Task 6 pre-flight version check stands under D-19.
- Section 4's ledger: D-8 superseded by D-19 (a new decision); the
  concurrency domain now reads D-7 and D-19. Section 8's D-ID cross-check
  is re-derived against `design.md`'s decision headings, not this ledger.
- Section 8's lens table row naming "REQ-E1.5's drill owned by Task 6", and
  its pre-flip note on the drills: Task 6 now owns the two-session,
  socket-nudge and refused-messaging drills, as Task 6's Done-when names
  them.
- Risk 3 is restated here: session messaging unavailable to the sender
  (no tool, below 2.1.224, or "Not sent" for a reason other than the
  holder's inbound controls) → the socket nudge through the review helper,
  a failed post reported in the handoff; the holder refused or held the
  message → no socket nudge, the handoff says so, and the holder's inbox
  read carries it. The inbox file stays the record (REQ-E1.8). Signal: a
  handoff reporting a failed or skipped nudge.

**Lens review pass (delta-scoped, spec class).** Fan-out: one read-only
sub-agent per lens group, six agents, briefed to be exhaustive within the
lens with severity pruning forbidden; the coordinator merged, deduped and
ran the self-critique pass, then validated the pivotal claim against Claude
Code's cross-session messaging documentation. Tooling grounding:
`spec-validate.sh` (no findings before or after), `gitleaks dir` over the
bundle (no leaks), and a read of the Task 6 branch's shared state file and
helper.

| Lens (spec set) | Findings | Notes |
| --- | --- | --- |
| Contract correctness and internal consistency | 5 | "Not sent" fell under both branches; REQ-E1.3's unconditional session message; the single-pass holder dropped; the version floor dropped; D-19's rejected-alternative reasoning contradicted its own premise. Applied. |
| Ambiguity and interpretation forks | 7 | Undefined "held" and inbound controls; who polls; "the helper"; MAY against a drill expecting arrival; where the socket address comes from; unlabelled drills. Applied. A deferred SendMessage tool counting as "cannot send" was declined: the skill text loads deferred tools. |
| Citation and coverage integrity | 5 | D-1's stale pointer; the fleet-messaging entry citing a superseded upstream decision; an unnamed upstream source, replaced by the official documentation; an incomplete Changelog; the no-nudge rule untraced to a check. Applied. Task 1's D-8 citation declined (merged and built under D-8); a Sources entry for the delta re-walkthrough citation declined (the format's citation kind resolves to this entry). |
| Dead verification paths | 4 | The refused drill's sender setup and evidence; the arrival evidence; the version floor on both sessions; the no-nudge rule's contract pin. Applied. A pinned way to remove the SendMessage tool was not adopted: unverified, so the drill confirms the tool's absence instead. |
| Decision-domain gaps | 5 | Observability of a failed or skipped nudge; the socket line's content and owner check (security); the undocumented line format (versioning); existing-seam reuse of fleet-messaging D-7 and D-16. Applied, with the walk updated. |
| Testability | none | Every touched Done-when names its evidence after the dead-path fixes. |
| Cross-file consistency | 3 | The stale brief records above, re-pointed here; the test entry's supersede sentence dropped to match the upstream precedent; `Last reviewed:` bumped. Applied. |
| Documentation and glossary drift | 2 | "Messaging tool" contradicted its own example, renamed "a sender that cannot send a session message"; heading wording aligned. Applied. |
| Rendered-content safety | n/a | The bundle is not rendered into an executing or markup context. |

Overlapping findings are counted once, under the lens that owns the fix.
Kickoff-specific checks: altitude, not applicable to the delta (it changes
a fallback inside D-1's stand-in and moves no altitude call); ship-gate,
none (the delta names no out-of-band fix). Outside this bundle: planwright's
pending seed note still records D-8's fallback, filed as an observation for
Task 9; the Task 6 branch's shared state file treats every "Not sent"
result as an inability to send and must follow REQ-E1.8 there.

Approved by the operator on 2026-10-07 after the approval summary; the
validator reported no findings after the edits.

Class: meaning
Lens-pass: the delta-scoped lens review pass recorded in this entry, every finding dispositioned
Anchor: `65cb1b044278f0d6560884853a24dac38ca044f2` — computed as
`spec-anchor.sh specs/review-skills`
