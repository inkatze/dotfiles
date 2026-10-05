---
name: copilot-review
description: Review and address unresolved GitHub Copilot review threads on the current PR. Pass `--nested` to loop autonomously (address, push, re-request review, wait, repeat) until convergence or diminishing returns. Runs only when the operator types `/copilot-review` or a parent skill calls it; never on the model's own initiative, and a plain-language request is answered by naming the command to type.
argument-hint: "[--nested]"
---

Review and address unresolved GitHub Copilot review threads on the current PR. Pass `--nested` to loop autonomously (address, push, re-request review, wait, repeat) until convergence or diminishing returns, instead of running one interactive pass.

## Invocation modes

Read the literal flag `--nested` from `$ARGUMENTS` at the start of the run.

- **Standalone** (no flag): run "## Steps" once: fetch threads, validate, record, act and walk (step 6), commit and push (step 7), reply and resolve (step 8).
- **Nested** (`--nested`): run "## Nested loop (--nested)". It repeats the cycle autonomously, re-requesting Copilot's review each iteration and waiting for it, until the unresolved-thread queue converges to zero, diminishing returns set in, or a stop condition fires. It is **not** local-only: Copilot needs a pushed commit to review, so it pushes on every iteration that applies a fix (a resolve-only iteration has no new head to push). It never creates or merges the PR; at convergence it asks whether to mark the PR ready, and does so only on that run's explicit yes.

## When Copilot hasn't reviewed, and the CLI fallback

Copilot reviews when it is **requested as a reviewer**, not because of a label, so "no review" has causes a label-driven bot does not: nobody requested it, auto-review on push did not fire, the org has Copilot code review disabled, or the App is not installed there. Say which applies instead of reporting "nothing to address":

1. **Has Copilot ever reviewed this PR?** Check `reviews(last: 20)` for a Copilot-authored review (the query in nested pre-flight step 3). If it did and left zero unresolved threads, that is a clean review, not an absence.
2. **If not, offer to request one** (`y/N`, never silently; it is visible on the PR), using step (f)'s transport order.
3. **If every transport fails** (**Re-review unavailable**), offer the CLI fallback, `/panel-review --backends copilot`, saying it produces local findings with no threads to reply to or resolve. Nested mode offers it in the handoff and never runs it on its own.

## Steps

Steps 1, 3, 4, 6 and 8 supply the fetch, validate, implement and mutate methodology both modes apply; the nested loop cites them by number. Steps 5 and 7 are standalone-only.

### 1. Resolve the doctrine and get PR and repo info

Resolve planwright's review doctrine per [doctrine.md](../review-shared/doctrine.md), then:

```bash
gh pr view --json number -q '.number'
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

### 2. (Optional) Jira context

A ticket key from the branch name or PR title, fetched when Jira tools are available, for use while validating (a concern might be out of scope, or a check required by the acceptance criteria).

### 3. Fetch unresolved review threads

Take the same-PR lock, keyed `copilot-review`, per [github.md](../review-shared/github.md) (nested mode already holds it from its pre-flight), and release it when the run ends. Fetch the threads per [github.md](../review-shared/github.md), and keep those where `isResolved` is false and the first comment's author is the Copilot bot. The standard login is `copilot-pull-request-reviewer` (`__typename: Bot`), but verify per run from `reviews(last: 20)` (`last`, not `first`, which returns the oldest), and use the verified login in every `--arg bot` below, or the baseline and poll silently match nothing:

```bash
jq --arg bot 'copilot-pull-request-reviewer' '[.[].data.repository.pullRequest.reviewThreads.nodes[]
     | select(.isResolved == false and .comments.nodes[0].author.login == $bot)]'
