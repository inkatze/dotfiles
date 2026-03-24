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

### 3. Get the full diff

```bash
git diff <base>...HEAD
```

If the diff is large, review file-by-file using `git diff <base>...HEAD -- <path>`.

### 4. Review all changes thoroughly for:

- Bugs, logic errors, and edge cases
- Security concerns (injection, auth issues, data exposure)
- Performance problems
- Code style and consistency with the surrounding codebase
- Missing or insufficient test coverage
- Dead code or unnecessary changes

### 5. Validate every finding

For each potential issue, read the full source file to understand context. Eliminate false positives and speculative concerns. Only report issues you are confident about.

### 6. Present the validated list

For each item, include:
- File path and line number
- Severity: **blocker**, **concern**, **suggestion**, or **nit**
- A clear description of the issue
- A proposed inline comment draft

If nothing substantive remains, say so.

### 7. Follow the standard review workflow

Let me choose: all at once or one by one, with progress tracking. Present each comment draft for my approval. I may want to adjust wording.

**Comment tone requirements:**
- Constructive and specific
- Prefix with severity when not obvious (e.g., "nit:", "suggestion:", "blocker:")
- Explain the "why", not just the "what"
- Suggest a fix or alternative when possible
- No em-dashes
- Sound natural and human, like me writing the comment myself

### 8. Summary

After all comments are finalized, present a summary of the review with the final approved comments, organized by file. I will submit the review manually.

### 9. Return to original branch

```bash
git checkout <original-branch>
```

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
