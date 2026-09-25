# Claude Instructions Audit — Requirements

**Status:** Draft
**Last reviewed:** 2026-09-25
**Format-version:** 2
**Execution:** derived — see the status render

## Goal

Audit every instruction that shapes agentic work in this operator's Claude
Code sessions, decide per rule what to keep, update, remove or add, and land
the verdicts. The instruction set has grown by accretion for months, and some
rules now cost more than they return; the named example is the insistence that
a branch be current with its base before a pull request is marked ready, which
is enforced in several unrelated places, none tunable from here, and routinely
forces a sync, a push and a CI re-run for no change in the merge result. The verdicts were taken during
drafting, cluster by cluster, and are recorded as decided rules below; the
per-rule evidence is a dated inventory held machine-locally (D-13). The
deliverable sits at local value: edits to this operator's own instruction
files, plus one repo-local mechanism that keeps them from regrowing, with
every rule this repo cannot change routed to the framework that owns it.
*(Cites: D-1, D-10, the invocation (Sources), altitude seed claim (Sources).)*

## Scope

### In scope

- The user-global `CLAUDE.md` tracked under the Claude role.
- Every review command tracked under the Claude role's commands directory,
  the output style, the hook scripts wired from the tracked `settings.json`,
  and the contract checker that gates edits to them.
- This repository's own root `CLAUDE.md` and the stale citations in the spec
  that governs it (`specs/claude-context`).
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
- **Rewriting frozen spec bundles for name hygiene.** The older bundles name
  the project repo and a work project; their bodies are anchored records and
  the names are already in public history. Only live instruction files are
  scrubbed (REQ-C1.8).
- **Merging the review commands into one.** They stay separate, deliberately
  complementary workflows; only their shared mechanics are stated once.
- **The spec-content freshness gate.** It fires only when a signed bundle's
  own content changed, not when main moved, and stays as it is.
- **Removing the planwright ready-guard hook locally.** It is plugin-global
  wiring; its posture change is an upstream item (REQ-I1.2).

## REQ-A — Currency posture

- **REQ-A1.1** The condition for marking a pull request ready SHALL be that
  the branch has no conflicts with its base (GitHub reports it mergeable),
  never that the base tip is an ancestor of the head.
  *(Cites: D-3, drafting-session decision (2026-09-24).)*
- **REQ-A1.2** No instruction SHALL require syncing with the base, pushing
  and re-running CI as a ritual before a ready flip; syncing is a choice the
  operator makes when a conflict or a stale test result calls for it.
  *(Cites: D-3.)*
- **REQ-A1.3** The rule that a skill never marks a pull request ready on its
  own initiative SHALL carry one stated exception: the spec pull request
  after a signed-off kickoff, which planwright marks ready by configuration.
  *(Cites: D-12, drafting-session decision (2026-09-24).)*
- **REQ-A1.4** The planwright mechanisms that enforce behind-by-zero (the
  ready-guard hook) and merge the base into a worker branch at every
  convergence pass SHALL be carried to planwright as seed items rather than
  worked around here.
  *(Cites: D-3, D-9, REQ-I1.2.)*

## REQ-B — One source of review doctrine

- **REQ-B1.1** The user-global `CLAUDE.md` SHALL NOT carry a copy of any
  planwright doctrine document; where a section duplicated one, it becomes a
  pointer naming the doctrine document and the resolution path.
  *(Cites: D-2, obs:ba58ecbc, obs:21d9faf7.)*
- **REQ-B1.2** Every dotfiles review skill SHALL resolve planwright's
  validation-rigor, discovery-rigor, finding-categorization and
  refactor-instinct doctrine at run time through planwright's rule-doc
  resolution script and follow it, including the four-bucket taxonomy and
  the act-then-review disposition of Needs-sign-off findings.
  *(Cites: D-2.)*
- **REQ-B1.3** The contract checker SHALL pin the doctrine pointer and the
  resolution path, and SHALL NOT forbid the name of any planwright bucket in
  the skill files; its retired-bucket sweep is removed.
  *(Cites: D-2, obs:9d53b50c.)*
