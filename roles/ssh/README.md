# ssh role

Symlinks the tracked SSH files into `~/.ssh/` and creates their machine-local
companions.

| Path | Tracked? | Holds |
|---|---|---|
| `~/.ssh/config` | yes — `files/config` | Cross-host defaults, public-host blocks |
| `~/.ssh/known_hosts` | yes — `files/known_hosts` | Pinned keys for **public** hosts only (github.com) |
| `~/.ssh/allowed_signers` | yes — `files/allowed_signers` | Commit-signature verification |
| `~/.ssh/config.local` | **no** | LAN host aliases |
| `~/.ssh/known_hosts.local` | **no** | Accepted LAN host keys |

## Why the split

This repo is public. `specs/linux-migration` REQ-F1.1 keeps LAN topology —
internal hostnames, RFC1918 addresses, host-key fingerprints — out of
committed artifacts, and `.gitleaks.toml` enforces it as a pre-commit
backstop. So anything naming a machine on your LAN belongs in the `.local`
files, which Ansible creates empty and never overwrites.

The split also fixes a real footgun. `~/.ssh/known_hosts` is a *symlink into
this repo*, and the config sets `StrictHostKeyChecking no`. Before the split,
accepting any new host key appended it straight into the tracked file, silently
dirtying your dotfiles checkout. `UserKnownHostsFile` now lists
`~/.ssh/known_hosts.local` **first**, and ssh appends to the first file in the
list, so new keys land outside the repo.

## `~/.ssh/config.local` — synced from 1Password

Included *before* the `Host *` block, so machine-local settings win
(`ssh_config` is first-value-wins).

It is **not** hand-written and **not** gitignored-and-forgotten: a gitignored
file would not sync across hosts, which is the whole point of managing dotfiles
with Ansible. Instead the *structure* is committed as
`files/config.lan.tpl` — containing only `op://` secret references, no values —
and `scripts/ssh-lan-config-sync.sh` renders it through
[`op inject`](https://www.1password.dev/cli/reference/commands/inject/) at
playbook time. Structure stays reviewable in git; values stay in 1Password.

### One-time 1Password setup

Create an item (default: vault `Private`, item `dotfiles-lan-ssh`; override
with `DOTFILES_OP_VAULT` / `DOTFILES_OP_ITEM`) with these text fields:

| Field | Holds |
|---|---|
| `server_alias` | short ssh alias for the Linux host |
| `server_host` | resolvable hostname (e.g. `<alias>.local`) |
| `server_ip` | LAN address |
| `server_user` | login user |

Then `op signin` and run the playbook. The script prints `OK` when the file
already matches, `CHANGED` when it rewrites it, and `FAILED:` on any
precondition failure.

### Behavior worth knowing

- **A host without `op` is skipped, not failed.** The play reports it and moves
  on, so a machine that legitimately has no 1Password CLI does not break the
  run. A host that *has* `op` but hits a locked vault or a missing field **does**
  fail — that is a real error, not an absence.
- **It fails closed.** The rendered output is rejected before installation if a
  template expression survived, if a secret reference leaked onto a config
  line, if no `Host` block is present, or if the result does not parse under
  `ssh -G`. A half-rendered `config.local` would break every ssh call on the
  host, so none of these are warnings.
- **It never writes through a symlink** or over a non-regular file.

Tests: `scripts/ssh-lan-config-sync-test.sh` (stubs `op`, so it needs no vault,
session, or network).

## Rotating a LAN host's key

`known_hosts.local` is machine-local, so a rebuilt host is a local fix — no
commit involved:

```bash
ssh-keygen -R <alias>.local -f ~/.ssh/known_hosts.local
ssh-keygen -R <lan-ip>     -f ~/.ssh/known_hosts.local
```

Then reconnect and accept the new key. Verify the fingerprint out-of-band
against the host's own `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`
before accepting.

## Platform note

`UseKeychain` is macOS-only — Linux OpenSSH rejects it fatally (`Bad
configuration option: usekeychain`, exit 255). It is applied through a
`Match ... exec "uname | grep -q Darwin"` guard so the same tracked file works
on both platforms.
