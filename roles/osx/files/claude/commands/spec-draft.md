Interactively elicit a spec from the user, producing the four-file bundle (`requirements.md`, `design.md`, `tasks.md`, `test-spec.md`) at `specs/{feature-name}/` with status `Draft`. The skill guides the user through structured thinking about goals, requirements, design decisions, task decomposition, and verification paths.

`/spec-draft` is a **collaborative authoring tool**, not a one-shot generator. Each section pauses for user input, red-lining, and confirmation before proceeding. The output is a spec bundle ready for `/spec-kickoff` sign-off.

Sources: REQ-A1.1 through REQ-A1.7, REQ-A3.1, REQ-A3.2 in `specs/pair-flow/`.

## When to use

You want to create a new spec for a feature, improvement, or system change. Two entry paths:

- **From scratch**: you have an idea and want to structure it.
- **From seed material** (REQ-A1.7): you have notes at `specs/_pending/notes.md`, a spike doc, partial requirements, or a conversation transcript. The skill uses these as input to bootstrap the draft.

After `/spec-draft` produces the bundle, the next step is `/spec-kickoff` to walk through and sign off.

## Pre-flight (once per run)

### 1. Parse the feature name from `$ARGUMENTS`

Read `$ARGUMENTS`. If a feature name is provided (e.g., `/spec-draft handover-brief`), use it as the directory name: `specs/<feature-name>/`. If empty, ask the user for a short kebab-case name.

Verify the target directory does not already exist. If it does, ask whether to overwrite (destructive) or resume from the existing partial state.

### 2. Check for seed sources (REQ-A1.7)

Look for seed material in order:

1. `specs/_pending/notes.md` — a staging area for unstructured ideas.
2. A file path provided in `$ARGUMENTS` (e.g., `/spec-draft handover-brief ~/notes/handover-ideas.md`).
3. Ask the user if they have any existing notes, spike docs, or conversation transcripts to seed from.

If seed material exists, read it and use it as the starting point for the requirements elicitation. Cite the seed in requirements where applicable.

If no seed material exists, start from the user's verbal description.

## The drafting process

The drafting process has **five phases**, each producing content for one or more of the four output files. Each phase is interactive: propose, discuss, revise, confirm.

### Phase 1: Goal and scope (feeds `requirements.md` header)

**a. Ask the user to describe the feature.** Open-ended: "What problem does this solve? Who benefits? What does success look like?"

**b. Propose a one-paragraph goal statement.** This becomes the opening of `requirements.md`. It should be specific enough that someone could tell whether the system achieves it.

**c. Surface scope boundaries.** Explicitly ask: "What is out of scope?" Record these early; they prevent scope creep during later phases.

**d. Confirm.** User red-lines the goal and scope. Revise until confirmed.

### Phase 2: Requirements elicitation (feeds `requirements.md`)

**a. Extract requirement candidates.** From the goal, scope, and seed material, propose 3-7 REQ candidates. Each gets:

- A stable ID in the form `REQ-<Group><N>.<M>` (e.g., `REQ-A1.1`). Group by functional area.
- SHALL or MUST language (SHALL for mandatory behavior, MUST for constraints).
- A citation to the framing source (user statement, seed material, or inferred from context).

**b. Socratic questioning per REQ.** For each proposed REQ, ask:

- Is this actually necessary, or is it a nice-to-have?
- What happens if we don't do this?
- Are there edge cases that make this REQ ambiguous?
- Does this conflict with any other REQ?

**c. Iterate.** User adds, removes, or rewords REQs. Assign stable IDs to additions. Continue until the user confirms the set is complete.

**d. Organize into groups.** Group REQs by functional area (e.g., REQ-A for lifecycle, REQ-B for execution). Each group gets a short name.

### Phase 3: Design decisions (feeds `design.md`)

**a. Identify decision points.** From the requirements, identify places where alternatives exist. Each becomes a D-ID.

**b. For each decision point, propose:**

- **Decision:** what was chosen.
- **Alternatives considered:** at least one alternative, with a brief description.
- **Chosen because:** the rationale (not just "it's simpler", but why simplicity matters here).

**c. Surface cross-cutting concerns.** Identify themes that span multiple decisions: security, performance, compatibility, operational concerns. Record these as a section in `design.md`.

**d. Confirm.** User red-lines each decision. If the user disagrees with a choice, update the decision and rationale.

### Phase 4: Task decomposition (feeds `tasks.md`)

**a. Propose tasks.** Break the work into tasks with:

- **Stable ID:** `Task N` or `Task N.M` for sub-tasks.
- **Title:** short, descriptive.
- **Deliverables:** concrete artifacts (files, scripts, configs).
- **Done when:** conditions unambiguous enough for an agent to evaluate (REQ-A1.4). These should be observable, not aspirational.
- **Dependencies:** explicit list of other task IDs.
- **Citations:** REQs and D-IDs the task implements.
- **Estimated effort:** half day, 1 day, 2 days, etc.

