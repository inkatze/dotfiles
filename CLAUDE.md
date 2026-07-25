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
In a git worktree it trusts mise, then kicks off lockfile+project-file-detected
dep installs in the background (both a lockfile and its matching project file
must sit at the worktree root; a stray root-level lockfile in a monorepo will
not trigger an install).
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

The SessionStart `tool-discovery` hook is supplied by the planwright plugin,
not this repo. planwright installs as a Claude Code plugin (marketplace flow,
see the planwright install task in `roles/osx/tasks/osx.yml`), and the plugin
wires its own hooks via its `hooks/hooks.json` resolved against
`CLAUDE_PLUGIN_ROOT`: `tool-discovery` on SessionStart and `tasks-pr-sync` on
PostToolUse(Bash). The tracked `settings.json` therefore no longer wires
either; doing so would double-fire them. The hook runs alongside the worktree
bootstrap, scans the cwd for known config files (linters, formatters, type
checkers, hook managers, CI workflows), and emits a markdown summary as
`additionalContext` so the agent sees what the project ships without grepping.
Silent no-op (exit 0, no output) when any of: nothing is detected, the cwd is
outside a git work tree, or `jq` is unavailable; a missing summary therefore
does not necessarily mean "no tooling found". Discovery feeds the `Discovery
Rigor` and `Refactor Instinct` rules in the user-global `CLAUDE.md`, both of
which prefer tool-grounded findings over judgment. Behavior and extension live
in the planwright repo; this repo only installs the plugin.

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

| Host | Ollama daemon | Client env (set in `roles/fish/files/ollama.fish`) |
|---|---|---|
| `work` | Served, bound to `0.0.0.0:11434` via `OLLAMA_HOST` in `~/Library/LaunchAgents/homebrew.mxcl.ollama.plist` | unset (the `ollama` CLI and HTTP consumers fall back to `localhost:11434`) |
| `personal`, `alt` | Not managed by Ansible | `OLLAMA_HOST=192.168.1.20:11434` (for the `ollama` CLI) and `OLLAMA_BASE_URL=http://192.168.1.20:11434` (for HTTP consumers like `/panel-*` skills) |

`ollama.fish` decides which box it is on by resolving the same inventory
alias `scripts/playbook.sh` does — the `DOTFILES_HOST` env var, else the
untracked `~/.config/dotfiles/host` file, plus the residual `alt` hostname
pattern that script still carries. Any alias other than `work` is a client.
An **unresolved** alias sets neither variable, so the host falls back to
`localhost:11434`: correct on `work`, and on an unconfigured client a
visible connection-refused rather than a silent call to a LAN address.
`personal` therefore now needs its alias file (or `DOTFILES_HOST=personal`)
to get Ollama routing — it used to be matched by hostname.

The migrated Linux host (`server`, `specs/linux-migration`) joins this
topology as a **client**, same posture as `personal`/`alt`: `work` stays
the sole daemon, and `server` routes to it over the LAN. The `linux` role
does not manage an Ollama daemon (Ollama is not in the Linux baseline).
`server` picks up its client env from the alias resolution above, since it
already writes `~/.config/dotfiles/host` for `scripts/playbook.sh` — by
declaration now, rather than by the accident of reusing the old Mac's
hostname.

The work host's IP is a DHCP reservation at `192.168.1.20`. Updates:

- Change the IP: edit `roles/fish/files/ollama.fish`.
- Move daemon to a different host: flip the `inventory_hostname == 'work'`
  guards in `roles/osx/tasks/homebrew.yml` and change which alias the fish
  snippet treats as the daemon host (it compares against `work`).

`OLLAMA_HOST=0.0.0.0:11434` is persisted by injecting it into the brew-
generated LaunchAgent plist with `PlistBuddy` (additive: existing tuning
keys like `OLLAMA_FLASH_ATTENTION` are preserved). Ansible also runs
`launchctl setenv` to apply the change to the current launchd session
without waiting for a reboot, then reloads the LaunchAgent via
`launchctl bootout` + `launchctl bootstrap` when the plist changed.
**Do not use `brew services restart ollama` for this**: that command
regenerates the plist from the formula's `service` block on every
invocation, wiping any keys not baked into the formula
(`OLLAMA_FLASH_ATTENTION` and `OLLAMA_KV_CACHE_TYPE` survive because the
formula defines them; `OLLAMA_HOST` does not). Same hazard applies to
`brew upgrade ollama`. Either way, re-run `mise run osx` to re-add the
key.