```

Filter on `login`, not `__typename == "Bot"`, so other bots stay out; threads from other authors belong to `/peer-review`. **Zero unresolved Copilot threads** is a clean result only if Copilot actually reviewed; otherwise follow "When Copilot hasn't reviewed" above.

### 4. Validate every thread

Read the comment, the referenced file:line and enough context (callers, related modules) to understand the real behavior. Apply validation-rigor's three passes.

**Do not take Copilot's recommendation as correct.** Even when the concern is real, design the fix from first principles and validate it the same three ways: a suggested fix can treat a symptom, introduce a bug, or be unidiomatic or out of scope.

Classify each thread as **valid** (needs a fix), **false positive**, or **low-confidence** (passes did not converge; never guess).

**Adjacent findings.** After classifying, run a scoped discovery-rigor pass over the files and hunks Copilot reviewed (not the full diff; that belongs in `/self-review`), with the project's tooling and the self-critique pass. Each finding becomes a row tagged `adjacent finding`.

### 5. Record the validated table (standalone)

| # | Thread ID | File:Line | Copilot's concern | What we found | Reproduced? | Classification | Confidence | Our proposed fix |
|---|---|---|---|---|---|---|---|---|

Copilot's concern is a one-line summary, not a paste; Reproduced? is `yes`, `no` or `n/a`; the proposed fix may differ from Copilot's. Adjust columns when the PR calls for it (`Severity`, `Test plan`, `Copilot's suggested fix`, `Scope risk`).

For the adjacent findings, record the lens-coverage table (scoped to what Copilot reviewed) and finding-categorization's four tables, in fixed order, with no draft-comment column: adjacent findings are surfaced for decision, not posted. The tables go to the artifact; the turn carries the projection per [workflow.md](../review-shared/workflow.md).

### 6. Act, then walk what is left (standalone)

Route each thread per finding-categorization: a `valid` thread with a mechanical, tool-grounded fix is Auto-applicable; one with a failing-then-passing test under an active kickoff brief is Agent-resolvable; any other `valid` fix, and every `false positive` dismissal, is Needs sign-off; `low-confidence` is Needs human judgment.

Act-then-review: apply Auto-applicable and Agent-resolvable fixes, and each Needs-sign-off fix as its own `[pending-sign-off]` commit for the PR's checklist, each with validation-rigor's solution validation (for a non-testable change, substitute review angles and say in the reply why no test was added). Walk the rest per [workflow.md](../review-shared/workflow.md): dismissals, the Needs-human-judgment threads, and any adjacent finding I choose to take up, which folds into this commit. A dismissal cites the three passes and why the concern does not apply.

### 7. Commit and push

Commit, then ask before pushing (`y/N`): a model-chosen run reaches this step too, and nested mode is the one that pushes unasked. Push before any reply describes the change; on a no, stop before step 8. On a hook failure, follow the push-hook rule in [github.md](../review-shared/github.md).

### 8. Reply to and resolve each thread

Per [github.md](../review-shared/github.md): reply to each thread through the posted-body rule, rescue any pending review once after the batch, then resolve each thread. The pending-review rescue matters doubly here: Copilot, like any reader, sees nothing of a reply parented under a pending review.

## Nested loop (--nested)

Iterate autonomously until Copilot has no unresolved threads (convergence) or iterations stop paying off (diminishing returns). Copilot reviews land as `state: COMMENTED`, so the convergence signal is "the latest Copilot review of our head leaves zero unresolved Copilot threads", not a state change.

Discovery cadence: the adjacent-findings discovery pass runs on the first iteration and on the iteration that detects convergence only; middle iterations report counts. "The converging iteration" is the one whose thread work would end the loop: run the discovery pass there before declaring convergence, and converge only if it surfaces nothing new to act on. Each pass records its lens-coverage table in the loop's artifact, `.claude/copilot-audit.md` in the worktree (gitignored, overwritten at the start of each run), which the handoff and the invoking skill read.

Drain-scope override: each iteration applies the fixes for `valid` threads (Auto-applicable, Agent-resolvable, and each Needs-sign-off fix as its own `[pending-sign-off]` commit) and posts dismissals for `false positive` threads, but never applies an adjacent finding. Reason: an adjacent finding has no thread tying it to Copilot's review, so landing it unattended would push changes nobody asked for into every re-review cycle; it is surfaced for the human instead.

### Nested pre-flight (once per run)

