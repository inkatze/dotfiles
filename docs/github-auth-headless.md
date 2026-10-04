# GitHub auth on a headless host

Two credentials, because ssh and the API do not share one.

**`git push`** uses the on-disk ed25519 key `roles/git` generates for hosts in
`git_unattended_auth_hosts`. Its public half is registered on GitHub as an
**Authentication** key (a separate entry type from the signing key), and the
remote must be `ssh://`, since `core.sshCommand` does nothing for an
`https://` remote. That command sets `IdentitiesOnly=yes`, so ssh never offers
the agent's keys: a 1Password agent with nobody at its screen blocks on an
approval prompt rather than failing, which stalled fetches for minutes before
the on-disk key was tried.

**The gh CLI** needs a token, set once on the host with
`gh auth login --insecure-storage`. That writes it to `~/.config/gh/hosts.yml`
(0600) instead of the system keyring. gh resolves `GH_TOKEN`, then
`GITHUB_TOKEN`, then that file, and the keyring last; verified against gh
2.96.0 with a scratch `GH_CONFIG_DIR`.

The keyring is unlocked by an interactive login and stays locked through an
unattended boot, so a keyring-stored token leaves `gh auth token` empty after
every headless reboot. gh then reports "the token in default is invalid",
which reads like a revoked credential and is not.

## Rejected alternatives

- **Exporting `GH_TOKEN` from a machine-local file** puts a live bearer token
  in the environment of every process the shell spawns, which on a host
  running autonomous agents is a real accident surface, and gh's own file tier
  already sits above the keyring.
- **Fetching the token from 1Password at shell start** presents a broad
  credential (read over a whole vault) to retrieve a narrow one, the reasoning
  `roles/git/defaults/main.yml` records for the signing key.
- **A GitHub App** has no native gh auth, and its tokens act as the app rather
  than as you, misattributing PR comments and review replies.

A fine-grained PAT is bound to one resource owner; a host that works across
owners needs a classic-scoped token from `gh auth login`.
