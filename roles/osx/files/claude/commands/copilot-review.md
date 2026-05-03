Review and address unresolved GitHub Copilot review threads on the current PR.

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

Filter to threads where `isResolved: false` AND the first comment author is the Copilot bot. The standard bot login is `copilot-pull-request-reviewer` (`__typename: Bot`), but verify per run, especially on GHES or repos with custom bot integrations. Use `reviews(last: 5)` so the query surfaces the most-recent reviews; `first: 5` would return the oldest and may not include Copilot on a long-lived PR:

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

Use the actual `Bot` login if it differs. If the PR has threads from other authors too, leave those for `/peer-review`.

Apply this jq filter to the **`reviewThreads` query output** (the first GraphQL block in this step, not the `reviews(last: 5)` bot-login verification block) (substitute the verified bot login if it isn't the default):

```bash
jq --arg bot 'copilot-pull-request-reviewer' '
    .data.repository.pullRequest.reviewThreads.nodes
    | map(select(.isResolved == false and .comments.nodes[0].author.login == $bot))'
```

Filter on `login` rather than `__typename == "Bot"` so other bot integrations (CodeQL, Dependabot review, etc.) don't get pulled in.

### 4. Validate every thread: three passes minimum (different angle each)

Apply the canonical rigor in CLAUDE.md `Validation Rigor (Issue Identification)`. For each unresolved Copilot thread:

- **Read first.** Comment body, referenced file:line, plus enough surrounding context (callers, related modules) to understand the real behavior.
- **Pass 1: direct reproduction.** When the claim is about runtime behavior, try to reproduce it. Write a failing test, run a script, trace through the code with concrete inputs, or construct an input that triggers the claimed bug. Inability to reproduce is a strong signal of a false positive.
- **Pass 2: orthogonal angle.** Look at it from a different perspective: callers and what they assume, related code paths and side effects, hidden invariants, project conventions, sibling implementations, existing test coverage that may already prove the case safe.
- **Pass 3: outside-in angle.** Sources outside the diff. `git log` / `git blame` for the why-it-is-the-way-it-is. Repo-wide search for similar patterns to see if the concern applies elsewhere or only here. For text/research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior): official docs, the library's own source/tests, deepwiki MCP, GitHub issues, RFCs, web search. Note what was consulted.

**Do not take Copilot's recommendation as correct.** Even when the underlying concern is real, design the best solution from first principles. Copilot's suggested fix may be insufficient (treating a symptom not the cause), wrong (introduces a new bug), unidiomatic for the codebase, or out of scope. Apply the same three-pass rigor to the proposed fix: does it actually resolve the issue, does it survive an orthogonal angle, does it match what docs/conventions/external references would recommend.

Classify each thread as **valid** (needs a fix), **false positive** (no real problem), or **low-confidence** (passes did not converge; never guess). Look for issues Copilot did not flag that are adjacent to what it did. Surface those as extra rows tagged "adjacent finding".

### 5. Present the validated table

Output one Markdown table. Default columns:

| # | Thread ID | File:Line | Copilot's concern | What we found | Reproduced? | Classification | Confidence | Our proposed fix |
|---|---|---|---|---|---|---|---|---|

Notes on columns:
- **Copilot's concern**: a tight one-line summary of what the bot said, not a copy-paste.
- **What we found**: the result of our investigation (the actual behavior, the real root cause, or "no issue, code already handles X").
- **Reproduced?**: `yes` / `no` / `n/a` (n/a for items not reproducible by their nature, e.g. style/naming).
- **Classification**: `valid` / `false positive` / `low-confidence` / `adjacent finding`.
- **Confidence**: `high` / `medium` / `low`. How sure we are about the classification.
- **Our proposed fix**: a one-line description of the change we want to make. May explicitly differ from Copilot's suggestion.

If a column is not useful for the current PR (or you want a different cut), say so before printing the table and adjust. Optional add-ons worth considering case by case: `Severity`, `Test plan`, `Copilot's suggested fix` (when it diverges meaningfully from ours), `Files touched by fix`, `Scope risk` (in-scope / out-of-scope).

### 6. Address items: solution validated with two or three test angles

Follow the standard review workflow (let me choose: all at once or one by one, with progress tracking).

For **valid** items that affect runtime behavior, apply the canonical rigor in CLAUDE.md `Validation Rigor (Solutions)`:

1. **Targeted test.** Write a test that demonstrates the bug. Run it and confirm it fails for the expected reason (not for an unrelated reason like a missing import). Apply the fix. Re-run the test and confirm it now passes.
2. **Wider check.** Run the broader project test suite, linters, and type-checkers. Watch for regressions, including in code paths the fix did not directly touch.
3. **Edge / integration / manual** (when relevant). Boundary cases (null, empty, max size, concurrency), an integration or smoke test, or manual exercise of the user-facing flow.

"When applicable" means: skip targeted-test for non-behavioral changes (doc-only fixes, comment changes, pure renames, type-only adjustments, formatting). For those, substitute review angles per the canonical doctrine: re-read the diff, read it from each caller's perspective, grep for places the change could silently break. Note in the reply why no test was added.

For **false positives**: prepare a brief dismissal comment explaining what we checked (cite the three passes) and why the concern does not apply.
For **low-confidence**: pause and ask me before taking action.

### 7. Commit and push

After all items are addressed, commit the changes and push.

### 8. Reply to and resolve each thread

**Use `addPullRequestReviewThreadReply` only.** Do **NOT** use `addPullRequestReviewComment` (with or without `inReplyTo`) for this workflow.

Both mutations can leave replies invisible by attaching them to a *pending* review owned by the viewer:

- `addPullRequestReviewComment` always builds onto a review and creates a pending one if none is in progress. This has bitten this skill before; replies sat as drafts until someone manually clicked Submit.
- `addPullRequestReviewThreadReply` is the more direct mutation, but per a 2026-05-02 live-run failure on `SymmetrySoftware/stl-poc#13` it can also auto-vivify a pending review when the viewer has none in progress. The reply then stays invisible (to the GitHub UI, to Copilot, to humans) until the pending review is submitted.

After the batch of replies, **always** submit any pending review you own on this PR before resolving threads (see "Submit any auto-vivified pending review" below). A successful-looking run can otherwise complete with all replies silently invisible.

**Shell quoting rules:**
- Always use multi-line query strings for GraphQL mutations. Single-line strings cause the shell to eat `$` in variable names like `$threadId`.
- Always write the response body to a temp file and use `-F body=@file` to pass it. This avoids fish shell interpreting backticks in the body as command substitution.

For each thread, run the reply mutation. After the whole batch of replies, run the pending-review submit step **once**, then run the resolve mutation per thread.

**Reply to the thread** (use the thread `id` from step 3, not the comment id):

```bash
printf '%s' 'RESPONSE_BODY' > /tmp/gh-review-comment.txt
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId,
      body: $body
    }) {
      comment { id }
    }
  }
' -f threadId='THREAD_ID' -F body=@/tmp/gh-review-comment.txt
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

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow (e.g., GraphQL schema changes, deprecated fields, new `gh` CLI capabilities, Copilot bot login changes). If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
