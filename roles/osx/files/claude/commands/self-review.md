Do a comprehensive code review of the current feature branch.

## Steps

1. Identify the base branch and get the full diff:
   ```
   git diff main...HEAD
   ```
   If the diff is large, review file-by-file using `git diff main...HEAD -- <path>`.

2. **Check for a Jira ticket**: Extract a Jira ticket key from the branch name (e.g., `PROJ-123` from `PROJ-123-feature-name` or `feature/PROJ-123-description`). If a key is found, fetch the ticket using the Jira MCP tools (`getJiraIssue`) and note the description, acceptance criteria, and any relevant details. If no key is found or Jira tools are unavailable, skip this step.

3. Review all changes thoroughly for:
   - Bugs, logic errors, and edge cases
   - Security concerns (injection, auth issues, data exposure)
   - Performance problems
   - Code style and consistency with the surrounding codebase
   - Missing or insufficient test coverage
   - Dead code or unnecessary changes
   - If a Jira ticket was found: whether the changes satisfy each acceptance criterion, and whether anything is missing or inconsistent with the ticket requirements

4. **Validate every finding**: For each potential issue, read the full source file to understand context. Eliminate false positives and speculative concerns. Only report issues you are confident about.

5. Present the validated list as a numbered summary with brief descriptions. Clearly state the confidence level. If nothing substantive remains, say so.

6. Follow the standard review workflow (let me choose: all at once or one by one, with progress tracking).

7. **Documentation check**: Before committing, verify that all documentation affected by the changes is up to date. For each changed file, consider whether any of the following need updates:
   - **Docstrings and inline docs**: Functions, classes, or modules whose behavior or signature changed
   - **READMEs**: Project-level or directory-level READMEs that describe affected features, setup steps, or usage
   - **Requirements and design docs**: Specs, RFCs, ADRs, or similar documents that describe the changed behavior
   - **Task and planning files**: TODOs, changelogs, or roadmap files that reference the changed functionality
   - **Configuration docs**: If config options, environment variables, or CLI flags were added, removed, or changed
   - **Any other prose in the repo** that references the changed code or behavior

   Search the repo for references to changed function names, feature names, or concepts to catch docs that live in unexpected places. Include documentation issues in the review findings alongside code issues.

8. After all items are addressed, commit the changes.

9. If the review found nothing substantive (or after addressing everything), offer to push and create a draft PR. Before creating it, check for PR templates and conventions:

   **Check for templates:**
   - Look for `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, or templates in `.github/PULL_REQUEST_TEMPLATE/`
   - If a template exists, use it as the structure for the PR body, filling in the sections based on the branch changes

   **Check for conventions:**
   - If no template exists, look at recent merged PRs for patterns:
     ```
     gh pr list --state merged --limit 5 --json title,body
     ```
   - If a clear pattern emerges (e.g., consistent sections, formatting), follow it

   **Create the PR:**
   - If a template or convention was found, use `gh pr create --draft` with a `--title` and `--body` that follows the discovered format
   - If nothing was found, fall back to `gh pr create --draft --fill`

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