- **REQ-B1.4** The Review Workflows and Spec-Driven Autonomy Pipeline sections
  of the user-global file SHALL be one-line pointers per workflow, naming the
  skill file or the planwright document that holds the description.
  *(Cites: D-2, drafting-session decision (2026-09-24).)*
- **REQ-B1.5** The user-global file SHALL NOT claim that a dotfiles review
  skill is a valid member of planwright's `review_sequence`; the claim is
  removed until the resolver accepts skills outside planwright's own root.
  *(Cites: D-9, obs:0ec2fbf5.)*

## REQ-C — Review commands as skills with shared mechanics

- **REQ-C1.1** Every review command tracked under the Claude role SHALL
  become a skill directory under the role's tracked skills directory,
  materialized by a symlink task like the other Claude surfaces, and the
  commands directory symlink SHALL be retired in the same change.
  *(Cites: D-4, research: Claude Code skills documentation.)*
- **REQ-C1.2** Mechanics that more than one review skill uses (the three-pass
  validation restatement, the workflow-choice and handoff ritual, the
  GraphQL reply-and-resolve blocks, the backend resolver and probes, the
  Slack notification mechanics, the push-hook failure handling) SHALL be
  stated once in a shared reference directory beside the skills and loaded
  by relative link at the step that needs them.
  *(Cites: D-4, obs:0ec2fbf5.)*
- **REQ-C1.3** No review skill SHALL carry a per-run Maintenance section
  asking the agent to audit the skill file and draft an update prompt after
  every run.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
- **REQ-C1.4** A nested review loop SHALL run the scoped discovery pass and
  emit the lens-coverage table on its first and final iterations only;
  middle iterations report counts.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
- **REQ-C1.5** In the attended turn, an empty bucket or lens SHALL be
  reported as one line naming the reason; the full tables with `none` rows
  belong to the artifact (the PR body or the audit file).
  *(Cites: D-10, the compact output style (Sources).)*
- **REQ-C1.6** Numeric thresholds shared across skills (iteration caps, lock
  staleness, poll windows) SHALL be declared once in the shared reference
  directory with a single value each, and a skill that needs a different
  value SHALL record why beside its override.
  *(Cites: D-4.)*
- **REQ-C1.7** Every reference from a skill to a step, probe, flag, tool or
  server that does not exist SHALL be corrected or removed, including the
  codex invocation that lacks the flag its scratch-directory contract needs.
  *(Cites: D-10, obs:f3d1c1b8.)*
- **REQ-C1.8** No live instruction file tracked in this repository SHALL
  name an external project, employer organization or work repository; war
  stories that carried such names are reduced to the rule they taught.
  *(Cites: D-8, drafting-session decision (2026-09-24).)*
- **REQ-C1.9** The direct contradictions between skills (the forbidden bare
  codex invocation, the heredoc-versus-Write rule for posted bodies, the
  paraphrased lens list) SHALL be resolved to one rule each, stated in the
  shared directory.
  *(Cites: D-4.)*

## REQ-D — Outbound messages to people

- **REQ-D1.1** No message addressed to another human (a chat message, an
  email, a pull-request review, comment or reply, an issue comment) SHALL be
  sent unless the operator has seen the exact text and recipient and said
  yes in that session.
  *(Cites: D-6, drafting-session decision (2026-09-24).)*
- **REQ-D1.2** REQ-D1.1 SHALL carry exactly two exceptions: an explicit
  one-time go-ahead the operator gives for a specific message or run, and
  replies to automated reviewers (Copilot and third-party review bots),
  which are addressed to a bot even when a human may read them.
  *(Cites: D-6.)*
- **REQ-D1.3** The rule in REQ-D1.1 and its exceptions SHALL live in the
  always-loaded user-global file; the Slack recipient-resolution and
  confirmation mechanics move to the shared reference directory, and the
  fixed-template exemption from confirming a body is removed.
  *(Cites: D-6, planwright instruction-hygiene doctrine (Sources).)*

