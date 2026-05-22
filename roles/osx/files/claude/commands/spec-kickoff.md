Walk a spec at `<spec-path>` section by section with the human, producing a signed-off kickoff brief at `specs/{feature}/kickoff-brief.md`. The brief is the durable contract between human and agent: every downstream pair-flow skill (`/execute-task`, `/orchestrate`) operates from it, not by re-reading the spec.

`/spec-kickoff` is a **didactic walkthrough, not a checklist** (D-7). The value is in the agent restating each section in its own words, surfacing implicit domain terms, and posing Socratic checks the human can answer or red-line. Questions that surface things neither party realized needed to be said are the success signal. A walkthrough that flows without friction probably means the questions were too soft.

The brief is written **incrementally** (D-41): each signed-off section appends to `kickoff-brief.md` immediately, so a killed session leaves a partial brief that the next invocation resumes from. The spec status flips `Draft` → `Active` on the final sign-off (D-31, REQ-A3.2), and the spec is committed to git as part of the bundle (REQ-A2.11, D-49).

Sources: REQ-A2.1 through REQ-A2.12, REQ-A3.1, REQ-A3.2, REQ-D9.1, D-7, D-19, D-20, D-27, D-31, D-35, D-40, D-41, D-42, D-49, D-51 in `specs/pair-flow/`.

## When to use

You have an existing spec bundle (a `specs/{feature}/` directory with `requirements.md`, `design.md`, `tasks.md`, `test-spec.md`) and you want to sign off on a shared understanding before letting `/execute-task` or `/orchestrate` run against it. Two paths converge here:

- **New spec.** Just drafted with `/spec-draft` (or by hand). No prior brief. Walk the whole thing.
- **Retrofit on an existing spec.** The spec predates pair-flow or its task structure does not meet D-15. The skill walks the spec normally, and at the task-graph step proposes the patches needed to make it orchestratable (stable IDs, `Done when:`, `Dependencies:`, `Citations:` per task).

A third path is **partial-invalidation re-walkthrough** (D-27, D-35): a previously signed-off brief exists, but the spec changed. The skill detects which sections of the brief are still valid and walks only the rest.

`/spec-kickoff` does **not** implement code, open PRs, or run tests. Its only output is the brief plus the status flip and, in retrofit mode, edits to the spec bundle itself.

## Pre-flight (once per run)

1. **Resolve the spec path.** Read `$ARGUMENTS`. If empty, ask the user for the spec path; do not guess from the cwd. Verify the path exists and is a directory. If not, halt with a clear error.

2. **Verify the four-file bundle.** Confirm `requirements.md`, `design.md`, `tasks.md`, `test-spec.md` all exist in the directory. If any is missing, halt and ask whether the user wants to invoke `/spec-draft` instead. `/spec-kickoff` does not create the bundle from scratch.

3. **Run the structural validator.**

   ```
   ~/.claude/scripts/spec-validate.sh <spec-path>
   ```

   Capture the full output and the exit code.

   - Exit 0 with 0 warnings: structure is clean; proceed.
   - Exit 0 with warnings (status is `Draft`): retrofit-mode candidate. Surface the warnings to the user, name this as retrofit mode, and confirm before proceeding. If the user declines, halt cleanly.
   - Exit 1 (status is `Active` with errors): refuse to proceed until the gaps are fixed. The spec is already Active per its header but does not meet the orchestration bar; do not produce a brief on a structurally broken Active spec.
   - Exit 2 or other: surface the error and halt.

