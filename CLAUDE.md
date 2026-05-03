# Dotfiles

Personal dotfiles managed by Ansible. This repo is the source of truth for
`~/.claude/` config, `~/.config/fish/`, tmux, mise, and related surfaces.
Edit files here, then run Ansible to propagate. Never edit materialized files
directly. See `specs/README.md` for planned improvements.

## How Claude config is materialized

Tracked Claude sources live under the Ansible role, not where they appear at
runtime:

| Runtime path | Tracked source | Mechanism |
|---|---|---|
| `~/.claude/CLAUDE.md` | `roles/osx/files/CLAUDE.md` | Symlink (outside `claude/` subdirectory) |
| `~/.claude/commands/*` | `roles/osx/files/claude/commands/` | Symlink |
| `~/.claude/scripts/*` | `roles/osx/files/claude/scripts/` | Symlink (hook scripts invoked from `settings.json`) |
| `~/.claude/settings.json` | `roles/osx/files/claude/settings.json` | jq merge (not symlink) |

Always edit the tracked source. The materialized file in `~/.claude/` is
overwritten on the next Ansible run. Run `readlink` on any `~/.claude/` file
before editing to confirm whether it is symlinked.

## Permissions three-layer model

| Layer | File | Scope | Persistence |
|---|---|---|---|
| Global tracked | `~/.claude/settings.json` (via this repo) | Cross-project allows + deny list | Durable, committed |
| Per-repo tracked | `<repo>/.claude/settings.json` | Project-specific durable allows | Durable, committed |
| Per-repo local | `<repo>/.claude/settings.local.json` | Ephemeral, short rules | Nukeable, gitignored |

For this dotfiles repo, the tracked `.claude/settings.json` holds
dotfiles-specific durable rules. Keep `.claude/settings.local.json`
near-empty.

## Adding a new Claude command

1. Drop the file under `roles/osx/files/claude/commands/`.
2. Include command front-matter (required for discovery).
3. Commit and run Ansible (or wait for the next symlink task run).
4. Verify in a fresh Claude session.

Hook logic lives in `roles/osx/files/claude/scripts/` and is wired from
`settings.json`. Skills are not managed by Ansible yet. Adding a new tracked
directory requires a matching symlink task in `roles/osx/tasks/osx.yml`.

## Adding a new hook

1. Write the script under `roles/osx/files/claude/scripts/` and `chmod +x` it.
2. Reference it from `roles/osx/files/claude/settings.json` under `hooks.<Event>`
   via `$HOME/.claude/scripts/<name>.sh`.
3. To remove an existing hook event, set its array to `[]` in the tracked
   `settings.json` so the jq merge overwrites the materialized entry.

### Per-repo worktree bootstrap hook

`roles/osx/files/claude/scripts/worktree-bootstrap.sh` runs on `SessionStart`.
In a git worktree it trusts mise, then kicks off lockfile-detected dep installs
in the background.
Each repo may ship an executable `.claude/worktree-bootstrap` script for
project-specific extra steps (codegen, DB setup, etc.). Marker:
`claude-bootstrap-done` inside the per-worktree gitdir (resolve with
`git rev-parse --git-dir`; in a worktree `.git` is a pointer file, so the
marker is not under `<worktree>/.git/`). Empty while running, `ok <ts>` on
success; removed on failure so the next session retries. Log:
`~/.claude/cache/worktree-bootstrap.log` (truncated when it exceeds ~256KB).
In a primary checkout (`.git` is a directory, not a pointer file) the hook
is a silent no-op by design.

**Trust caveat:** the hook runs `.claude/worktree-bootstrap` from the repo
with no sandboxing, so opening Claude in an untrusted checkout executes
whatever that script contains. Same trust model as `mise trust`: inspect the
script before opening a repo you did not author.

## MCP server registration

User-scope MCP servers live in `~/.claude.json` under `.mcpServers.<name>`.
Any server that needs a secret is registered through a sync script under
`scripts/` so the secret stays in 1Password and never lands in this repo.

`scripts/claude-mcp-sync-github.sh` reads the GitHub PAT from 1Password item
`co7bb5b6pfej3lhfni4skvonki` (tries the `token` field, then `credential`; the
LOGIN-category `password` field is deliberately not a fallback because it
resolves to the GitHub account password) and registers the GitHub Copilot
MCP server. It is idempotent: prints
`OK` when the configured `.mcpServers.github` entry already matches the
desired `type`/`url`/`Authorization`, `CHANGED` when it had to (re-)register,
and exits non-zero with a `FAILED:` message otherwise. The Ansible tasks call
it with `changed_when: 'CHANGED' in …stdout` so PAT rotations show up as a
single changed step.

The script writes `~/.claude.json` directly via `jq` (atomic temp-file +
rename) and passes the PAT through the `GITHUB_PAT` env var, scoped only to
the `jq` invocations that need it (the rest of the script, including the
`claude mcp get` sanity check, never sees it). Both choices are deliberate:
argv is visible to other processes on the box; env vars aren't, by default.
Before writing, the existing `~/.claude.json` is checked for valid JSON and
an object-typed `.mcpServers`; either is rejected with a `FAILED:` message
rather than letting a raw `jq` parse error leak through. After the rename it
runs `claude mcp get github` as a sanity check; if a previous file existed
it is restored from a backup, and on a first-time registration the
partially-written file is removed and the script exits with a "no prior
config to restore" `FAILED:` message — in either case the machine ends in
a coherent state rather than carrying a half-broken config.

It runs in two places: at the end of `homebrew.yml` (so brew has already
installed `1password-cli` on a fresh machine) and at the end of `upgrade.yml`
(so `mise run upgrade` picks up rotated PATs). Both invocations are guarded
with `when: lookup('ansible.builtin.env', 'CI', default='') == ''` so the CI
matrix (which has neither an unlocked 1Password session nor `op` installed)
skips them. Both also assume an authenticated `op` session at run time on a
non-CI machine: `mise run install` or `mise run upgrade` will exit with
`FAILED: could not read GitHub PAT …` if 1Password is locked, so sign in via
`op signin` (or unlock the desktop app with the CLI integration enabled)
before running either. The strict-fail behavior is deliberate: a silent
skip on a locked vault would let stale PATs land unnoticed. To add another
secret-bearing MCP server, follow the same pattern: new script under
`scripts/`, new task in both files, same CI guard.

## Do not edit directly in `~/.claude/`

Any file symlinked from this repo is overwritten on the next Ansible run.
Always `readlink` first. Edit the tracked source instead.

## Ansible role layout

`roles/osx/` is the Mac role. Claude-related files live under
`roles/osx/files/claude/`; symlink tasks are in `roles/osx/tasks/`.
