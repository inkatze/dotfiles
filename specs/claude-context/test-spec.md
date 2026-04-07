# Dotfiles Repo-Root CLAUDE.md Test Specification

## What to verify

There is no automated test surface for a CLAUDE.md file. Verification is by
fresh-session smoke test plus structural spot checks against the requirements.

### Auto-load

- A fresh Claude session launched with `cwd = /Users/inkatze/dev/dotfiles` shows the
  new `CLAUDE.md` in its loaded context. The system reminder at session start cites
  the file path.
- Sessions launched with cwd outside the dotfiles repo do **not** load the file
  (sanity check that it is repo-scoped, not global).

### Behavioral checks (fresh session, cwd in dotfiles)

- Asked "where do I add a new slash command?", Claude points to
  `roles/osx/files/claude/commands/`, not `~/.claude/commands/`.
- Asked "edit my commit command", Claude edits the tracked source file under
  `roles/osx/files/claude/commands/`, not the symlink target in `~/.claude/`.
- Asked where a new durable permission belongs, Claude can map the request to the
  correct layer of the three-layer model (global tracked, per-repo tracked, per-repo
  local) without re-deriving it from scratch.

### Structural spot checks

- File length is ≤ 120 lines.
- No section duplicates content already in `~/.claude/CLAUDE.md` (Fish, mise,
  conventional commits, no-Claude-footer, GPG signing, explicit-remote-on-push).
- No Ansible tutorial content.
- No full file-tree dumps or role inventories.
- Every section earns its keep against the three-part scope gate from `design.md`.
  Sections that fail the gate are removed rather than rewritten.
- The "Permissions three-layer model" section is a compact restatement, not a
  re-derivation, of #8's decision.

### Git diff hygiene

- The implementation commit touches only the new `CLAUDE.md` (and, for the spec
  itself, only the files under `specs/claude-context/`). No stray edits to
  unrelated config, roles, or settings files.

### Memory hygiene

- No new file is created under
  `~/.claude/projects/-Users-inkatze-dev-dotfiles/memory/` as part of this work.
- The existing `project_improvement_plan.md` memory entry is unchanged.

## Out of scope

- Performance, latency, or context-window measurements. CLAUDE.md is small and
  loaded once per session; no measurement is meaningful at this size.
- Verifying #8's permissions model itself. That belongs to #8's own test spec.
  This spec only verifies that the model is referenced correctly, not that it is
  correct.
