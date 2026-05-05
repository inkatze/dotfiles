Do a comprehensive code review of the current feature branch.

## Steps

1. Identify the base branch and get the full diff:
   ```
   git diff main...HEAD
   ```
   If the diff is large, review file-by-file using `git diff main...HEAD -- <path>`.

2. **Check for a Jira ticket**: Extract a Jira ticket key from the branch name (e.g., `PROJ-123` from `PROJ-123-feature-name` or `feature/PROJ-123-description`). If a key is found, fetch the ticket using the Jira MCP tools (`getJiraIssue`) and note the description, acceptance criteria, and any relevant details. If no key is found or Jira tools are unavailable, skip this step.

3. **Generate findings via parallel lens fan-out** (Discovery Rigor canonical spec in CLAUDE.md `Discovery Rigor (Issue Identification)`). The goal is a complete finding list on the first pass so you do not have to re-run this skill to drain pass-2 findings.

   a. **Run project tooling once.** Linters, formatters, type checkers, static analyzers, complexity / duplication meters, dead-code detectors, security scanners. Discover via `lefthook.yml`, CI workflows, `mise.toml` tasks, language config files, and the SessionStart `tool-discovery` summary if present in this session's context. Capture the output; it becomes shared input for every lens agent.

   b. **Spawn one `Explore` sub-agent per canonical lens, in parallel.** Default is to spawn for all 9 lenses; only skip a lens when it is genuinely n/a for the diff (e.g., concurrency for a doc-only change), and record the reason for the lens-coverage table. Each sub-agent receives:
      - The full diff (or relevant slice for large diffs)
      - The tooling output from (a)
      - A narrow brief: "find issues in this diff for ONE lens only: `<lens>`. Be exhaustive within your lens. Severity-pruning is forbidden. If no findings, return `none` with a one-line reason. Cite linter / type-checker rules when they fire."
      - The lens's specific concerns, copied verbatim from CLAUDE.md `Discovery Rigor (Issue Identification)` so the sub-agent does not have to re-read it.

   c. **Coordinator merges and dedupes.** A finding hitting two lenses gets one row with both lens labels. Apply the **review-mode refactor instinct** filter (CLAUDE.md `Refactor Instinct`): drop refactor flags that are not anchored in tool output and do not represent this-PR-makes-it-worse. Pre-existing mess unrelated to the diff is out of scope.

   d. **Jira AC lens** (when a ticket was found in step 2): walk acceptance criteria; flag missing or inconsistent items as findings. This lens is in addition to the canonical 9.

   e. **Self-critique pass (mandatory).** Re-scan the diff and the merged list. Assume the list is incomplete. Add what you find under-represented. The cost is small; the upside is that you do not have to re-run this skill to drain pass-2 findings.

4. **Validate every finding with the three-pass rigor** (canonical spec in CLAUDE.md `Validation Rigor (Issue Identification)`). For each potential issue:
   - **Pass 1 (reproduce):** when the claim is about runtime behavior, reproduce it. Failing test, repro script, trace through the code path with concrete inputs, or construct the failing input.
   - **Pass 2 (orthogonal angle):** look at callers / upstream context, related code paths, project conventions, sibling implementations, existing tests that may already cover the case.
   - **Pass 3 (outside-in):** consult `git log` / `git blame` for context, repo-wide search for similar patterns, and for text/research-based claims (API correctness, spec compliance, deprecated patterns, security claims, library behavior) consult official docs, library source/tests, deepwiki MCP, GitHub issues, RFCs, web search. Note what was checked.

   Drop or downgrade items where the three passes do not converge. Eliminate false positives and speculative concerns. Only report issues you are confident about.