1. **PR and repo info** (Steps step 1).
2. **Take the same-PR lock** per [github.md](../review-shared/github.md), keyed `copilot-review`, and initialize the iteration counter at 0. Carry the printed lock path and token: this loop's cross-call files (`<lock>/…` below) live in that directory, so they are keyed by repo and PR and go away with the lock at the end of the run.
3. **Confirm the Copilot bot login and detect the repo mode**, from a window wide enough to find a Copilot review behind other reviewers:

   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviews(last: 20) { nodes { author { __typename login } commit { oid } } }
         }
       }
     }
   ' -f owner='OWNER' -f repo='REPO' -F number=NUMBER
   ```

   `commit { oid }` is the commit each review was submitted against; step (a)'s stale-baseline guard reads the newest Copilot node's value. With no Copilot review in the window, either inspect another open or recently merged PR in the repo the same way, or default to `repo_mode = "app"` (Copilot installs as an App by default) and let step (f)'s verification confirm it.

   - `__typename == "Bot"` → `repo_mode = "app"`: Copilot is an App, not a collaborator. The mode decides the login form, the read-back expectations and the fallback, never which transport is permitted.
   - Otherwise → `repo_mode = "collaborator"`.

   Do not assume a push alone triggers a review: auto-review on push can silently not fire, so step (g)'s poll is the only authoritative confirmation.
4. **Bootstrap a first review when the PR has none**: zero unresolved Copilot threads **and** no Copilot review at all. Capture the baseline, poll-window start and head as step (e) Path A does (the baseline lands empty, which step (g) treats as "any new review id passes"), request a review via step (f), and poll via step (g), treating the bootstrap like Path A. On `NEW_REVIEW`, parse its suppressed comments per step (g), then enter the loop at step (a); a first review with zero threads is an immediate success. On `TIMEOUT`, **No response**. The bootstrap adds no iteration of its own. With any existing Copilot activity, skip it.

### Iteration loop

**Cap check** at the top of every iteration, before step (a): if the counter has reached the iteration cap in [limits.md](../review-shared/limits.md), stop (**Iteration cap**). Refresh the same-PR lock here too.

#### a. Fetch Copilot's open threads

Steps step 3's fetch and filter. No "skip if older than last push" filter: `isResolved: false` is the signal, and a previous iteration's failed resolve should be retried, not skipped. Record the count as `unresolved_before`.

**Immediate-success short-circuit, first iteration only, guarded on HEAD.** Zero unresolved threads is also what a **stale baseline** looks like: Copilot last reviewed an older head, everything from that review was addressed, and commits have landed since that it has never seen (a merge, a push between runs). Such a forced fresh review has been the only pass to catch a defect every local review missed. So fetch the current head (`gh pr view NUMBER --json headRefOid -q '.headRefOid'`) and re-run pre-flight step 3's query, taking the `commit { oid }` of the **last** Copilot node (`map(select(.author.login == $bot)) | last`):

- **SHAs match**: converged; go to "After the loop".
- **SHAs differ but `git diff --quiet <reviewed-sha> <head-sha>` shows no tree change**: treat as matching.
- **The tree changed, the reviewed commit is gone (`commit` null), or no Copilot node exists**: capture the baseline, poll-window start and head as step (e) Path A does, then run (f) and (g). A `NEW_REVIEW` with threads increments the counter and loops to (a); one with zero threads is convergence (do not loop back, which would burn another request on the same head); `TIMEOUT` is **No response**.

The same staleness can arrive mid-run, so step (f.5)'s and step (g)'s convergence exits re-check the current `headRefOid` against the head their evidence is anchored to, and a moved head with a changed tree runs this guard's request-and-poll branch instead of exiting.

**Pre-check for already-handled threads.** If the code already implements what Copilot asked (a prior iteration's fix whose resolve never landed), classify the thread `already-handled`: skip (b) and (c) for it, and let (e) reply "addressed in <sha>" and re-resolve. Guardrail: name the commit on this branch that applied the fix (`git log "$(gh pr view --json baseRefName -q '.baseRefName')..HEAD" --oneline -- <file>`) and confirm the code behaviorally matches the ask; if either is uncertain, send the thread through (b). A misjudged `already-handled` resolves a thread that should stay open.

#### b. Validate every thread (strict)

Steps step 4 in full, more conservatively than standalone, since nobody checks in real time:

- Passes that do not converge: **Cannot reproduce** or **Ambiguity**.
- Two valid interpretations: **Ambiguity**.
- A fix touching lines this PR did not introduce or modify: if **all** threads are out of scope, **Scope creep**; if only some, follow the **Partial scope creep recipe** below.
- At least 3 threads with more than half `false positive`: **High false-positive ratio**. A single hallucination on a small iteration is dismissed in-loop.

#### c. Implement

Steps step 6's routing and act-then-review, with no walk: validation-rigor's solution validation on every fix, any regression in the wider check is **Test failure**. For non-behavioral changes, substitute review angles, including the contract-reword grep, which matters doubly here since each straggler costs a full Copilot cycle. Draft dismissals for `false positive` threads but post nothing yet.

#### d. Run the full local check suite

Whatever the project ships (`mise run test`, `lefthook run pre-commit`, the language's test runner). Any failure, pre-existing or not, is **Test failure**.

#### e. Commit, push, reply, resolve

Land the code before talking about it, per [github.md](../review-shared/github.md).

**Path A (code changes were made):**

1. **Before pushing**, capture the baseline Copilot review id, the poll-window start, and, after committing, the head:

   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviews(last: 20) { nodes { id author { login } } }
         }
       }
     }
   ' -f owner='OWNER' -f repo='REPO' -F number=NUMBER > <lock>/baseline-raw \
     || { echo "baseline GraphQL query failed; stop and diagnose"; exit 1; }
   jq -r --arg bot 'copilot-pull-request-reviewer' '
       .data.repository.pullRequest.reviews.nodes
       | map(select(.author.login == $bot))
       | last // empty
       | .id // ""' <lock>/baseline-raw \
     > <lock>/baseline-review-id \
     || { echo "jq failed to parse the baseline response; stop and diagnose"; exit 1; }
   echo $(( $(date +%s) - 2 )) > <lock>/push-epoch
   ```

   The guards matter because an empty baseline file is also the legitimate no-prior-review case; a failed capture must stop rather than look like it. Plain `jq -r`, not `-re`, which exits 4 on that legitimate empty result. Capturing **before** the push closes a race: a fast auto-triggered review landing between the push and a later capture would be mistaken for pre-existing. The two seconds absorb second-precision timestamps. Each Bash call is a fresh shell, so the values travel in these files, namespaced by PR number.
