Iterate `/self-review` autonomously, applying only Auto-applicable items, until none remain. Hand control back the moment anything Needs human attention or any safety condition fires.

Same Discovery + Validation rigor as `/self-review`, executed on autopilot, with hard stop conditions baked in for safety.

## When to use

You are nearly done with a branch and want to drain the trivial, tool-grounded fixes (linter rule violations, formatter output, type-checker errors, missing imports, unused variables, typos in comments, inferable type annotations) before opening a PR. Polish auto-applies items that meet the strict Auto-applicable definition in CLAUDE.md `Finding Categorization` and stops the moment anything needs your judgment.

Polish does **not** create a PR. Run `/self-review` after Polish hands off, once you have addressed the Needs human attention items.

## Pre-flight (once per run)

1. **Identify the base branch and capture diff baseline** (same as `/self-review` step 1).
2. **(Optional) Fetch Jira ticket for context** (same as `/self-review` step 2). Used only as an extra lens during Discovery Rigor, not as a fix authority. Failing to satisfy an acceptance criterion is always Needs human attention.
3. **Initialize iteration counter** = 0.
4. **Confirm the working tree is clean.** Polish requires `git status --porcelain` to be empty before it starts. Uncommitted changes interfere with the per-iteration commit boundary and make rollback ambiguous. If the tree is dirty, stop and ask the user to commit or stash first.

## Iteration loop

For each iteration (cap = **10**):

**Cap check (run at the start of every iteration, before step (a)).** Read the iteration counter (initialized to 0 in pre-flight step 3; incremented in step (f)). If the counter has reached **10**, do not enter step (a). Trigger the **Iteration cap** stop condition and hand control back.

### a. Generate findings via parallel lens fan-out

Apply `/self-review` step 3 in full: parallel `Explore` sub-agents per canonical lens, shared tooling output as input, coordinator merges and dedupes, self-critique pass. Then `/self-review` step 4 (Validation Rigor) on every finding.

### b. Categorize per CLAUDE.md `Finding Categorization`

Each finding lands in exactly one bucket: **Auto-applicable** (all four bright-line conditions met, no disqualifiers) or **Needs human attention** (everything else). The four conditions:

1. Tool-grounded (a specific linter / type-checker / formatter / static-analyzer rule was cited).
2. Mechanical fix (rename, reformat, drop-unused, missing-import, missing-newline, typo, inferable-type-annotation; no design decision).
3. No user-observable behavior change.
4. All three Validation Rigor passes converged with high confidence.

Plus the unconditional disqualifiers (security-sensitive code, migrations, destructive ops, CI config, lockfiles, secrets files, .env). Anything disqualified is Needs human attention regardless of how mechanical the fix looks.

Be more conservative than `/self-review` because nobody is checking the categorization in real time. **When in doubt, route to Needs human attention.** False negatives (a real Auto-applicable item routed to human) are cheap, costing one extra iteration. False positives (a judgment item auto-applied) silently corrupt the branch.

### c. Decide loop fate

Branch on the bucket counts:

- **Both buckets empty.** Success. Exit the loop. Print the final summary noting "no findings remain". Do not commit.
- **Auto-applicable empty, Needs human attention non-empty.** Stop. Trigger **Human attention required** stop condition. Print the latest tables and hand control back. Do not push, do not commit, do not auto-apply anything.
- **Auto-applicable non-empty, regardless of Needs human attention count.** Proceed to step (d). Items in Needs human attention will be re-evaluated next iteration; the user can address them after Polish hands off.

### d. Apply Auto-applicable items (solution validation rigor)

For each Auto-applicable item, apply CLAUDE.md `Validation Rigor (Solutions)` even though the fix is mechanical. The reason: a "simple" fix can still break tests if the rule citation was wrong about scope or the fix has subtle implications.

1. **Pre-fix tool run.** Run the cited tool against the file(s) and confirm the rule actually fires on the current code. If it does not (e.g., the rule was already silenced, the file changed since discovery), drop the item and continue. Do not apply a fix for a rule that does not currently fire.
2. **Apply the fix.**
3. **Post-fix tool run.** Run the cited tool again against the same file(s) and confirm the rule no longer fires.
4. **Wider check.** Run the broader project test suite, linters, and type-checkers. Any failure (even a pre-existing one we surface for the first time) triggers the **Test failure** stop condition.

For non-testable fixes (formatting, typos in comments, doc adjustments), substitute review angles per the canonical doctrine in CLAUDE.md.

### e. Commit

