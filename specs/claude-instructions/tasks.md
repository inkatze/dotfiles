# Claude Instructions Audit — Tasks

**Status:** Draft
**Last reviewed:** 2026-10-05
**Format-version:** 2
**Execution:** derived — see the status render

Tasks 1 to 4, 8 and 9 land in this repository. Tasks 5, 6 and 7 land
elsewhere (the project repo, the planwright repository, the work host) and are
parked under Deferred with a free-text gate so the orchestrator never dispatches them from
this checkout; the operator runs them by hand where they belong.

The materialized Claude links point at the checkout Ansible last ran from,
the main checkout by convention, so a session never loads a task branch's
skills or user-global file. Each Done-when below is therefore split: the
**branch** conditions gate the task PR and run from the worktree; the
**post-merge** conditions run from the main checkout after the merge and an
Ansible run, and their result is recorded as a comment on the merged pull
request. Post-merge checks are the `[manual]` entries of `test-spec.md`,
swept by the drain pass's manual inventory.

## Tasks

### Task 1 — Word-budget guard

- **Deliverables:** `roles/claude/files/scripts/instruction-budget.sh`
  counting words per instruction surface as REQ-G1.1 defines it, with warn
  and error thresholds declared in the script beside the REQ-G1.3 formula;
  a fixture suite in the style of the contract checker's; a lefthook entry
  with a glob over every surface it covers; a step running it in the
  existing contract-checker CI job. Initial surfaces are the user-global
  file, the repo-root file and each command file; initial thresholds are
  derived per REQ-G1.3 from each surface's current word count. The repo-root
  `CLAUDE.md` names the guard in one line (the pointer REQ-K1.1 relies on).
- **Done when:** On the branch: `lefthook run pre-commit --all-files --command
  instruction-budget` runs the checker; the fixture suite passes and
  includes cases in which the checker exits non-zero on a planted overage,
  an unreadable surface, a covered path with no thresholds and a threshold
  that does not match the formula, warns on a warn-range size, passes under
  warn, and finds the lefthook entry and the CI step naming the script; the
  checker exits 0 on the task branch's tree.
- **Dependencies:** none
- **Citations:** D-1, D-5 · REQ-G1.1, REQ-G1.2, REQ-G1.3, REQ-G1.4, REQ-G1.5,
  REQ-K1.1
- **Estimated effort:** half day

### Task 2 — Convert the review commands to skills with a shared directory

- **Deliverables:**
  - `roles/claude/files/skills/<name>/SKILL.md` for every review command,
    each with `disable-model-invocation: true` and the command's name and
    flags unchanged; the bot-review example config moved beside that
    skill's SKILL.md.
  - `roles/claude/files/skills/review-shared/` holding: the planwright root
    resolution (the enabled install path) and halt-on-miss rule; the four
    doctrine-resolution invocations; the validation and solution-validation
    pointers to planwright's doctrine; the workflow-choice and handoff
    ritual; the GraphQL reply-and-resolve blocks; the backend resolver and
    probes, with codex in its contained form only; the posted-body rule
    (quoted per-post random heredoc delimiter on stdin); the push-hook
    failure handling; the Slack recipient-resolution and confirmation
    mechanics; the safety mechanics REQ-C1.2 names; and the single
    declaration of every iteration cap, lock-staleness window and
    review-poll window, overrides written with a reason line.
  - Each SKILL.md links to the shared files it uses; skills that apply
    findings locally follow planwright's taxonomy per REQ-B1.2, and each
    drain-scope override is stated in its skill with its reason.
    Maintenance sections removed; nested loops run discovery per REQ-C1.4;
    empty rows as one line in the turn; stale references and the
    `review_sequence` claim removed; external names scrubbed.
  - In `roles/claude/tasks/main.yml`: the link task per D-4 (glob, link only
    when absent or ours, prune our dangling links) and removal of the
    commands path only when it is a link into this repository.
  - The contract checker, its fixture suite and the lefthook globs moved to
    the new layout: the retired-bucket guards removed; every other existing
    pin kept and retargeted; new check classes with one fixture per planted
    drift for each `[test]` entry of `test-spec.md` citing a REQ this task
    cites; the identifier check per D-8 over the skills tree, the shared
    directory and this bundle, with a fixture that points it at a temporary
    identifier file holding a synthetic name.
  - The budget guard's surfaces and glob moved from the command files to
    each SKILL.md and each shared file, thresholds declared per REQ-G1.3.
  - Each new shared file inventoried per REQ-K1.1 in the machine-local
    inventory.
  - The inventory directory at mode 0700 with its files at 0600.
  - The repo-root `CLAUDE.md` kept current with the conversion: the
    materialization table row, the "adding a new Claude command" section
    rewritten for skills, the line saying skills are not managed, the
    machine-local table's "read by" cells, and the example-config pointer.
    The user-global file's command paths and example-config pointer updated
    to the new paths.
