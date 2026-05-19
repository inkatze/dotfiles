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

### Tool-discovery hook

`roles/osx/files/claude/scripts/tool-discovery.sh` runs on `SessionStart`
alongside the worktree bootstrap. It scans the cwd for known config files
(linters, formatters, type checkers, hook managers, CI workflows) and emits
a markdown summary as `additionalContext`, so the agent sees what the project
ships without grepping. Silent no-op (exit 0, no output) when any of: nothing
is detected, the cwd is outside a git work tree, or `jq` is unavailable; a
missing summary therefore does not necessarily mean "no tooling found".
Read-only, runs ~30 file-existence checks plus a handful of `grep -q` probes;
no caching, no side effects. Discovery feeds
the `Discovery Rigor` and `Refactor Instinct` rules in the user-global
`CLAUDE.md`, both of which prefer tool-grounded findings over judgment.
To extend: add another `[ -f ... ] && add "<tool> (\`<command>\`)"` block
in the script.

## MCP server registration

User-scope MCP servers live in `~/.claude.json` under `.mcpServers.<name>`.
Any server that needs a secret is registered through a sync script under
`scripts/` so the secret stays in 1Password and never lands in this repo.

`scripts/claude-mcp-sync-github.sh` reads the GitHub PAT from 1Password
item `co7bb5b6pfej3lhfni4skvonki` (tries `token` then `credential`; the
LOGIN-category `password` field is intentionally skipped because it
resolves to the account password). Idempotent: `OK` when the configured
entry matches the desired `type`/`url`/`Authorization` AND `claude mcp
get` confirms it is loadable, `CHANGED` on (re-)register, non-zero with
a `FAILED:` line on any precondition failure. Ansible gates
`changed_when` on `CHANGED` so PAT rotations surface as a single
changed step.

Writes happen via `jq` (atomic temp + rename) with `GITHUB_PAT` scoped only
to the two jq invocations that need it. Argv is world-readable via `ps -A
-o args=`; env vars are not in argv, but same-user processes can still
inspect them (`/proc/<pid>/environ` on Linux, `ps eww <pid>` on macOS), so
the per-jq scoping shrinks the same-user window to those two jq calls.
Pre-validation rejects unreadable, malformed, non-object, symlinked, or
non-regular paths with `FAILED:` rather than leaking raw `jq` errors. The
post-rename `claude mcp get` sanity check restores the backup on failure
when a previous file existed; first-time registrations have nothing to
roll back to, so the partial write is removed and the script exits with
a "no prior config to restore" `FAILED:` message.

It runs from `homebrew.yml` (under `mise run install` (`--skip-tags
shell,upgrade`) and `mise run osx` (`-t osx`); both reach `homebrew.yml`
because it carries the `osx` tag) and `upgrade.yml` (under `mise run
upgrade`). Both invocations are guarded with
`when: lookup('ansible.builtin.env', 'CI', default='') == ''` so the CI
matrix skips them. Both also assume an authenticated `op` session on
non-CI machines — sign in via `op signin` (or unlock the desktop app
with the CLI integration enabled) before running, otherwise the script
exits `FAILED: could not read GitHub PAT …`. The strict-fail on a
locked vault is deliberate: a silent skip would let stale PATs land
unnoticed. To add another secret-bearing MCP server, mirror this
layout: new script under `scripts/`, new task in both files, same CI
guard.

## Cross-host Ollama topology

The `/panel-*` skills hit Ollama over HTTP. Only the `work` inventory host
runs the daemon and pulls the 32B models; `personal` and `alt` are clients
that route to it over the LAN.

| Host | Ollama daemon | OLLAMA_BASE_URL |
|---|---|---|
| `work` | Served, bound to `0.0.0.0:11434` via `OLLAMA_HOST` in `~/Library/LaunchAgents/homebrew.mxcl.ollama.plist` | unset (clients fall back to `http://localhost:11434`) |
| `personal`, `alt` | Not managed by Ansible | `http://192.168.1.20:11434` (set in `roles/fish/files/fish/conf.d/ollama.fish`) |

The work host's IP is a DHCP reservation at `192.168.1.20`. Updates:

- Change the IP: edit `roles/fish/files/fish/conf.d/ollama.fish`.
- Move daemon to a different host: flip the `inventory_hostname == 'work'`
  guards in `roles/osx/tasks/homebrew.yml` and adjust the fish snippet's
  hostname patterns (which mirror `scripts/playbook.sh`).

`OLLAMA_HOST=0.0.0.0:11434` is persisted by injecting it into the brew-
generated LaunchAgent plist with `PlistBuddy` (additive: existing tuning
keys like `OLLAMA_FLASH_ATTENTION` are preserved). Ansible also runs
`launchctl setenv` to apply the change to the current launchd session
without waiting for a reboot, then `brew services restart ollama` when the
plist changed. After `brew upgrade ollama` Homebrew may regenerate the
plist; re-running `mise run osx` re-adds the key.

**Trust caveat:** Ollama has no auth. Binding to `0.0.0.0` exposes the
daemon to everything on the LAN. Fine on a trusted home network; on
untrusted networks, stop the service (`brew services stop ollama`) or
revert the LaunchAgent edit, and SSH-tunnel from clients instead
(`ssh -L 11434:localhost:11434 <work-host>` plus `OLLAMA_BASE_URL=
http://localhost:11434` on the client).

## Ansible role layout

`roles/osx/` is the Mac role. Claude-related files live under
`roles/osx/files/claude/`; symlink tasks are in `roles/osx/tasks/`.