**Trust caveat:** Ollama has no auth. Binding to `0.0.0.0` exposes the
daemon to everything on the LAN. Fine on a trusted home network; on
untrusted networks, stop the service (`brew services stop ollama`) or
revert the LaunchAgent edit, and SSH-tunnel from clients instead
(`ssh -L 11434:localhost:11434 <work-host>` plus
`OLLAMA_HOST=localhost:11434` and
`OLLAMA_BASE_URL=http://localhost:11434` on the client).

## Ansible role layout

The repo is split by platform via `os_family` guards in `main.yml`:

| Role | Guard | Covers |
|---|---|---|
| `roles/osx/` | `ansible_os_family == "Darwin"` | Homebrew, macOS defaults, Claude/Cursor config, MCP + Ollama plumbing |
| `roles/linux/` | `ansible_os_family == "Debian"` | apt baseline (fish, tmux, core CLI, `openssh-server`), mise, sshd hardening drop-in, Tailscale, 1Password CLI (`op`) |

Only one platform baseline runs on a given host; the other role is skipped
whole by its `when:` guard, so adding `roles/linux/` left the Mac hosts'
runs unchanged. The remaining roles (`kitty`, `fish`, `services`,
`environments`, `neovim`, `tmux`, `ssh`, `git`) are cross-platform config
and run on every host; driving their first Linux run clean is the
`specs/linux-migration` Task 7 stabilization loop, not the platform split
itself.

Claude-related files live under `roles/osx/files/claude/`; symlink tasks
are in `roles/osx/tasks/`. The `linux` role's sshd hardening lives at
`roles/linux/files/sshd/60-hardening.conf` (a role-owned `sshd_config.d/`
drop-in, REQ-E1.1: key-only auth, no root login).

**Inventory and host aliases.** `hosts` lists `work`, `personal`, `alt`
(macOS) and `server` (the migrated Linux host); all run the playbook
locally (`ansible_connection=local`), so no LAN IP or real hostname is
committed (REQ-F1.1). `scripts/playbook.sh` maps the running machine to an
alias through a machine-local indirection — the `DOTFILES_HOST` env var, or
an untracked `~/.config/dotfiles/host` file naming the alias — so no real
hostname is committed. `work` stays the fallback when nothing resolves (CI
depends on it), but the fallback now warns on stderr so a machine that
should have declared itself does not silently install another host's
profile. One residual hostname pattern remains for `alt`; `personal` was
matched that way until the REQ-F1.1 cleanup and must now name itself.

### Machine-local files under `~/.config/dotfiles/`

| File | Read by | Holds |
|---|---|---|
| `host` | `scripts/playbook.sh`, `roles/fish/files/ollama.fish` | This machine's inventory alias (`work`/`personal`/`alt`/`server`) |
| `ssh-host` | the `sshc` function in `roles/fish/files/fish/config.fish` | `kitten ssh` target hostname |
| `kitty-ssh.conf` | `roles/kitty/files/kitty/ssh.conf` (via `globinclude`) | Host-specific kitty `ssh.conf` sections |
| `op-service-account-token` | `scripts/ssh-lan-config-sync.sh` | 1Password service-account token (bearer credential, mode 0600) |

None are created by Ansible and none live in the repo (`~/.config/kitty` is
a symlink into it, which is why the kitty companion sits here instead).
Each is optional; absence degrades visibly rather than silently.

`op-service-account-token` is the only one that is a *secret*. It exists
because the 1Password desktop-app integration authorizes per calling process
and re-prompts for each new one — fine in a long-lived terminal, useless under
Ansible (a fresh process per task), and impossible during a headless boot where
no desktop app is running to approve anything. A service-account token
authenticates non-interactively instead.

Two consequences worth knowing before moving items around:

- **Service accounts cannot access the Personal or Private vault.** 1Password
  refuses the grant outright, which is why `dotfiles-lan-ssh` lives in the
  `Dotfiles Service Account` vault rather than `Private`, and why that is the
  script's default vault.
- The script refuses to read the file unless it is mode 0600 or 0400, and an
  already-exported `OP_SERVICE_ACCOUNT_TOKEN` takes precedence, so CI can
  supply one without the file existing.

To rotate: `op service-account create <name> --vault 'Dotfiles Service
Account':read_items`, write the returned token to the file with `umask 077`,
and never let it reach a terminal — it is printed exactly once.
