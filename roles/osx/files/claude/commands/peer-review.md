Review and address unresolved peer review threads on the current PR.

This is a human reviewer, so take extra care with response quality and tone.

## Steps

### 1. Get PR and repo info

```bash
gh pr view --json number -q '.number'
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

### 2. (Optional) Fetch Jira ticket for context

Extract a Jira ticket key from the branch name or PR title. If a key is found, fetch the ticket using the Jira MCP tools (`getJiraIssue`) and note the description and acceptance criteria. Use this context when validating threads (e.g., a concern might be out of scope per the AC, or a missing check might be required by the AC). If no key is found or Jira tools are unavailable, skip this step.

### 3. Fetch unresolved review threads

Use this exact GraphQL query (substitute the owner, repo, and number values):

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            path
            line
            startLine
            comments(first: 20) {
              nodes {
                id
                body
                author { __typename login }
                createdAt
              }
            }
          }
        }
      }
    }
  }
' -f owner='OWNER' -f repo='REPO' -F number=NUMBER
```

### 4. Validate each unresolved thread: three passes minimum (different angle each)

Filter to threads where `isResolved: false` AND the first comment author is NOT a `Bot` (`__typename != "Bot"`). Bot threads (Copilot and friends) belong to `/copilot-review` or `/copilot-pairing`; processing them here would generate human-tone replies to a bot.

**Known gap.** This filter excludes *all* bots, but `/copilot-review` and `/copilot-pairing` only handle the Copilot bot specifically (filtered by `author.login`). Non-Copilot bot threads (e.g., CodeQL, Dependabot review) are therefore not handled by any of these workflows. Address them out-of-band: reply/resolve manually, or copy this command and narrow the filter to a specific bot login plus adjust the tone instructions for that bot. The current trade-off is deliberate: human tone is wrong for a bot, and Copilot tone is wrong for non-Copilot bots, so silent exclusion beats applying the wrong workflow.

Pipe the previous query's output through this jq filter:

```bash
jq '.data.repository.pullRequest.reviewThreads.nodes
    | map(select(.isResolved == false and .comments.nodes[0].author.__typename != "Bot"))'
```

For each remaining thread, apply the canonical rigor in CLAUDE.md `Validation Rigor (Issue Identification)`:

- **Read first.** The full comment thread (all comments, not just the first), the actual source at the referenced location, and the reviewer's likely intent.
- **Pass 1: direct reproduction.** When the concern is about runtime behavior, reproduce it. Failing test, repro script, trace through the code with concrete inputs. Inability to reproduce is a strong signal it may be a preference or a false positive.
- **Pass 2: orthogonal angle.** A different lens: callers and what they assume, related code paths, project conventions and sibling implementations, existing test coverage that may already prove the case safe.
- **Pass 3: outside-in angle.** Sources outside the diff: `git log` / `git blame` for the why-it-is-the-way-it-is, repo-wide search for similar patterns, and for text/research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior) consult official docs, library source/tests, deepwiki MCP, GitHub issues, RFCs, web search. Note what was checked.

Classify each as **valid**, **false positive**, **preference**, or **low-confidence** (passes did not converge; never guess). When the concern is a matter of preference, surface the trade-off rather than asserting correctness.

### 5. Present the validated threads as two tables

Split per CLAUDE.md `Finding Categorization`. Both tables always appear; if a bucket is empty, print a single `none` row.

**Auto-applicable** (the reviewer flagged something tool-grounded and mechanical; reply can be a terse "Done in `<sha>`"):

| # | Thread ID | File:Line | Reviewer's concern | What we found | Rule cited | Validation passes | Recommendation | Draft response |
|---|---|---|---|---|---|---|---|---|

- **What we found**: a one-line, plain-prose verdict from our investigation. For Auto-applicable items this is usually "tool confirmed, fix is mechanical" or similar.
- **Rule cited**: the linter / type-checker / formatter rule that confirms the reviewer's concern.
- **Draft response**: short, polite. "Done in `<sha>`" or "Good catch, fixed in `<sha>`" is usually enough.

**Needs human attention** (preference, design, refactor, ambiguity, low-confidence, anything that needs a real reply):

| # | Thread ID | File:Line | Reviewer's concern | What we found | Classification | Confidence | Validation passes | Recommendation | Draft response |
|---|---|---|---|---|---|---|---|---|---|

- **What we found**: a one-line, plain-prose verdict from our investigation (the rationale that supports the `Classification` bucket).
- **Classification**: valid / false positive / preference / low-confidence.
- **Confidence**: high / medium / low.
- **Recommendation**: implement fix / dismiss / defer to follow-up / acknowledge preference and explain trade-off / etc.
- **Draft response**: literal reply you would post. See step 6 tone requirements (concise but not curt, acknowledges good points, no corporate speak, no em-dashes, sounds natural and human, written as if the user wrote it themselves).

If a column is not useful for this PR, say so before printing the table and adjust. Optional add-ons worth considering: `Severity`, `Files touched by fix`, `Scope risk` (in-scope / out-of-scope).

No lens-coverage table here: this skill validates pre-existing human threads, it does not generate net-new findings via Discovery Rigor (a full-diff sweep belongs in `/self-review`).

### 6. Address items