5. Present results as the canonical lens-coverage table from CLAUDE.md `Discovery Rigor (Issue Identification)` followed by **two findings tables** split per CLAUDE.md `Finding Categorization`. Both tables always appear; if a bucket is empty, print a single `none` row.

   **Auto-applicable** (would be safe for `/polish` to handle autonomously):

   | # | Lens | File:Line | Finding | Rule cited | Validation passes | Recommendation |
   |---|---|---|---|---|---|---|

   - **Rule cited**: the linter / type-checker / formatter rule that grounds the finding (e.g. `ruff F401`, `tsc TS2304`, `rubocop Style/UnlessElse`). Mandatory for this table; if no rule cites it, the finding does not belong here.
   - **Recommendation**: the mechanical action to take (e.g. "remove unused import", "add missing semicolon", "fix typo `recieved` → `received`").

   **Needs human attention** (everything else: bugs, refactors, naming, design, missing tests, anything in security-sensitive code):

   | # | Lens | File:Line | Finding | Severity | Confidence | Validation passes | Recommendation |
   |---|---|---|---|---|---|---|---|

   - **Severity**: blocker / concern / suggestion / nit.
   - **Confidence**: high / medium / low.
   - **Recommendation**: implement fix / dismiss / defer to follow-up / document / etc.

   No `Draft comment` column on either table: this skill implements fixes, it does not post per-finding comments.

6. Follow the standard review workflow (let me choose: all at once or one by one, with progress tracking). When implementing fixes, apply the **two-or-three-angle solution validation** (canonical spec in CLAUDE.md `Validation Rigor (Solutions)`):
   - Targeted failing test for the bug's exact reason → fix → confirm test passes.
   - Run the broader test suite, linters, and type-checkers. Watch for regressions.
   - When relevant: edge cases (null, empty, max, concurrency), integration / smoke tests, or manual exercise of the user-facing flow.

   For non-testable changes, substitute review angles (re-read the diff, read from each caller's perspective, grep for places the change could silently break) and note why no test was added.

7. **Documentation check**: Before committing, verify that all documentation affected by the changes is up to date. For each changed file, consider whether any of the following need updates:
   - **Docstrings and inline docs**: Functions, classes, or modules whose behavior or signature changed
   - **READMEs**: Project-level or directory-level READMEs that describe affected features, setup steps, or usage
   - **Requirements and design docs**: Specs, RFCs, ADRs, or similar documents that describe the changed behavior
   - **Task and planning files**: TODOs, changelogs, or roadmap files that reference the changed functionality
   - **Configuration docs**: If config options, environment variables, or CLI flags were added, removed, or changed
   - **Any other prose in the repo** that references the changed code or behavior

   Search the repo for references to changed function names, feature names, or concepts to catch docs that live in unexpected places. Include documentation issues in the review findings alongside code issues.

8. After all items are addressed, commit the changes.

9. If the review found nothing substantive (or after addressing everything), offer to push the branch. Then handle the PR, gracefully reusing an existing one if present:

   **Check if a PR already exists for this branch:**
   ```
   gh pr view --json number,url,state,isDraft,title 2>/dev/null
   ```
   - If a PR exists: push the branch (`git push origin <branch>`) so the existing PR picks up the new commits. Report the existing PR's URL and state (draft/ready, open/merged). Do NOT create a new PR. If the existing PR is merged or closed, ask the user whether to reopen it or create a fresh one instead of assuming.
   - If no PR exists: proceed with the template/convention check below and create a draft PR.

   **Check for templates (only when creating a new PR):**
   - Look for `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, or templates in `.github/PULL_REQUEST_TEMPLATE/`
   - If a template exists, use it as the structure for the PR body, filling in the sections based on the branch changes

   **Check for conventions (only when creating a new PR):**
   - If no template exists, look at recent merged PRs for patterns:
     ```
     gh pr list --state merged --limit 5 --json title,body
     ```
   - If a clear pattern emerges (e.g., consistent sections, formatting), follow it

   **Create the PR (only when none exists):**
   - If a template or convention was found, use `gh pr create --draft` with a `--title` and `--body` that follows the discovered format
   - If nothing was found, fall back to `gh pr create --draft --fill`

## Maintenance

After completing the workflow, check if any part of these instructions seem outdated, incorrect, or misaligned with the current project's tooling or workflow. If something looks off, flag it and offer a ready-to-use prompt I can paste into a new dotfiles session to update this command.

$ARGUMENTS
