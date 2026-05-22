# Pair-Flow — Test Spec

**Status:** Draft
**Last reviewed:** 2026-05-22

This file pins each REQ to a verification path. Most REQs are verified by manual exercise (the system is workflow infrastructure operated by the user, not a service with unit-testable boundaries). Markers used: `[manual]`, `[design-level only]`, `[Gherkin]` (where the scenario form helps articulate the check). Gherkin is used selectively per D-8, not throughout.

## REQ-A — Spec lifecycle (drafting and comprehension)

### REQ-A1.1, A1.2 — `/spec-draft` extracts requirements via Socratic questioning [manual]

```gherkin
[Gherkin]
Given the user invokes /spec-draft <name> with no seed material
When the user describes the feature in their own words
Then the agent extracts at least three REQ candidates, assigns stable IDs (REQ-X1.1...),
  and proposes SHALL/MUST language and a citation for each
And the user can red-line any REQ before it is recorded
```

Verified by: drafting one real upcoming spec (Task 7), inspecting the produced `requirements.md` for: stable IDs, SHALL/MUST language, citations, no prose-only REQs.

### REQ-A1.3 — `/spec-draft` records D-IDs with alternatives [manual]

Verified by: produced `design.md` contains at least one D-ID with `Alternatives considered:` and `Chosen because:` lines.

### REQ-A1.4 — `/spec-draft` proposes task graph with `Done when:`, `Dependencies:`, `Citations:` [manual]

Verified by: every task in the produced `tasks.md` has those three fields.

### REQ-A1.5 — `/spec-draft` pins each REQ to a verification path [manual]

Verified by: every REQ in the produced `requirements.md` is referenced by at least one entry in the produced `test-spec.md`.

### REQ-A1.6 — `/spec-draft` runs spec validator [manual]

Verified by: validator output appears in the session transcript before the agent declares the spec stakeholder-ready.

### REQ-A1.7 — `/spec-draft` uses seed sources [manual]

Verified by: invocation with `specs/_pending/notes.md` (or equivalent) present produces a draft that cites the seed in at least one REQ.

### REQ-A2.1, A2.2, A2.3 — `/spec-kickoff` walkthrough produces signed-off brief [manual]

```gherkin
[Gherkin]
Given an existing spec at specs/{feature}/ with REQs and decisions
When /spec-kickoff is invoked
Then the agent walks the spec section by section
And for each section the agent restates in its own words
And the agent surfaces at least one implicit domain term definition or assumption
And the user has the opportunity to red-line per section before the next section begins
And after all sections, the agent poses Socratic checks (slicing, edge cases, decision rationale)
And the kickoff brief is written to specs/{feature}/kickoff-brief.md only after the user signs off
```

Verified by: invocation on `tecpan/specs/settings`. The user signs off without major correction (success criterion for Task 6).

### REQ-A2.4 — Task graph reconstruction surfaces unstated dependencies [manual]

Verified by: invocation on a spec where the user knows of an unstated dependency. Agent's graph either lists the dependency or surfaces it as a flagged uncertainty.

### REQ-A2.5 — Risk register produced [manual]

Verified by: kickoff brief contains a `## Risks` section with at least one entry that names a plausible failure mode the user agrees is real.

### REQ-A2.6 — Brief invalidation on spec change [manual]

```gherkin
[Gherkin]
Given a signed-off kickoff brief referencing spec commit hash <h>
When any of the four spec files change (new commit <h'>)
Then the brief's affected section(s) are marked invalidated
And /spec-kickoff prompts for re-signoff on those sections before downstream skills proceed
```

Verified by: modifying `tasks.md` in a kickoff-briefed spec and observing the next `/orchestrate` invocation flags the invalidation.

### REQ-A2.7 — Retrofit mode on existing specs [manual]

Verified by: invocation on `tecpan/specs/org` (the spec identified as rough in the 2026-05-22 analysis) surfaces at least three implicit decisions or assumptions the user agrees were under-specified (success criterion for Task 6).

## REQ-B — Task execution

### REQ-B1.1, B1.2 — `/execute-task` accepts one or many task IDs [manual]

Verified by: invocation with a single task ID and with a bundle (two adjacent tasks per D-11). Both produce a single PR.

### REQ-B1.3 — Test-first for new behavior [manual]

```gherkin
[Gherkin]
Given a task whose test-spec.md entry describes new behavior X
When /execute-task is invoked
Then the agent writes the test for X first
And the agent runs the test, confirming it fails for the intended reason
And only then writes implementation code
And the test passes after implementation
```

Verified by: session transcript shows the test was written before the implementation, the failure was observed, and the pass was observed.

