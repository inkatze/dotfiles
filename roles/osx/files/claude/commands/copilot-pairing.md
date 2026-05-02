Iterate with GitHub Copilot autonomously until it stops requesting changes on the current PR.

Same validation rigor as `/copilot-review`, executed on autopilot, with hard stop conditions baked in for safety.

## When to use

You want a hands-off pairing pass with Copilot. The skill loops: address Copilot's threads, push, re-request review, wait, repeat. It pauses for human input the moment anything is ambiguous, looping, expanding scope, or breaking tests.

## Pre-flight (once per run)

1. **Get PR / repo info** (same as `/copilot-review` step 1).
2. **(Optional) Jira context** (same as `/copilot-review` step 2).
3. **Confirm the Copilot bot login.** Default is `copilot-pull-request-reviewer`. Verify by inspecting an existing review on the PR:
   ```bash
   gh api graphql -f query='
     query($owner: String!, $repo: String!, $number: Int!) {
       repository(owner: $owner, name: $repo) {
         pullRequest(number: $number) {
           reviews(first: 5) { nodes { author { __typename login } } }
         }
       }
     }
   ' -f owner='OWNER' -f repo='REPO' -F number=NUMBER
   ```
   Use the actual `Bot` login if it differs.
4. **Initialize iteration counter** = 0. The loop's per-iteration filter is `isResolved: false` (step (a)), so we don't need to snapshot HEAD or the baseline thread-ID set.

## Iteration loop

For each iteration (cap = **10**):

### a. Fetch Copilot's open threads

Use the same GraphQL query as `/copilot-review` step 3. Filter to threads where `isResolved: false` AND first comment author login == Copilot bot login. Do not add a "skip if older than last push" filter: `isResolved: false` is the canonical signal, and a previous iteration's resolve mutation may have failed silently; this loop should retry it, not skip it.

**Pre-check for already-handled threads.** Before running the validation passes, read the referenced file and decide whether the code already implements what Copilot asked for (because a prior iteration applied the fix but the resolve mutation never landed). If yes, classify the thread as `already-handled`, skip steps (b) and (c) for it, and let step (e) post a brief reply ("addressed in <commit-sha>") and re-fire the resolve mutation. This is what keeps a benign retry from tripping the **Cannot reproduce** stop condition in step (b)'s Pass 1.

### b. Validate every thread (strict, three passes minimum)

Apply `/copilot-review` step 4 in full: the canonical three-pass rigor in CLAUDE.md `Validation Rigor (Issue Identification)`. Pass 1 reproduces, pass 2 takes an orthogonal angle, pass 3 consults outside-the-diff sources (git history, repo-wide search, official docs, library source/tests, deepwiki MCP, GitHub issues, RFCs, web search for text/research-based claims).

Be more conservative than in `/copilot-review` because nobody is checking our work in real time:

- If the three passes do not converge, mark `low-confidence` and trigger the **Cannot reproduce** or **Ambiguity** stop condition (whichever fits).
- If two valid interpretations exist, trigger **Ambiguity**.
- If the fix would touch a file outside the PR's existing diff, trigger **Scope creep**.
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

**Path A — code changes were made (the common path):**

1. **Commit and push.**
   - `git add` only the files we actually changed for this iteration (never `git add -A`).
   - Commit with a message of the form `chore(copilot): iter N, address <short summary>`.
   - Push: `git push origin <branch>`. **Never** `--force`, `--force-with-lease`, or any rebase flag.
2. **Capture push timestamp.** Immediately after push completes:
   ```bash
   date -u +%Y-%m-%dT%H:%M:%SZ > /tmp/copilot-pairing-push-ts
   ```
   The Bash tool spawns a fresh shell per invocation, so a plain shell variable will not be visible to the step (g) script. Use the temp file, or inline the literal value into the step (g) script when you send it. This timestamp is the high-water mark for step (g)'s poll filter; capturing it any earlier risks matching a Copilot review that pre-dates this push.