2. `git add` only the files this iteration changed, commit `chore(copilot): iter N, address <short summary>` (a Needs-sign-off fix in its own `[pending-sign-off]` commit), write `git rev-parse HEAD > <lock>/push-head`, and push with `git push origin <branch>`. **Never** `--force`, `--force-with-lease`, or a rebase. A hook failure is **Push hook failure**.
3. **Reply** per Steps step 8: `valid` threads with the change and the new SHA; `already-handled` with `addressed in <sha>` from the base-scoped `git log` above (never a hardcoded `main`); `false positive` with the drafted dismissal, unless the thread already carries a viewer dismissal from a prior pass whose resolve failed, in which case go straight to the resolve.
4. **Rescue any pending review** (mandatory), per [github.md](../review-shared/github.md); if one cannot be submitted, **Pending reply unsubmittable**.
5. **Resolve** the threads, then step (f).

**Path B (no code changes; every thread `already-handled` or `false positive`):** skip commit and push, but still capture the baseline, poll-window start and head (the unchanged head) as Path A step 1 does, post the replies (Path A step 3), rescue pending reviews, resolve, and run (f) and (g): Copilot can re-review an unchanged head when observable PR state changed (replies, resolves, description or label edits). Path B's `TIMEOUT` falls through to (f.5).

#### f. Re-request Copilot review (mode-aware, verify-loud)

Both modes use the same transport order, native gh route first, then REST. Three traps make working requests look broken:

- **gh ≥ 2.88.0 requests Copilot natively**: `gh pr edit NUMBER --add-reviewer @copilot` special-cases the `@copilot` handle and works in both modes. Check `gh --version` once per run; on older gh, go straight to REST.
- **Every requested-reviewer read-back hides Bot reviewers**: both the REST `requested_reviewers` read-back and GraphQL `reviewRequests` come back empty after a successful request, so neither can tell success from a no-op. Verify through the issue timeline's `review_requested` events, with (g)'s poll as the authority.
- **The `[bot]` suffix behaves differently per API**: REST's `reviewers[]` requires the suffixed form, while a raw bot login given to anything GraphQL-backed fails with "Could not resolve user", bare or suffixed; only the `@copilot` handle escapes this.

**`app` mode:** auto-review on push is **not** guaranteed, so never skip the request. Try `gh pr edit NUMBER --add-reviewer @copilot`; on failure or older gh, REST with the suffixed login:

```bash
gh api -X POST "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer[bot]'
```

