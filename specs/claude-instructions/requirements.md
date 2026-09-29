# Claude Instructions Audit — Requirements

**Status:** Ready
**Last reviewed:** 2026-09-26
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Audit every instruction that shapes agentic work in this operator's Claude
Code sessions, decide per rule what to keep, update, remove or add, and land
the verdicts. The instruction set has grown by accretion for months, and some
rules now cost more than they return; the named example is the insistence that
a branch be current with its base before a pull request is marked ready, which
is enforced in several unrelated places, none tunable from here, and routinely
forces a sync, a push and a CI re-run for no change in the merge result. The
verdicts were taken during drafting, cluster by cluster, and are recorded as
decided rules below; the per-rule evidence is a dated inventory held
machine-locally (D-13). The deliverable sits at local value: edits to this
operator's own instruction files, plus one repo-local mechanism that keeps
them from regrowing, with every rule this repo cannot change routed to the
framework that owns it.
*(Cites: D-1, D-10, the invocation (Sources), altitude seed claim (Sources),
the machine-local inventory (Sources).)*

## Scope

### In scope

- The user-global `CLAUDE.md` tracked under the Claude role.
- Every review command tracked under the Claude role's commands directory,
  the hook scripts wired from the tracked `settings.json`, and the contract
  checker that gates edits to them. The output style was audited and is kept
  as it is.
- This repository's own root `CLAUDE.md`, and the stale citations, validator
  errors and superseded content requirements of the spec that governs it
  (`specs/claude-context`).
- The `.claude/` directory and `CLAUDE.md` of the operator's personal project
  repository, referred to here as **the project repo**.
- A word-budget guard over the instruction surfaces in this repository.
- A seed note for the planwright repository carrying every planwright-owned
  rule this audit found wanting.
- An audit of the operator's work repositories' instruction files, referred
  to here as **the work repos**, run on the work host.

### Out of scope

- **Machine-local memory files.** Untracked, per-machine, and not repo
  content.
- **Changing planwright core from this repository.** Every planwright-owned
  rule is routed to planwright's own drafting flow (REQ-I); nothing here
  edits the plugin cache or adds a doctrine shadow.
- **Rewriting frozen spec bundles for name hygiene.** Older bundles are
  anchored records and are not rewritten; only live instruction files and
  this bundle are scrubbed (REQ-C1.8).
- **Merging the review commands into one.** They stay separate, deliberately
  complementary workflows; only their shared mechanics are stated once.
- **The spec-content freshness gate.** It fires only when a signed bundle's
  own content changed, not when main moved, and stays as it is.
- **Removing the planwright ready-guard hook locally.** It is plugin-global
  wiring; its posture change is an upstream item (REQ-I1.2).

## REQ-A — Currency posture

- **REQ-A1.1** The currency condition for marking a pull request ready SHALL
  be that the branch has no conflicts with its base (GitHub reports
  `mergeable: MERGEABLE`), never that the base tip is an ancestor of the
  head. The other ready conditions (CI green, the review cadence the pull
  request calls for actually run) are unchanged. Every condition is
  evaluated against the current head immediately before the flip, and a
  condition that cannot be confirmed, including a mergeability GitHub still
  reports as `UNKNOWN`, counts as unmet.
  *(Cites: D-3, drafting-session decision (2026-09-24).)*
  *(Amended at kickoff 2026-09-25: only the currency condition changes.)*
- **REQ-A1.2** No instruction SHALL require syncing with the base, pushing
  and re-running CI as a ritual before a ready flip; syncing is a choice the
  operator makes when a conflict or a stale test result calls for it.
  *(Cites: D-3.)*
- **REQ-A1.3** The rule that a skill never marks a pull request ready on its
  own initiative SHALL carry one stated exception: the spec pull request
  after a signed-off kickoff, which planwright marks ready by configuration.
  A flip the operator confirms in that run (such as `/copilot-review
  --nested` asking at convergence) is operator-requested, not an exception.
  *(Cites: D-12, drafting-session decision (2026-09-24).)*
- **REQ-A1.4** The planwright mechanisms that enforce a zero behind-count
  (the ready-guard hook) and merge the base into a worker branch at every
  convergence pass SHALL be carried to planwright as seed items rather than
  worked around here.
  *(Cites: D-3, D-9, REQ-I1.2.)*
