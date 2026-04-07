# Dotfiles Repo-Root CLAUDE.md Requirements

## File location and tracking

- The system shall provide a `CLAUDE.md` file at the root of the dotfiles repo
  (`/Users/inkatze/dev/dotfiles/CLAUDE.md`).
- The file shall be tracked in git.
- The file shall **not** be symlinked into `~/.claude/`. It is repo-scoped context,
  not global Claude config.
- The file shall not require any Ansible task to be run for it to take effect.
  Claude Code's built-in CLAUDE.md auto-load behavior is the only mechanism.

## Size and shape

- The file shall be no longer than 120 lines.
- The file shall be organized into short, decision-oriented sections, each answering
  "when you're about to do X, know Y."
- Sections shall be omitted rather than padded if they have nothing non-obvious to
  say.

## Scope gate

- Each fact in the file shall satisfy all three of:
  1. Non-obvious from a quick `ls` or `cat .mise.toml` in the repo root.
  2. Not already covered by global `~/.claude/CLAUDE.md`.
  3. Would change how Claude acts when working in this repo.
- Facts that fail any leg of the test shall be excluded.

## Required content

The file shall contain, at minimum, the following sections (omit any that turn out
to have nothing non-obvious to say):

- **What this repo is.** One paragraph identifying the repo as personal dotfiles,
  Ansible-managed, source of truth for `~/.claude/*`, `~/.config/fish/*`, tmux,
  mise, and similar. Explains the mental model: edits land in this repo, an Ansible
  run propagates them.
- **How Claude config is materialized.** The non-obvious fact that files under
  `roles/osx/files/claude/` are the tracked source of truth and Ansible symlinks
  them into `~/.claude/`. Editing the symlink target directly is wrong; edit the
  tracked source file. Applies equally to commands, skills, and hooks.
- **Permissions three-layer model.** A compact restatement of #8's decision:
  global `~/.claude/settings.json` (tracked via this repo) for durable cross-project
  allows plus the deny list; per-repo tracked `.claude/settings.json` for
  project-specific durable allows; per-repo `.claude/settings.local.json` for
  ephemeral, short, nukeable rules. Note that for the dotfiles repo itself, the
  tracked `.claude/settings.json` (created in #8) holds dotfiles-specific durable
  rules and the local file should stay near-empty.
- **Adding a new Claude command, skill, or hook.** The path and propagation:
  drop the file under `roles/osx/files/claude/{commands,skills,hooks}/`, commit,
  let the Ansible symlink task pick it up, verify in a fresh session. Note that
  `SKILL.md` and command front-matter are required for discovery.
- **Things to NOT edit directly in `~/.claude/`.** Anything symlinked from this
  repo. If in doubt, `readlink` the file first.
- **Ansible role layout pointer.** A single-line hint that `roles/osx/` is the Mac
  role, most Claude-related files live under `roles/osx/files/claude/`, and
  `roles/osx/tasks/` contains the symlink tasks. Deliberately not a full tree dump.

## Excluded content

The file shall **not** contain:

- Fish shell or mise usage notes (already in global CLAUDE.md).
- Conventional-commit, no-Claude-footer, GPG-signing, or explicit-remote-on-push
  rules (already in global CLAUDE.md).
- Ansible tutorial content.
- Full file-tree dumps or role inventories.
- A "Git conventions specific to this repo" section unless conventions actually
  diverge from the global rules. Omit rather than pad.

## Files modified

- No files outside the new `CLAUDE.md` (and this spec directory) shall be modified
  as part of this work. The existing global `~/.claude/CLAUDE.md` is not touched;
  there is no duplication.

## Memory system

- No new memory file shall be created as part of this work.
- The existing `project_improvement_plan.md` memory entry shall remain untouched.

## Dependency on #8

- The "Permissions three-layer model" section shall consume #8's decisions without
  duplicating their full reasoning.
- If #8's model changes during implementation, this file shall be updated to match.
