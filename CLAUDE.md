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
| `~/.claude/CLAUDE.md` | `roles/claude/files/CLAUDE.md` | Symlink |
| `~/.claude/commands/*` | `roles/claude/files/commands/` | Symlink |
| `~/.claude/scripts/*` | `roles/claude/files/scripts/` | Symlink (hook scripts invoked from `settings.json`) |
| `~/.claude/settings.json` | `roles/claude/files/settings.json` | jq merge (not symlink) |

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

The default permission mode is part of the global tracked layer:
`permissions.defaultMode` in `roles/claude/files/settings.json`.

**The jq merge is a one-way mirror, and that hides drift.** It asserts the
keys this repo declares and deliberately leaves everything else alone, so
Claude Code keeps ownership of what it writes itself (theme, onboarding
state, per-project trust). The cost is that a key set by hand on one
machine, or persisted there by the app when you toggle something, works
perfectly on that machine and is invisible to every other one. Nothing
reports the difference.

`defaultMode` was exactly that for months: set on the Macs, absent from
this repo, so the Linux host never got it. The repo's own observations log
even recorded behaviour caused by it
(`specs/_observations/entries/2026-07-22-fleet-guard-seam-cb14c90f.md`
refers to "user settings pin defaultMode auto") without anyone noticing it
was undeclared. Moving the Claude role cross-platform did not fix this,
because that only propagates keys the repo already carries.

So when a Claude Code behaviour is meant to be shared, declare it here
rather than setting it in the app. To audit: diff `~/.claude/settings.json`
on a Mac against `roles/claude/files/settings.json` and look for keys the
repo does not mention.

## Adding a new Claude command

1. Drop the file under `roles/claude/files/commands/`.
2. Include command front-matter (required for discovery).
3. Commit and run Ansible (or wait for the next symlink task run).
4. Verify in a fresh Claude session.

Hook logic lives in `roles/claude/files/scripts/` and is wired from
`settings.json`. Skills are not managed by Ansible yet. Adding a new tracked
directory requires a matching symlink task in `roles/claude/tasks/main.yml`.

## Adding a new hook

1. Write the script under `roles/claude/files/scripts/` and `chmod +x` it.
2. Reference it from `roles/claude/files/settings.json` under `hooks.<Event>`
   via `$HOME/.claude/scripts/<name>.sh`.
3. To remove an existing hook event, set its array to `[]` in the tracked
   `settings.json` so the jq merge overwrites the materialized entry.

### Per-repo worktree bootstrap hook

`roles/claude/files/scripts/worktree-bootstrap.sh` runs on `SessionStart`.
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
see the planwright install task in `roles/claude/tasks/main.yml`), and the plugin
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

### Slack: a deliberate manual prerequisite

The `/code-review` and `/peer-review` commands DM the person on the other
end of a PR through a Slack MCP server. **Nothing in this repo provisions
it.** There is no sync script, no Ansible task, and no `mcpServers.slack`
entry; a fresh machine has the commands but not the transport.

That is a choice, not an oversight. The notification is a courtesy the
commands are explicitly built to do without: the shared `Slack
Notifications (review workflows)` rule in the user-global `CLAUDE.md`
says a missing server means "say so once in the terminal and carry on",
so the review, which is the actual deliverable, is unaffected. Automating
a registration for a server used by two commands on one machine buys
little and adds another 1Password item and CI-guarded task pair to keep
working.

Register it by hand when you want it, on the machine that wants it. If
that ever becomes more than one machine, promote it: mirror the layout
above rather than copying the registration around.

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

## Review backends: codex vs gemini

`/panel-review` and `/code-review` run their discovery pass through a
non-Anthropic CLI. The machine picks the *default*; a run can still override it
(`--backends` on either command, `PANEL_REVIEW_PROFILE` for the profile
itself). `/panel-review` also accepts `qwen-coder`, `gpt-oss` and `copilot`
via `--backends`; only the two below are ever chosen automatically.

| Alias | Backend | CLI comes from | Key comes from |
|---|---|---|---|
| `work` | `codex` | `Brewfile` (`cask "codex"`) | `codex login`, interactive |
| `personal`, `alt` | `gemini` | `Brewfile` (`brew "gemini-cli"`) | `scripts/claude-gemini-auth-sync.sh` |
| `server` | `gemini` | mise, pinned in `roles/linux/files/mise/linux.toml` | same script, service-account path |

**The profile is the inventory alias**, resolved in `scripts/playbook.sh`'s
order: `DOTFILES_HOST`, else `~/.config/dotfiles/host` (honouring
`DOTFILES_HOST_FILE`), else the residual `alt` hostname match, else `work`.
`PANEL_REVIEW_PROFILE` is honoured ahead of all of it as a per-run override.