4. **Resolve repo configuration.** Run:

   ```
   ~/.claude/scripts/pair-flow-config.sh repo-class
   ```

   - Exit 0 with a value (`solo` or `multi-reviewer`): use it.
   - Exit 2 with `needs-confirmation:<inferred>`: surface the inferred value and the reasoning ("inferred from PR review history: no non-author human reviewers seen in last 30 PRs" or equivalent), and ask the user to confirm or override per REQ-D9.1 / D-20. **Never** call `confirm-repo-class` without an explicit human confirmation. On confirmation, run:

     ```
     ~/.claude/scripts/pair-flow-config.sh confirm-repo-class <value>
     ```

   - On decline, continue without writing; the brief can still be produced. The next invocation will re-prompt.

   The repo-class is recorded in the brief's preamble. It does not gate anything in this skill; downstream skills (`/polish`, `/execute-task`) consult it for the Agent-resolvable bucket.

5. **Detect an existing brief and compute invalidation scope.** Check for `specs/{feature}/kickoff-brief.md`.

   - **No brief exists.** Walk the whole spec.

   - **Partial brief exists** (the file is present but missing the final "Sign-off" section). Treat the last successfully-written section as the resume point per D-41. Show the user a one-line summary of completed sections and ask whether to resume or restart. Restart deletes the partial file and walks from the top.

   - **Signed-off brief exists.** Look at the `**Spec commit:**` line in the brief. Diff the spec files since that commit. Apply the D-51 wholesale-rewrite trigger:

     1. Both `requirements.md` AND `design.md` changed in the same commit → whole-brief invalidation.
     2. More than 50% of REQ-IDs (or D-IDs) changed in a single commit (additions or modifications; pure removals do not count) → whole-brief invalidation.

     Otherwise apply section-scoped invalidation per D-27:

     - Change to `requirements.md` REQ-X → invalidate brief sections referencing REQ-X.
     - Change to `design.md` D-Y → invalidate brief sections referencing D-Y.
     - Change to `tasks.md` (reorder, retitle, add, remove) → invalidate the Task graph section only.
     - Change to `test-spec.md` → invalidate the Verification section only.

     Show the user a one-line summary of unchanged sections (anchor context per D-35) and confirm before walking only the invalidated set.

