Iterate `/panel-review` autonomously, applying only Auto-applicable items, until none remain. Hand control back when no Auto-applicable items are left to drain (surfacing any Needs sign-off and Needs human judgment items in the final tables) or any safety condition fires.

Same Discovery + Validation rigor as `/panel-review`, executed on autopilot, with hard stop conditions baked in for safety.

## When to use

You want the `/copilot-pairing` shape (review, address, push, re-review, repeat) but with non-Anthropic model backends doing the discovery instead of GitHub Copilot. Common cases:

- Copilot quota is exhausted for the month and you still want pairing-style autonomous draining.
- You want backend variance (different training distributions) without GitHub's per-request billing model.
- You are starting from a branch with no PR yet and want pairing-style cleanup before opening one.

`/panel-pairing` is the autonomous counterpart to `/panel-review`. It only auto-applies items in the Auto-applicable bucket (CLAUDE.md `Finding Categorization`); Needs sign-off and Needs human judgment items are surfaced for human review when the loop exits, same boundary `/polish` uses for self-review. For interactive review of all buckets, use `/panel-review` directly.

## Pre-flight (once per run)

1. **Identify base branch and capture the diff** (same as `/panel-review` pre-flight 1).
2. **(Optional) Jira ticket** (same as `/panel-review` pre-flight 2).
3. **Detect repo profile** (same as `/panel-review` pre-flight 3).
4. **Resolve the backend set.** Same logic as `/panel-review` pre-flight 4, but with different profile defaults tuned for autonomous loops (more variance, you walk away during iterations):

   | Profile | Default backends |
   |---|---|
   | work | `codex`, `qwen-coder` |
   | personal | `qwen-coder`, `deepseek-r1` |

   `--backends` overrides. `copilot` is opt-in only.