The commands are deliberately one notch stricter than `playbook.sh`: they take
the alias file only when it has non-whitespace content. `playbook.sh` still
tests mere existence, so a `touch`ed alias file there yields an empty
`ansible-playbook -l ""`, which Ansible reads as *no limit* and runs every
inventory host against this machine. Worth fixing there too; it is left alone
here only because this change has no business editing the playbook entrypoint.

Three of those clauses are easy to drop, and the first cut of this change
dropped all three. Without the `alt` hostname branch, an `alt` Mac (which
legitimately has no alias file, see the machine-local files section below)
resolves to `work` and reaches for codex, which it never logs into. Without the
non-whitespace test, a `touch`ed alias file yields an empty profile, which is
not `work` and therefore selects gemini on the work host — the very bug this
change exists to fix, re-entered through a different door. And without
`DOTFILES_HOST_FILE`, a host that relocates its alias file has `playbook.sh`
and the review commands disagreeing about which machine it is.

It used to be *only* that env var, defaulting to `personal`, and the default
was a live bug rather than a latent one: nothing in this repo ever sets
`PANEL_REVIEW_PROFILE`, so the work Mac resolved to `personal` and reached for
gemini on every review, which is the exact opposite of the table. Keying on
the alias the rest of the repo already uses means the work host is right with
nothing to remember, and a new host is wrong only if it has not declared
itself, which is the same failure every other alias consumer has.

The one deliberate divergence from `ollama.fish` is the fallback direction.
There an unresolved alias must set nothing, so an unconfigured client gets a
visible connection-refused instead of silently talking to a LAN address. Here
it means `work`, matching `playbook.sh`, because `work` is the host that does
not write an alias file.

**On Linux the CLI comes from mise**, because apt has no gemini package and
mise's registry offers exactly one backend for it (`npm:@google/gemini-cli`).
It is pinned in `linux.toml` and installed from `linux_mise_tools` like every
other entry there.

The npm backend looks like it should need a node the `linux` role installs
nothing of, since `roles/environments` owns the node pin and runs later. It
does not: with a throwaway `MISE_DATA_DIR` and node both uninstalled and absent
from PATH, `mise install npm:<pkg>` still succeeds, because mise bootstraps a
node for the backend rather than borrowing the host's. Worth recording because
the first cut of this change split the pin from its install across two roles to
route around an ordering problem that measurement showed does not exist.

The key sync is cross-platform and lives in `roles/claude`, not in either
platform role. It was in the Darwin-guarded `roles/osx` until this change,
which is why the Linux host had fish `conf.d/gemini.fish` exporting
`GEMINI_API_KEY` from a file nothing ever wrote. It carries `osx` *and* `linux`
tags, so both `mise run osx` and `mise run linux` sync the key on their
respective hosts. Those tags are the only place in the repo where a platform
tag names tasks outside its platform role, which is a wart: on a Mac,
`mise run linux` will now run the four Claude tasks that carry them (behind its
sudo prompt), and on the Linux host `mise run osx` will run them too. Both are
harmless, and the alternative is a `mise run claude` task that does not exist
yet.

Because that role is unguarded, the sync is preceded by an `op --version`
probe, the same split `roles/ssh` uses: a host without the 1Password CLI is
skipped with a notice, while a host that has `op` and still fails is a real
error. Without the probe, a not-yet-provisioned host aborts the last role in
`main.yml` partway through, taking the planwright plugin install with it.

**On a headless host the key comes from the service account, and that
constrains the vault.** There is no 1Password desktop app to authorize
against, so `claude-gemini-auth-sync.sh` falls back to
`~/.config/dotfiles/op-service-account-token` the same way
`ssh-lan-config-sync.sh` does. A service account cannot be granted the
Personal or Private vault, so the key item has to live in
`Dotfiles Service Account`, and it must be addressed with an explicit
`--vault`: without one, `op` refuses every field with "a vault query must be
provided when this command is called by a service account", which reads like a
missing item and is not. Moving the item between vaults also reassigns its
id, so `ITEM_UUID` in that script is the id *in that vault*, not the one it
had in Private.

**Gemini CLI needs `--skip-trust` for any headless run** (measured on
gemini-cli 0.54.4). Without it the CLI downgrades `--approval-mode plan` to
`default` and *then* aborts with "not running in a trusted directory". Keep
`--approval-mode plan` on every invocation: it is what holds the run read-only,
and the downgrade-before-abort ordering means a future version that stops
aborting would otherwise run with that guard already stripped.

