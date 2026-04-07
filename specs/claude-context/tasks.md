# Dotfiles Repo-Root CLAUDE.md Implementation Status

## Task order

Tasks are ordered by dependency.

### 1. Draft `CLAUDE.md` at the dotfiles repo root

Create `/Users/inkatze/dev/dotfiles/CLAUDE.md`, tracked in git, not symlinked.
Target 60–120 lines. Sections, in order:

1. **What this repo is** — one paragraph: personal dotfiles, Ansible-managed,
   source of truth for `~/.claude/*`, `~/.config/fish/*`, tmux, mise. Mental model:
   edits land here, Ansible run propagates.
2. **How Claude config is materialized** — files under
   `roles/osx/files/claude/` are the tracked source of truth; Ansible symlinks them
   into `~/.claude/`. Edit the tracked source, not the symlink target.
3. **Permissions three-layer model** — compact restatement of #8's resolved model
   (global tracked, per-repo tracked, per-repo local). Note that the dotfiles
   `.claude/settings.json` (tracked, created in #8) holds dotfiles-specific durable
   rules; `.claude/settings.local.json` should stay near-empty.
4. **Adding a new Claude command / skill / hook** — drop the file under
   `roles/osx/files/claude/{commands,skills,hooks}/`, commit, run Ansible (or
   let the symlink task pick it up on its next run), verify in a fresh session.
   Front-matter / `SKILL.md` required for discovery.
5. **Things to NOT edit directly in `~/.claude/`** — anything symlinked from this
   repo. If in doubt, `readlink` first.
6. **Ansible role layout pointer** — one line: `roles/osx/` is the Mac role; most
   Claude-related files live under `roles/osx/files/claude/` and `roles/osx/tasks/`
   has the symlink tasks. Not a full tree dump.
7. **Git conventions specific to this repo** — only if any actually differ from
   global. Likely none, in which case omit the section rather than pad.

Apply the three-part scope gate (see `design.md`) to every line. Soft dependency:
#8 must be planned (not necessarily shipped). Already satisfied — #8 is in Wave A.

### 2. Verify in a fresh Claude session

See `test-spec.md` for the verification checklist. No code or config changes; this
task gates the commit on a manual fresh-session smoke test.

### 3. Commit on a feature branch

Conventional-commit message, no Claude footer, no co-author trailer, GPG signed,
explicit remote on push. Example: `docs(claude): add repo-root CLAUDE.md`. Do not
push or open a PR as part of the spec work; that happens when the implementation
task lands.

## Effort

**XS–S** — ~30 minutes total to draft, verify, and commit. Most of the effort is
restraint: resisting the urge to dump structure that Claude can derive on its own.

## Rollback

`git rm CLAUDE.md` in the dotfiles repo. No other surfaces are touched.