## REQ-E — User-global file diet

- **REQ-E1.1** A rule that was added in reaction to an incident SHALL state
  the constraint and nothing else; its origin story, dates and commit
  references leave the file.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
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
  *(Cites: D-10.)*
- **REQ-E1.5** The file's two internal contradictions about `/polish`
  (drain scope stated two ways; Needs sign-off described as prompt-gated in
  one section and applied on the branch in another) SHALL be resolved by
  REQ-B1.1 and REQ-B1.4 leaving one statement.
  *(Cites: D-2.)*

## REQ-F — Repo-root file diet

- **REQ-F1.1** This repository's root `CLAUDE.md` SHALL fit the ceiling the
  claude-context bundle already sets, keeping every actionable rule.
  *(Cites: D-7, specs/claude-context (Sources), obs:d4c39e75.)*
- **REQ-F1.2** Rationale and history a section carried beyond its rules
  SHALL move to a note under a `docs/` directory at the repository root, one
  note per topic, and the section SHALL point at the note or at the script
  header or spec that already holds the same text.
  *(Cites: D-7.)*
- **REQ-F1.3** Every verified stale claim in the file (a tracked per-repo
  settings file that does not exist, a mise task said to be missing that
  exists, language servers said to be declared that are not, incomplete
  machine-local file tables, a misfiled block) SHALL be corrected.
  *(Cites: D-10.)*
- **REQ-F1.4** Sections that duplicate the user-global file SHALL be reduced
  to the repo-specific fact or removed.
  *(Cites: D-7, specs/claude-context (Sources).)*
- **REQ-F1.5** The claude-context bundle SHALL have its stale role paths
  corrected and a `Format-version:` line added as an expression-only
  amendment with a dated changelog entry; its ceiling is not changed.
  *(Cites: D-7, planwright spec-format doctrine (Sources).)*

## REQ-G — Word-budget guard

- **REQ-G1.1** A repo-local checker SHALL count words per instruction
  surface (the user-global file, the repo-root file, each review skill, each
  shared reference file) and fail when a surface exceeds its error
  threshold, warning when it exceeds its warn threshold.
  *(Cites: D-5, planwright instruction-hygiene doctrine (Sources).)*
- **REQ-G1.2** The checker SHALL run from lefthook on edits to any surface it
  covers and in CI on every push, alongside the contract checker.
  *(Cites: D-5, obs:f237512e.)*
- **REQ-G1.3** Thresholds SHALL be set by rule, not by taste: each surface's
  warn threshold is its post-diet word count rounded up to the next multiple
  of 250 plus 250, and its error threshold is the warn threshold plus 500;
  the values live in the checker beside the rule that produced them.
  *(Cites: D-5.)*
- **REQ-G1.4** The guard SHALL ship first with thresholds at the surfaces'
  current sizes so it is green on arrival, and each diet task SHALL lower
  its own surface's thresholds per REQ-G1.3 in the same change.
  *(Cites: D-5.)*
- **REQ-G1.5** A surface the checker cannot read SHALL be an error, never a
  silent skip.
  *(Cites: D-5.)*

## REQ-H — The project repo's instruction files

- **REQ-H1.1** Skills in the project repo that contradict its own
  conventions SHALL be rewritten to match them, and a skill carrying no
  project-specific content SHALL be deleted.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
- **REQ-H1.2** The finished worker-fleet checkpoint directory under the
  project repo's `.claude/` SHALL be deleted.
  *(Cites: D-10.)*
- **REQ-H1.3** The project repo's local permission rule pinned to an
  uninstalled plugin version SHALL be removed.
  *(Cites: D-10.)*
- **REQ-H1.4** The project repo's route-helper block SHALL keep its routing
  rule and lose the copied coverage figures and review history, and its one
  stale phase claim SHALL be corrected in the file and the design document
  that repeats it.
  *(Cites: D-10.)*