**b. Order by dependency.** Tasks with no dependencies come first. Tasks with the most dependents (critical path) should be prioritized.

**c. Identify parallelism.** Note which tasks can be worked on concurrently (different dependency chains).

**d. Confirm.** User red-lines task structure, adds/removes tasks, adjusts dependencies.

**e. Add state sections.** Write the `tasks.md` with the standard sections per `specs/README.md`: `Forward plan` (all tasks initially), `Completed`, `In progress`, `Awaiting input`, `Deferred`, `Out of scope`.

### Phase 5: Verification paths (feeds `test-spec.md`)

**a. Pin each REQ to a verification path** (REQ-A1.5). For each REQ, propose one of:

- A specific test name or Gherkin scenario (for behavior that can be tested).
- `[manual]` with a description of what to check manually.
- `[design-level only]` for REQs verified by design inspection rather than runtime behavior.

**b. Use Gherkin selectively** (per D-8). Use `Given / When / Then` format when the behavior benefits from explicit state/trigger/outcome separation. Not required for every entry.

**c. Confirm coverage.** Every REQ must appear in `test-spec.md`. Surface any REQ that has no clear verification path and ask the user how to verify it.

## Writing the bundle

After all five phases are confirmed, write the four files:

### `requirements.md`

```markdown
# <Feature Name> — Requirements

**Status:** Draft
**Last reviewed:** <today's date>

## Goal

<goal statement from Phase 1>

## <Group A name>

- **REQ-A1.1** <requirement text>
...

## Sources

<citations to seed material, conversations, docs>
```

### `design.md`

```markdown
# <Feature Name> — Design

**Status:** Draft
**Last reviewed:** <today's date>

## Decision log

### D-1: <decision title>

**Decision:** <what was chosen>

**Alternatives considered:**
- <alternative 1>. Rejected because: <reason>.

**Chosen because:** <rationale>

...

## Cross-cutting concerns

<themes from Phase 3c>
```

### `tasks.md`

```markdown
# <Feature Name> — Tasks

**Status:** Draft
**Last reviewed:** <today's date>

## Forward plan

### Task 1 — <title>

- **Deliverables:** <artifacts>
- **Done when:** <conditions>
- **Dependencies:** <task IDs or "none">
- **Citations:** <REQ-IDs, D-IDs>
- **Estimated effort:** <estimate>

...

## Completed

(none yet)

## In progress

(none yet)

## Awaiting input

(none yet)

## Deferred

(none yet)

## Out of scope

(none yet)
```

### `test-spec.md`

```markdown
# <Feature Name> — Test Spec

**Status:** Draft
**Last reviewed:** <today's date>

## <Group A name>

### REQ-A1.1 — <short description> [manual|test|Gherkin]

<verification path>

...
```

## Post-write validation (REQ-A1.6)

After writing all four files, run the spec validator:

```
~/.claude/scripts/spec-validate.sh specs/<feature-name>
```

- **0 errors, 0 warnings:** the spec meets the structural bar. Declare it stakeholder-ready.
- **Warnings:** surface them to the user. These are non-blocking but worth addressing. Offer to fix them inline.
- **Errors:** surface them. These must be fixed before the spec is usable by `/spec-kickoff`. Fix inline and re-run.

Do not declare the spec stakeholder-ready until the validator passes with 0 errors.

## Final output

After validation passes, tell the user:

1. The bundle is at `specs/<feature-name>/` with status `Draft`.
2. Next step: review the bundle cold, then invoke `/spec-kickoff specs/<feature-name>` to walk through and sign off (flips to Active).
3. The files are in the working tree (not committed). The user should review and commit at their discretion.

## Invariants

These hold at every step:

- **Status is always `Draft`** (REQ-A3.1). Only `/spec-kickoff` flips to Active.
- **All four files produced as a bundle.** No partial output (either all four or none).
- **Every REQ has a stable ID, SHALL/MUST language, and a citation.**
- **Every D-ID has Decision, Alternatives considered, and Chosen because.**
- **Every task has Deliverables, Done when, Dependencies, Citations, and Estimated effort.**
- **`test-spec.md` covers every REQ** with at least one verification path entry.
- **Interactive throughout.** Never generate the full bundle without user confirmation at each phase. The value is in the user thinking through the structure, not in the generated text.
- **Never commit or push.** The user handles that.
- **Never invoke `/spec-kickoff` or any execution skill.** Drafting and sign-off are separate concerns.
- **Validator must pass** before declaring the spec stakeholder-ready (REQ-A1.6).

## Maintenance

After completing a draft (or halting), check if any part of these instructions seems outdated or misaligned with: changes to the four-file format in `specs/README.md`, changes to the validator's checks, changes to the `tasks.md` section conventions, or changes to REQ-A1.x in the pair-flow spec. If something looks off, flag it and offer a ready-to-use prompt to update this command.

$ARGUMENTS