| Outcome | Body contains | Action |
|---|---|---|
| 2xx | n/a | Verify via the timeline, then (g). |
| 422 | `already requested` | **Success**: a pending request means a review is coming. Never DELETE and re-POST here: no read-back confirms the DELETE, and cancelling can kill a review in progress. Verify, then (g). |
| 422 | `not a collaborator` | Fall back to the GitHub MCP server's `request_copilot_review` tool (`mcp__<github-server>__request_copilot_review`, with `owner`, `repo`, `pullNumber`; the server name depends on the active configuration). If no such tool is available and the gh route also failed, **Re-review unavailable**. |
| Other | n/a | Log a warning and go to (g); the poll is authoritative. |

After a success, verify it was recorded:

```bash
gh api "repos/OWNER/REPO/issues/NUMBER/timeline" --paginate \
  --jq '[.[] | select(.event == "review_requested")] | last'
```

If no event from this request names Copilot, log a warning and go to (g) anyway. **Step (g) is mandatory in app mode.**

**`collaborator` mode:** the gh route first, as in app mode; on failure or older gh, a best-effort REST re-request with the bare login:

```bash
gh api -X POST "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'
```

| Outcome | Body contains | Action |
|---|---|---|
| 2xx | n/a | (g). |
| 422 | `already requested` | **Success**, as in app mode: never DELETE and re-POST. (g). |
| 422 | `not a collaborator` | Mode detection was likely wrong: retry once with the `[bot]` login per app mode, and on success set `repo_mode = "app"` for the rest of the run. If that also 422s, **Re-review unavailable** (not a poll that would misreport as **No response**). |
| Other | n/a | Log a warning and go to (g). |

This step's HTTP outcome never triggers **No response**; only (g)'s poll does.

#### f.5. Resolved-thread sanity check (Path B fall-through)

Reached on Path B after (g) times out. Re-fetch threads:

- **Zero remaining**: converged, subject to step (a)'s mid-run stale-baseline re-check against the head captured at the last (e).
- **Some remaining** (a resolve failed again): record `unresolved_after`. If the same threads stayed unresolved across two consecutive iterations, **Persistent resolve failure**; otherwise check **Diminishing returns**, and if it does not fire, increment the counter and loop to (a).

#### g. Wait for Copilot's response

**Mandatory after every Path-A push, in both modes.** Nothing else confirms a review: not the push, not (f)'s HTTP outcome, not a run of earlier iterations that converged.

Wait up to the review-poll window in [limits.md](../review-shared/limits.md) from one backgrounded script (`run_in_background`), which the harness does not introspect; never one Bash call per attempt with a sleep between them.

```bash
push_epoch=$(cat <lock>/push-epoch 2>/dev/null)
baseline_id=$(cat <lock>/baseline-review-id 2>/dev/null)
push_head=$(cat <lock>/push-head 2>/dev/null)
case "$push_epoch" in
  ''|*[!0-9]*) echo "push_epoch missing or not a plain integer (\"$push_epoch\"); step (e)'s capture is corrupt"; exit 2 ;;
esac
[ -n "$push_head" ] || { echo "push_head not set; capture it in step (e) before running"; exit 2; }
deadline=$(( push_epoch + 600 ))
polls=0; fails=0
while [ $(date +%s) -lt $deadline ]; do
  resp=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviews(last: 20) { nodes { id author { login } state submittedAt body commit { oid } } }
        }
      }
    }
  ' -f owner='OWNER' -f repo='REPO' -F number=NUMBER) || { fails=$((fails + 1)); sleep 30; continue; }
  latest=$(printf '%s' "$resp" | jq -r --arg bot 'copilot-pull-request-reviewer' --arg baseline "$baseline_id" --arg head "$push_head" --argjson since "$push_epoch" '
        .data.repository.pullRequest.reviews.nodes
        | map(select(
            (.author.login? // "") == $bot
            and (.id? // "") != $baseline
            and ((.submittedAt? // null) | type) == "string"
            and ((.submittedAt | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) >= $since)
            and ((.commit.oid? // "") == $head)
            and ((.body? // "") | test("encountered an error and was unable to review"; "i") | not)
          ))
        | last // empty') || { fails=$((fails + 1)); sleep 30; continue; }
  polls=$((polls + 1))
  if [ -n "$latest" ]; then
    printf '%s' "$latest" > <lock>/latest-review
    echo "NEW_REVIEW $latest"; exit 0
  fi
  sleep 30
done
[ "$polls" -gt 0 ] || { echo "POLL_ERROR: all $fails polls failed; no review state was read"; exit 3; }
echo "TIMEOUT"; exit 1
```

