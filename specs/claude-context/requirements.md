# Dotfiles Repo-Root CLAUDE.md Requirements

**Status:** Ready
**Cold-start next step:** Implement the plan: write `CLAUDE.md` at the dotfiles repo root per the Required Content section of this file. See `tasks.md` for the ordered task list.
**Last reviewed:** 2026-04-09

## File location and tracking

- The system shall provide a `CLAUDE.md` file at the root of the dotfiles repo.
- The file shall be tracked in git.
- The file shall **not** be symlinked into `~/.claude/`. It is repo-scoped context,
  not global Claude config.
- The file shall not require any Ansible task to be run for it to take effect.
  Claude Code's built-in CLAUDE.md auto-load behavior is the only mechanism.

## Size and shape

- The file shall target 120 lines and shall not exceed 200 lines. Research
  shows CLAUDE.md files under 200 lines achieve 92% rule-application rate,
  dropping to 71% above 400 lines (practitioner analysis, 2025). 120 is the
  budget; 200 is the hard ceiling.
- The file shall be organized into short, decision-oriented sections, each answering
  "when you're about to do X, know Y."
- Sections shall be omitted rather than padded if they have nothing non-obvious to
  say.
- Rules in the produced `CLAUDE.md` shall use imperative voice (`Always X`,
  `Never Y`, `Do Z`), not descriptive phrasing (`We prefer`, `Consider`,
  `Try to`). Research: imperative rules achieve 94% compliance; descriptive
  phrasing drops to 73% (practitioner analysis, 2025).

## Scope gate

- Each fact in the file shall satisfy all three of:
  1. Non-obvious from a quick `ls` or `cat mise.toml` in the repo root.
  2. Not already covered by global `~/.claude/CLAUDE.md`.
  3. Would change how Claude acts when working in this repo.
- Facts that fail any leg of the test shall be excluded.

## Required content

The file should include the following sections when they satisfy the scope gate and
have something non-obvious to say; sections that do not may be omitted:

- **What this repo is.** One paragraph identifying the repo as personal dotfiles,
  Ansible-managed, source of truth for the managed parts of `~/.claude/`,
  `~/.config/fish/*`, tmux, mise, and similar. Explains the mental model: edits
  land in this repo, an Ansible run propagates them.
- **How Claude config is materialized.** The non-obvious fact that the tracked
  Claude sources live in the Ansible role and are materialized by different
  mechanisms: `roles/osx/files/claude/commands/` is symlinked into
  `~/.claude/commands/`, `~/.claude/CLAUDE.md` is symlinked from
  `roles/osx/files/CLAUDE.md` (note: outside the `claude/` directory), and
  `roles/osx/files/claude/settings.json` is merged into `~/.claude/settings.json`
  by a jq-based task rather than symlinked. Editing the materialized file
  directly is wrong; edit the tracked source. Adding new surfaces (skills, hooks)
  requires creating the tracked directory and matching management in
  `roles/osx/tasks/osx.yml`.
- **Permissions three-layer model.** A compact restatement of #8's decision:
  global `~/.claude/settings.json` (tracked via this repo) for durable cross-project
  allows plus the deny list; per-repo tracked `.claude/settings.json` for
  project-specific durable allows; per-repo `.claude/settings.local.json` for
  ephemeral, short, nukeable rules. Note that for the dotfiles repo itself, the
  tracked `.claude/settings.json` (created in #8) holds dotfiles-specific durable
  rules and the local file should stay near-empty.
- **Adding a new Claude command.** The path and propagation: drop the file under
  `roles/osx/files/claude/commands/`, commit, let the Ansible symlink task pick
  it up, verify in a fresh session. Command front-matter is required for
  discovery. Hook scripts are now managed under `roles/osx/files/claude/scripts/`
  with a matching symlink task and are wired from `settings.json`. Skills are
  still out of scope for this section and would require a new tracked directory
  plus symlink task.
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
