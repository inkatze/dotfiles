# Claude Instructions Audit — Test Spec

**Status:** Draft
**Last reviewed:** 2026-09-25
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: the budget guard and the contract checker give every textual
requirement a `[test]` path through their fixture suites and CI; behaviour
of the converted skills is `[manual]`, run once per skill from the main
checkout after merge (a worktree cannot exercise a changed skill through the
tool, so branch-time checks follow the file by hand); cross-repository
requirements are `[manual]` on the host where they land; decisions with no
runtime are `[design-level]`. CI is the repository's GitHub workflow, which
runs lefthook's checks and the fixture suites.

## REQ-A — Currency posture

### REQ-A1.1 — Ready-flip condition is mergeability [test + manual]

The contract checker pins the reworded ready-flip sentence in the user-global
file; its fixture suite plants "current with its base" and expects a failure.
Manually: a fresh session asked what must hold before a ready flip answers
mergeable plus CI green.

### REQ-A1.2 — No sync ritual [test]

The contract checker's negative pin: the strings "sync, push, re-run" and
"current with its base" may not appear in the user-global file; fixture
plants each.

### REQ-A1.3 — Kickoff flip exception [test]

The contract checker pins the exception clause; the fixture suite plants a
version of the never-flip rule without it and expects a failure.

### REQ-A1.4 — planwright items carried upstream [manual]

Task 6's note is read on the planwright side and contains the ready-guard and
convergence-merge items; verified when Task 6's done-when is checked.

## REQ-B — One source of review doctrine

### REQ-B1.1 — No doctrine copies in the global file [test]

The contract checker asserts that none of the four doctrine section headings
appear as full sections (heading followed by more than the pointer
paragraph); the fixture plants a copied paragraph under a pointer heading and
expects a failure.

### REQ-B1.2 — Skills resolve planwright doctrine [test + manual]

The contract checker pins, in every SKILL.md, the resolution-script
invocation for each of the four docs. Manually: one review skill run from the
main checkout emits four bucket tables in its artifact and applies a
Needs-sign-off finding on the branch with the pending-sign-off marker.

### REQ-B1.3 — Checker pins the pointer, not the bucket count [test]

The checker's fixture suite has no retired-bucket case and has a
missing-pointer case that fails; the string `Agent-resolvable` in a SKILL.md
produces no error (a fixture plants it and expects a pass).

### REQ-B1.4 — Workflow sections are pointers [test]

The budget guard's threshold for the user-global file, lowered per REQ-G1.3
in Task 3, cannot be met with the descriptions in place; additionally the
checker asserts each workflow line is a single bullet naming a skill file or
planwright doc.

### REQ-B1.5 — No review_sequence claim [test]

Contract checker negative pin on the `review_sequence` claim text; fixture
plants it.

## REQ-C — Review commands as skills with shared mechanics

### REQ-C1.1 — Skills directory materialized [test + manual]

An Ansible run on a host (or the CI lint job's syntax check plus a
`--check` run) shows the skills symlink task and the commands symlink
removal; manually, `readlink ~/.claude/skills` points into the repo and
`~/.claude/commands` is gone.

### REQ-C1.2 — Shared mechanics stated once [test]

The contract checker asserts each shared block's anchor sentence appears in
exactly one file under the skills tree (the shared directory) and that every
SKILL.md links to the shared file for each block it uses; fixture plants a
duplicated block and a missing link.

### REQ-C1.3 — No Maintenance sections [test]

Checker negative pin: no `## Maintenance` heading under the skills tree;
fixture plants one.

### REQ-C1.4 — Lens table on first and final iteration only [test + manual]

Checker pins the once-per-loop sentence in each nested skill. Manually: one
nested run's transcript shows the table twice and counts in between.

### REQ-C1.5 — Empty rows are one line in the turn [manual]

A standalone run with an empty bucket shows a one-line `none: <reason>` in
the turn and a full table with a `none` row in the artifact.

### REQ-C1.6 — Shared thresholds declared once [test]

Checker asserts each named threshold appears with a value only in the shared
file, and that a SKILL.md override carries a rationale line; fixture plants a
bare override.

### REQ-C1.7 — Stale references corrected [test + manual]

Checker negative pins on the known stale strings (the self-review step
citations, the `gh copilot` probe); the codex invocation is pinned with its
scratch-directory flag. Manually: the codex backend runs once from an empty
scratch directory without the git-check refusal.

### REQ-C1.8 — No external names in live files [test]

A repo-wide grep in the checker's fixture suite over the tracked instruction
files for a machine-local denylist of names (held under `~/.config/dotfiles/`,
never committed) returns nothing; the committed check itself asserts only
that the denylist file, when present, produces no hits.