### REQ-B1.4 — Regression test first for bug fixes [manual]

Same Gherkin shape as B1.3 but for a regression-fixing task.

### REQ-B1.5 — Research findings recorded in kickoff brief [manual]

Verified by: invocation on a task that requires consulting external docs. Kickoff brief's risk register gains an entry summarizing what was learned and from where.

### REQ-B1.6 — Project CI is green before declaring done [manual]

Verified by: session transcript shows `mix ci` (or equivalent) was run and exited zero before PR open.

### REQ-B1.7 — `/polish` invoked as final convergence [manual]

Verified by: session transcript shows `/polish` was invoked as the last step before PR open.

### REQ-B1.8 — Draft PR body references kickoff brief, task IDs, REQs [manual]

Verified by: produced PR body contains a path to the kickoff brief, task ID(s), and the REQs the change satisfies.

## REQ-C — Autonomous resolution

### REQ-C1.1, C1.2 — Agent-resolvable bucket and predicate [manual]

```gherkin
[Gherkin]
Given a finding that has a failing test that becomes passing after the fix
And full project CI passes after the fix
And the fix is aligned with the active kickoff brief
And the fix is not in a hard-disqualifier zone
When /polish presents its three-bucket categorization
Then the finding appears in the Agent-resolvable bucket with attached evidence:
  the failing-then-passing test name, the CI invocation, and the kickoff alignment citation
```

Verified by: a real polish run on a task where the predicate holds. Inspect the categorization output for the new bucket with evidence rows.

### REQ-C1.3 — Solo repo auto-application [manual]

```gherkin
[Gherkin]
Given the active repo is declared Repo-class: solo
And a finding qualifies for Agent-resolvable
When /polish processes the finding
Then the fix is applied without human pause
And the bucket entry records the auto-apply with a timestamp
```

Verified by: run on tecpan (Repo-class: solo). Inspect that the fix landed without an `AskUserQuestion` interrupt.

### REQ-C1.4 — Multi-reviewer surfacing with evidence [manual]

Verified by: when (and only when) a multi-reviewer repo is in scope (out of v1 scope but predicate must be correctly checked), the same finding surfaces in the bucket but does not auto-apply.

### REQ-C1.5 — Skills recognize the bucket [manual]

Verified by: each affected skill's documentation file (`polish.md`, `panel-pairing.md`, etc.) contains the four-table presentation contract.

### REQ-C1.6 — Existing buckets unchanged [design-level only]

Verified by: diffing user-global CLAUDE.md against the prior version shows no edits to the definitions of `Auto-applicable`, `Needs sign-off`, `Needs human judgment`.

## REQ-D — Orchestration

### REQ-D1.1 — `/orchestrate` skill exists and advances a spec [manual]

Verified by: invocation on a spec with at least one ready task produces a draft PR.

### REQ-D2.1 — Statelessness across invocations [manual]

```gherkin
[Gherkin]
Given a spec with task X marked "In progress: PR #42 draft" in tasks.md
When /orchestrate is invoked from a fresh session (no in-memory state)
Then the agent reads tasks.md, recognizes task X is in flight, and either
  picks the next ready task or no-ops cleanly
And does not restart task X or duplicate the PR
```

Verified by: simulated fresh-session run on a partially executed spec.

### REQ-D3.1 — Ready-task identification [manual]

Verified by: spec with task B depending on task A. `/orchestrate` does not pick B until A is in `Completed`.

### REQ-D4.1 — Bundling per D-11 [manual]

Verified by: spec with two consecutive ready tasks meeting the bundling rule. Both end up in one PR.

### REQ-D5.1 — Format gate with retrofit offer [manual]

```gherkin
[Gherkin]
Given a spec whose tasks.md uses prose without stable IDs or Done-when conditions
When /orchestrate is invoked
Then orchestration halts before performing any move
And the agent offers to invoke /spec-kickoff in retrofit mode
And the user can accept (retrofit runs) or decline (orchestration aborts cleanly)
```

Verified by: invocation on `tecpan/specs/org` as-is. Halt and retrofit offer observed.

### REQ-D6.1 — v1 halts after PR open [manual]

Verified by: orchestration sequence ends at draft PR creation; no post-PR actions taken.

### REQ-D7.1 — Halt conditions emit `Awaiting input` [manual]

Verified by: induced failure modes (ambiguous task, hard-disqualifier finding, contract drift) each result in an inbox entry with state `awaiting-input` and a description of what's blocking.

### REQ-D8.1 — Lockfile coordination [manual]

Verified by: two concurrent `/orchestrate` invocations on the same spec. Second one no-ops cleanly with a logged reason.

## REQ-E — Continuity across sessions