- **Done when:** On the branch: the contract checker and its suite pass on the
  new layout; the budget guard passes and every declared threshold matches
  the formula at this commit; `ansible-playbook main.yml --syntax-check`
  passes and `--list-tasks --tags claude` lists the link task and the
  commands removal; `grep -rnE '^#+ Maintenance' roles/claude/files/skills`
  returns nothing; every relative link from a SKILL.md resolves to an
  existing file under `roles/claude/files/skills/`; the identifier check,
  run on a host holding the identifier file, reports zero hits.
  After merge: after an Ansible run, a before-and-after
  listing of `~/.claude/skills/` shows the tracked entries added and no
  other entry changed, and `~/.claude/commands` is gone; each skill runs
  once from the main checkout against a real pull request up to the step
  before its first outbound post, or its local handoff.
- **Dependencies:** 1
- **Citations:** D-2, D-4, D-5, D-6, D-8, D-10, D-14, D-15 · REQ-B1.2,
  REQ-B1.3, REQ-B1.5, REQ-B1.6, REQ-C1.1, REQ-C1.2, REQ-C1.3, REQ-C1.4,
  REQ-C1.5, REQ-C1.6, REQ-C1.7, REQ-C1.8, REQ-C1.9, REQ-C1.10, REQ-C1.11,
  REQ-G1.1, REQ-G1.3, REQ-G1.4, REQ-J1.2, REQ-K1.1, REQ-K1.2
- **Estimated effort:** 2 days
- **Operator departure (2026-09-29):** approved by the operator. The
  dispatching host holds neither the machine-local inventory nor the
  identifier file, so on the branch the stale-reference pins cover only the
  two strings that `test-spec.md` names for REQ-C1.7. Two checks move to manual
  pre-merge steps, run on the host that holds those files and recorded on
  the task PR before it merges: inventorying each new shared file with the
  inventory directory at 0700 and its files at 0600 (REQ-K1.1, REQ-K1.2),
  and the identifier check over the skills tree, the shared directory, both
  `CLAUDE.md` files and this bundle showing zero hits (REQ-C1.8, REQ-J1.2).

### Task 3 — Diet the user-global CLAUDE.md

- **Deliverables:** `roles/claude/files/CLAUDE.md` with every section that
  duplicates a planwright doctrine document replaced by one pointer bullet
  under the Code & PR Reviews section, naming the document and the shared
  resolution file; the Review Workflows and pipeline sections as one-line
  pointers, the hard-invariants paragraph kept; the Slack section reduced to
  the outbound-message rule, its two exceptions, the unattended-run and
  bot-definition rules, and "never guess a recipient", mechanics gone to the
  shared directory; the ready-flip rule changed per REQ-A1.1 (currency only),
  the ritual removed, the hook-denial rule and the kickoff exception clause
  added; incident rules cut per REQ-E1.1; the three shell lines; the
  lifecycle vocabulary and the acting-on-specs invariant aligned to
  planwright's statuses; stale MCP references and the `review_sequence`
  claim removed; the file's thresholds re-derived per REQ-G1.3; the contract
  checker's pins updated for every reworded sentence, plus new check classes
  with one fixture per planted drift for each `[test]` entry of
  `test-spec.md` citing a REQ this task cites, including the global
  doctrine-pointer pin and the REQ-D1.3 only-here assertions.
- **Done when:** On the branch: the contract checker and the budget guard pass;
  the REQ-B1.1 checker assertion passes (no doctrine section beyond its
  pointer); `grep -nE 'Draft → Active|non-Active spec|deepwiki|review_sequence'
  roles/claude/files/CLAUDE.md` returns nothing; each
  incident rule is at most two sentences, spellings aside; the identifier
  check over the file reports zero hits on a host holding the identifier
  file.
  After merge: a fresh session asked "what must be true
  before you mark a pull request ready?" answers mergeable, CI green and the
  review cadence run, and nothing about being current with the base except
  as a planwright hook behaviour.