5. **Verify each backend** (same as `/panel-review` pre-flight 5; stop with the same install / auth messages on any failure).
6. **Initialize iteration counter** = 0.
7. **Confirm the working tree is clean.** `git status --porcelain` must be empty before the loop starts. Uncommitted changes interfere with per-iteration commit boundaries and make rollback ambiguous. If the tree is dirty, stop and ask the user to commit or stash first.
8. **Confirm the branch has an upstream**, or that the first push will create one. `git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds when an upstream exists; if it fails, the first push in step (e) uses `git push -u origin <branch>` instead of `git push origin <branch>`. Do not pre-push at pre-flight; the first iteration's push handles it.

## Iteration loop

For each iteration (cap = **15**):

**Cap check (run at the start of every iteration, before step (a)).** Read the iteration counter (initialized to 0 in pre-flight step 6; incremented in step (f)). If the counter has reached **15**, do not enter step (a). Trigger the **Iteration cap** stop condition and hand control back. This is the only place the cap is enforced; the increment in (f) does not enforce it itself.

### a. Generate + validate findings

Run `/panel-review` steps 1-5 in full: project tooling sweep, parallel backend discovery pass, merge + dedupe, self-critique pass, three-pass Validation Rigor on every finding.

Be more conservative than in `/panel-review` because nobody is checking the categorization in real time. **When in doubt, route to Needs sign-off or Needs human judgment, never Auto-applicable.** False negatives (a real Auto-applicable item routed to human) are cheap, costing one extra iteration. False positives (a judgment item auto-applied) silently corrupt the branch.

### b. Categorize per `Finding Categorization`

Each finding lands in exactly one bucket: Auto-applicable, Needs sign-off, or Needs human judgment. The four Auto-applicable conditions and disqualifiers are in CLAUDE.md `Finding Categorization`.

### c. Decide loop fate

Branch on the bucket counts:

- **All three buckets empty.** Success. Exit the loop. Print the final summary noting "panel converged, no findings remain". Do not commit (nothing changed this iteration).
- **Auto-applicable empty, Needs sign-off or Needs human judgment non-empty.** Stop. Trigger **Human attention required** stop condition. Print the latest tables (Auto-applicable empty, both other buckets populated) and hand control back. Do not push, do not commit, do not auto-apply anything from the populated buckets.
- **Auto-applicable non-empty, regardless of the other buckets.** Proceed to step (d). Items in the other buckets are re-evaluated next iteration; the user addresses them after `/panel-pairing` hands off.

### d. Apply Auto-applicable items (solution validation rigor)

For each Auto-applicable item, apply CLAUDE.md `Validation Rigor (Solutions)` even though the fix is mechanical:

1. **Pre-fix tool run.** Run the cited tool against the file(s) and confirm the rule actually fires on the current code. If it does not (e.g., the rule was already silenced, the file changed since discovery), drop the item and continue. Do not apply a fix for a rule that does not currently fire.
2. **Apply the fix.**
3. **Post-fix tool run.** Run the cited tool again against the same file(s) and confirm the rule no longer fires.
4. **Wider check.** Run the broader project test suite, linters, and type-checkers. Any failure (even a pre-existing one we surface for the first time) triggers the **Test failure** stop condition.

For non-testable fixes (formatting, typos in comments, doc adjustments), substitute review angles per the canonical doctrine in CLAUDE.md.

### e. Commit and push

Order matters: land the code, then move on.

1. `git add` only the files actually changed (never `git add -A`).
2. Commit with a message of the form `chore(panel): iter N, <short summary>` (e.g., `chore(panel): iter 1, drop unused imports and fix typos`).
3. Push: `git push origin <branch>` (or `git push -u origin <branch>` on the first iteration if pre-flight step 8 detected no upstream). **Never** `--force`, `--force-with-lease`, or any rebase flag. If the push fails on a hook (pre-push test, security check, lefthook stage, etc.), trigger the **Push hook failure** stop condition; do not silently retry, do not bypass with `--no-verify`, and do not "fix" unrelated test flakes inside this branch.
4. Do **not** amend, squash, or rebase. Each iteration is its own commit so you can inspect and revert per-iteration if needed.

### f. Iteration summary

Print a short summary:

- Iteration N / cap.
- Backends invoked + wall-clock per backend (so you can see which were slow / fast).
- Counts: Auto-applicable applied, Needs sign-off surfaced, Needs human judgment surfaced, dropped at step (d.1) (rule no longer fires).
- Files touched.
- Commit SHA.
- Test command run + result.

This is what you scroll back through to audit the run. Then increment iteration counter and loop to (a).

## Stop conditions (mandatory human handoff)

If any condition fires, **stop**. Print the latest tables, name the condition, and wait for the user. Do not commit further, do not push, do not invoke backends again.

| Condition | Trigger |
|---|---|
| **Human attention required** | Step (c) found Needs sign-off or Needs human judgment items and Auto-applicable is empty. The normal path to handoff. |
| **Test failure** | Any test, linter, type-check, or formatter failed at step (d.4), including pre-existing failures surfaced for the first time. |
| **Push hook failure** | `git push origin <branch>` (step e.3) failed on a hook (pre-push test, security check, lefthook stage, etc.). Diagnose whether the failure traces to this iteration's diff or to pre-existing / unrelated state, surface the diagnosis, and hand off. Do not silently retry, do not bypass with `--no-verify`, and do not "fix" unrelated test flakes inside this branch. |
| **Loop detection** | A substantively similar finding (same file, same root issue, regardless of which backend surfaced it) has been raised in two consecutive iterations after the prior iteration applied a fix. Indicates the fix is not actually addressing the underlying issue, or that backends are hallucinating consistent false positives. |
| **Backend failure** | A backend invocation in step (a) failed (timeout, parse error, model error, auth lost mid-run). Stop rather than silently dropping the backend; the user invoked this skill specifically for that backend's variance. |
| **Iteration cap** | 15 iterations completed without convergence. |
| **Ambiguity** | A finding is borderline between buckets and the bright-line conditions cannot be confidently asserted across two consecutive iterations. Hand off rather than guessing. |
| **Security-sensitive** | Any Auto-applicable candidate touches auth, secrets, crypto, permissions, IAM, SQL/shell construction, or sandbox boundaries. Per the categorization disqualifiers, the item should already be Needs sign-off; if for any reason it landed in Auto-applicable, stop. |
| **Migrations / data / destructive ops** | Same as above for schema migrations, backfills, deletes, drops, anything irreversible. |
| **Dirty working tree** | Pre-flight step 7 found uncommitted changes. Stop before iteration starts. |
| **High false-positive ratio** | At least 3 items in the iteration AND more than half were dropped at step (d.1) (rule no longer fires). Backends may be misreading the diff or hallucinating tool output. Pause for re-alignment rather than spamming useless commits. |

## Auto-execution invariants

These hold at every step:

- **Never** address a Needs sign-off or Needs human judgment item, even if it looks easy. Those are reserved for the post-loop human pass via `/panel-review` or manual fixes.
- **Never** route a finding to Auto-applicable without a specific rule citation. "I am sure this is a typo" does not qualify; "ruff F401: imported but unused" does. The rule citation must come from the project tooling run in step (a), not from a backend's free-form recommendation.
- **Never** silently drop a backend that failed in step (a). The user picked the backend set; partial runs hide which variance source went missing.
- **Never** modify CI configuration, `.env`, secrets, or lockfiles, even on a tool's recommendation.
- **Never** push `--force`, `--force-with-lease`, or amend / squash / rebase commits already pushed.
- **Never** silently retry a failed `git push` or bypass with `--no-verify`. Trigger the **Push hook failure** stop condition with a brief diagnosis instead.
- **Never** create a PR. `/panel-pairing` is a fix-drain loop; PR creation is `/self-review` or `/panel-review`'s job after the loop hands off.
- **Never** post anything to chat platforms, tickets, or any remote system.
- **Never** skip step (d.4) (wider test / lint / type-check run). A "simple" fix that breaks an unrelated test is the failure mode this guards against.
- **Never** trust the iteration counter alone for cap enforcement; verify at the top of the iteration via the explicit cap check.

## After the loop

When `/panel-pairing` exits (success, human handoff, or any other stop condition), the next move is the user's:

- On success ("panel converged, no findings remain"): consider running `/self-review` or `/panel-review` to do a final pass and open a PR.
- On Human attention required: address the surfaced Needs sign-off and Needs human judgment items by running `/panel-review` interactively (or `/self-review` if you want Claude-only review of the remainder). After they are resolved, re-run `/panel-pairing` to drain anything new and open a PR.
- On Test failure, Push hook failure, or other safety stops: investigate the named condition. `/panel-pairing` does not auto-resume; the user explicitly re-invokes after the underlying issue is understood.

## Maintenance

After completing the workflow (or stopping), check if any part of these instructions seems outdated, incorrect, or misaligned with current tooling: backend CLI command syntax changes, changes to `Finding Categorization` thresholds, new auto-fix tools that should be tool-grounded by default, drift from `/panel-review`'s discovery shape (which `/panel-pairing` follows), or stop-condition gaps revealed by a real run. If something looks off, flag it and offer a ready-to-use prompt to paste into a new dotfiles session to update this command.

$ARGUMENTS