What `--skip-trust` costs is worth stating precisely rather than either
hand-waving or overstating it, because both commands run the CLI inside a
working tree and `/code-review` runs it inside *someone else's* checked-out PR.
Folder trust is what gates the CLI loading project-supplied configuration from
the current directory. A direct test on 0.54.4 (a `.gemini/settings.json`
declaring an MCP server whose command writes a marker file, run under
`--skip-trust --approval-mode plan`) did **not** execute it, so this is not the
drive-by code execution it might look like. It is still a gate being switched
off over untrusted content, so both commands now **require** the CLI to be run
from a freshly `mktemp -d`'d empty directory, in a subshell, with the diff and
tooling output going in on stdin. Not `/tmp` itself, which is world-writable
and therefore pre-seedable with a `GEMINI.md`; and a subshell because this
shell keeps its cwd between tool calls. From an empty directory the trust gate
has nothing to act on. It does not cover user-level `~/.gemini/` config, which
loads regardless of cwd.

## Ansible role layout

The repo is split by platform via `os_family` guards in `main.yml`:

| Role | Guard | Covers |
|---|---|---|
| `roles/osx/` | `ansible_os_family == "Darwin"` | Homebrew, macOS defaults, MCP + Ollama plumbing |
| `roles/linux/` | `ansible_os_family == "Debian"` | apt baseline (fish, tmux, core CLI, `openssh-server`), mise, sshd hardening drop-in, Tailscale, 1Password CLI (`op`) |

Only one platform baseline runs on a given host; the other role is skipped
whole by its `when:` guard, so adding `roles/linux/` left the Mac hosts'
runs unchanged. The remaining roles (`kitty`, `fish`, `environments`,
`neovim`, `tmux`, `ssh`, `git`, `claude`) are cross-platform config
and run on every host; driving their first Linux run clean is the
`specs/linux-migration` Task 7 stabilization loop, not the platform split
itself.

`roles/services/` is the exception to those. It runs on every host and
carries no `when:` in `main.yml`, but it is not the same role on both
platforms: its two task files guard themselves. On Debian it provisions the
declared dev-services layer (`specs/dev-services`); on Darwin it applies the
role's older macOS-only content (the `~/.my.cnf` symlink, plus the colima
steps on the `personal` host, which carry their own `inventory_hostname`
guard) and provisions none of the declared services. The declaration is
`roles/services/defaults/main.yml`, one entry per service carrying the
package, the systemd unit, and the address and port the lifecycle verifies it
on. Install, enable, start and verify are driven from that list and name no
service, so adding one is an entry there rather than an edit to a task file.
A service needing more than that shared lifecycle names its own setup file in
a `setup:` field, which is the only route into it; PostgreSQL's database role
for the invoking account is today's only such case.

Claude-related files live under `roles/claude/files/`; the tasks are in
`roles/claude/tasks/`. That role is **cross-platform and unguarded**: Claude
Code runs on macOS and Linux alike, and keeping this config inside the
Darwin-guarded `osx` role meant the Linux host silently had no global
`CLAUDE.md`, no managed `settings.json`, and no commands or hook scripts. The `linux` role's sshd hardening lives at
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
| `host` | `scripts/playbook.sh`, `roles/fish/files/ollama.fish`, the `/panel-review` and `/code-review` commands | This machine's inventory alias (`work`/`personal`/`alt`/`server`) |
| `ssh-host` | the `sshc` function in `roles/fish/files/fish/config.fish` | `kitten ssh` target hostname |
| `kitty-ssh.conf` | `roles/kitty/files/kitty/ssh.conf` (via `globinclude`) | Host-specific kitty `ssh.conf` sections |
| `op-service-account-token` | `scripts/ssh-lan-config-sync.sh`, `scripts/claude-gemini-auth-sync.sh` | 1Password service-account token (bearer credential, mode 0600) |
| `slack-users.json` | the `/code-review` and `/peer-review` commands | GitHub login → Slack user ID, so review notifications can find a person |
| `private-identifiers` | `scripts/gitleaks-identifier-rules.sh` | Private project identifiers the secret scanner's `private-project-identifier` rule is generated from, one per line (mode 0600) |

None are created by Ansible and none live in the repo (`~/.config/kitty` is
a symlink into it, which is why the kitty companion sits here instead).
Each is optional; absence degrades visibly rather than silently.

`private-identifiers` is the input to a *generator*, not to the hook. It is
untracked for the same reason as `slack-users.json`: this repo is public and
the identifiers name a private project, which `specs/dev-services` REQ-D1.1
keeps out of every committed artifact but the scanner configuration. The
generated rule block is committed, so the guard still works on a fresh
checkout and in CI; the file is only needed to *regenerate* it:

