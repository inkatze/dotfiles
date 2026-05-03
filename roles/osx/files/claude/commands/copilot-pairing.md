Iterate with GitHub Copilot autonomously until it stops requesting changes on the current PR.

Same validation rigor as `/copilot-review`, executed on autopilot, with hard stop conditions baked in for safety.

## When to use

You want a hands-off pairing pass with Copilot. The skill loops: address Copilot's threads, push, re-request review, wait, repeat. It pauses for human input the moment anything is ambiguous, looping, expanding scope, or breaking tests.

## Pre-flight (once per run)

1. **Get PR / repo info** (same as `/copilot-review` step 1).
2. **(Optional) Jira context** (same as `/copilot-review` step 2).
3. **Confirm the Copilot bot login and detect repo mode.** Default login is `copilot-pull-request-reviewer`. Verify by inspecting an existing review on the PR (`reviews(last: 5)` so we surface the most-recent reviews; `first: 5` would return the oldest and may not include Copilot on a long-lived PR):
   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviews(last: 5) { nodes { author { __typename login } } }
         }
       }
     }
   ' -f owner='OWNER' -f repo='REPO' -F number=NUMBER
   ```
   Use the actual `Bot` login if it differs. Then set `repo_mode` from the same `__typename` field:
   - `__typename == "Bot"` → `repo_mode = "app"`. Copilot is installed as a GitHub App, not a collaborator. The REST endpoint `POST /repos/{owner}/{repo}/pulls/{n}/requested_reviewers` returns 422 ("not a collaborator") for App-typed reviewers and must NOT be used in this mode. Step (f) instead calls the `request_copilot_review` MCP tool (which wraps an internal endpoint that accepts Bot reviewers). Do not assume push alone will trigger a Copilot review: auto-review-on-push has been observed to silently no-op (see step (f) for the verified failure mode), so step (g)'s 10-minute poll is the only authoritative confirmation that Copilot has reviewed.
   - Otherwise → `repo_mode = "collaborator"`. Use the explicit re-request POST in step (f).
4. **Initialize iteration counter** = 0. The loop's per-iteration filter is `isResolved: false` (step (a)), so we don't need to snapshot HEAD or the baseline thread-ID set.

## Iteration loop

For each iteration (cap = **10**):

**Cap check (run at the start of every iteration, before step (a)).** Read the iteration counter (initialized to 0 in pre-flight step 4; incremented in step (g) on `NEW_REVIEW` and in step (f.5) on "one or more remaining"). If the counter has reached **10**, do not enter step (a). Trigger the **Iteration cap** stop condition and hand control back. This is the only place the cap is enforced; the counter increments in (g) and (f.5) do not enforce it themselves.

### a. Fetch Copilot's open threads

Use the same GraphQL query as `/copilot-review` step 3. Filter to threads where `isResolved: false` AND first comment author login == Copilot bot login. Do not add a "skip if older than last push" filter: `isResolved: false` is the canonical signal, and a previous iteration's resolve mutation may have failed silently; this loop should retry it, not skip it.

**Pre-check for already-handled threads.** Before running the validation passes, read the referenced file and decide whether the code already implements what Copilot asked for (because a prior iteration applied the fix but the resolve mutation never landed). If yes, classify the thread as `already-handled`, skip steps (b) and (c) for it, and let step (e) post a brief reply ("addressed in <commit-sha>") and re-fire the resolve mutation. This is what keeps a benign retry from tripping the **Cannot reproduce** stop condition in step (b)'s Pass 1.

**Guardrail.** A misjudged `already-handled` posts a misleading "addressed in <sha>" reply and resolves a thread that should not be resolved, and the rigor that would catch the misjudgement (step (b)) is the very rigor we just skipped. To classify as `already-handled`, you must (1) point to the specific commit on this branch that applied the fix (find via `git log "$(gh pr view --json baseRefName -q '.baseRefName')..HEAD" --oneline -- <file>`), and (2) confirm the current code on that file:line behaviorally matches Copilot's ask, not just looks superficially similar. If either step is uncertain, do **not** classify as `already-handled`; let the thread go through the full three-pass validation in step (b). False negatives are cheap (one extra validation pass); false positives are silent and corrupt the loop.

### b. Validate every thread (strict, three passes minimum)

Apply `/copilot-review` step 4 in full: the canonical three-pass rigor in CLAUDE.md `Validation Rigor (Issue Identification)`. Pass 1 reproduces, pass 2 takes an orthogonal angle, pass 3 consults outside-the-diff sources (git history, repo-wide search, official docs, library source/tests, deepwiki MCP, GitHub issues, RFCs, web search for text/research-based claims).

Be more conservative than in `/copilot-review` because nobody is checking our work in real time:

- If the three passes do not converge, mark `low-confidence` and trigger the **Cannot reproduce** or **Ambiguity** stop condition (whichever fits).
- If two valid interpretations exist, trigger **Ambiguity**.
- If the fix would touch a file outside the PR's existing diff, trigger **Scope creep**.
- After classifying every thread, if more than half of this iteration's threads are `false positive`, trigger **High false-positive ratio** (the model may be misreading the change; pause for re-alignment rather than spamming dismissals).
- Apply the same three-pass rigor to every proposed fix. Do not trust Copilot's recommendation; design our own from first principles, then validate it from three angles before accepting.

### c. Implement valid items: solution validated with two or three test angles

Apply `/copilot-review` step 6 (canonical rigor in CLAUDE.md `Validation Rigor (Solutions)`):

1. **Targeted test.** Write a failing test for the bug's exact reason, confirm it fails for the right reason, apply the fix, confirm it now passes.
2. **Wider check.** Run the broader project test suite, linters, type-checkers. Any regression (even in unrelated areas) triggers the **Test failure** stop condition.
3. **Edge / integration / manual** (when relevant). Boundary cases, integration or smoke tests, manual exercise of the user-facing flow.

Skip the targeted-test step only for non-behavioral changes (docs, comments, pure renames, formatting). For those, substitute review angles per the canonical doctrine.

For **false positives**, draft the dismissal reply (citing the three passes) but do NOT post yet. We post all replies in step (e) after the build is green.

### d. Run the full local check suite

Run whatever the project ships for local verification: tests, linters, type checkers, formatters. Common entry points: `npm test`, `pytest`, `go test ./...`, `cargo test`, `bundle exec rspec`, `mise run test`, `lefthook run pre-commit`. If the project has a single canonical command, prefer it. If anything fails (even a pre-existing failure unrelated to our changes), trigger the **Test failure** stop condition.

### e. Commit, push, reply, resolve

Order matters: land the code first, then talk about it. If we replied/resolved before pushing and the push failed, threads would sit resolved without an actual fix landed and the next iteration would not see them as unresolved (silent loss of work).

**Branch on whether this iteration produced code changes.**

**Path A (code changes were made, the common path):**

1. **Commit and push.**
   - `git add` only the files we actually changed for this iteration (never `git add -A`).
   - Commit with a message of the form `chore(copilot): iter N, address <short summary>`.
   - Push: `git push origin <branch>`. **Never** `--force`, `--force-with-lease`, or any rebase flag.
2. **Capture push timestamp** as a Unix epoch, used for both deadline math and the poll filter (substitute the PR number from pre-flight step 1):
   ```bash
   date +%s > /tmp/copilot-pairing-push-epoch.NUMBER
   ```
   The Bash tool spawns a fresh shell per invocation, so a plain shell variable will not be visible to the step (g) script. Use the temp file, or inline the literal value into the step (g) script when you send it. The filename is namespaced by PR number so concurrent pairing sessions on different PRs (e.g., separate worktrees) do not clobber each other's timestamps. We use epoch (not ISO-8601) so the poll filter can compare numerically via `fromdateiso8601` and avoid lexicographic edge cases at sub-second precision. This high-water mark is the floor for step (g)'s poll filter; capturing it any earlier risks matching a Copilot review that pre-dates this push.
3. **Reply to threads** using `/copilot-review` step 8 mutations (multi-line GraphQL, body via temp file). **Use `addPullRequestReviewThreadReply` only**; see the DO-NOT-USE callout in `/copilot-review` step 8 about `addPullRequestReviewComment`. Reply body varies by classification, since this iteration may have a mix:
   - **`valid`**: short reply describing the change we made, ideally referencing the new commit SHA from (e.1).
   - **`already-handled`**: reply with `addressed in <commit-sha>` per Path B step 2, using the same `git log "$(gh pr view --json baseRefName -q '.baseRefName')..HEAD" --oneline -- <file>` lookup. Do not hardcode `main` as the base.
   - **`false positive`**: post the dismissal reply drafted in step (b) (citing the three passes and why the concern does not apply).
4. **Submit any auto-vivified pending review (mandatory).** `addPullRequestReviewThreadReply` can create a new pending review owned by the viewer when none is in progress; the replies posted in (e.3) then stay invisible (to GitHub UI, to Copilot, to humans) until that review is submitted. See `/copilot-review` step 8's "Submit any auto-vivified pending review" sub-step for the exact GraphQL. Procedure: query the PR's `reviews(states: PENDING)` filtered by `author.login == viewer.login`; for each, call `submitPullRequestReview(id, event: COMMENT)`. Re-query and assert zero pending reviews owned by the viewer remain before proceeding to step (e.5). If a pending review cannot be submitted, stop with the **Pending reply unsubmittable** condition.
5. **Resolve threads** using `/copilot-review` step 8's `resolveReviewThread` mutation.
6. Proceed to step (f).

**Path B (no code changes; every thread was `already-handled` or `false positive`):**

1. Skip commit/push and skip the push-timestamp capture (no new HEAD; step (g) is skipped on this path).
2. Post the reply for each thread, varying by classification (use `addPullRequestReviewThreadReply` either way; same DO-NOT-USE callout applies):
   - **`already-handled`**: reply with a short body referencing the prior commit that actually addressed it. Find the commit via `git log "$(gh pr view --json baseRefName -q '.baseRefName')..HEAD" --oneline -- <file>` (scoped to this branch's commits, top entry is the most recent). Do not hardcode `main`: PRs targeting `develop`, `release/*`, or any other base branch would otherwise return wrong or empty commits.
   - **`false positive`**: post the dismissal reply drafted in step (b) (citing the three passes and why the concern does not apply).
3. **Submit any auto-vivified pending review (mandatory).** Same procedure as Path A step 4. The auto-vivify failure mode applies here too because we still call `addPullRequestReviewThreadReply`.
4. Resolve threads via `resolveReviewThread`.
5. Proceed to step (f.5), not (f): do not re-request review against an unchanged HEAD, since Copilot will not respond and step (g) will time out.

### f. Re-request Copilot review (mode-aware, verify-loud)

Branch on `repo_mode` from pre-flight step 3.

**`app` mode (`__typename == "Bot"` in pre-flight):** auto-review on push is **not** guaranteed. Verified failure mode (2026-05-02 live run on `SymmetrySoftware/stl-poc#13`): push completed, `reviewRequests.nodes` came back empty, no auto-review fired, and step (g) would have timed out silently after 10 minutes. Do not skip the request.

Explicitly request Copilot via the GitHub MCP tool:

```
mcp__<github-server>__request_copilot_review
params: { owner, repo, pullNumber }
```

The substitute for `<github-server>` depends on the active MCP server (e.g. `claude_ai_Github-Symmetry`, `claude_ai_Github-Gusto`). The REST endpoint `POST /repos/{owner}/{repo}/pulls/{n}/requested_reviewers` returns 422 "not a collaborator" for Bot reviewers and must NOT be used in app mode; the MCP tool wraps an internal Copilot-review-request endpoint that accepts Bot reviewers. If no `request_copilot_review` MCP tool is available on the active server, stop with **Re-review unavailable** and report; do not assume push alone will trigger a review.

After the MCP call returns success, **verify** Copilot is actually on the requested-reviewer list:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewRequests(first: 10) {
          nodes {
            requestedReviewer {
              ... on Bot { login }
              ... on User { login }
            }
          }
        }
      }
    }
  }
' -f owner='OWNER' -f repo='REPO' -F number=NUMBER
```

If the verified Copilot bot login (from pre-flight step 3) is in `reviewRequests.nodes`, proceed to step (g). If not, log a warning ("MCP request_copilot_review returned success but reviewRequests does not include the bot") and proceed to step (g) anyway: the poll is the authoritative confirmation. **Step (g) is mandatory in app mode.** Skipping it on the assumption that the request "must have worked" is the regression earlier wording was written to prevent.

**`collaborator` mode:** try to trigger a new Copilot review by re-adding it to the requested reviewers list. Substitute the verified bot login from pre-flight step 3 if it differs from the default.

```bash
gh api -X POST "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'
```

This call is **best-effort**, not load-bearing. The actual signal the loop relies on is step (g)'s GraphQL poll for a new review.

Inspect the response and branch:

| Outcome | Body contains | Action |
|---|---|---|
| 2xx | n/a | Proceed to step (g). |
| 422 | `already requested` (or similar "duplicate reviewer") | DELETE the reviewer, re-POST. Then proceed to step (g). |
| 422 | `not a collaborator` | Pre-flight mode detection was wrong (the bot is no longer a Bot-typed reviewer). Log the mismatch and proceed to step (g). On the next run, re-check pre-flight step 3. |
| Other (4xx/5xx) | n/a | Log warning. Proceed to step (g). |

DELETE+POST retry pattern (only for the `already requested` case):

```bash
gh api -X DELETE "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'

gh api -X POST "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'
```

Do NOT trigger the **No response** stop condition based on this step's HTTP outcome. **No response** is reserved for step (g)'s 10-minute poll timing out, the only authoritative signal that Copilot did not review.

### f.5. Resolve-only iteration short-circuit

Only reached if step (e) produced no commits. Re-fetch reviewThreads (same query as step (a)) and count unresolved Copilot threads:

- **Zero remaining**: success. Exit the loop. Print the iteration summary noting "resolve-only iteration, no new code, all Copilot threads now resolved".
- **One or more remaining** (rare: a resolve mutation failed again): increment iteration counter and loop back to step (a). If the same threads remain unresolved across two consecutive iterations, trigger the **Persistent resolve failure** stop condition.

Skip steps (f) and (g) on this path.

### g. Wait for Copilot's response

**This step is mandatory after every Path-A push, in both `app` and `collaborator` modes.** Do not infer that Copilot has reviewed from any other signal: not the push itself, not step (f)'s HTTP outcome, not "the last N iterations all converged so this one will too". The poll below is the only authoritative confirmation.

We need to wait up to **10 minutes** for a new Copilot review. Do not foreground-sleep or chain `sleep` calls between polls: the harness's Bash tool blocks long sleeps and chained sleeps. Use one of the two patterns below.

**Preferred: a single backgrounded poll script** (`Bash` with `run_in_background=true`). The script polls itself and exits when the condition is met or the deadline passes. You'll be notified when it exits. Substitute the verified bot login from pre-flight step 3 in the `--arg bot ...` flag if it differs from the default.

```bash
# Read push_epoch from the temp file written in step (e). Bash tool calls do
# not share shell state, so reading from the file (or inlining the literal
# value before sending the script) is required. File is namespaced by PR
# number; substitute NUMBER from pre-flight step 1.
push_epoch=$(cat /tmp/copilot-pairing-push-epoch.NUMBER 2>/dev/null)
[ -n "$push_epoch" ] || { echo "push_epoch not set; capture it in step (e) before running"; exit 2; }
deadline=$(( push_epoch + 600 ))
while [ $(date +%s) -lt $deadline ]; do
  latest=$(gh api graphql -f query='
    query($owner: String!, $repo: String!, $number: Int!) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviews(last: 5) { nodes { author { login } state submittedAt } }
        }
      }
    }
  ' -f owner='OWNER' -f repo='REPO' -F number=NUMBER \
    | jq -r --arg bot 'copilot-pull-request-reviewer' --argjson since "$push_epoch" '
        .data.repository.pullRequest.reviews.nodes
        | map(select(.author.login == $bot and (.submittedAt | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) > $since))
        | last // empty')
  if [ -n "$latest" ]; then echo "NEW_REVIEW $latest"; exit 0; fi
  sleep 30
done
echo "TIMEOUT"; exit 1
```

**Alternative**: `Monitor` the same script with an until-loop if you want streaming progress lines.

Branch on the script's exit:

- **Exit 0 (`NEW_REVIEW`)**: re-fetch reviewThreads. If any are unresolved, increment iteration counter and loop back to (a). If zero unresolved, success: exit the loop.
- **Exit 1 (`TIMEOUT`)**: trigger the **No response** stop condition.
- **Exit 2 (bad input)**: step (e) failed to capture `push_epoch`. Bug in our flow. Stop and surface the script's stderr.
- **Any other exit code (e.g. 143 from SIGTERM, 137 from SIGKILL/OOM, or any 128+N signal exit from a harness session end)**: the script was killed externally; its output is not authoritative. Re-query GraphQL directly, reading `push_epoch` from `/tmp/copilot-pairing-push-epoch.NUMBER` for both the deadline check and the poll filter:
  ```bash
  push_epoch=$(cat /tmp/copilot-pairing-push-epoch.NUMBER)
  gh api graphql -f query='...same as the poll script...' \
    -f owner='OWNER' -f repo='REPO' -F number=NUMBER \
    | jq --arg bot 'copilot-pull-request-reviewer' --argjson since "$push_epoch" '
        .data.repository.pullRequest.reviews.nodes
        | map(select(.author.login == $bot and (.submittedAt | sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) > $since))'
  ```
  - **New Copilot review found**: treat as `NEW_REVIEW` and proceed as above.
  - **No new review, still inside the 10-minute window** (`[ $(date +%s) -lt $((push_epoch + 600)) ]`): restart the background poll script. Cap restarts at **2** per iteration to prevent thrashing; after that, treat as **No response**.
  - **No new review, past deadline**: treat as `TIMEOUT` and trigger **No response**.

Never assume "loop succeeded" from a non-zero, non-1 exit code. Always cross-check via GraphQL.

### h. Iteration summary

After each iteration, print a short summary:
- Iteration number / cap
- Path taken (A = code changes pushed, B = resolve-only)
- Threads addressed (counts by classification: valid / already-handled / false positive / adjacent finding)
- Commit SHA pushed (Path A only; `n/a` on Path B)
- Test command run + result (Path A only; `n/a` on Path B since no code changed)
- Re-review request status: Path A only. In `app` mode, report the outcome of step (f)'s `request_copilot_review` MCP call plus the `reviewRequests.nodes` verification result; in `collaborator` mode, report the actual HTTP outcome from step (f). On Path B, `n/a` (step (f) is skipped).

This is what I scroll back through to audit the run.

## Stop conditions (mandatory human handoff)

If any condition fires, **stop**. Print the latest iteration table, name the condition, and wait for me. Do not push, do not reply, do not re-request review.

| Condition | Trigger |
|---|---|
| **Ambiguity** | Comment is unclear, has multiple valid interpretations, or requires a product/UX call. |
| **Loop detection** | Copilot raised a substantively similar concern (same file, same root issue) in two consecutive iterations. |
| **Persistent resolve failure** | A `resolveReviewThread` mutation has silently failed (or been rolled back) for the same threads across two consecutive iterations, so the resolve-only short-circuit in step f.5 cannot drain the queue. |
| **Scope creep** | A fix would touch code outside the PR's existing diff, or contradicts the PR's stated intent / Jira AC. |
| **Test failure** | Any test, linter, type-check, or formatter fails after our change, including pre-existing failures we surface for the first time. |
| **Security-sensitive** | The change touches auth, secrets handling, crypto, permissions, IAM, SQL/shell construction, or sandbox boundaries. Always pause. |
| **High false-positive ratio** | More than half of an iteration's threads are false positives (model may be misreading the change). Pause for re-alignment. |
| **Iteration cap** | 10 iterations completed without convergence. Stop and report. |
| **Cannot reproduce** | Issue is not reproducible and the proposed fix is non-trivial. |
| **Migrations / data / destructive ops** | Schema migrations, data backfills, deletes, drops, or anything irreversible. Always human-driven. |
| **No response** | 10-minute poll window in step (g) expires with no new Copilot review. |
| **Re-review unavailable** | Step (f) `app` mode found no `request_copilot_review` MCP tool on the active server, so we cannot trigger a Copilot review and step (g)'s poll would never see one. |
| **Pending reply unsubmittable** | A pending review owned by the viewer cannot be submitted via `submitPullRequestReview` in step (e.4), so replies posted in (e.3) would remain invisible to GitHub, Copilot, and humans. |
| **Conflicting signals** | Copilot's later review contradicts an earlier one we already addressed. Pause to decide which to honor. |

## Auto-execution invariants

These hold at every step:
- **Never** `git push --force` or `--force-with-lease`.
- **Never** amend, squash, or rebase commits already pushed.
- **Never** resolve a thread without an explanatory reply.
- **Never** skip the failing-test-first step on a behavior-changing fix.
- **Never** commit or touch files outside the PR's diff to "fix" something we noticed in passing. Surface it as an adjacent finding for human review instead.
- **Never** modify CI configuration, `.env`, secrets, or lockfiles unless the Copilot thread is specifically about that file.
- **Never** post anything to chat platforms or tickets.
- **Never** skip step (g) after a Path-A push. The 10-minute poll is the only authoritative signal that Copilot has (or has not) reviewed. App-mode auto-review, step (f)'s HTTP outcome, prior iterations' patterns, and elapsed iteration count are not substitutes. Confirmation bias from a long successful run is the failure mode this invariant catches.
- **Never** leave replies in a pending review. `addPullRequestReviewThreadReply` may auto-vivify a pending review owned by the viewer when none is in progress; step (e.4) submits it before resolving threads. A run that completes with replies still pending is a silent failure: GitHub, Copilot, and humans see no replies, and the next iteration polls Copilot reviewing against a state where it has no record of our responses (confirmation-bias path: looks fine, isn't).
- **Never** trust an external-effect step's happy-path response without re-querying state. After step (f)'s `request_copilot_review` MCP call, verify the bot is on `reviewRequests.nodes`; after step (e.3)'s reply mutation, verify zero pending reviews owned by the viewer remain. Both bugs that motivated this section's wording (2026-05-02 live run on `SymmetrySoftware/stl-poc#13`) returned success and looked fine.

## Maintenance

After completing the workflow (or stopping), check if any part of these instructions seem outdated or misaligned with current tooling: GraphQL schema changes, deprecated fields, new `gh` CLI capabilities, changes to how Copilot reviews are requested or to the bot's login. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