### REQ-E1.1 — `tasks.md` sections present [manual]

Verified by: any spec produced by `/spec-draft` or retrofitted by `/spec-kickoff` contains all five sections.

### REQ-E1.2 — `In progress` annotation format [manual]

Verified by: a task in flight is annotated with phase and timestamp.

### REQ-E2.1, E2.2 — `/resume` loads context without requiring handover [manual]

```gherkin
[Gherkin]
Given a worktree with an in-flight task in tasks.md
And no handover brief file exists in the worktree
When the user opens a fresh Claude session in that worktree and types /resume
Then the agent reads the kickoff brief, tasks.md, recent git log, and open PR state
And produces a summary that the user verifies is sufficient to continue work
```

Verified by: actual cold-start session on a real tecpan worktree (success criterion for Task 5).

### REQ-E3.1 — Side-effect updates to tasks.md [manual]

Verified by: each affected skill's run produces a corresponding tasks.md edit observable in git diff.

### REQ-E4.1 — Optional handover brief does not block resume [design-level only]

Verified by: `/resume` skill's prompt explicitly states the handover is optional; absence is not an error.

## REQ-F — Cross-session awareness

### REQ-F1.1, F1.2 — Inbox substrate exists and writes JSON [manual]

Verified by: `~/.claude/inbox/` exists; sample inbox entry contains the documented fields (`host`, `session`, `repo`, `branch`, `state`, `timestamp`, optional `summary`).

### REQ-F2.1 — tmux popup renders inbox [manual]

```gherkin
[Gherkin]
Given two concurrent Claude sessions writing inbox entries
When the user presses the bound tmux key combination
Then a popup appears listing both entries
And entries with state "awaiting-input" appear first in the list
And selecting an entry shows its full JSON contents
```

Verified by: actual two-session test (success criterion for Task 3).

### REQ-F2.2 — tmux status segment counts `awaiting-input` [manual]

Verified by: same test; status bar segment shows the correct integer.

### REQ-F3.1 — macOS notification on state transition [manual]

Verified by: triggered transition observed as a macOS Notification Center entry.

### REQ-F4.1 — Phone push is out of scope for v1 [design-level only]

Verified by: v1 ships without phone push integration; design accommodates layering it on later (the inbox file substrate is the future reader's source).

## REQ-G — Operational integration

### REQ-G1.1 — Panel-* investigation deliverable exists [manual]

Verified by: `specs/pair-flow/research/panel-underuse.md` exists, names a primary cause, cites transcript evidence, and recommends one of the three options (Task 1's `Done when`).

### REQ-G2.1 — File-path PreToolUse hook installed [manual]

Verified by: hook is wired in `settings.json`, manually exercised on a known-bad path, clean error observed. Telemetry baseline (82 mistakes/month) re-measured 30 days post-install and compared.

### REQ-G3.1 — Codex default on all profiles [manual]

Verified by: `/panel-review --help` (or equivalent) and skill source on each profile show codex as the default backend.

### REQ-G4.1 — New skills tracked under Ansible role [manual]

Verified by: each new skill file lives at `roles/osx/files/claude/commands/<name>.md` and is materialized into `~/.claude/commands/` after `mise run osx`.

### REQ-G5.1 — New hooks wired in settings.json [manual]

Verified by: each new hook is referenced in the tracked `roles/osx/files/claude/settings.json` and appears in the materialized file.

### REQ-G6.1 — Project CLAUDE.md updated [manual]

Verified by: a cold-read of the project CLAUDE.md by the user surfaces no missing information about the pipeline (Task 14's `Done when`).

## What's not tested here

Explicitly listing out-of-scope verification so the bar is clear:

- **Performance of the orchestrator under load.** Not measured. The system is single-user, not a service. Sub-second responsiveness is not a goal.
- **Security of inbox JSON contents.** The inbox is on the user's filesystem; contents are not encrypted. If the user syncs via iCloud, Apple's encryption applies at rest. No additional encryption layer is verified.
- **Behavior under git merge conflicts in `tasks.md`.** Possible during concurrent orchestrator runs. Handled at the merge level; no special tooling.
- **Cross-version compatibility with future Claude Code releases.** The skills depend on Claude Code's slash-command and hook contracts; breakage on upgrade is detected by the next test cycle, not pre-emptively.
- **Telemetry accuracy.** The post-implementation re-analysis is point-in-time; not continuously validated.
- **Multi-reviewer behavior end-to-end.** The predicate (D-3, D-4) is implemented to support it, but the actual workflow on paycalc is out of v1 scope (see Out of scope in `tasks.md`).
- **`/copilot-pairing` and `/copilot-review` integration.** These remain transitional and unchanged by this spec.
