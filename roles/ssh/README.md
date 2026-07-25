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

## `~/.ssh/config.local` template

Included *before* the `Host *` block, so machine-local settings win
(`ssh_config` is first-value-wins). Fill in your own values:

```sshconfig
Host <alias> <lan-ip>
    User <user>
    ForwardAgent yes
    SendEnv ANTHROPIC_API_KEY

Host <alias>
    Hostname <alias>.local
```

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