### REQ-C1.9 — Inter-skill contradictions resolved [test]

Checker pins the single codex invocation form, the single posted-body rule
and the verbatim lens list in the shared directory; fixture plants the old
contradicting sentence in a SKILL.md.

## REQ-D — Outbound messages to people

### REQ-D1.1 — Draft approval before any message to a human [test + manual]

Checker pins the rule sentence in the user-global file. Manually: a
peer-review run shows each reply and its recipient and waits for a yes.

### REQ-D1.2 — Exactly two exceptions [test]

Checker pins both exception clauses and asserts no third bullet under the
rule; fixture plants a third.

### REQ-D1.3 — Rule always-loaded, mechanics in the shared directory [test]

Checker asserts the recipient-resolution text appears only in the shared
directory and the rule appears only in the user-global file; the
fixed-template exemption sentence is a negative pin.

## REQ-E — User-global file diet

### REQ-E1.1 — Rule without story [test + manual]

Budget guard at the lowered threshold; checker negative pins on the dated
incident phrases. Manually: a read-through finds each incident rule at or
under two lines.

### REQ-E1.2 — Shell reality [test]

Checker pins the three shell lines and a negative pin on "use `set` not
`export`".

### REQ-E1.3 — Lifecycle vocabulary [test]

Checker negative pins on `Draft → Active → Done` and `non-Active spec`;
positive pin on the Ready-inclusive invariant.

### REQ-E1.4 — No phantom tools [test]

Checker negative pins on `deepwiki`; the Slack mention is asserted to carry
the word optional.

### REQ-E1.5 — One statement about `/polish` [test]

Checker asserts the `/polish` description appears once in the file.

## REQ-F — Repo-root file diet

### REQ-F1.1 — Within the ceiling [test]

The budget guard's threshold for the root file, plus a line-count assertion
in its fixture suite mirroring the claude-context ceiling.

### REQ-F1.2 — Rationale relocated with pointers [test + manual]

A link check over the root file (each `docs/` path named exists) in the
budget guard's suite. Manually: a read-through confirms each collapsed
section still carries its rules.

### REQ-F1.3 — Stale claims corrected [manual]

Each listed claim is checked against the tree at review of Task 4.

### REQ-F1.4 — No duplicates of the global file [manual]

A side-by-side read of the two files at review of Task 4 finds no shared
paragraph.

### REQ-F1.5 — claude-context amended expression-only [test]

`spec-validate.sh specs/claude-context` reports no error about the format
line; the changelog entry and its class marker are present (grep in the
budget guard's suite).

## REQ-G — Word-budget guard

### REQ-G1.1 — Counts and thresholds [test]

Fixture suite: a planted overage errors, a planted warn-range size warns,
a size under warn passes.

### REQ-G1.2 — Wired in lefthook and CI [test]

Fixture asserts the lefthook entry and the CI workflow step exist and name
the script; CI itself runs it on every push.

### REQ-G1.3 — Threshold rule [test]

Fixture recomputes each declared threshold from the declared post-diet count
and fails on a mismatch.

### REQ-G1.4 — Green on arrival, lowered by each diet [test]

Task 1's CI run is green; each diet task's CI run is green at the lowered
values.

### REQ-G1.5 — Unreadable surface is an error [test]

Fixture removes a surface and expects a failure.

## REQ-H — The project repo's instruction files

### REQ-H1.1 — Skills fixed or deleted [manual]

Each remaining skill exercised once on a scaffold in the project repo;
output matches the repo's conventions.

### REQ-H1.2 — Checkpoint directory deleted [manual]

The directory is absent from the working copy.

### REQ-H1.3 — Dead permission rule removed [manual]

The local settings file no longer names the uninstalled version.

### REQ-H1.4 — Route block trimmed, phase claim corrected [manual]

A read of the file and the design document at review of Task 5.

## REQ-I — Seed for planwright

### REQ-I1.1 — Pending note exists [manual]

The note is present in the planwright checkout and passes its checks.

### REQ-I1.2 — Every item carried [manual]

Each item in the REQ is found in the note with a rationale.

## REQ-J — The work repos

### REQ-J1.1 — Audit run on the work host [manual]

Dated tables exist on the work host for each work repo; verdicts applied or
recorded declined.

### REQ-J1.2 — Nothing named here [test]

The REQ-C1.8 denylist check covers the bundle's own files as well.

## REQ-K — Re-check discipline

### REQ-K1.1 — New surfaces are inventoried [design-level]

The budget guard is the mechanical trigger; the requirement itself is the
recorded discipline.

### REQ-K1.2 — Inventory stored machine-locally [manual]

The directory exists under `~/.config/dotfiles/` at mode 0600 and nothing
under `specs/claude-instructions/` contains the tables.