- **REQ-A1.5** Until planwright's ready-guard changes upstream, a hook
  denial of a ready flip on a branch that meets REQ-A1.1 SHALL be reported
  to the operator and never worked around (no sync to satisfy it, no
  bypass).
  *(Cites: D-3, kickoff decision (2026-09-25).)*

## REQ-B — One source of review doctrine

- **REQ-B1.1** The user-global `CLAUDE.md` SHALL NOT carry a copy of any
  planwright doctrine document; where a section duplicated one, it becomes a
  pointer naming the doctrine document and the resolution path.
  *(Cites: D-2, obs:ba58ecbc, obs:21d9faf7, specs/pair-flow (Sources).)*
- **REQ-B1.2** Every dotfiles review skill SHALL resolve planwright's
  validation-rigor and discovery-rigor doctrine at run time and follow it.
  The review skills that apply findings to their own branch (`/panel-review`,
  `/copilot-review`, `/bot-review`) SHALL also follow finding-categorization
  and refactor-instinct, including the four-bucket taxonomy and the
  act-then-review disposition of Needs-sign-off findings. `/code-review`
  keeps its severity tiers and never applies a fix to another author's
  branch; `/peer-review` keeps its prompt before any reply (REQ-D1.1). A
  skill whose drain scope differs from planwright's (bot-review's nested
  deferral of Needs-sign-off findings, each nested loop's scope) SHALL state
  that scope as a recorded override in the skill, with its reason.
  *(Cites: D-2, D-15, kickoff decision (2026-09-25).)*
  *(Amended at kickoff 2026-09-25: taxonomy scoped to local-apply skills,
  drain-scope overrides given a home.)*
- **REQ-B1.3** The contract checker SHALL pin the doctrine pointer and the
  resolution path, and SHALL NOT forbid the name of any planwright bucket in
  the skill files; its retired-bucket guards (the sweep and code-review's
  separate guard) are removed.
  *(Cites: D-2, obs:9d53b50c.)*
- **REQ-B1.4** The Review Workflows and Spec-Driven Autonomy Pipeline sections
  of the user-global file SHALL be one-line pointers per workflow, naming the
  skill file or the planwright document that holds the description; the
  pipeline section's hard-invariants paragraph stays.
  *(Cites: D-2, drafting-session decision (2026-09-24), the legacy decouple
  note (Sources).)*
- **REQ-B1.5** Neither the user-global file nor any review skill SHALL claim
  that a dotfiles review skill is a valid member of planwright's
  `review_sequence`; the claim is removed until the resolver accepts skills
  outside planwright's own root.
  *(Cites: D-9, the machine-local inventory (Sources).)*
- **REQ-B1.6** The shared reference directory SHALL state one way for a
  review skill to locate planwright's install root (the enabled version's
  install path as Claude Code records it in its installed-plugins file), and
  a missing record or a doctrine document that does not resolve SHALL halt
  the skill naming what is missing, never falling back to a remembered or
  inline copy of the rule.
  *(Cites: D-2, kickoff decision (2026-09-25).)*
  *(Amended at kickoff 2026-09-25: the enabled version, not the newest
  cached one.)*

## REQ-C — Review commands as skills with shared mechanics

- **REQ-C1.1** Every review command tracked under the Claude role SHALL
  become a skill directory under the role's tracked skills directory,
  materialized as one symlink per tracked skill directory and one for the
  shared reference directory inside `~/.claude/skills/`, leaving any other
  entry there untouched, and the commands directory symlink SHALL be
  retired in the same change.
  *(Cites: D-4, research: Claude Code skills documentation.)*
  *(Amended at kickoff 2026-09-25: per-entry symlinks, because the
  materialized skills directory already holds content this repo does not
  own.)*
- **REQ-C1.2** Mechanics that more than one review skill uses SHALL be
  stated once in a shared reference directory beside the skills and loaded
  by relative link at the step that needs them. These include the pointers
  to planwright's validation doctrine, the workflow-choice and handoff
  ritual, the GraphQL reply-and-resolve blocks, the backend resolver and
  probes, the Slack notification mechanics and the push-hook failure
  handling, and they SHALL keep the safety mechanics the commands carry
  today: the untrusted-comment rule, the same-pull-request lock, the
  per-repository egress consent, and the outbound-prompt guards.
  *(Cites: D-4, obs:0ec2fbf5.)*
  *(Amended at kickoff 2026-09-25: safety mechanics named as must-keep.)*
