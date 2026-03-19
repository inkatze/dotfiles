Do a comprehensive code review of the current feature branch.

## Steps

1. Identify the base branch and get the full diff:
   ```
   git diff main...HEAD
   ```
   If the diff is large, review file-by-file using `git diff main...HEAD -- <path>`.

2. Review all changes thoroughly for:
   - Bugs, logic errors, and edge cases
   - Security concerns (injection, auth issues, data exposure)
   - Performance problems
   - Code style and consistency with the surrounding codebase
   - Missing or insufficient test coverage
   - Dead code or unnecessary changes

3. **Validate every finding**: For each potential issue, read the full source file to understand context. Eliminate false positives and speculative concerns. Only report issues you are confident about.

4. Present the validated list as a numbered summary with brief descriptions. Clearly state the confidence level. If nothing substantive remains, say so.

5. Follow the standard review workflow (let me choose: all at once or one by one, with progress tracking).

6. After all items are addressed, commit the changes.

7. If the review found nothing substantive (or after addressing everything), offer to push and create a draft PR:
   ```
   gh pr create --draft --fill
   ```

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