Follow the standard review workflow (let me choose: all at once, one by one, batched decisions, or clustered decisions, with progress tracking). For batched mode, the `/peer-review` option set is **Address now / Defer to follow-up / Dismiss / Discuss first** (with auto-added "Other" for custom decisions). For clustered mode, the cluster-wide option set is **Address all / Defer all to follow-up / Dismiss all / Pick individually** (with "Pick individually" dropping into batched mode for that cluster only).

**Response tone requirements** (this is critical since we are replying to a person):
- Concise but not curt
- Acknowledge good points genuinely
- When disagreeing, explain the reasoning clearly without being defensive
- Use "I" not "we" unless referring to a team decision
- No corporate speak, no filler phrases
- No em-dashes
- Sound natural and human, like me writing the response myself

Present each response draft for my approval before posting. I may want to adjust wording.

**Solution validation when fixes are involved.** When a thread leads to a code change, apply the canonical rigor in CLAUDE.md `Validation Rigor (Solutions)`:

1. **Targeted test.** Write a failing test for the bug's exact reason, confirm it fails for the right reason, apply the fix, confirm it now passes.
2. **Wider check.** Run the broader test suite, linters, type-checkers. Watch for regressions.
3. **Edge / integration / manual** (when relevant). Boundary cases, integration / smoke tests, or manual exercise of the user-facing flow.

For non-testable changes, substitute review angles per the canonical doctrine and note in the reply why no test was added.

### 7. Commit and push

After all items are addressed, commit the changes and push.

**If the push fails on a hook (pre-push test, security check, lefthook stage, etc.):** diagnose whether the failure is caused by this branch's diff or by something pre-existing / unrelated (a flaky test, a broken main, a security check tripping on untouched code). Surface the diagnosis to me and ask whether to (a) investigate and fix in-scope, or (b) hold off pushing. Do not silently retry, **never** bypass with `--no-verify` (the repo policy in `.github/copilot-instructions.md` and the global CLAUDE.md "Executing actions with care" rule both forbid it), and do not "fix" unrelated test flakes inside this branch without checking first.

### 8. Reply to and resolve each thread (only after I approve the response)

**Use `addPullRequestReviewThreadReply` only.** Do **NOT** use `addPullRequestReviewComment` (with or without `inReplyTo`) for this workflow.

Both mutations can leave replies invisible by attaching them to a *pending* review owned by the viewer:

- `addPullRequestReviewComment` always builds onto a review and creates a pending one if none is in progress; replies sit as drafts until someone manually clicks Submit.
- `addPullRequestReviewThreadReply` is the more direct mutation, but per a 2026-05-02 live-run failure on `SymmetrySoftware/stl-poc#13` it can also auto-vivify a pending review when the viewer has none in progress. The reply then stays invisible (to GitHub UI, to the human reviewer, to anyone else) until the pending review is submitted.

After the batch of replies, **always** submit any pending review you own on this PR before resolving threads (see "Submit any auto-vivified pending review" below). A successful-looking run can otherwise complete with all replies silently invisible: the human reviewer sees no response and the threads still appear unanswered to them.

**Shell quoting rules:**
- Always use multi-line query strings for GraphQL mutations. Single-line strings cause the shell to eat `$` in variable names like `$threadId`.
- Construct the response body as an inline single-quoted bash heredoc inside the same `Bash` invocation that runs the GraphQL mutation. The single-quoted delimiter (`<<'EOF'`) keeps backticks, `$variables`, and other shell metacharacters literal, so the body is safe to embed without escaping. The previously-suggested temp-file pattern (`printf` to `/tmp/...` then `-F body=@file` in a separate `Bash` call) has been observed to trip harness permission denials with the rationale "body content is unverifiable" because the harness can flag chained file-write-then-public-post sequences as suspicious. Inline heredoc keeps body construction and posting in a single tool invocation. Fall back to a temp file only when the body is genuinely too large to inline (rare).

For each thread, run the reply mutation. After the whole batch of replies, run the pending-review submit step **once**, then run the resolve mutation per thread.

**Reply to the thread** (use the thread `id` from step 3, not the comment id):

```bash
body=$(cat <<'EOF'
RESPONSE_BODY (multi-line ok; backticks and $vars stay literal)
EOF
)
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId,
      body: $body
    }) {
      comment { id }
    }
  }
' -f threadId='THREAD_ID' -f body="$body"
```

**Submit any auto-vivified pending review** (run once after all replies are posted, before resolving):

Query the PR's pending reviews and the viewer's login in one round-trip, then submit each pending review owned by the viewer:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    viewer { login }
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviews(states: PENDING, first: 10) {
          nodes { id author { login } }
        }
      }
    }
  }
' -f owner='OWNER' -f repo='REPO' -F number=NUMBER
```

For each `reviews.nodes` entry where `author.login == viewer.login`:

```bash
gh api graphql -f query='
  mutation($id: ID!) {
    submitPullRequestReview(input: {
      pullRequestReviewId: $id,
      event: COMMENT
    }) {
      pullRequestReview { id state submittedAt }
    }
  }
' -f id='REVIEW_ID'
```

Re-run the pending-reviews query and assert no pending reviews owned by the viewer remain. If a pending review cannot be submitted, stop and surface the error rather than silently resolving threads on top of invisible replies.

**Resolve the thread:**

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {
      threadId: $threadId
    }) {
      thread { isResolved }
    }
  }
' -f threadId='THREAD_ID'
```

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow (e.g., GraphQL schema changes, deprecated fields, new `gh` CLI capabilities, tone mismatches). If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