- **REQ-C1.3** No review skill SHALL carry a per-run Maintenance section
  asking the agent to audit the skill file and draft an update prompt after
  every run.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
- **REQ-C1.4** A nested review loop SHALL run the scoped discovery pass on
  its first iteration and on the iteration that detects convergence only;
  middle iterations report counts. Each discovery pass records its
  lens-coverage table in the loop's artifact, per discovery-rigor.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
  *(Amended at kickoff 2026-09-25: the limit applies to the discovery pass,
  not to the doctrine's table.)*
- **REQ-C1.5** In the attended turn, an empty bucket or lens SHALL be
  reported as one line naming the reason; the full tables with `none` rows
  belong to the artifact (the PR body or the audit file).
  *(Cites: D-10, the compact output style (Sources).)*
- **REQ-C1.6** Every iteration cap, lock-staleness window and review-poll
  window in any review skill SHALL be declared once in the shared reference
  directory with a single value each, and a skill that needs a different
  value SHALL record why beside its override.
  *(Cites: D-4.)*
- **REQ-C1.7** Every reference from a skill to a step, probe, flag, tool or
  server that does not exist SHALL be corrected or removed, including the
  codex invocation that lacks the flag its scratch-directory contract needs.
  *(Cites: D-10, obs:f3d1c1b8, the machine-local inventory (Sources).)*
- **REQ-C1.8** No live instruction file tracked in this repository, and no
  file of this bundle, SHALL name an external project, employer
  organization or work repository; war stories that carried such names are
  reduced to the rule they taught.
  *(Cites: D-8, drafting-session decision (2026-09-24), the legacy decouple
  note (Sources).)*
- **REQ-C1.9** Where two skills state conflicting rules for the same
  mechanic, the shared directory SHALL state one rule. In particular: the
  codex backend runs only in the contained form (read-only sandbox, prompt
  on stdin, an empty scratch directory as working directory), and the flag
  that skips its git check is used only together with that form; a posted
  body goes through an inline heredoc with a quoted, per-post random
  delimiter on stdin, never interpolated into argv; the lens list is
  planwright's discovery-rigor list, pointed at and never copied, and a
  backend prompt that needs it builds it at run time from the resolved
  document.
  *(Cites: D-4, kickoff decision (2026-09-25).)*
  *(Amended at kickoff 2026-09-25: the winning rule named for each.)*
- **REQ-C1.10** Every safety pin the contract checker carries today (the
  mark-ready gate, the bot-review safety sentences, the severity-tier pins,
  the retired-backend sweep) SHALL survive the conversion, retargeted to the
  new paths; only the retired-bucket guards of REQ-B1.3 are removed.
  *(Cites: D-4, kickoff decision (2026-09-25).)*
- **REQ-C1.11** Every converted review skill SHALL set
  `disable-model-invocation: true`, and keep its invocation name and flags
  exactly as the command had them.
  *(Cites: D-4, kickoff decision (2026-09-25).)*

## REQ-D — Outbound messages to people

- **REQ-D1.1** No message addressed to another human (a chat message, an
  email, a pull-request review, comment or reply, an issue comment) SHALL be
  sent unless the operator has seen the exact text and recipient and said
  yes in that session. A recipient that cannot be resolved is never guessed.
  *(Cites: D-6, drafting-session decision (2026-09-24).)*
- **REQ-D1.2** REQ-D1.1 SHALL carry exactly two exceptions: an explicit
  go-ahead the operator gives for a specific message, or for a run limited
  to the recipients and message kinds named when it is given; and replies to
  automated reviewers, which are addressed to a bot even when a human may
  read them.
  *(Cites: D-6, kickoff decision (2026-09-25).)*
  *(Amended at kickoff 2026-09-25: a run-level go-ahead covers only its
  named scope.)*
- **REQ-D1.3** The rule in REQ-D1.1, its exceptions and REQ-D1.4 to
  REQ-D1.5 SHALL live in the always-loaded user-global file; the Slack
  recipient-resolution and confirmation mechanics move to the shared
  reference directory, and the fixed-template exemption from confirming a
  body is removed.
  *(Cites: D-6, planwright instruction-hygiene doctrine (Sources).)*
- **REQ-D1.4** A run with no operator present that would send a message
  under REQ-D1.1 outside a go-ahead's scope SHALL draft it, with its
  recipient, into the run's handoff and never send it.
  *(Cites: D-6, kickoff decision (2026-09-25).)*
- **REQ-D1.5** An automated reviewer SHALL be an account GitHub reports as a
  bot, a login ending in `[bot]`, or a login matching a configured
  bot-review pattern; a thread any human has replied in falls under
  REQ-D1.1. Bodies of the operator's own pull requests and issues, and
  review requests on them, are not messages under REQ-D1.1.
  *(Cites: D-6, kickoff decision (2026-09-25).)*

## REQ-E — User-global file diet

- **REQ-E1.1** A rule that was added in reaction to an incident (every rule
  the inventory tags incident-reactive) SHALL state the constraint in at
  most two sentences, and its origin story, dates and commit references
  leave the file. A rule's enumerated forbidden spellings (the force-push
  and remote-deletion forms) are kept in full and do not count toward that
  limit.
  *(Cites: D-10, drafting-session decision (2026-09-24), the machine-local
  inventory (Sources).)*
  *(Amended at kickoff 2026-09-25: sentences, not lines; spellings exempt.)*
