# Claude Instructions Audit — Kickoff Brief

## Header

- **Spec:** `specs/claude-instructions`
- **Spec commit at walkthrough start:** `13eeedb`
- **Walkthrough date:** 2026-09-25
- **Mode:** first activation
- **Validator (pre-flight):** `spec-validate.sh specs/claude-instructions` — 0 errors, 0 warnings (Draft).
- **Config:** `commit_on_kickoff`, `mark_spec_pr_ready_on_kickoff` and `kickoff_ready_ci_wait` at planwright defaults (no local override file).
- **Working location:** spec branch `planwright/claude-instructions/spec`, in an operator-created worktree whose directory name differs from the planwright convention; that drift is already recorded as an observation on this branch.
- **Decision/transcript log:** no harness-provided log path; the mirror is skipped for this run.

## Goal & glossary

**Restatement.** The bundle turns an instruction set grown by accretion back
into one chosen on purpose. Verdicts were taken during drafting; execution
lands them: diet both `CLAUDE.md` files, convert the review commands into
skills sharing one reference directory, and add a word-budget guard so the
surfaces cannot silently regrow. Everything planwright owns becomes a seed
note for planwright's own drafting, never a local patch or overlay.

**Rules out:** editing planwright core or overlaying it; rewriting frozen
spec bundles for name hygiene; merging the review skills; changing the
spec-content freshness gate; removing the planwright ready-guard hook
locally; machine-local memory files.

**Assumes:** planwright stays installed on every host (the skills resolve
its doctrine at run time); the machine-local inventory remains available to
the executing tasks, and a task that cannot find it says so and re-extracts
(D-13).

**Glossary resolutions.**

- **Instruction surface** — a file the budget guard counts: the user-global
  `CLAUDE.md`, the repo-root `CLAUDE.md`, each review skill, each shared
  reference file (REQ-G1.1). The audit's scope is wider (output style,
  hooks, checker); only these are budgeted.
- **Diet** — reducing a surface to its rules, then re-deriving its
  thresholds per REQ-G1.3 in the same change.
- **Instruction source** — anything that instructs an agent (a skill, a
  hook, a `CLAUDE.md` section); REQ-K1.1's re-check applies to these, a
  wider set than the budgeted surfaces.
- **Mergeable** — GitHub's `mergeable: MERGEABLE` (no conflicts with the
  base). A `BEHIND` merge state does not block a ready flip. A repository
  whose branch protection itself requires up-to-date branches still gates
  the merge on GitHub's side; that is repository configuration, not an
  instruction this bundle governs. Mergeability replaces only the currency
  condition; CI green and the review cadence stay (REQ-A1.1, amended at the
  sign-off lens review).
- **The project repo / the work repos** — neutral labels per D-8; real names
  stay machine-local.
- **Seed note** — a pending note in planwright's pending-notes directory, in
  that repository's format (REQ-I1.1).

Signed off: 2026-09-25

## Requirements walkthrough

**Per-group outcomes.**

- **REQ-A (currency):** confirmed. "Mergeable" means no conflicts (glossary);
  behind-the-base never blocks a ready flip; the kickoff spec-PR flip is the
  one stated exception to the never-flip rule; planwright's ready-guard and
  convergence merge travel as seed items.
- **REQ-B (one doctrine source):** confirmed. The checker's retired-bucket
  sweep exists today (`roles/claude/files/scripts/skill-contracts.sh`) and is
  what REQ-B1.3 removes.
- **REQ-C (skills with shared mechanics):** confirmed. Every file in the
  commands directory is a review command except the bot-review example
  config, which moves beside the bot-review skill (edit 1).
- **REQ-D (outbound messages):** confirmed as written.
- **REQ-E (global diet):** confirmed as written.
- **REQ-F (repo-root diet):** confirmed. The root file is far over the
  claude-context ceiling, so REQ-F1.1 is a large cut. The claude-context
  amendment is widened to clear every validator error (edit 2).
- **REQ-G (budget guard):** inconsistency found and resolved by spec edit:
  REQ-G1.3's rule contradicted REQ-G1.4 and Task 1's initial thresholds.
  Resolution: the rule applies from the guard's first commit and every
  threshold matches it exactly (edit 3).
