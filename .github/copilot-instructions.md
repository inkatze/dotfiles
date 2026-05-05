# Copilot instructions: dotfiles

Personal dotfiles managed by Ansible. `~/.claude/`, `~/.config/fish/`, tmux,
mise, and related surfaces are materialized from tracked sources in this repo.
Edit the source, run Ansible, never edit the materialized files.

The conventions below apply to PR reviews, chat answers, and code suggestions.

## How to review (single-pass exhaustiveness)

Reviews here are expected to be **exhaustive in one pass**. Multiple iterations
of partial feedback are a failure mode, not the workflow. When you review a
diff, walk every lens before producing the comment list:

<!-- diverges from CLAUDE.md `Discovery Rigor` by design: idempotency added (Ansible repo); performance and concurrency dropped (no hot paths or concurrent code in this repo). -->

1. Correctness and logic bugs
2. Security and secret handling (this repo touches 1Password, GitHub PATs, MCP)
3. Error handling and failure modes (especially in shell and Ansible tasks)
4. Edge cases (empty input, missing files, locked vault, CI vs local, first-run)
5. Idempotency (Ansible roles must be idempotent, see `lint` job in CI)
6. Naming, readability, and code structure
7. Documentation: does `CLAUDE.md`, `specs/`, or inline docs need updating?
8. Tests / verification: is the change covered by CI matrix or manual repro?
9. Cross-file consistency: did the diff break a documented invariant?

For each lens, either list findings or state `none` with a one-line reason.
Do not silently drop categories. Severity-based self-pruning ("I already found
a bug, the doc nit isn't worth mentioning") is the exact behavior to avoid;
report findings at every severity in the same pass.

After producing the list, do one self-critique pass: assume the list is
incomplete, re-scan the diff specifically for what feels under-represented,
and add what you find.

## Refactor instinct: review vs. implementation

Guiding principle: **small, continuous refactors prevent large, breaking
ones.** Favor composable code shaped by frequent small cleanups over big
periodic rewrites. The two modes below have **different bars** for when to
act on this.

Whichever mode you are in, **ground refactor decisions in the project's
tooling, not vibes.** Before claiming something needs a refactor, check what
the repo already runs: linters, formatters, type checkers, static analyzers,
complexity or duplication meters, dead-code detectors, security scanners.
Look at `lefthook.yml`, CI workflows, `mise.toml` tasks, language-specific
config files (`.rubocop.yml`, `pyproject.toml`, `tsconfig.json`,
`Cargo.toml`, etc.), and pre-commit hooks to discover what's available.

- If a tool flags it, the finding is grounded; cite the tool and rule.
- If no tool flags it but you still feel it should be refactored, your
  judgment is less reliable; be more conservative, especially in review mode.
- If the repo has no relevant tooling for the language/area you're touching,
  prefer suggesting that tooling be added over making subjective calls.

### When reviewing a PR (high bar)

- Only flag refactors when **this PR** materially worsens structure (new
  duplication introduced, nesting deepened, abstraction muddled, naming made
  worse). Pre-existing mess unrelated to the diff is out of scope.
- Anchor flags in tool output where possible. "X trips <linter> rule Y" is
  grounded; "this could be cleaner" is not and should be dropped.
- Prefer follow-up suggestions over blocking comments. "Consider as a
  follow-up" is usually the right framing.
- Do not propose alternative architectures, rewrites, or stylistic preferences
  unless the current shape will demonstrably cause maintenance pain.
- Do not invent abstractions for hypothetical future requirements. Three
  similar lines is fine; demanding a helper for them is noise.

### When implementing or editing (low bar)

- Clean up **as you go**. Rename a confusing variable, extract a helper when
  a third caller appears, split a function that grew past one screen.
- Before adding to messy code, pause and either (a) make the small cleanup
  inline, or (b) surface the friction to the user with a concrete proposal.
  Do not barrel through and add more mess.
- Run the project's linters/formatters/type checkers locally before
  declaring done. If they surface fixable issues in the area you touched,
  fix them in the same change rather than leaving them for review.
- Refactor proposals during implementation should be small, scoped to the
  area you're touching, and easy to accept or reject.

## Validating findings before posting

A comment that turns out to be wrong is worse than a comment not made. For
each finding before posting:

1. **Reproduce or trace.** For runtime claims, mentally execute with concrete
   inputs or point to the exact failing case. If you cannot, downgrade or drop.
2. **Orthogonal check.** Look at callers, sibling implementations, existing
   tests, project conventions. If the pattern is intentional and consistent
   elsewhere, it is probably not a bug.
3. **Outside-in check.** Consult `git log` / `git blame` for context on why
   the code is shaped the way it is. Check `CLAUDE.md`, `specs/README.md`,
   and per-directory docs for documented conventions before flagging a
   "violation."

Findings that fail any of these three should be dropped, not softened.

## Project-specific context (do not flag these as bugs)

- **Fish shell, not bash/zsh.** `set -x VAR value` is correct, `export` is not.
  `string match`, `function`, `set -l` are intentional.
- **`mise` runs everything.** `fish -c "<cmd>"` wrappers in scripts are
  deliberate so mise-managed runtimes are picked up.
- **Ansible materialization model.** Files under `roles/osx/files/claude/` are
  the source of truth. The runtime path `~/.claude/...` is materialized via
  symlink (most files) or `jq` merge (`settings.json`). Do not suggest editing
  the runtime path.
- **MCP secret handling.** `scripts/claude-mcp-sync-github.sh` reads the
  GitHub PAT from 1Password, writes via atomic `jq` temp+rename, and scopes
  `GITHUB_PAT` to two `jq` invocations. Argv exposure and same-user env
  inspection are documented and accepted; do not re-flag them. The
  strict-fail on a locked vault is **deliberate** (a silent skip would
  let stale PATs land unnoticed); do not suggest softening it.
- **CI guard `when: lookup('ansible.builtin.env', 'CI', default='') == ''`**
  is intentional on the MCP sync tasks. Do not suggest removing it.
- **`mise run` invocations** route through `mise.toml` task definitions; some
  tasks deliberately pass `--skip-tags` or `-t <tag>`. Do not flag these as
  inconsistencies without checking `mise.toml`.
- **`lefthook` pre-commit hooks** exist (`lefthook.yml`). Bypassing them
  (`--no-verify`) is never acceptable; do not suggest it as a workaround.
- **Idempotency expectations** vary by role. The CI matrix in
  `.github/workflows/test.yml` declares `strict_idempotency: true|false` per
  role; respect that signal before flagging a non-idempotent task.

## Writing style

- No em-dashes in prose. Use commas, parentheses, colons, or split sentences.
- Commit messages: conventional style (`type: description`), no co-author
  attribution, no AI-generation footer.
- `git push` always specifies remote and branch explicitly
  (`git push origin <branch>`); bare `git push` is wrong here.

## Output shape for review comments

When posting review comments, prefer this shape:

```
**[lens]** <one-line claim>

<2-4 lines: where, why it matters, what to do>
<optional: severity = blocking | nit | follow-up>
```

Group findings by file when there are many. Do not pad with restated diff
context the author can already see.
