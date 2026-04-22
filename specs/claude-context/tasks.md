# Dotfiles Repo-Root CLAUDE.md Implementation Status

## Task order

Tasks are ordered by dependency.

### 1. Draft `CLAUDE.md` at the dotfiles repo root

Create `CLAUDE.md` at the dotfiles repo root, tracked in git, not symlinked.
Target 120 lines (hard ceiling 200). Sections, in order:

1. **What this repo is** — one paragraph: personal dotfiles, Ansible-managed,
   source of truth for the managed parts of `~/.claude/` (`~/.claude/CLAUDE.md`,
   `settings.json`, `commands/`), `~/.config/fish/*`, tmux, mise. Mental model:
   edits land here, Ansible run propagates.
2. **How Claude config is materialized** — tracked Claude sources live in the
   Ansible role: `roles/osx/files/claude/commands/` is symlinked into
   `~/.claude/commands/`, `~/.claude/CLAUDE.md` is symlinked from
   `roles/osx/files/CLAUDE.md` (outside the `claude/` directory), and
   `settings.json` is produced by a jq merge/write task rather than symlinked.
   Edit the tracked source, not the materialized file in `~/.claude/`.
3. **Permissions three-layer model** — compact restatement of #8's resolved model
   (global tracked, per-repo tracked, per-repo local). Note that the dotfiles
   `.claude/settings.json` (tracked, created in #8) holds dotfiles-specific durable
   rules; `.claude/settings.local.json` should stay near-empty.
4. **Adding a new Claude command** — drop the file under
   `roles/osx/files/claude/commands/`, commit, run Ansible (or let the symlink
   task pick it up on its next run), verify in a fresh session. Command
   front-matter required for discovery. Hook scripts live under
   `roles/osx/files/claude/scripts/` and are symlinked by a matching task in
   `roles/osx/tasks/osx.yml`; they are wired from `settings.json`. Skills are
   not yet managed by Ansible; adding them would require a new tracked
   directory plus a matching symlink task and is out of scope here.
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

See `test-spec.md` for the verification checklist. Using the `CLAUDE.md` drafted in
step 1, make no additional code or config changes during this step; it gates the
commit on a manual fresh-session smoke test before committing.

### 3. Commit on a feature branch

Conventional-commit message, no Claude footer, no co-author trailer, GPG signed.
Example: `docs(claude): add repo-root CLAUDE.md`. For this task, make the commit
locally on your feature branch only. The push and PR for the implementation work
happen later, as part of that implementation workflow, not as part of this task
(this restriction is about the implementation step itself, not about the spec PR
that introduces these documents).

## Effort

**XS–S** — ~30 minutes total to draft, verify, and commit. Most of the effort is
restraint: resisting the urge to dump structure that Claude can derive on its own.

## Rollback

`git rm CLAUDE.md` in the dotfiles repo. No other surfaces are touched.