- **REQ-H, REQ-I, REQ-J:** confirmed as written.
- **REQ-K (re-check):** confirmed; the inventory directory mode is corrected
  (edit 4).

**Consolidated spec-edit list.**

1. `tasks.md` Task 2 deliverables: the bot-review example config moves
   beside that skill's SKILL.md and the repo-root pointer updates.
2. REQ-F1.5, D-7, Task 4 deliverables and done-when, test-spec REQ-F1.5:
   the claude-context amendment adds `**Format-version:** 1` and the three
   mirrored `**Status:**` headers, and succeeds when `spec-validate.sh`
   reports no errors. No self-re-anchor entry, since that bundle has no
   brief.
3. REQ-G1.3, REQ-G1.4, D-5, Task 1 deliverables and done-when, test-spec
   REQ-G1.3: thresholds derive from each surface's declared count by rule
   from the first commit; the fixture fails on any mismatch.
4. D-13 and test-spec REQ-K1.2: the inventory directory is mode 0700 with
   its files at 0600.

**Mid-walk lens (agent-authored meaning-class edits 2 and 3).** Scoped to
each edit and its dependents. Edit 2: a scratch copy of claude-context with
only the added headers validates with zero errors, so declaring a format
version unlocks no further findings; dependents in design, tasks and
test-spec updated. Edit 3: every "post-diet", "current size" and "floor"
phrasing across the bundle swept and aligned; the remaining "lowered per
REQ-G1.3" phrasings describe diet tasks and stay correct. No findings.

Signed off: 2026-09-25

## Design walkthrough

**Reconciled ledger.**

| D-ID | Disposition | Note |
| --- | --- | --- |
| D-1 | Confirmed | Local-value altitude; one repo-local mechanism. |
| D-2 | Confirmed | Doctrine resolved at run time from planwright. |
| D-3 | Confirmed | "Mergeable" pinned in the glossary. |
| D-4 | Amended | Per-entry symlinks into the existing `~/.claude/skills/` (edit 5). |
| D-5 | Amended | Threshold rule from the first commit (edit 3). |
| D-6 | Confirmed | |
| D-7 | Amended | claude-context header repair widened (edit 2). |
| D-8 | Confirmed | |
| D-9 | Confirmed | |
| D-10 | Confirmed | |
| D-11 | Confirmed | |
| D-12 | Confirmed | |
| D-13 | Amended | Inventory directory 0700, files 0600 (edit 4). |
| D-14 | Confirmed | |
| D-15 | Amended | Its distinct nested drain scope stays a recorded override, under REQ-B1.2 (sign-off lens review, L-B1). |

No design decision contradicts a walked requirement.

**Spec edit 5.** REQ-C1.1, D-4, Task 2 deliverables and done-when, test-spec
REQ-C1.1: the skills are materialized as one symlink per tracked skill
directory plus one for `review-shared/`, inside the real
`~/.claude/skills/`, leaving entries this repo does not own untouched. The
whole-directory form the commands surface uses would collide with an
existing, unmanaged subtree there.

**Mid-walk lens (edit 5).** Scoped to materialization and its dependents.
The relative `../review-shared/` links still resolve under per-entry links,
because the shared directory is itself linked beside the skills. Two
consequences carried to the risk register rather than edited: a retired
skill needs an explicit removal task or its link dangles, and the shared
directory appears as an entry without a SKILL.md.

Signed off: 2026-09-25

## Verification approach

**Coverage mix.** Per the tags on each entry in `test-spec.md` and its
intro paragraph: textual requirements verified by the contract checker and
budget guard fixture suites; converted-skill behaviour, cross-repository
requirements and the identifier check carry a manual arm; REQ-K1.1 is
design-level.

**Ownership.**

