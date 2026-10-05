# Claude Instructions Audit — Test Spec

**Status:** Draft
**Last reviewed:** 2026-10-05
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: the budget guard and the contract checker give every textual
requirement a `[test]` path through their fixture suites; behaviour of the
converted skills and the user-global file is `[manual]`, run from the main
checkout after merge, because the materialized links point at the checkout
Ansible last ran from, so a session never loads a branch's files (see
`tasks.md`'s intro for where post-merge results are recorded);
cross-repository requirements are `[manual]` on the host where they land;
decisions with no runtime are `[design-level]`. CI is the repository's
GitHub workflow, run on every pull request and every push to main: lint and
the fixture suites, where the contract checker's suite and the budget
guard's suite each include a baseline case that runs the checker against
the tree. lefthook runs the checkers locally at pre-commit. Pin strings are
matched as they appear in the file, tolerant of line wrapping.
*(Cites: obs:94d1e43e, obs:d2443543.)*

## REQ-A — Currency posture

### REQ-A1.1 — Only the currency condition changes [test + manual]

The contract checker pins the reworded ready-flip sentence (mergeable as the
currency condition, CI green and the review cadence kept, evaluated at the
current head, `UNKNOWN` counts as unmet) in the user-global file; its fixture
suite plants a version naming the base as current and one dropping the
review cadence, and expects a failure for each. Manually, after merge: a
fresh session asked what must hold before a ready flip answers mergeable, CI
green and the review cadence run.

### REQ-A1.2 — No sync ritual [test]