```sh
scripts/gitleaks-identifier-rules.sh --write   # after changing the set
scripts/gitleaks-identifier-rules.sh --check   # assert the block is current
```

Absence degrades visibly in the strong sense here: the generator refuses with
a non-zero exit for a file that is absent, empty, unparseable, or readable
beyond its owner, rather than emitting a rule set covering fewer identifiers
(REQ-D1.4). A hygiene guard that quietly matches less than intended is worse
than one that refuses to run. The mode is enforced rather than assumed, the
same posture `scripts/ssh-lan-config-sync.sh` takes toward
`op-service-account-token`, so `chmod 600` it on creation.

`slack-users.json` is untracked for a different reason than the others: it is
not a secret, but it holds *other people's* email-derived identities. This repo
is public, and colleagues' Slack IDs are not mine to publish. It is built up as
review workflows resolve people (email lookup first, asking me second), so a
missing entry costs one question rather than a failure.

`op-service-account-token` is the only one that is a *secret*. It exists
because the 1Password desktop-app integration authorizes per calling process
and re-prompts for each new one — fine in a long-lived terminal, useless under
Ansible (a fresh process per task), and impossible during a headless boot where
no desktop app is running to approve anything. A service-account token
authenticates non-interactively instead.

Three consequences worth knowing before moving items around:

- **Service accounts cannot access the Personal or Private vault.** 1Password
  refuses the grant outright, which is why both items that need this token
  (`dotfiles-lan-ssh` and the Gemini API key) live in the
  `Dotfiles Service Account` vault rather than `Private`, and why that is both
  scripts' default vault. Note the blast radius that creates: one machine-local
  file on the headless host now reaches the LAN ssh topology *and* a billable
  Google API key. Splitting them across two service accounts is the move if
  that ever stops being an acceptable trade.
- Moving an item into that vault **reassigns its id**. That is only a problem
  for `claude-gemini-auth-sync.sh`, which addresses its item by id, so a move
  there is also an edit to the script. `ssh-lan-config-sync.sh` addresses its
  item by name (`dotfiles-lan-ssh`, via the `op://` references in its
  template), which survives a move untouched.
- Both scripts refuse to read the file unless it is mode 0600 or 0400, and an
  already-exported `OP_SERVICE_ACCOUNT_TOKEN` takes precedence, so CI can
  supply one without the file existing.

To rotate: `op service-account create <name> --vault 'Dotfiles Service
Account':read_items`, write the returned token to the file with `umask 077`,
and never let it reach a terminal — it is printed exactly once.

## GitHub auth on a headless host

Two different credentials, because ssh and the API do not share one.

**`git push`** uses the on-disk ed25519 key `roles/git` generates for hosts in
`git_unattended_auth_hosts`. Register its public half on GitHub as an
**Authentication** key (a separate entry type from the signing key), and make
sure the remote is `ssh://`, since `core.sshCommand` does nothing for an `https://`
remote.

**The gh CLI** needs a token, and there is no repo artifact for it: run

```sh
gh auth login --insecure-storage
```

on the host, once. That writes the token to `~/.config/gh/hosts.yml` (0600)
instead of the system keyring, and gh's resolution order is `GH_TOKEN` →
`GITHUB_TOKEN` → that file → keyring **last**. Verified on this host against
gh 2.96.0 with a scratch `GH_CONFIG_DIR`: a token in the file is returned and
the keyring is never consulted.

**Why this matters.** The keyring is unlocked by an interactive PAM or
graphical login and stays locked through an unattended boot, so a
keyring-stored token leaves `gh auth token` returning EMPTY after every
headless reboot. gh then reports "the token in default is invalid", which
reads like a revoked credential and is not: every API call and every HTTPS
push fails until a human logs in.

**Rejected alternatives, so they are not re-litigated.** Exporting `GH_TOKEN`
from a machine-local file works, but puts a live bearer token in the
environment of every process the shell spawns, which on a host running
autonomous agents is a real accident surface (`env` in a log, a bug report, an
MCP subprocess). It is also unnecessary, since gh's own file tier already sits
above the keyring. Fetching the token from 1Password at shell start presents a
broad credential (read over a whole vault) to retrieve a narrow one, per the
same reasoning `roles/git/defaults/main.yml` records for the signing key. A
GitHub App with short-lived installation tokens is the textbook machine-auth
answer and the wrong one here: gh has no native App auth, and App tokens act as
the app rather than as you, which would misattribute PR comments and review
replies.

**Caveat on fine-grained PATs.** One is bound to a single resource owner, so it
cannot reach repos under a second owner. If this host ever works across owners,
use a classic-scoped token from `gh auth login` instead.