The deadline is the shared review-poll window, written in seconds. The match combines `submittedAt >= push_epoch` with `id != baseline_id` (second-precision timestamps alone miss a same-second review; the id alone would re-match older ones), and `commit.oid == push_head`, so a review of some other commit is never credited to this push. The null-safe accessors keep a malformed node from aborting the poll.

**Errored reviews are not a response.** Copilot posts a `COMMENTED` review with no threads when it fails ("encountered an error and was unable to review"), indistinguishable by state and thread count from a clean pass; the body filter keeps the loop from converging on a review that never happened. Verify the body, never just the state.

**Read suppressed comments out of the body.** A review can report no new comments while its body carries a collapsed `Suppressed comments (N)` block with a real finding; those never become threads, so every thread step walks past them. On every `NEW_REVIEW`, parse that block from the saved review, validate each **new** entry with (b)'s three passes, and route survivors as adjacent findings. Keep a per-run ledger at `<lock>/suppressed-seen` (`file:line` plus the entry's first words) so a re-emitted entry is not re-validated. Validation is not optional: a suppressed entry's facts can be right while its conclusion is inverted.

Branch on the script's exit:

- **0 (`NEW_REVIEW`)**: re-fetch threads, parse suppressed comments, record `unresolved_after`. Zero unresolved is convergence, subject to step (a)'s mid-run re-check. Otherwise check **Diminishing returns**, then increment the counter and loop to (a).
- **1 (`TIMEOUT`) on Path A**: **No response**.
- **1 (`TIMEOUT`) on Path B**: step (f.5).
- **2**: step (e) failed to capture its values; stop and surface stderr.
- **3 (`POLL_ERROR`)**: no poll in the window read the reviews (the API call or its parse failed every time): **Poll failure**, never **No response**, since Copilot's silence was never observed.
- **Anything else** (a 128+N signal exit when the script was killed): its output is not authoritative. Re-run the same query once with the same filter, reading the same files. A match is `NEW_REVIEW`. No match inside the window: restart the poll, at most twice per iteration, then treat as `TIMEOUT`. Past the window: `TIMEOUT`, split by path as above.

#### h. Iteration summary

Iteration N and the cap; the path taken; threads by classification; the pushed SHA (Path A); the test command and result (Path A); the re-request transport and outcome, with the timeline verification in app mode, and on Path B whether (g) saw a review; and **unresolved threads `<before>` → `<after>` (net resolved)**, the record **Diminishing returns** reads.

### Stop conditions (mandatory human handoff)

Stop, print the latest iteration table, name the condition, and wait: no push, no reply, no re-request. The one exception is the **Partial scope creep recipe** below.

| Condition | Trigger |
|---|---|
| **Ambiguity** | A comment is unclear, has multiple valid interpretations, or needs a product or UX call. |
| **Loop detection** | Copilot raised the same root issue in the same file in two consecutive iterations. |
| **Persistent resolve failure** | A resolve failed for the same threads across two consecutive iterations. |
| **Scope creep** | Every fix would touch code outside the PR's diff, or contradicts the PR's stated intent. |
| **Test failure** | Any test, linter, type check or formatter fails after our change, pre-existing failures included. |
| **Push hook failure** | Step (e)'s push fails on a hook; diagnose per [github.md](../review-shared/github.md) and hand off. |
| **Hard-disqualifier zone** | The change touches security-sensitive code, a migration or destructive op, CI config, a lockfile or a secrets file. Always pause. |
| **High false-positive ratio** | At least 3 threads with more than half false positives. |
| **Iteration cap** | The shared cap reached without convergence. |
| **Diminishing returns** | The last 3 iterations each netted at most one resolved thread while threads remained; never before 3 iterations. |
| **Cannot reproduce** | Not reproducible, and the proposed fix is non-trivial. |
| **No response** | The review-poll window expired with no new Copilot review. |
| **Poll failure** | Every poll in (g) failed to read the reviews (`POLL_ERROR`), so no silence was observed. |
| **Re-review unavailable** | No transport can request a review: the gh route failed or is unavailable, and in app mode REST genuinely 422'd with no MCP fallback available, or in collaborator mode both login forms 422'd. Offer the CLI fallback in the handoff; never run it unasked. |
| **Pending reply unsubmittable** | A viewer-owned pending review cannot be submitted, so replies would stay invisible. |
| **Conflicting signals** | A later Copilot review contradicts an earlier one already addressed. |