- `[test]` entries: the GitHub workflow runs lint and the fixture suites on
  every pull request and every push to main (the contract checker's and
  budget guard's suites each run their checker against the tree);
  lefthook runs the checkers locally at pre-commit. CI does not run
  lefthook, and does not run planwright's validator.
- `[manual]` entries: the operator sweeps them. Skill-behaviour checks run
  from the main checkout after merge, since a worktree cannot exercise a
  changed skill through the tool. Cross-repository checks (REQ-H, REQ-I,
  REQ-J) run on the host where they land.

**Dead-path check.**

- The name check (REQ-C1.8, REQ-J1.2) was tagged `[test]` but passes
  vacuously in CI, which holds no identifier file. Retagged
  `[test + manual]` with a manual run on a host holding the file at review
  of Tasks 2, 3 and 4 (edit 7); the sign-off lens review added a synthetic
  fixture so CI proves the mechanism, and made CI warn instead of passing
  silently (L-D1).
- The test-spec intro claimed CI runs lefthook's checks; corrected to what
  the workflow runs (edit 6, expression-only).
- REQ-C1.1's Ansible `--check` run is not part of CI; the syntax check is.
  The entry already offers the host run as the alternative, so it is not
  dead.
- REQ-B1.4's budget arm is weak on its own: the rule leaves headroom above
  the post-diet count, so the threshold alone may not reject re-added
  descriptions. The entry's second arm (each workflow line is a single
  bullet) carries it. No edit.

Signed off: 2026-09-25

## Task graph

**Graph.** Reconstructed from the `Dependencies:` lines in `tasks.md`
(authoritative). After edit 8, Task 1 is the root; Task 2 follows it; Tasks
3 and 4 each follow Tasks 1 and 2 and run in parallel with each other; Task
7 follows Tasks 2 and 3. Tasks 5 and 6 have no dependencies.

**Dispatchable from this checkout:** Tasks 1 to 4. Tasks 5, 6 and 7 are
parked under `## Deferred` with free-text gates and run by hand where they
land (see `tasks.md`).

**Critical path.** Effort-weighted from each task's `Estimated effort:`
line, over the tasks dispatchable here: Task 1, then Task 2, then Task 3
or Task 4, which tie. Deferred Task 7 follows Task 3 on the work host and
is outside this path.

**Edge added (edit 8).** Task 4 now depends on Task 2: both edit the
repo-root `CLAUDE.md` and the budget script's thresholds, so Task 4 diets a
file that already carries Task 2's skills wording instead of racing it.

**Deliberate non-edges (do not "fix").**

- Task 3 and Task 4 stay parallel: they edit different files (user-global
  vs repo-root `CLAUDE.md`), and REQ-F1.4's duplication check is a review
  of Task 4 against whichever global file is current.
- Task 5 and Task 6 depend on nothing: they land in other repositories and
  do not read this repository's results.
- Task 7 does not depend on Task 4: the work repos see the user-global file
  and the skills, not this repository's root file.

Signed off: 2026-09-25

## Risk register

**Decision-domains gap check.** Walked the merged catalog
(`resolve-catalog.sh decision-domains`, seed domains only, no overlay
additions) against the bundle. Domains the bundle touches and decides:
secrets and configuration (D-6, D-8, D-13), LLM output quality (D-5, D-14),
human comprehension (D-2, D-7), existing-seam reuse (D-2, D-5), dependency
adoption (none new). Touched but undecided, now resolved or carried here:

- **Observability / existing-seam reuse:** how a skill locates planwright
  and what it does when a doctrine document does not resolve. Resolved at
  kickoff by minting REQ-B1.6 (edit 9): one root resolution, halt naming
  the document on a miss. The sign-off lens review changed the resolution
  from the newest cached version to the enabled version (L-C6).
- **Deploy and migration:** the commands-to-skills cutover changes a
  materialized surface on every host. Carried as risk 1.

The remaining catalog domains (data storage, caching, queues, API surface,
auth, concurrency, versioning, product, pricing, knowledge engineering,
organization design, IP posture) are not touched.

**Mid-walk lens (edit 9).** Scoped to REQ-B1.6 and its dependents: paired
test-spec entry added in the same edit; Task 2 cites it and carries it in
its deliverables. No findings.

