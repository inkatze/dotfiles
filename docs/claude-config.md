# Claude config: output style, status line, settings merge

Rationale behind the "How Claude config is materialized" and "Permissions"
rules in the repo-root `CLAUDE.md`.

## The `compact` output style

Claude Code ships `Default`, `Proactive`, `Explanatory` and `Learning`;
`outputStyle: compact` in the tracked `settings.json` resolves against
`roles/claude/files/output-styles/compact.md` and silently falls back to the
default if that symlink is missing.

The file sets `keep-coding-instructions: true`, which is load-bearing: a
custom style *replaces* Claude Code's built-in software engineering
instructions unless that field is set, so dropping it would trade verbosity
for every default about scoping changes, writing comments, and verifying work.

Output style is part of the system prompt and is read once per session, so a
change needs `/clear` or a new session. Picking a style through `/config`
writes `outputStyle` to the project-level `.claude/settings.local.json`,
which wins over this repo's global value for that project.

## The status line

`statusLine` runs `roles/claude/files/scripts/statusline.sh`, which prints the
directory, git branch, model and context usage on its own row. It supplements
Claude Code's own "context left until auto-compact" warning, which cannot be
moved or turned off from here. The line stays blank in a folder whose trust
dialog has not been accepted, and when `disableAllHooks` is true.

A hook is removed by declaring its event as `[]` in the tracked file;
`statusLine` has no such handle, since the merge treats it as an ordinary key
that it only adds or overwrites and never removes. Dropping the key from the
tracked file leaves it live on every host, so removing the status line means
editing each live `~/.claude/settings.json`.

## The settings merge is a one-way mirror

`scripts/claude-settings-merge.sh` asserts the keys this repo declares and
leaves everything else alone, so Claude Code keeps ownership of what it writes
itself (theme, onboarding state, per-project trust). Its header documents the
hook-array semantics.

The cost is that a key set by hand on one machine, or persisted there by the
app when you toggle something, works on that machine and is invisible to
every other one. Nothing reports the difference. `permissions.defaultMode`
was exactly that for months: set on the Macs, absent from this repo, so the
Linux host never got it. The repo's own observations log recorded behaviour
caused by it without anyone noticing it was undeclared. Moving the Claude role
cross-platform did not fix this, because that only propagates keys the repo
already carries.

## Permission layers

| Layer | File | Scope | Persistence |
|---|---|---|---|
| Global tracked | `~/.claude/settings.json` (via this repo) | Cross-project allows + deny list | Durable, committed |
| Per-repo tracked | `<repo>/.claude/settings.json` | Project-specific durable allows | Durable, committed |
| Per-repo local | `<repo>/.claude/settings.local.json` | Ephemeral, short rules | Nukeable, gitignored |

This repo gitignores `.claude/` wholesale, so it has no per-repo tracked
layer: its durable rules belong in the global tracked file.