- **Dependencies:** 1, 2
- **Citations:** D-2, D-3, D-5, D-6, D-10, D-11, D-12 · REQ-A1.1, REQ-A1.2,
  REQ-A1.3, REQ-A1.5, REQ-B1.1, REQ-B1.3, REQ-B1.4, REQ-B1.5, REQ-C1.8,
  REQ-D1.1, REQ-D1.2, REQ-D1.3, REQ-D1.4, REQ-D1.5, REQ-E1.1, REQ-E1.2,
  REQ-E1.3, REQ-E1.4, REQ-E1.5, REQ-G1.3, REQ-G1.4
- **Estimated effort:** 1 day

### Task 4 — Diet the repo-root CLAUDE.md and amend claude-context

- **Deliverables:** the root `CLAUDE.md` within the claude-context hard
  ceiling, every narrative section collapsed to its rules plus a pointer; a
  new `docs/` directory with one note per relocated subject; every verified
  stale claim corrected and every table that lists a directory or tree
  completed (the machine-local table gains every file under
  `~/.config/dotfiles/` a tracked script or skill reads, the inventory
  directory included); the misfiled machine-local block moved under its
  heading; the identifier-guard section updated for D-8's review-time
  check; sections duplicating the global file reduced to the repo-specific
  fact; `specs/claude-context` with its role paths corrected, a
  `**Format-version:** 1` line and the three mirrored `**Status:**` headers
  added, its superseded content requirements marked per REQ-F1.6, and dated
  changelog entries (the header repair marked expression-only); the file's
  budget thresholds re-derived per REQ-G1.3; budget-suite cases for the root
  file's line ceiling (read from claude-context, not copied) and for every
  markdown link and repo path in the root file resolving, with a fixture for
  each.
- **Done when:** On the branch: the root file is at or under the claude-context
  hard ceiling; the budget guard passes and its suite passes with the new
  cases; `<planwright root>/scripts/spec-validate.sh specs/claude-context`
  exits 0 with no errors; its requirements changelog carries the dated
  expression-only entry; the root file contains a line naming the tracked
  Claude sources directory, a line naming the settings-merge script or its
  note, and a section on adding a skill; the identifier check over the
  file reports zero hits on a host holding the identifier file.
  After merge: a fresh session in this repository answers
  where the tracked Claude sources live, how settings are merged and how to
  add a skill.
- **Dependencies:** 1, 2
- **Citations:** D-5, D-7, D-8, D-10 · REQ-C1.8, REQ-F1.1, REQ-F1.2,
  REQ-F1.3, REQ-F1.4, REQ-F1.5, REQ-F1.6, REQ-G1.3, REQ-G1.4
- **Estimated effort:** 1 day

### Task 5 — Clean the project repo's instruction files

- **Deliverables:** in the project repo, each item the inventory's
  project-repo table flags: convention-contradicting skills rewritten to the
  repo's current conventions and skills with no project-specific content
  deleted; stale local artifacts under `.claude/` deleted; dead local
  permission rules removed; the routing guidance trimmed to its rule; each
  flagged stale claim corrected wherever it is repeated.
- **Done when:** a pull request in the project repo carries the tracked
  changes and its CI is green; the flagged artifacts and rules are gone from
  the working copy; each remaining skill, run once on a throwaway scaffold,
  produces output that passes the project repo's formatter, linter and
  tests; the identifier check over the changed files reports zero hits
  before the commit.
- **Dependencies:** none
- **Citations:** D-8, D-10 · REQ-H1.1, REQ-H1.2, REQ-H1.3, REQ-H1.4
- **Estimated effort:** half day

### Task 6 — Seed the planwright note

- **Deliverables:** one pending note in the planwright repository's
  pending-notes directory, in that repository's own note format, carrying
  every item REQ-I1.2 lists with the evidence from the inventory and the
  consumed observations, worded without any external project name.
- **Done when:** the note exists on a planwright branch or in its main
  checkout and passes that repository's pre-commit checks; every item in
  REQ-I1.2 appears in it with a one-line rationale; the identifier check
  over the note reports zero hits before the commit.
- **Dependencies:** none
- **Citations:** D-8, D-9 · REQ-A1.4, REQ-I1.1, REQ-I1.2
- **Estimated effort:** half day

### Task 7 — Audit the work repos