#### Partial scope creep recipe

When an iteration's threads split between lines this PR introduced or modified and pre-existing lines it does not touch:

1. **Address the in-scope threads** through (b), (c), (d) and all of (e).
2. **Reply to the out-of-scope threads as adjacent findings**, naming that the lines predate this PR (cite the commit or blame), the proposed fix, and where it should live. **Do not resolve them**: leaving them open is what hands them to the human. Then re-run the pending-review rescue, since these replies can create a new pending review.
3. **Pause for the decision, deferring (f) and (g) only until it comes.** Ask: **(a)** fix in this PR (resume; the next Path A's (f) and (g) cover step 1's push too), **(b)** track in a follow-up (post `tracked in <link>` on each and resolve), or **(c)** won't fix in this PR (post a one-line rationale on each and resolve). After (b) or (c), since step 1 pushed code, run (f) and (g) before ending; new threads loop back to (a).

With **no** in-scope threads, the full **Scope creep** stop applies instead.

### Auto-execution invariants

- **Never** force-push, or silently retry or `--no-verify` a failed push.
- **Never** rewrite a commit already pushed to this PR's branch: Copilot's threads anchor to commit SHAs, so a rewrite orphans the threads being replied to. That is this loop's reason, distinct from the repo-wide rule, which allows a lease-guarded force-push on an in-scope feature branch.
- **Never** resolve a thread without an explanatory reply.
- **Never** skip the failing-test-first step on a behavior-changing fix.
- **Never** touch files outside the PR's diff to fix something noticed in passing; surface it as an adjacent finding.
- **Never** modify CI configuration, `.env`, secrets or lockfiles; a thread asking for it is a **Hard-disqualifier zone** stop.
- **Never** post to chat platforms or tickets.
- **Never** create or merge the PR itself. Nested mode pushes commits to the existing branch but otherwise leaves the PR's lifecycle alone, with one narrow exception: marking it ready, only at convergence and only after the explicit per-run confirmation in "After the loop". Never automatically, never on a diminishing-returns/stop-condition/iteration-cap exit, and never for create or merge; those stay absolute.
- **Never** skip (g) after a Path-A push, except the Partial scope creep recipe's pre-decision pause. Path B runs (g) too.
- **Never** leave replies in a pending review.
- **Never** trust an external-effect step's happy-path response without re-querying: after (f), a `review_requested` timeline event; after (e)'s replies, zero viewer-owned pending reviews.

### After the loop

- **Convergence.** Present remaining adjacent findings per [workflow.md](../review-shared/workflow.md)'s handoff rule. If applying one changed code, that change gets its own capture, commit, push, (f) and (g), counted as an iteration; new threads loop back to (a).

  With no adjacent-finding fix outstanding, check `gh pr view --json isDraft,state`. On a query failure, surface it and hand off; if the PR is not `OPEN`, or not a draft, stop here. Otherwise re-fetch threads to reconfirm zero (time has passed since convergence); nonzero increments the iteration counter and loops back to (a).

  **Only once the recheck confirms zero**, in an attended session, ask once, with a stop condition's weight: "Mark PR #<n> ready for review? Stop and wait for me." Before asking, and again on yes immediately before `gh pr ready`, evaluate the ready conditions against the current head: GitHub reports `mergeable: MERGEABLE` (`UNKNOWN` after one re-query a few seconds later counts as unmet), CI is green, and every step of the review cadence the PR calls for has run; on an unmet or unconfirmable one, name it and leave the PR a draft, and if planwright's ready-guard hook denies the flip, report the denial and leave it a draft: no sync to satisfy it, no bypass. On yes with every condition met, run `gh pr ready <number>` and re-query `isDraft` to confirm it flipped; if it did not, surface that. On no, leave it a draft. **Dispatched or unattended**: do not ask and do not self-answer; leave it a draft and hand off, naming the outcome. This confirmation-gated ready-flip is the only PR-lifecycle action this loop takes, and only on this exit path.
- **Diminishing returns, any other stop condition, or the iteration cap.** Present remaining adjacent findings, then hand off. Never ask about marking ready: residual threads or an unresolved safety condition mean the run is not done.

$ARGUMENTS