Commit the changes from this iteration:

- `git add` only the files actually changed (never `git add -A`).
- Commit with a message of the form `chore(polish): iter N, <short summary>` (e.g., `chore(polish): iter 1, drop unused imports and fix typos`).
- Do **not** push. Polish does not interact with remotes; pushing is `/self-review`'s job.
- Do **not** amend, squash, or rebase. Each iteration is its own commit so the user can inspect and revert per-iteration if needed.

### f. Iteration summary

Print a short summary:

- Iteration N / cap
- Counts: Auto-applicable applied, Needs human attention surfaced (carried into next iteration's input), dropped at step (d.1) (rule no longer fires)
- Files touched
- Commit SHA
- Test command run + result

This is what the user scrolls back through to audit the run. Then increment iteration counter and loop to (a).

## Stop conditions (mandatory human handoff)

If any condition fires, **stop**. Print the latest tables, name the condition, and wait for the user. Do not commit further, do not modify anything else.

| Condition | Trigger |
|---|---|
| **Human attention required** | Step (c) found Needs human attention items and Auto-applicable is empty. The normal path to handoff. |
| **Test failure** | Any test, linter, type-check, or formatter failed at step (d.4), including pre-existing failures surfaced for the first time. |
| **Loop detection** | The same Auto-applicable item has been "fixed" in two consecutive iterations (rule fires before the fix in iteration N, fires again before the fix in iteration N+1). Indicates the fix is not actually addressing the rule. |
| **Iteration cap** | 10 iterations completed without convergence. |
| **Ambiguity** | A finding is borderline between buckets and the four bright-line conditions cannot be confidently asserted. Always route to Needs human attention; the bucket re-evaluation in the next iteration is the safety net, but if it persists across iterations, stop. |
| **Security-sensitive** | Any Auto-applicable candidate touches auth, secrets, crypto, permissions, IAM, SQL/shell construction, or sandbox boundaries. Per the categorization disqualifiers, the item should already be Needs human attention; if for any reason it landed in Auto-applicable, stop. |
| **Migrations / data / destructive ops** | Same as above for schema migrations, backfills, deletes, drops, anything irreversible. |
| **Dirty working tree** | Pre-flight step 4 found uncommitted changes. Stop before iteration starts. |
| **High false-positive ratio** | At least 3 items in the iteration AND more than half were dropped at step (d.1) (rule no longer fires). The model may be misreading the diff or hallucinating tool output. Pause for re-alignment rather than spamming useless commits. |

## Auto-execution invariants

These hold at every step:

- **Never** address a Needs human attention item, even if it looks easy.
- **Never** route a finding to Auto-applicable without a specific rule citation. "I am sure this is a typo" does not qualify; "rubocop Style/UnlessElse" does.
- **Never** modify CI configuration, `.env`, secrets, or lockfiles, even on a tool's recommendation.
- **Never** push, force-push, amend, squash, or rebase. Polish is local-only; remote interaction is `/self-review`'s job.
- **Never** create a PR. The user runs `/self-review` after Polish hands off.
- **Never** post anything to chat platforms, tickets, or any remote system.
- **Never** skip step (d.4). A "simple" fix that breaks an unrelated test is the failure mode this guards against.
- **Never** trust the iteration counter alone for cap enforcement; verify at the top of the iteration via the explicit cap check. Confirmation bias from a long successful run is the failure mode this catches.
- **Never** call any of the other review skills (`/copilot-review`, `/copilot-pairing`, `/peer-review`, `/code-review`, `/self-review`) from inside the loop. Polish runs `/self-review`'s discovery and validation steps directly; it does not invoke the skill, which would re-trigger pre-flight, prompt the user for workflow choice, or attempt PR creation.

## After the loop

When Polish exits (success, human handoff, or any other stop condition), the next move is the user's:

- On success ("no findings remain"): consider running `/self-review` to make a final pass and open a PR.
- On Human attention required: address the surfaced items. After they are resolved, re-run `/polish` to drain anything else, then `/self-review` to wrap up.
- On Test failure or other safety stops: investigate the named condition. Polish does not auto-resume; the user explicitly re-invokes after the underlying issue is understood.

## Maintenance

After completing the workflow (or stopping), check if any part of these instructions seems outdated, incorrect, or misaligned with current tooling: changes to the canonical lens list, changes to `Finding Categorization` thresholds, new auto-fix tools that should be tool-grounded by default, or drift from `/self-review`'s discovery shape (which Polish follows). If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