## REQ-I — Seed for planwright

- **REQ-I1.1** A pending note SHALL be written into the planwright
  repository's pending-notes directory, in that bundle's own format, carrying
  every planwright-owned item this audit could not change here.
  *(Cites: D-9.)*
- **REQ-I1.2** The note SHALL carry at least: a ready-guard posture that
  accepts a mergeable-but-behind branch or an opt-out knob; a way to skip the
  convergence merge of the base into a worker branch; hang guards on the
  dispatch fetch; the Awaiting-input shape for a bundle-level ready flip;
  the duplicate halt-bullet clause; the kickoff pre-flight order; the
  doctrine passages that lag the scripts on where the freshness gate reads
  from; and whether `review_sequence` should accept nestable skills outside
  planwright's root.
  *(Cites: D-9, obs:4570a2c5, obs:6e1b5fcc, obs:9eeec28e.)*

## REQ-J — The work repos

- **REQ-J1.1** The work repos' instruction files SHALL be inventoried with
  the same method (D-10) on the work host, after the skills conversion and
  the global diet have landed, and their verdicts applied there.
  *(Cites: D-10, drafting-session decision (2026-09-24).)*
- **REQ-J1.2** Nothing committed in this repository SHALL name a work repo;
  the audit's record of them stays on the work host.
  *(Cites: D-8.)*

## REQ-K — Re-check discipline

- **REQ-K1.1** The inventory is a dated snapshot; a new instruction surface
  (a new skill, a new hook, a new `CLAUDE.md` section over a paragraph) SHALL
  be inventoried against the same method before it ships, and the budget
  guard is what makes a silent addition visible.
  *(Cites: D-13, D-5.)*
- **REQ-K1.2** The inventory tables SHALL be stored machine-locally under
  the documented `~/.config/dotfiles/` directory and never committed.
  *(Cites: D-13.)*

## Changelog

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
- **`specs/claude-context`.** The bundle governing this repository's root
  `CLAUDE.md`: its scope gate and its 200-line ceiling, which REQ-F keeps.
- **`specs/pair-flow`.** The origin bundle for the review doctrine the
  user-global file copied before the planwright extraction.
- **obs:ba58ecbc, obs:21d9faf7.** The two bucket-count drift entries.
- **obs:d4c39e75.** The repo-root size-ceiling breach.
- **obs:94d1e43e, obs:d2443543.** A skill edited in a worktree cannot be
  exercised through the tool; carried into the test-spec's manual
  verification caveat.
- **obs:4570a2c5, obs:6e1b5fcc, obs:9eeec28e.** planwright-side drifts
  carried into the seed note.
- **obs:0ec2fbf5.** The shared-mechanics observation recorded with the
  `/bot-review` merge.
- **obs:f3d1c1b8.** The codex scratch-directory flag gap.
- **obs:9d53b50c, obs:f237512e.** The contract checker's one
  nondeterministic failure and the CI job naming question that bear on the
  checker changes.
- **The legacy decouple note (2026-06-04).** Its still-open point that the
  review workflows are framed as a pipeline layer rather than standalone
  tooling; resolved by REQ-B1.4.
- **planwright instruction-hygiene doctrine.** The measured claim that
  instruction-following degrades with instruction load, and the word-budget
  mechanism this bundle adapts.
- **planwright customization-boundary and spec-format doctrine.** The
  capability-versus-style rule applied in D-9, and the amendment ritual
  applied in REQ-F1.5.
- **Research: Claude Code documentation.** The tools page (the Bash tool's
  shell and startup files), the skills page (supporting files linked by
  relative path, loaded lazily) and the plugins page (skills recommended for
  new work, commands still supported), plus two open upstream issues
  confirming fish cannot be selected; consulted 2026-09-24.
- **The compact output style.** Its rule that a table is for genuinely
  tabular data, which REQ-C1.5 reconciles with the always-emit-tables rule.
