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
                author { login }
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

### 4. Validate each unresolved thread — three passes minimum (different angle each)

Filter to only unresolved threads (`isResolved: false`). For each one, apply the canonical rigor in CLAUDE.md `Validation Rigor (Issue Identification)`:

- **Read first.** The full comment thread (all comments, not just the first), the actual source at the referenced location, and the reviewer's likely intent.
- **Pass 1: direct reproduction.** When the concern is about runtime behavior, reproduce it. Failing test, repro script, trace through the code with concrete inputs. Inability to reproduce is a strong signal it may be a preference or a false positive.
- **Pass 2: orthogonal angle.** A different lens: callers and what they assume, related code paths, project conventions and sibling implementations, existing test coverage that may already prove the case safe.
- **Pass 3: outside-in angle.** Sources outside the diff: `git log` / `git blame` for the why-it-is-the-way-it-is, repo-wide search for similar patterns, and for text/research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior) consult official docs, library source/tests, deepwiki MCP, GitHub issues, RFCs, web search. Note what was checked.

Classify each as **valid**, **false positive**, **preference**, or **low-confidence** (passes did not converge — never guess). When the concern is a matter of preference, surface the trade-off rather than asserting correctness.

### 5. Present the validated list

For each item, include:
- The reviewer's concern (summarized)
- Your assessment (valid, false positive, preference, low-confidence) with a one-line note on which validation passes converged
- A proposed response draft
- The proposed code change (if any)

### 6. Address items

Follow the standard review workflow (let me choose: all at once or one by one, with progress tracking).

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

### 8. Reply to and resolve each thread (only after I approve the response)

**Shell quoting rules:**
- Always use multi-line query strings for GraphQL mutations. Single-line strings cause the shell to eat `$` in variable names like `$threadId`.
- Always write the response body to a temp file and use `-F body=@file` to pass it. This avoids fish shell interpreting backticks in the body as command substitution.

For each thread, run both mutations in sequence:

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
