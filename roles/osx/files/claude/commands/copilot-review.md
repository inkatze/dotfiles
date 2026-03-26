Review and address unresolved GitHub Copilot review threads on the current PR.

## Steps

### 1. Get PR and repo info

```bash
gh pr view --json number -q '.number'
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

### 2. Fetch unresolved review threads

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

### 3. Validate each unresolved thread

Filter to only unresolved threads (`isResolved: false`). For each one:

- Read the comment body and identify the referenced file path and line(s)
- Read the actual source code at that location
- **Validate thoroughly**: Determine if the concern is legitimate by checking the real code. Copilot often produces false positives.
- Classify as: **valid** (needs a fix), **false positive**, or **low-confidence**

### 4. Present the validated list

Show all threads with their classifications. Emphasize false positives so I can see what was caught. Include the thread ID for each item.

### 5. Address items

Follow the standard review workflow (let me choose: all at once or one by one, with progress tracking).

For false positives: prepare a brief dismissal comment.
For valid items: fix the code and prepare a comment explaining the change.

### 6. Commit and push

After all items are addressed, commit the changes and push.

### 7. Reply to and resolve each thread

**Important:** Always use multi-line query strings for GraphQL mutations. Single-line strings cause the shell to eat `$` in variable names like `$threadId`.

For each thread, run both mutations in sequence:

**Reply to the thread** (use the thread `id` from step 2, not the comment id):

```bash
gh api graphql -f query='
  mutation($threadId: ID!, $body: String!) {
    addPullRequestReviewThreadReply(input: {
      pullRequestReviewThreadId: $threadId,
      body: $body
    }) {
      comment { id }
    }
  }
' -f threadId='THREAD_ID' -f body='RESPONSE_BODY'
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

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow (e.g., GraphQL schema changes, deprecated fields, new `gh` CLI capabilities). If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
