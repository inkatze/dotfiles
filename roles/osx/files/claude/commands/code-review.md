Do a comprehensive code review on a PR and draft review comments for me to submit.

## Steps

### 1. Checkout the PR

If `$ARGUMENTS` contains a PR number or URL, use it. Otherwise, ask.

```bash
gh pr checkout <number>
```

Note the current branch before checking out so we can return to it at the end.

### 2. Get PR and repo info

```bash
gh pr view --json number,baseRefName,title,body,author -q '{number: .number, base: .baseRefName, title: .title, author: .author.login}'
gh repo view --json owner,name -q '.owner.login + " " + .name'
```

### 3. Check for a Jira ticket

Extract a Jira ticket key from the branch name, PR title, or PR body (e.g., `PROJ-123`). If a key is found, fetch the ticket using the Jira MCP tools (`getJiraIssue`) and note the description, acceptance criteria, and any relevant details. If no key is found or Jira tools are unavailable, skip this step.

### 4. Get the full diff

```bash
git diff <base>...HEAD
```

If the diff is large, review file-by-file using `git diff <base>...HEAD -- <path>`.

### 5. Review all changes thoroughly for:

- Bugs, logic errors, and edge cases
- Security concerns (injection, auth issues, data exposure)
- Performance problems
- Code style and consistency with the surrounding codebase
- Missing or insufficient test coverage
- Dead code or unnecessary changes
- If a Jira ticket was found: whether the changes satisfy each acceptance criterion, and whether anything is missing or inconsistent with the ticket requirements

### 6. Validate every finding

For each potential issue, read the full source file to understand context. Eliminate false positives and speculative concerns. Only report issues you are confident about.

### 7. Present the validated list

For each item, include:
- File path and line number
- Severity: **blocker**, **concern**, **suggestion**, or **nit**
- A clear description of the issue
- A proposed inline comment draft

If nothing substantive remains, say so.

### 8. Follow the standard review workflow

Let me choose: all at once or one by one, with progress tracking. Present each comment draft for my approval. I may want to adjust wording.

**Comment tone requirements:**
- Constructive and specific
- Prefix with severity when not obvious (e.g., "nit:", "suggestion:", "blocker:")
- Explain the "why", not just the "what"
- Suggest a fix or alternative when possible
- No em-dashes
- Sound natural and human, like me writing the comment myself

### 9. Summary

After all comments are finalized, present a summary of the review with the final approved comments, organized by file. I will submit the review manually.

### 10. Return to original branch

```bash
git checkout <original-branch>
```

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