The contract checker's negative pin: no sentence in the user-global file
names being current with the base as a ready condition or asks for a sync
before a flip; the fixture plants the present wording ("the branch current
with its base") and expects a failure.

### REQ-A1.3 — Kickoff flip exception [test]

The contract checker pins the exception clause and the operator-confirmed
clause; the fixture suite plants a version of the never-flip rule without
the exception and expects a failure.
**Superseded-by: REQ-A1.6** (2026-10-05); the exception and the
operator-confirmed clause are pinned under REQ-A1.6's entry.

### REQ-A1.4 — planwright items carried upstream [manual]

Task 6's note is read on the planwright side and contains the ready-guard and
convergence-merge items; verified when Task 6's done-when is checked.

### REQ-A1.5 — Hook denial reported, never worked around [test]

The contract checker pins the hook-denial sentence in the user-global file;
the fixture removes it and expects a failure.

### REQ-A1.6 — Ready flip scoped by ownership [test + manual]

The contract checker pins, in the user-global file, the solo-repository
clause (the agent flips itself once every review step the pull request
calls for has passed and CI is green on the current head, re-checked
immediately before the flip), the collaborative clause (operator-requested,
an unknown owner counts as collaborative), the kickoff exception and the
operator-confirmed clause; fixtures plant a version that drops the
collaborative clause, one that lets the agent flip everywhere, one that
drops the re-check before the flip and one that drops the kickoff exception,
and expect a failure for each. The checker also pins in `/copilot-review`
that its convergence flip evaluates the same conditions and reports a
ready-guard denial; a fixture drops that sentence. Manually, after merge: a
fresh session in this repository, asked who marks its pull request ready,
answers the agent, after the review order and CI; the same question in a
repository with another contributor answers the operator.

## REQ-B — One source of review doctrine

### REQ-B1.1 — No doctrine copies in the global file [test]

The contract checker asserts that the user-global file carries no heading
for any planwright doctrine document and that each doctrine document is
named in exactly one pointer bullet; the fixture plants a copied doctrine
section and expects a failure.

### REQ-B1.2 — Skills resolve planwright doctrine [test + manual]

The contract checker pins, in every SKILL.md, a relative link to the shared
doctrine-resolution file, and pins the four resolution invocations once in
that file; for the local-apply skills it pins the four-bucket reference, for
`/code-review` its severity tiers, and in each skill with a drain-scope
override the override sentence with its reason. Manually, after merge: one
local-apply skill run records four bucket tables in its artifact and, when
the run yields a Needs-sign-off finding, applies it on the branch with a
pending-sign-off checklist entry; a run that yields none records that.

### REQ-B1.3 — Checker pins the pointer, not the bucket count [test]

The checker's fixture suite has no retired-bucket case and has a
missing-pointer case that fails; the string `Agent-resolvable` planted in
each SKILL.md produces no error.

### REQ-B1.4 — Workflow sections are pointers [test]

The checker asserts each line under the Review Workflows heading is one
bullet naming a skill file or a planwright document, and that the pipeline
section keeps its hard-invariants paragraph; the fixture plants a
multi-sentence workflow description and expects a failure.

### REQ-B1.5 — No review_sequence claim [test]

Contract checker negative pin on the `review_sequence` membership claim in
the user-global file and every SKILL.md; the fixture plants it in each and
expects a failure.

### REQ-B1.6 — One root resolution, halt on a miss [test + manual]

The contract checker pins the root-resolution sentence (the enabled install
path) and the halt-on-miss sentence in the shared directory, and asserts no
file outside the shared directory names the plugin cache path; the fixture
plants a cache-path lookup in a SKILL.md. Manually, after merge: the shared
resolution step, invoked with a document name that does not exist, stops
and names it.

## REQ-C — Review commands as skills with shared mechanics

### REQ-C1.1 — Skills directory materialized [test + manual]

`ansible-playbook main.yml --syntax-check` passes and `--list-tasks --tags
claude` lists the link task and the commands removal. Manually, after merge:
a listing of `~/.claude/skills/` before and after an Ansible run shows the
tracked entries added as links into the repository and no other entry
changed, and `~/.claude/commands` is gone.

### REQ-C1.2 — Shared mechanics stated once, safety mechanics kept [test]

The checker holds a list of shared blocks, one anchor sentence each (the
safety mechanics REQ-C1.2 names among them), and asserts each anchor appears
in exactly one file under the skills tree, in the shared directory, and that
each SKILL.md using a block links to its file; fixtures plant a duplicated
block, a missing link and a removed safety anchor.

### REQ-C1.3 — No Maintenance sections [test]

Checker negative pin: no heading matching `^#+ Maintenance` under the skills
tree; fixture plants one.

### REQ-C1.4 — Discovery on first and converging iterations [test + manual]

Checker pins the discovery-cadence sentence in each nested skill. Manually,
after merge: on a nested run of three or more iterations, the artifact
records a lens-coverage table for the first and the converging iteration
only, and the turn shows counts in between.

### REQ-C1.5 — Empty rows are one line in the turn [manual]

After merge, on any standalone run: every bucket or lens that comes out
empty shows as a one-line `none: <reason>` in the turn and as a `none` row
in the artifact's table.

### REQ-C1.6 — Shared thresholds declared once [test]

The checker lists the threshold names (iteration cap, lock-staleness window,
review-poll window) and asserts each appears with a value only in the shared
file, and that an override in a SKILL.md is followed by a reason line;
fixture plants a bare override.

### REQ-C1.7 — Stale references corrected [test + manual]

Checker negative pins on the stale strings the inventory flags (the
self-review step citations, the `gh copilot` probe); the codex invocation is
pinned with its scratch-directory flag. Manually, after merge, on a host with
codex logged in: the codex backend runs once from an empty scratch
directory without the git-check refusal.

### REQ-C1.8 — No external names in live files [test + manual]

The contract checker's suite runs the identifier check (D-8) over the
skills tree, the shared directory, both `CLAUDE.md` files and this bundle,
never over frozen bundles; a fixture points it at a temporary identifier
file holding a synthetic name, plants that name and expects a failure that
prints file and line but not the name. CI holds no identifier file, so the
real check warns there instead of passing silently; manually, at review of
Tasks 2, 3 and 4, it runs on a host holding the identifier file and shows
zero hits.

### REQ-C1.9 — Inter-skill contradictions resolved [test]

Checker pins, in the shared directory, the contained codex form, the
posted-body rule (quoted random delimiter on stdin) and the pointer to
discovery-rigor's lens list, and asserts no file under the skills tree
carries a copied lens list; fixtures plant a bare codex invocation, an
unquoted heredoc for a posted body and a copied list in a SKILL.md.

### REQ-C1.10 — Safety pins survive [test]

The fixture suite's baseline asserts every pin group present before the
conversion (the mark-ready gate, the bot-review safety sentences, the
severity tiers, the retired-backend sweep) still exists under its new path;
a fixture deletes each group's anchor and expects a failure.

### REQ-C1.11 — Slash-invoked only, names and flags kept [test]

The checker asserts every SKILL.md front-matter sets
`disable-model-invocation: true` and that each skill's documented flags
match the list the checker holds; fixtures drop the key and a flag.
**Superseded-by: REQ-C1.12** (2026-10-05).

### REQ-C1.12 — Model invocation scoped by caller, names and flags kept [test + manual]

The checker derives each skill's mode from the argument-hint it holds: a
hint without `--nested` requires `disable-model-invocation: true`, a hint
with it forbids the key; each skill's documented flags still match the
checker's list. Fixtures drop the key from a slash-only skill, add it back
to a nested-mode skill, and drop a flag, expecting a failure for each. The
checker pins in each nested-mode skill's description the sentence that it
runs only when the operator types it or a parent skill calls it with
`--nested`; a fixture drops it. Manually, after merge and an Ansible run: a
parent skill's `--nested` invocation of one of the three is not blocked by
Claude Code, and the two slash-only skills still are.

## REQ-D — Outbound messages to people

### REQ-D1.1 — Draft approval before any message to a human [test + manual]

Checker pins the rule sentence and the never-guess-a-recipient sentence in
the user-global file. Manually, after merge: a peer-review run on a pull
request with at least one unresolved human review thread shows each reply
and its recipient and waits for a yes.

### REQ-D1.2 — Exactly two exceptions [test]

Checker pins both exception clauses, including the named-scope limit of a
run-level go-ahead, and asserts no third exception under the rule; fixture
plants a third and an unscoped run-level go-ahead.

### REQ-D1.3 — Rule always-loaded, mechanics in the shared directory [test]

Checker asserts the recipient-resolution anchor sentence appears only in the
shared directory and the rule's anchor sentence only in the user-global
file; the fixed-template exemption sentence is a negative pin.

### REQ-D1.4 — Unattended runs draft, never send [test]

Checker pins the unattended-run sentence in the user-global file and the
matching handoff step in the shared directory; fixture removes each.

### REQ-D1.5 — Bot and message definitions [test]

Checker pins the automated-reviewer definition, the mixed-thread clause and
the own-pull-request clause in the user-global file; fixture removes each.

## REQ-E — User-global file diet

### REQ-E1.1 — Rule without story [test + manual]

Budget guard at the re-derived threshold; checker negative pin on dates and
commit hashes inside rule sections; checker pins every listed force-push and
remote-deletion spelling. Manually: a read-through finds each rule the
inventory tags incident-reactive at or under two sentences, spellings
aside.

### REQ-E1.2 — Shell reality [test]

Checker pins the three shell lines and a negative pin on the present
fish-only wording (`set` not `export`).

### REQ-E1.3 — Lifecycle vocabulary [test]

Checker negative pins on `Draft → Active` and `non-Active spec`; positive
pin on the Ready-inclusive invariant.

### REQ-E1.4 — No phantom tools [test]

Checker negative pin on `deepwiki`; any remaining line naming a Slack MCP
carries the word optional, and absence passes.

### REQ-E1.5 — One statement about `/polish` [test]

Checker pins the one sentence stating `/polish`'s drain scope and asserts it
appears once; negative pins on the two contradicting phrasings present
today.

## REQ-F — Repo-root file diet

### REQ-F1.1 — Within the ceiling [test]

The budget guard's suite asserts the root file's line count is at or under
the hard ceiling read from `specs/claude-context`, plus the root file's
budget threshold.

### REQ-F1.2 — Rationale relocated with pointers [test + manual]

The budget guard's suite asserts every markdown link and repo path in the
root file resolves; a fixture removes a target. Manually, at review of Task
4: the task PR lists each section's actionable rules before the diet, and
each is present after it or has a pointer.

### REQ-F1.3 — Stale claims corrected, tables complete [manual]

At review of Task 4: each stale claim the inventory flags is checked against
the tree, and every file under `~/.config/dotfiles/` that a tracked script
or skill reads has a row in the machine-local table.

### REQ-F1.4 — No duplicates of the global file [manual]

At review of Task 4: no paragraph of ten or more words appears verbatim in
both files, and a side-by-side read finds no paraphrased duplicate.

### REQ-F1.5 — claude-context header repair [manual]

Manually, at review of Task 4, with the planwright validator from the
enabled plugin: `spec-validate.sh specs/claude-context` exits 0. The
validator is not in this repository, so CI cannot run it.

### REQ-F1.6 — claude-context content superseded [manual]

At review of Task 4: each claude-context requirement this bundle makes false
carries a superseded-by pointer, and its changelog has the dated line.

## REQ-G — Word-budget guard

### REQ-G1.1 — Counts and thresholds [test]

Fixture suite: a planted overage errors, a warn-range size warns, a size
under warn passes, a covered path with no thresholds errors, and a text with
multibyte punctuation counts the same under the C locale on both platforms.

### REQ-G1.2 — Wired in lefthook and CI [test]

Fixture asserts the lefthook entry and the step in the contract-checker CI
job exist and name the script; CI runs it on every pull request and every
push to main, and a warning appears as an annotation.

### REQ-G1.3 — Threshold formula [test]

Fixture recomputes each declared threshold from the surface's declared count
with the formula and fails on a mismatch, including a count that is an exact
multiple of 250.

### REQ-G1.4 — Green on arrival, re-derived by each change [test]

Task 1's CI run is green with every initial threshold matching the formula;
each later task's CI run is green with every changed or added surface's
thresholds matching it.

### REQ-G1.5 — Unreadable surface is an error [test]

Fixture removes a surface and expects a failure.

## REQ-H — The project repo's instruction files

### REQ-H1.1 — Skills fixed or deleted [manual]

Each remaining skill, run once on a throwaway scaffold in the project repo,
produces output that passes the repo's formatter, linter and tests.

### REQ-H1.2 — Stale artifacts deleted [manual]

The flagged artifacts are absent from the working copy.

### REQ-H1.3 — Dead permission rules removed [manual]

The local settings file no longer carries the flagged rules.

### REQ-H1.4 — Routing guidance trimmed, stale claims corrected [manual]

A grep for each flagged stale phrase in the files that repeated it returns
nothing, and the routing block carries no copied figure or dated history
line.

## REQ-I — Seed for planwright

### REQ-I1.1 — Pending note exists [manual]

The note is present in the planwright checkout and passes that repository's
pre-commit checks.

### REQ-I1.2 — Every item carried [manual]

Each item in the REQ is found in the note with a rationale.

## REQ-J — The work repos

### REQ-J1.1 — Audit run on the work host [manual]

The work host's inventory index names the work repos audited with one dated
table each; every verdict has a pull request link or a "declined" entry.

### REQ-J1.2 — Nothing named here [test + manual]

The REQ-C1.8 identifier check covers this bundle's files; manually, it runs
on a host whose identifier file holds the work-repo names and shows zero
hits.

## REQ-K — Re-check discipline

### REQ-K1.1 — New instruction sources are inventoried [design-level]

The budget guard is the mechanical trigger (a covered path with no declared
thresholds errors); the requirement itself is the recorded discipline.

### REQ-K1.2 — Inventory stored machine-locally [manual]

`stat -c %a` on the inventory directory prints 700 and on each file 600, and
no file under `specs/claude-instructions/` contains the inventory tables'
header rows.