3. **Reply to threads** using `/copilot-review` step 8 mutations (multi-line GraphQL, body via temp file). **Use `addPullRequestReviewThreadReply` only** — see the DO-NOT-USE callout in `/copilot-review` step 8 about `addPullRequestReviewComment`.
4. **Resolve threads** using `/copilot-review` step 8's `resolveReviewThread` mutation.
5. Proceed to step (f).

**Path B — no code changes (every thread was `already-handled`):**

1. Skip commit/push and skip the push-timestamp capture (no new HEAD; step (g) is skipped on this path).
2. Reply to each thread with a short body referencing the prior commit that actually addressed it (find the commit via `git log --oneline -- <file>` for the relevant file). Use `addPullRequestReviewThreadReply` (same DO-NOT-USE callout applies).
3. Resolve threads via `resolveReviewThread`.
4. Proceed to step (f.5), not (f): do not re-request review against an unchanged HEAD, since Copilot will not respond and step (g) will time out.

### f. Re-request Copilot review (best-effort)

Try to trigger a new Copilot review by re-adding it to the requested reviewers list:

```bash
gh api -X POST "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'
```

This call is **best-effort**, not load-bearing. The actual signal the loop relies on is step (g)'s GraphQL poll for a new review. Repos where Copilot is installed as a GitHub App typically auto-review on push, so an explicit re-request is unnecessary (and the REST endpoint will reject it).

Inspect the response and branch:

| Outcome | Body contains | Action |
|---|---|---|
| 2xx | — | Proceed to step (g). |
| 422 | `already requested` (or similar "duplicate reviewer") | DELETE the reviewer, re-POST. Then proceed to step (g). |
| 422 | `not a collaborator` (or any other 422) | Log a single-line warning that the explicit re-request was rejected (likely auto-review-on-push repo). Proceed to step (g). |
| Other (4xx/5xx) | — | Log warning. Proceed to step (g). |

DELETE+POST retry pattern (only for the `already requested` case):

```bash
gh api -X DELETE "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'

gh api -X POST "repos/OWNER/REPO/pulls/NUMBER/requested_reviewers" \
  -f 'reviewers[]=copilot-pull-request-reviewer'
```

Do NOT trigger the **No response** stop condition based on this step's HTTP outcome. **No response** is reserved for step (g)'s 10-minute poll timing out — that is the only authoritative signal that Copilot did not review.

### f.5. Resolve-only iteration short-circuit

Only reached if step (e) produced no commits. Re-fetch reviewThreads (same query as step (a)) and count unresolved Copilot threads:

- **Zero remaining**: success. Exit the loop. Print the iteration summary noting "resolve-only iteration, no new code, all Copilot threads now resolved".
- **One or more remaining** (rare: a resolve mutation failed again): increment iteration counter and loop back to step (a). If the same threads remain unresolved across two consecutive iterations, trigger the **Loop detection** stop condition.

Skip steps (f) and (g) on this path.

### g. Wait for Copilot's response

We need to wait up to **10 minutes** for a new Copilot review. Do not foreground-sleep or chain `sleep` calls between polls: the harness's Bash tool blocks long sleeps and chained sleeps. Use one of the two patterns below.

**Preferred: a single backgrounded poll script** (`Bash` with `run_in_background=true`). The script polls itself and exits when the condition is met or the deadline passes. You'll be notified when it exits.

```bash
# Read push_ts from the temp file written in step (e). Bash tool calls do not
# share shell state, so reading from the file (or inlining the literal value
# before sending the script) is required.
push_ts=$(cat /tmp/copilot-pairing-push-ts 2>/dev/null)
[ -n "$push_ts" ] || { echo "push_ts not set; capture it in step (e) before running"; exit 2; }
deadline=$(( $(date +%s) + 600 ))
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
    | jq -r --arg bot 'copilot-pull-request-reviewer' --arg ts "$push_ts" '
        .data.repository.pullRequest.reviews.nodes
        | map(select(.author.login == $bot and .submittedAt > $ts))
        | last // empty')
  if [ -n "$latest" ]; then echo "NEW_REVIEW $latest"; exit 0; fi
  sleep 30
done
echo "TIMEOUT"; exit 1
```

**Alternative**: `Monitor` the same script with an until-loop if you want streaming progress lines.

Branch on the script's exit:

- **Exit 0 (`NEW_REVIEW`)**: re-fetch reviewThreads. If any are unresolved, increment iteration counter and loop back to (a). If zero unresolved, success — exit the loop.
- **Exit 1 (`TIMEOUT`)**: trigger the **No response** stop condition.
- **Exit 2 (bad input)**: step (e) failed to capture `push_ts`. Bug in our flow. Stop and surface the script's stderr.
- **Any other exit code (e.g. 144 from external SIGTERM, OOM kill, harness session end)**: the script was killed externally; its output is not authoritative. Re-query GraphQL directly using the `push_ts` from `/tmp/copilot-pairing-push-ts`:
  ```bash
  push_ts=$(cat /tmp/copilot-pairing-push-ts)
  gh api graphql -f query='...same as the poll script...' \
    -f owner='OWNER' -f repo='REPO' -F number=NUMBER \
    | jq --arg bot 'copilot-pull-request-reviewer' --arg ts "$push_ts" '
        .data.repository.pullRequest.reviews.nodes
        | map(select(.author.login == $bot and .submittedAt > $ts))'
  ```
  - **New Copilot review found**: treat as `NEW_REVIEW` and proceed as above.
  - **No new review, still inside the 10-minute window** (compare `push_ts + 600s` to current `date +%s`): restart the background poll script. Cap restarts at **2** per iteration to prevent thrashing — after that, treat as **No response**.
  - **No new review, past deadline**: treat as `TIMEOUT` and trigger **No response**.

Never assume "loop succeeded" from a non-zero, non-1 exit code. Always cross-check via GraphQL.

### h. Iteration summary

After each iteration, print a short summary:
- Iteration number / cap
- Threads addressed (counts by classification: valid / false positive / adjacent finding)
- Commit SHA pushed
- Test command run + result
- Re-review request status

This is what I scroll back through to audit the run.

## Stop conditions (mandatory human handoff)

If any condition fires, **stop**. Print the latest iteration table, name the condition, and wait for me. Do not push, do not reply, do not re-request review.

| Condition | Trigger |
|---|---|
| **Ambiguity** | Comment is unclear, has multiple valid interpretations, or requires a product/UX call. |
| **Loop detection** | Copilot raised a substantively similar concern (same file, same root issue) in two consecutive iterations. |
| **Scope creep** | A fix would touch code outside the PR's existing diff, or contradicts the PR's stated intent / Jira AC. |
| **Test failure** | Any test, linter, type-check, or formatter fails after our change, including pre-existing failures we surface for the first time. |
| **Security-sensitive** | The change touches auth, secrets handling, crypto, permissions, IAM, SQL/shell construction, or sandbox boundaries. Always pause. |
| **High false-positive ratio** | More than half of an iteration's threads are false positives (model may be misreading the change). Pause for re-alignment. |
| **Iteration cap** | 10 iterations completed without convergence. Stop and report. |
| **Cannot reproduce** | Issue is not reproducible and the proposed fix is non-trivial. |
| **Migrations / data / destructive ops** | Schema migrations, data backfills, deletes, drops, or anything irreversible. Always human-driven. |
| **No response** | 10-minute poll window expires with no new Copilot review. |
| **Conflicting signals** | Copilot's later review contradicts an earlier one we already addressed. Pause to decide which to honor. |

## Auto-execution invariants

These hold at every step:
- **Never** `git push --force` or `--force-with-lease`.
- **Never** amend, squash, or rebase commits already pushed.
- **Never** dismiss a thread without an explanatory reply.
- **Never** skip the failing-test-first step on a behavior-changing fix.
- **Never** commit or touch files outside the PR's diff to "fix" something we noticed in passing. Surface it as an adjacent finding for human review instead.
- **Never** modify CI configuration, `.env`, secrets, or lockfiles unless the Copilot thread is specifically about that file.
- **Never** post anything to chat platforms or tickets.

## Maintenance

After completing the workflow (or stopping), check if any part of these instructions seem outdated or misaligned with current tooling: GraphQL schema changes, deprecated fields, new `gh` CLI capabilities, changes to how Copilot reviews are requested or to the bot's login. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
