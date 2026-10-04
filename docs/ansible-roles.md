# Ansible role layout and host aliases

Rationale behind the role-layout rules in the repo-root `CLAUDE.md`.

## Platform split

Only one platform baseline runs on a given host (`roles/osx/` on Darwin,
`roles/linux/` on Debian); the other is skipped whole by its `when:` guard in
`main.yml`. The Claude role is cross-platform and unguarded: keeping it in the
Darwin-guarded `osx` role once meant the Linux host had no global
`CLAUDE.md`, no managed `settings.json`, and no review commands or hook
scripts.

## The services role guards itself

`roles/services/` runs on every host with no `when:` in `main.yml`, but its
two task files guard themselves. On Debian it provisions the declared
dev-services layer (`specs/dev-services`); on Darwin it applies only the older
macOS content (the `~/.my.cnf` client defaults, plus colima on the `personal`
host) and none of the declared services. Install, enable, start and verify
are driven from the declaration and name no service, so a new service is an
entry rather than a task edit.

## `~/.my.cnf` and `~/.npmrc` are applied to, not owned

Their canonical content is credentials (a client password; registry
`_authToken` lines), and writers resolve a symlink and write through to its
target, so owning either path would make a public checkout the write target
for a credentials file. Both roles insert this repo's defaults as a marked
`blockinfile` block instead, replacing a symlink an earlier run left behind
(matched on the repo-relative target, so a symlink pointing anywhere else is
never removed).

The block lands at EOF, so on a key both sides set, ours wins.
`npm config set` rewrites the whole file without preserving comments,
stripping the markers; the next run re-appends the block once and is
idempotent again after that. `mode: "0600"` is asserted unconditionally.

## Inventory aliases

`hosts` lists `work`, `personal`, `alt` (macOS) and `server` (Linux), all run
locally, so no LAN IP or real hostname is committed. `scripts/playbook.sh`
maps the running machine to an alias through `DOTFILES_HOST` or the
machine-local `host` file; `work` is the fallback (CI depends on it) and warns
on stderr. One residual hostname pattern remains for `alt`.

An empty or whitespace-only alias file counts as absent. That is a safety
property, not a nicety: an empty alias would become `ansible-playbook -l ""`,
which Ansible reads as *no limit* and runs every inventory host against this
machine. A resolved value that is not a single plain ASCII name listed as a
host in `hosts` is refused outright, which catches `,`, a non-breaking space,
a leading `-` or `!`, and the group names `all`, `ungrouped` and `secrets`,
each of which Ansible would widen to several hosts. The review skills pass
such a value through as a profile, which merely selects gemini.
`scripts/playbook-alias-test.sh` pins the `playbook.sh` side.