- **REQ-E1.2** The shell rules SHALL state the measured reality: the Bash
  tool runs bash on Linux and zsh on macOS and cannot be pointed at fish;
  commands written for the operator use fish syntax; mise-managed tools run
  through `fish -c` so activation applies.
  *(Cites: D-11, research: Claude Code tools documentation and shell issues.)*
- **REQ-E1.3** Spec lifecycle vocabulary in the file SHALL match planwright's
  status set, and the invariant about acting on specs SHALL permit the
  signed-off statuses planwright executes.
  *(Cites: D-2.)*
- **REQ-E1.4** References to tools or servers not registered on any host
  (a deepwiki MCP, a Slack MCP as an assumed presence) SHALL be removed or
  stated as optional.
  *(Cites: D-10, the machine-local inventory (Sources).)*
- **REQ-E1.5** The file's internal contradictions about `/polish` (its drain
  scope, and whether Needs sign-off is prompt-gated or applied on the
  branch) SHALL be resolved by REQ-B1.1 and REQ-B1.4 leaving one statement.
  *(Cites: D-2.)*

## REQ-F — Repo-root file diet

- **REQ-F1.1** This repository's root `CLAUDE.md` SHALL stay within the hard
  line ceiling the claude-context bundle sets, keeping every actionable
  rule.
  *(Cites: D-7, specs/claude-context (Sources), obs:d4c39e75.)*
- **REQ-F1.2** Rationale and history a section carried beyond its rules
  SHALL move to a note under a `docs/` directory at the repository root, one
  note per subject, and the section SHALL point at the note or at the script
  header or spec that already holds the same text.
  *(Cites: D-7.)*
- **REQ-F1.3** Every verified stale claim in the file SHALL be corrected, and
  every table that lists a directory's or tree's entries SHALL list all of
  them. Examples: a tracked per-repo settings file that does not exist, a
  mise task said to be missing that exists, language servers said to be
  declared that are not, a misfiled block.
  *(Cites: D-10, the machine-local inventory (Sources).)*
- **REQ-F1.4** Sections that duplicate the user-global file SHALL be reduced
  to the repo-specific fact or removed.
  *(Cites: D-7, specs/claude-context (Sources).)*
- **REQ-F1.5** The claude-context bundle SHALL have its stale role paths
  corrected, a `**Format-version:** 1` line added and the mirrored
  `**Status:**` header added to its three other files, as an expression-only
  amendment with a dated changelog entry, so that `spec-validate.sh` reports
  no errors on it; its ceiling is not changed. The bundle has no kickoff
  brief, so the amendment carries no self-re-anchor entry.
  *(Cites: D-7, planwright spec-format doctrine (Sources).)*
  *(Amended at kickoff 2026-09-25: header repair widened from the format
  line to every validator error.)*
- **REQ-F1.6** The claude-context content requirements this bundle makes
  false (the commands section and its test, the tracked per-repo settings
  file) SHALL be marked superseded by this bundle's REQ-C1.1 and REQ-F1.3,
  with a changelog line; its line ceiling and scope gate stay in force.
  *(Cites: D-7, planwright spec-format doctrine (Sources), kickoff decision
  (2026-09-25).)*

## REQ-G — Word-budget guard