- **Deliverables:** on the work host: the same extraction method (read-only
  workers on the in-session model, one table per surface, held
  machine-locally) run over each work repo's instruction files; cluster
  verdicts taken with the operator; each verdict proposed in its repository
  through that repository's own review flow, since shared instruction files
  follow their owners' review.
- **Done when:** the work host's inventory directory holds an index naming
  the work repos audited, with one dated table per repo; every verdict has
  either a pull request link in its repository or a "declined" entry in its
  table; the identifier check over this repository, with the work-repo names
  in the identifier file, reports zero hits.
- **Dependencies:** 2, 3
- **Citations:** D-8, D-10 · REQ-J1.1, REQ-J1.2
- **Estimated effort:** 1 day

### Task 8 — Scope model invocation by caller

- **Deliverables:**
  - The `disable-model-invocation` key removed from the front matter of
    every review skill whose argument-hint carries `--nested`; the two
    skills without that mode keep it. Names and flags unchanged.
  - The contract checker requires the key only on a skill without a
    `--nested` mode and rejects it on one with that mode, deriving the set
    from the argument-hint rather than a list; the
    `front-matter-model-invocation` fixture points at a slash-only skill,
    and a new fixture adds the key back to a nested-mode skill and expects
    a failure. The checker pins the description sentence below; a fixture
    drops it. Checker and fixtures change in one commit.
  - Each nested-mode skill's description says the skill runs only when the
    operator types it or a parent skill calls it with `--nested`.
  - The repo-root `CLAUDE.md` skill-creation step says which skills take
    the key; every surface whose word count moved has its budget row
    re-derived per REQ-G1.3.
  - The unmerged flight branch named in the Sources is the starting point:
    its commits carry the key removal, the checker derivation, the two
    fixtures and the repo-root sentence; this task adopts them, adds the
    description rewording with its pin, and lands through one task pull
    request.
  - Provisioning: an Ansible run of the Claude role from the main checkout
    after merge, so each host materializes the changed skills.
- **Done when:** On the branch: the contract checker and its suite pass;
  `grep -L 'disable-model-invocation' roles/claude/files/skills/*/SKILL.md`
  lists exactly the skills whose argument-hint carries `--nested`, and
  `grep -l` lists the rest; each nested-mode skill's description carries
  the sentence; the budget guard passes with every declared threshold
  matching the formula. After merge and an Ansible run: from the main
  checkout, a session that runs a parent skill naming one nested-mode skill
  reaches that skill's first step instead of a blocked call, and a session
  asked to run `/peer-review` on its own initiative is blocked.
- **Dependencies:** 2
- **Citations:** D-4, D-16 · REQ-C1.10, REQ-C1.12, REQ-G1.4, REQ-K1.1
- **Estimated effort:** 0.5 day

### Task 9 — Scope the ready flip by repository ownership

- **Deliverables:**
  - The Pull Request Lifecycle section of the user-global `CLAUDE.md`
    rewritten per REQ-A1.6: the solo clause, the collaborative clause with
    the unknown-owner default, the kickoff exception and the
    operator-confirmed clause kept, the re-check at the head immediately
    before the flip kept, the hook-denial sentence kept.
  - The contract checker's ready-flip and kickoff-exception pins retargeted
    to the new sentences, with the fixtures REQ-A1.6's test-spec entry
    names, in the same commit as the wording.
  - `/copilot-review`'s convergence flip evaluates the REQ-A1.1 conditions
    before `gh pr ready` and reports a ready-guard denial instead of
    working around it; its existing confirmation-gated sentence stays, and
    the new sentence is pinned.
  - Every surface whose word count moved has its budget row re-derived per
    REQ-G1.3.
- **Done when:** On the branch: the contract checker and its suite pass,
  including the new fixtures; the budget guard passes with every declared
  threshold matching the formula; the global file states the flip scope
  once. After merge and an Ansible run: the two fresh-session answers
  REQ-A1.6's test-spec entry names.
- **Dependencies:** 3, 8
- **Citations:** D-3, D-12, D-17 · REQ-A1.1, REQ-A1.5, REQ-A1.6, REQ-G1.4
- **Estimated effort:** 0.5 day

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
- Rewriting the frozen spec bundles (D-8).
- Merging the review skills into one skill.
- Any change to the spec-content freshness gate.
- Removing the planwright ready-guard hook on any host.
- The machine-local memory files.