| # | Risk | Mitigation / early signal |
| --- | --- | --- |
| 1 | Between pulling the merged Task 2 and running Ansible on a host, the commands directory is gone and the skills are not yet linked, so the review workflows are unavailable there. | Run the Claude role on each host right after pulling; rollback is a revert plus the same run (D-4). Early signal: a review slash command missing in a fresh session. |
| 2 | The shared directory sits in `~/.claude/skills/` without a SKILL.md. | The link task prunes its own dangling links (D-4, L-F2), which covers retired skills. Early signal: a load warning on the shared directory. |
| 3 | Pointing at planwright's doctrine means an upstream doctrine change alters the dotfiles skills' behaviour with no change in this repository. | Accepted by D-2's design. REQ-B1.6 makes a renamed or removed document halt visibly instead of drifting. Early signal: a halt after a plugin update. |
| 4 | The repo-root diet (REQ-F1.1) is a large cut and may drop an actionable rule along with the rationale. | Task 4's done-when fresh-session questions; relocated rationale stays browsable under `docs/`. Early signal: a session in this repo asking something the old file answered. |
| 5 | The inventory is a dated snapshot (D-13); the files it describes move while the tasks run. | Each task re-reads its surface before acting and treats inventory rows as leads, not truth; REQ-K1.1 re-check for new surfaces. Early signal: a row naming text no longer in the file. |
| 6 | Checker pins lag a reworded sentence, failing the commit, or worse, a pin gets loosened to pass. | The same-commit rule for checker and fixture updates (repo-root `CLAUDE.md`). Early signal: a contract-checker failure on a diet commit. |
| 7 | The contract checker has one known nondeterministic failure (obs:9d53b50c); moving it to the new layout can make that flake look like a regression. | Reproduce any failure twice before acting on it. Early signal: a failure that does not repeat. |
| 8 | An external project or employer name reaches a committed file: a task PR, a docs note, or this brief. | D-8 neutral labels; the identifier check run on a host holding the identifier file at review of Tasks 2, 3 and 4 (edit 7, L-D1). |
| 9 | Tasks 5, 6 and 7 run by hand elsewhere and could be forgotten. | Each is a `## Deferred` entry with a gate in `tasks.md`, surfaced by the drain pass. Early signal: the bundle never derives Done. |
| 10 | Skill-behaviour checks cannot run from a worktree, so a broken skill surfaces only after merge. | Post-merge checks run from the main checkout right after each merge and are recorded on the merged PR (`tasks.md` intro). Early signal: a merged PR with no post-merge record. |
| 11 | A skill run in progress when the main checkout moves can load an old SKILL.md with a new shared file, since shared files load lazily. | Low stake, accepted. Early signal: a step citing a shared anchor that is not there. |
| 12 | After Task 3, the unchanged planwright ready-guard still denies flips the new rule allows. | REQ-A1.5: report, never work around; the fix travels in Task 6's note. Early signal: a hook denial on a mergeable branch. |
| 13 | This kickoff ran on planwright 0.44.0 doctrine while 0.46.0 is enabled on this host. | Recorded as an observation; the executing tasks resolve the enabled version (REQ-B1.6). Early signal: a doctrine rule the tasks cite that differs from what this brief assumed. |

No open questions remain: each is either decided in the spec or accepted
above.

Signed off: 2026-09-25

## Sign-off

### Lens review (first activation, full bundle)

Artifact class: **spec** (planwright `artifact-lenses`, spec set). Path:
fan-out, one read-only agent per lens, merged and deduped by the
coordinator, then a self-critique pass. Tooling shared with every lens:
`spec-validate.sh` 0 errors, 0 warnings.

| Lens | Findings | Notes |
| --- | --- | --- |
| Contract correctness and internal consistency | L-A1, L-B1, L-B2, L-B3, L-B4, L-E1, L-E3, L-E4, L-E5, L-E6 | Ready-flip rule scope; four-bucket adoption scope; lens-list copy vs no-copy; task ownership of checks. |
| Ambiguity and interpretation forks | L-B1, L-B3, L-B4, L-B5, L-B7, L-C3, L-C4, L-D1, L-E1, L-E2, L-E4, L-F2, L-F3, L-F4 | Per-skill taxonomy and drain scope, posted-body rule, denylist spec, threshold formula, link list vs glob. |
| Citation and coverage integrity | L-E1, L-E6, L-E8 | Wrong or missing obs cites, uncited Sources, task citation gaps. |
| Dead verification paths | L-B4, L-D1, L-E5, L-E6, L-E7, L-E10 | Fixture cases and checker classes no task owned; vacuous pins; post-merge-only checks. |
| Decision-domain gaps | L-A2, L-A3, L-C3, L-C4, L-D1, L-D3, L-D4, L-E2, L-F2, L-F3, L-F5 | Invocation mode, link collision and rollback, unattended outbound messages, identifier file, warning visibility. |
| Testability | L-E1, L-E4, L-E5, L-E6, L-E9, L-E10 | Done-when needing a merge, undefined greps, "lowered" vs re-derived, subjective checks. |
| Cross-file consistency | L-A1, L-B1, L-B2, L-B3, L-B4, L-D1, L-E1, L-E2, L-E5, L-E9, L-F1, L-F4 | Stale-at-Task-2 root tables; claude-context content beyond headers; decision-domains walk vs brief. |
| Documentation and glossary drift | L-D1, L-E7, L-E8, L-E9, L-F1 | Trigger wording, heading count, enumerated counts, term drift. |
| Security (data hygiene, safety gates, rendering) | L-A1, L-A3, L-A4, L-B1, L-B5, L-B6, L-C1, L-C2, L-C4, L-C5, L-C6, L-D1, L-D2, L-E7 | Safety pins and guards through the conversion; outbound exception scope; retired identifier guard; heredoc expansion. |
| Performance | n/a | Nothing in a spec executes. |
| Concurrency / state | n/a | No shared state in a spec; the lazy-load version mix is carried as risk 11. |
| Error handling and failure modes | n/a | No execution path; failure behaviours the bundle governs sit under decision-domain gaps. |