- **REQ-G1.1** A repo-local checker SHALL count words per instruction
  surface (the user-global file, the repo-root file, each review skill's
  SKILL.md, each shared reference file) and fail when a surface's count is
  greater than its error threshold, warning when it is greater than its
  warn threshold. Words are counted the same way on every platform (the C
  locale, whitespace-separated), and a covered path with no declared
  thresholds is an error.
  *(Cites: D-5, planwright instruction-hygiene doctrine (Sources).)*
- **REQ-G1.2** The checker SHALL run from lefthook on edits to any surface it
  covers and in CI on every pull request and every push to main, as a step
  in the contract checker's job; its warnings SHALL be visible there
  (stderr locally, annotations in CI).
  *(Cites: D-5, obs:f237512e.)*
- **REQ-G1.3** Thresholds SHALL be set by rule, not by taste: for a
  surface's declared word count n, warn = 250 × ceil(n / 250) + 250 and
  error = warn + 500. The declared count is the surface's word count at the
  commit that sets its thresholds; the values live in the checker beside
  the rule that produced them, and every declared threshold matches the
  rule exactly.
  *(Cites: D-5.)*
  *(Amended at kickoff 2026-09-25: the rule applies from the guard's first
  commit, written as a formula.)*
- **REQ-G1.4** The guard SHALL ship first with thresholds derived per
  REQ-G1.3 from the surfaces' current sizes, so it is green on arrival; each
  task that changes a surface, or adds one, SHALL re-derive or declare that
  surface's thresholds in the same change.
  *(Cites: D-5.)*
  *(Amended at kickoff 2026-09-25: initial thresholds follow the rule;
  re-derivation covers new surfaces.)*
- **REQ-G1.5** A surface the checker cannot read SHALL be an error, never a
  silent skip.
  *(Cites: D-5.)*

## REQ-H — The project repo's instruction files

- **REQ-H1.1** Skills in the project repo that contradict its own
  conventions SHALL be rewritten to match them, and a skill carrying no
  project-specific content SHALL be deleted.
  *(Cites: D-10, drafting-session decision (2026-09-24), the machine-local
  inventory (Sources).)*
- **REQ-H1.2** Stale local artifacts under the project repo's `.claude/`
  from finished work SHALL be deleted.
  *(Cites: D-10, the machine-local inventory (Sources).)*
- **REQ-H1.3** The project repo's dead local permission rules SHALL be
  removed.
  *(Cites: D-10, the machine-local inventory (Sources).)*
- **REQ-H1.4** The project repo's routing guidance SHALL keep its rule and
  lose copied figures and review history, and each stale claim the
  inventory flags in it SHALL be corrected wherever it is repeated.
  *(Cites: D-10, the machine-local inventory (Sources).)*

## REQ-I — Seed for planwright

- **REQ-I1.1** A pending note SHALL be written into the planwright
  repository's pending-notes directory, in that repository's own format,
  carrying every planwright-owned item this audit could not change here.
  *(Cites: D-9, planwright customization-boundary doctrine (Sources).)*
- **REQ-I1.2** The note SHALL carry at least: a ready-guard posture that
  accepts a mergeable-but-behind branch or an opt-out knob; a way to skip the
  convergence merge of the base into a worker branch; hang guards on the
  dispatch fetch; the Awaiting-input shape for a bundle-level ready flip;
  the duplicate halt-bullet clause; the kickoff pre-flight order; the
  doctrine passages that lag the scripts on where the freshness gate reads
  from; and whether `review_sequence` should accept nestable skills outside
  planwright's root.
  *(Cites: D-3, D-9, obs:4570a2c5, obs:6e1b5fcc, obs:9eeec28e,
  obs:5d46a147, the machine-local inventory (Sources).)*

## REQ-J — The work repos

- **REQ-J1.1** The work repos' instruction files SHALL be inventoried with
  the same method (D-10) on the work host, after the skills conversion and
  the global diet have landed, and their verdicts proposed there through
  those repositories' own review flows.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
- **REQ-J1.2** Nothing this bundle's execution commits to this repository
  SHALL name a work repo; the audit's record of them stays on the work host.
  *(Cites: D-8.)*

## REQ-K — Re-check discipline