6. **Initialize the brief skeleton if needed.** If no brief exists, write the preamble (spec path, spec commit hash from `git rev-parse HEAD`, today's date, repo-class, retrofit-mode flag if any). Commit nothing yet; the skill writes to the working tree only.

## The walkthrough

The walkthrough has **seven sections** (the same sections become the brief's sections). Walk them in order. For each section, follow the per-section pattern below.

### Section order

1. **Goal and glossary** — restate the spec's stated goal; surface implicit domain terms; confirm the glossary covers what it needs to.
2. **Requirements walkthrough** — REQ by REQ. Restate, raise edge cases, surface implicit assumptions.
3. **Design walkthrough** — D by D. Restate the decision, restate alternatives and why this one was chosen, check whether the rationale still holds today.
4. **Verification approach** — walk `test-spec.md`. Confirm every REQ is pinned to a verification path. Surface REQs that are only `[design-level only]` or `[manual]` without a concrete check.
5. **Task graph reconstruction** — read `tasks.md`. Topologically order tasks by `Dependencies:`. Identify parallelizable tasks. Surface unstated dependencies (a task that obviously depends on another but does not list it). In retrofit mode, this is where structural patches to `tasks.md` are proposed.
6. **Risk register** — synthesize across the prior sections. What is underspecified? What depends on external systems? What could plausibly fail and how would we notice?
7. **Sign-off** — final confirmation. Status flip happens here.

### Per-section pattern

For each section:

**a. Read.** Read the relevant portion of the spec file(s) directly. Do not paraphrase from memory.

**b. Restate.** Restate the section in the agent's own words to the user. The restatement should be substantive enough that the user can spot a misread. One paragraph for a small section, several for a large one. Do not just summarize: name the thing the section is claiming, name the thing it is ruling out, and name the assumption it carries.

**c. Surface implicit terms and assumptions.** Identify any domain term used without definition, any assumption that depends on the reader's prior context, or any term used inconsistently across the spec. Surface these as "Definition you may want to add:" or "Assumption I am making: ..."

**d. Pose Socratic checks.** At each section, raise the relevant flavor of Socratic check:

- **Goal section:** slicing sanity — is this scoped tight enough to ship, or too tight to be useful? Are we conflating multiple goals?
- **Requirements section:** edge cases — what input or state would make this REQ ambiguous? Is the SHALL language doing real work or padding?
- **Design section:** decision rationale — does the "Chosen because" still hold? Were the alternatives really rejected for the reasons stated, or is there a load-bearing assumption hidden in "Rejected because"?
- **Verification section:** verifiability — is the verification path actually executable, or does it require judgment we have not specified?
- **Task graph section:** unstated dependencies — does Task N actually depend on M even though it does not list M? Is the order stable across reorderings?
- **Risk register:** failure modes — what would have to be true for the system to silently fail? Who notices?

The questions should be specific. "Are there edge cases?" is too soft; "REQ-X1.1 says SHALL refresh every 30 seconds — what happens if the heartbeat is mid-write when the session is killed?" is what the walkthrough is for.

**e. Surface inconsistencies (D-42 escalation gate).** If during the restatement or Socratic checks a genuine inconsistency emerges — a REQ contradicts another, a design choice conflicts with a requirement, a glossary term means different things in different sections — **halt the walkthrough**. Do not write the section to the brief. Surface the inconsistency to the user and offer two paths per D-42:

   - **(a) Edit the spec.** User edits `requirements.md`, `design.md`, etc. (or invokes `/spec-draft` to redo affected portions), then re-runs `/spec-kickoff`. The partial brief is preserved.
   - **(b) Record an explicit override.** User confirms the apparent inconsistency is intentional. Record the override in the brief's preamble with a one-line explanation, then continue.

   Do not silently proceed. The whole point of the contract is that disagreements are on record.

**f. Wait for sign-off on the section.** The user red-lines the restatement, answers the Socratic checks, and confirms the section is signed off. Take the time the user needs; the walkthrough is interactive.

**g. Write the signed-off section to the brief.** Append the section to `kickoff-brief.md` immediately (D-41). Include:

   - The agent's restatement (as a paragraph or two of prose)
   - The surfaced implicit terms (as a bulleted list)
   - The Socratic checks raised and the user's answers
   - Any explicit assumptions the user red-lined into the section
   - A `Signed off: <YYYY-MM-DD>` line at the end of the section

   Do not commit yet. The brief lives in the worktree; a commit lands after the final sign-off.

   Update `Last reviewed:` on the spec files only when the kickoff edits them (retrofit mode, D-42 path-b override notes). The brief is the kickoff's own output; it does not need a `Last reviewed:` of the spec it walks.

### Retrofit mode specifics

When the validator surfaced warnings about D-15 task structure (missing `Done when:`, `Dependencies:`, `Citations:`, or stable IDs in `tasks.md`), the **Task graph reconstruction** section also produces patches to `tasks.md`:

- Walk each task in order.
- Propose stable IDs in the form `Task N` or `Task N.M` consistent with existing tasks in the bundle.
- Propose `Done when:` conditions derived from the task description, surfaced to the user for red-line.
- Propose `Dependencies:` derived from the task graph reconstruction work just done.
- Propose `Citations:` derived from REQs and Ds the task touches.

Each proposed patch waits for user red-line before being applied. Apply patches via `Edit`; update `Last reviewed:` on `tasks.md` to today (REQ-A2.9, D-40). Re-run the validator after patches are applied to confirm structure now meets the bar.

### Partial-invalidation walk

When only some brief sections are invalidated (D-27, D-35):

- Show the user a one-line per unchanged section to anchor context ("Section 2 (Requirements walkthrough): unchanged, signed off 2026-05-08.").
- Walk only the invalidated sections, using the per-section pattern.
- Overwrite each invalidated section in `kickoff-brief.md` with the freshly-walked content and a new `Signed off:` date.
- Leave unchanged sections alone.

## Sign-off and status flip

After the seventh section (Sign-off) is confirmed:

1. **Final confirmation prompt.** Surface the brief's current state to the user: section count, retrofit-mode flag, override notes if any, spec commit hash. Ask for explicit "sign off" confirmation. Anything less than an explicit confirmation means do not flip status.

2. **Flip spec status to Active.** Edit each of the four spec files' `**Status:** Draft` line to `**Status:** Active`. Update each file's `**Last reviewed:**` to today (REQ-A2.9, D-40). Use `Edit` per file; do not rewrite the files wholesale.

3. **Re-run the validator** against the bundle. Status is now Active, so warnings have become errors. If the validator reports any error, **revert the status flip on all four files**, surface the error, and ask the user how to proceed. Do not leave the spec in an Active-but-invalid state.

4. **Write the brief's final preamble fields.** Spec commit hash (from `git rev-parse HEAD`), final sign-off date, status-flip confirmed.

5. **Stage the changes.** `git add` the four spec files and `kickoff-brief.md` (and `tasks.md` patches if retrofit mode). Do **not** commit and do **not** push; the user runs commit on their own to allow them to bundle other changes or inspect first. Print the staged file list and a suggested commit message: `docs(spec): {feature} kickoff-brief; status Draft -> Active`.

The brief is now the contract. Downstream pair-flow skills can run against this spec.

## Stop conditions (mandatory human handoff)

Halt and hand control back when any condition fires. Do not work around any of these.

| Condition | Trigger |
|---|---|
| **Inconsistency in the spec** | D-42 surfaced a genuine contradiction. User chose path (a) to edit the spec, or refused path (b). Brief is not written. |
| **Validator error after status flip** | Status flip produced errors. Revert and surface. |
| **Retrofit declined** | Validator reported D-15 gaps but user declined retrofit. Brief is not produced (cannot sign off on a spec the user does not want to fix). |
| **Repo-class not confirmed** | The user declined to confirm the inferred `repo-class`. Brief proceeds but downstream Agent-resolvable behavior degrades; flag this in the brief's preamble. |
| **Partial brief stale beyond resume** | The partial brief references a spec commit the agent cannot find (force-pushed, rebased away). Stop and surface the staleness. |
| **Ambiguity that cannot be resolved in walkthrough** | A Socratic check exposes a question the user genuinely cannot answer in this session. Record it as an open question in the brief's risk register and ask whether to halt or continue. Continuing means the brief is incomplete and the open question must be closed before `/execute-task` runs against the task that depends on it. |
| **Spec validation failed before walk** | Active spec with errors at pre-flight step 3. |

## Invariants

These hold at every step:

- **Never** write to `kickoff-brief.md` until the human signs off on the section (D-41 incremental, not eager).
- **Never** flip status to `Active` without explicit human sign-off at section 7.
- **Never** silently write to `~/.claude/pair-flow.local.yml`. Always confirm with the human before calling `confirm-repo-class` (REQ-D9.1, D-20).
- **Never** produce a brief on a spec with an unresolved inconsistency (D-42).
- **Never** treat retrofit-mode patches as auto-applicable. Each patch waits for human red-line.
- **Never** commit or push. The human runs commit at the end.
- **Never** invoke `/execute-task`, `/orchestrate`, `/polish`, or any other pair-flow skill from inside the walkthrough. Kickoff is its own concern.
- **Never** skip the validator pre-run or the validator post-flip. The status-aware enforcement (D-45) is load-bearing.
- **Never** rewrite the four spec files wholesale on the status flip. Use `Edit` so the diff is surgical.

## Maintenance

After completing the walkthrough (or halting), check if any part of these instructions seems outdated or misaligned with the current pair-flow spec at `specs/pair-flow/`: changes to D-7, D-15, D-27, D-31, D-35, D-41, D-42, D-49, or D-51; new fields in `tasks.md`'s task structure; changes to the helper scripts. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