Kickoff-specific checks: **altitude** clean (seed claim pinned in Sources,
D-1 cited from the goal, tasks match local value plus one mechanism);
**ship-gate** one finding (the inventory-directory tightening named only in
prose, merged as L-E7).

Validation (per `validation-rigor`, non-testable class): each merged finding
was re-read against the bundle text, cross-checked for convergence across
lenses, and grounded against the tree for its load-bearing fact (workflow
triggers, the global file's ready conditions and doctrine headings, the
checker's safety pins, the enabled planwright version, the existing
machine-local identifier file, the inventory directory mode). Findings are
merged by decision axis below; dispositions follow.

### Merged findings

The lens outputs, merged and deduped by decision axis. A finding reported
by several lenses appears once, under each lens that reported it in the
table above.

**Cluster A: ready-flip rule scope**

- **L-A1** REQ-A1.1 reads as replacing the whole ready condition set with mergeability; the live rule also requires CI green and the review cadence run, and evaluates at the current head immediately before the flip (unconfirmable counts as unmet, including GitHub's `UNKNOWN`). Tests and Task 3 already assume CI green stays.
- **L-A2** Until planwright's ready-guard changes upstream, the unchanged hook still denies a behind-but-mergeable flip; the bundle does not say what the agent does then.
- **L-A3** D-3's rationale states as fact that the ritual buys nothing; a green result from before the base moved is an accepted gap, and the premise holds only where CI runs on the PR merge ref.
- **L-A4** REQ-A1.3's "one stated exception" vs `/copilot-review --nested`'s operator-confirmed ready flip, pinned by the checker.

**Cluster B: how the skills adopt planwright doctrine**

- **L-B1** REQ-B1.2 has "every" skill adopt four buckets and act-then-review, which conflicts with `/code-review` (severity tiers, never applies to another author's PR), `/peer-review` (Needs-sign-off replies reach humans, REQ-D1.1), `/bot-review --nested` (pinned deferral, D-15), and the current nested drain scopes of `/panel-review` and `/copilot-review`. REQ-C1.6 holds numeric thresholds only, so it cannot carry a drain-scope override.
- **L-B2** REQ-C1.9's test pins a verbatim lens list in the shared directory, which REQ-B1.2 and REQ-B1.6 forbid as a copy; backend prompts need the list at run time.
- **L-B3** REQ-C1.4 limits the lens-coverage table to first and final iterations, against discovery-rigor's record-every-pass rule; "final" is undefined.
- **L-B4** REQ-B1.2's test pins the resolution invocation in every SKILL.md, while REQ-C1.2 and REQ-B1.6 state it once in the shared directory.
- **L-B5** REQ-C1.9 does not name the winning posted-body rule (Write tool vs inline heredoc); untrusted text in an unquoted heredoc expands.
- **L-B6** REQ-C1.9 does not say the single codex form is the contained one (read-only sandbox, prompt on stdin, scratch cwd); the git-check flag is safe only with those.
- **L-B7** The `review_sequence` claim REQ-B1.5 removes from the global file also sits in two skills.

**Cluster C: safety gates through the conversion**

- **L-C1** No requirement keeps the checker's existing safety pins (mark-ready, bot-review safety, severity tiers, retired-backend sweep) through the move; only the retired-bucket sweep is named for removal, and a second code-review guard on the same bucket name exists.
- **L-C2** REQ-C1.2's shared list omits safety mechanics the commands carry today: the untrusted-comment rule, the same-PR lock, the per-repo egress consent, and the outbound-prompt guards; Task 2 also lists a solution-validation block REQ-C1.2 does not.
- **L-C3** Skills are model-invocable by default; a converted review skill that posts to GitHub or Slack could self-trigger. Names and flags are not pinned.
- **L-C4** The outbound-message rule's edges are open: "or run" lets one yes cover unseen messages; "never guess a recipient" moves out of the always-loaded file; which PR actions count as messages; how "automated reviewer" is decided and mixed threads; what an unattended nested run does with a message it would send.
- **L-C5** "Every incident rule at most two lines" could compress the push-safety rules' listed spellings; "line" and the set of incident rules are undefined.
- **L-C6** REQ-B1.6's newest-cached rule is not the enabled version by definition; on this host they coincide.

**Cluster D: names and disclosure**

- **L-D1** The denylist is unspecified (file, format, mode, absence behaviour, echo of matches, owning suite, scan scope) and collides with the retired identifier guard and the existing machine-local identifier file recorded in the repo-root `CLAUDE.md`; REQ-J1.2 as worded is violated by frozen bundles on day one.
- **L-D2** Committed text points readers at where unscrubbed names live and describes private-repo internals more specifically than needed.
- **L-D3** Task 6's seed note and Task 5's PR carry inventory evidence into other repositories with no name check.
- **L-D4** Task 7 treats the operator's call as enough for shared work-repo files and does not say which backend reads employer content.

**Cluster E: task ownership, citations, testability (mechanical)**

- **L-E1** Task 2 does not repoint the budget guard's surfaces and lefthook glob to the skills and shared files, or declare their thresholds; "lowered" does not apply to new surfaces.
- **L-E2** Task 2 leaves stale-at-merge text: the materialization table row, the "skills are not managed" line, the machine-local "Read by" cells, and the global file's commands paths.
- **L-E3** REQ-D1.3's only-here/only-there assertion and the global doctrine-pointer pin depend on Task 3's edits but sit on Task 2.
- **L-E4** Task 2's link done-when forbids the example config link edit 1 introduced.
- **L-E5** The root line ceiling, `docs/` link check and claude-context changelog check are owned by no task; the ceiling figure is copied, and claude-context sets 120 as target and 200 as hard ceiling.
- **L-E6** Checker classes and fixture cases for the `[test]` entries are owned by no task; Task 1's fixture list omits the warn and wiring cases.
- **L-E7** Ship-gate: the inventory directory is 0755 on disk; nothing tightens it to 0700.
- **L-E8** Citation fixes: REQ-B1.5's obs cite does not support it; REQ-I1.2 lacks its observation, inventory and D-3 cites; five Sources are uncited; task citation gaps (D-5, D-6, D-8, D-14, REQ-G1.3/G1.4, REQ-J1.2, REQ-C1.8, REQ-K1.1/K1.2).
- **L-E9** Drift fixes: "every push" vs the workflow's triggers; five doctrine headings, not four; enumerated counts to rules; the design decision-domains walk and cluster ledger behind the brief; D-2 missing REQ-B1.6's content; amended D-IDs without markers; G1.4 test entry; undefined terms; test-spec intro overgeneralized; brief critical-path tie; negative-pin strings not present verbatim.
- **L-E10** Testability rewrites: Done-when items that need a merge split into branch-time and post-merge checks with a recorded location; greps given files and literals; subjective checks given procedures.

**Cluster F: remaining design choices**

- **L-F1** claude-context requires content (a commands section, a tracked settings file) that REQ-C1.1 and REQ-F1.3 make false; fixing it is meaning-class, not the expression-only header repair REQ-F1.5 names.
- **L-F2** Link task policy: collision handling, commands removal only when it is our symlink, rollback, list vs glob.
- **L-F3** Threshold arithmetic and counting: formula at exact multiples, `>` vs `>=`, the word-count method across GNU and BSD, where warnings surface.
- **L-F4** CI placement: a step in the existing contract-checker job, or a new job (the job-naming observation is consumed but undecided).
- **L-F5** Risks to add: mixed-version load of lazily read shared files; hook denial after Task 3.

### Dispositions

The operator chose clustered decisions. Every merged finding above is
dispositioned; none is declined or deferred.

| Findings | Disposition |
| --- | --- |
| L-A1 to L-A4 | Applied as listed: REQ-A1.1 reworded (currency condition only), REQ-A1.3 clarified, REQ-A1.5 minted, D-3 rationale qualified. |
| L-B1 | Applied, operator's choice: four buckets and act-then-review for the local-apply skills only; `/code-review` keeps severity tiers, `/peer-review` keeps its prompt; drain-scope overrides recorded in each skill under REQ-B1.2. |
| L-B2 to L-B4, L-B6, L-B7 | Applied as listed: lens list pointed at, never copied; discovery on first and converging iterations; one shared resolution file; contained codex form; `review_sequence` claim removed from skills too. |
| L-B5 | Applied, operator's choice on the agent's recommendation: inline heredoc with a quoted, per-post random delimiter on stdin. |
| L-C1 to L-C3, L-C5 | Applied as listed: REQ-C1.10 and REQ-C1.11 minted, REQ-C1.2 names the safety mechanics, REQ-E1.1 limits by sentences with spellings exempt. |
| L-C4 | Applied, operator's choices: run-level go-ahead limited to its named scope (on the agent's recommendation); unattended runs draft into the handoff (REQ-D1.4); bot and message definitions (REQ-D1.5); never-guess-a-recipient kept always-loaded. |
| L-C6 | Applied, operator's choice: the enabled version's install path. |
| L-D1 | Applied, operator's choice: reuse the existing machine-local identifier file; a review-time check scoped to live instruction files and this bundle, never commit-blocking, citing the `specs/dev-services` retirement. |
| L-D2 to L-D4 | Applied as listed. |
| L-E1 to L-E10 | Applied as listed; L-E7 also executed on this host (inventory directory set to 0700). |
| L-F1 | Applied, operator's choice: claude-context's stale content requirements marked superseded (REQ-F1.6); its ceiling and scope gate stay. |
| L-F2 to L-F5 | Applied as listed: link policy in D-4; threshold formula and counting in REQ-G1.1 and REQ-G1.3; a step in the existing contract-checker job; risks 11 and 12. |

**Spec edits from the lens review.** REQ-A1.5, REQ-C1.10, REQ-C1.11,
REQ-D1.4, REQ-D1.5 and REQ-F1.6 minted, each with its paired `test-spec.md`
entry; the amended REQs and D-IDs carry an "Amended at kickoff" marker.
Task blocks rewritten for ownership, citations and branch/post-merge
Done-when; `test-spec.md` rewritten so every entry names a runnable check.

**Post-lens stale-reference sweep.** Swept the bundle and the earlier
brief sections for the re-scoped rules (resolution method, identifier
check, trigger wording, threshold wording, drain-scope home, critical
path); the glossary, design ledger, verification, task-graph and risk
sections above were reconciled in place before this record.

### Sign-off record

Signed off: 2026-09-26, by the operator, after the approval summary.
Validator at Ready: `spec-validate.sh specs/claude-instructions`, 0 errors,
0 warnings. Pre-flip checks: gitleaks over the bundle clean; recorded claims
re-derived mechanically (every merged finding tabled and dispositioned,
every D-ID in the ledger, every REQ with a test-spec entry and a task
citation, every D-ID cited).

Class: meaning
Lens-pass: the lens review, merged findings and dispositions recorded above in this section
Anchor: `ab627a7fbb611ba2577a5bfb6cc046957e8706dd` — computed as
`spec-anchor.sh specs/claude-instructions`

## Amendment log

### 2026-09-29 — lefthook flag in Task 1's Done-when

Written by `/execute-task` during Task 1. Cites the `requirements.md`
changelog line of 2026-09-29: `--commands` corrected to `--command`, the
flag lefthook 2 provides.

Class: expression-only
Anchor: `a315f6995bde7691c2465b220aa2e34b1b701f4b` — computed as
`spec-anchor.sh specs/claude-instructions`