- **REQ-K1.1** The inventory is a dated snapshot; a new instruction source
  (a new skill, a new hook, a new `CLAUDE.md` section over a paragraph) SHALL
  be inventoried against the same method before it ships, and the budget
  guard is what makes a silent addition visible.
  *(Cites: D-13, D-5.)*
- **REQ-K1.2** The inventory tables SHALL be stored machine-locally under
  the documented `~/.config/dotfiles/` directory (directory mode 0700,
  files 0600) and never committed.
  *(Cites: D-13.)*

## Changelog

- 2026-09-29 — Expression-only: Task 1's Done-when named lefthook's
  `--commands` flag, which lefthook 2 does not have; corrected to
  `--command`.
- 2026-09-25 — Kickoff walkthrough and sign-off lens review: REQ-A1.5,
  REQ-C1.10, REQ-C1.11, REQ-D1.4, REQ-D1.5 and REQ-F1.6 minted; the amended
  REQs carry an "Amended at kickoff" marker. The kickoff brief records every
  edit and the lens finding behind it.
- 2026-09-25 — Bundle drafted via `/spec-draft`. Verdicts taken during the
  drafting session on 2026-09-24 and 2026-09-25; the `/bot-review` command
  merged mid-session and was folded into REQ-C rather than gated.

## Sources

- **The invocation (2026-09-24).** The request to inventory every
  instruction related to agentic work, see what each does, and decide what
  to keep, update, remove or add, with the base-currency strictness named as
  one example of a rule now applied to the operator's detriment.
- **Altitude seed claim (2026-09-24).** The invocation's framing of the
  deliverable as an inventory with per-rule verdicts, not a single fix.
  Pinned during seed gathering; resolved in D-1.
- **The machine-local inventory (2026-09-24).** The rule-by-rule tables
  extracted by read-only workers over the surfaces in scope, plus the
  addendum for the command that merged mid-session, held at
  `~/.config/dotfiles/claude-instructions-inventory/` per D-13; the
  evidence every cluster verdict was taken on.
- **Kickoff decision (2026-09-25).** Decisions taken during the kickoff
  walkthrough and its sign-off lens review, recorded in
  `specs/claude-instructions/kickoff-brief.md`.
- **`specs/claude-context`.** The bundle governing this repository's root
  `CLAUDE.md`: its scope gate and its line ceiling (a target and a hard
  ceiling), which REQ-F keeps.
- **`specs/pair-flow`.** The origin bundle for the review doctrine the
  user-global file copied before the planwright extraction.
- **obs:ba58ecbc, obs:21d9faf7.** The two bucket-count drift entries.
- **obs:d4c39e75.** The repo-root size-ceiling breach.
- **obs:94d1e43e, obs:d2443543.** A command edited in a worktree cannot be
  exercised through the tool; carried into the test-spec's manual
  verification caveat.
- **obs:4570a2c5, obs:6e1b5fcc, obs:9eeec28e, obs:5d46a147.** planwright-side
  drifts carried into the seed note.
- **obs:0ec2fbf5.** The shared-mechanics observation recorded with the
  `/bot-review` merge.
- **obs:f3d1c1b8.** The codex scratch-directory flag gap.
- **obs:9d53b50c, obs:f237512e.** The contract checker's one
  nondeterministic failure and the CI job naming question that bear on the
  checker changes; the job keeps its name (REQ-G1.2).
- **The legacy decouple note (2026-06-04).** Its still-open points that the
  review workflows are framed as a pipeline layer rather than standalone
  tooling, resolved by REQ-B1.4, and that organization names be scrubbed,
  carried by REQ-C1.8.
- **planwright instruction-hygiene doctrine.** The measured claim that
  instruction-following degrades with instruction load, and the word-budget
  mechanism this bundle adapts.
- **planwright customization-boundary doctrine.** The capability-versus-style
  rule applied in D-9 and REQ-I1.1.
- **planwright spec-format doctrine.** The amendment and supersession rules
  applied in REQ-F1.5 and REQ-F1.6.
- **Research: Claude Code documentation.** The tools page (the Bash tool's
  shell and startup files), the skills page (supporting files linked by
  relative path, loaded lazily; the invocation-control front-matter) and the
  plugins page (skills recommended for new work, commands still supported),
  plus open upstream issues confirming fish cannot be selected; consulted
  2026-09-24.
- **The compact output style.** Its rule that a table is for genuinely
  tabular data, which REQ-C1.5 reconciles with the always-emit-tables rule.
