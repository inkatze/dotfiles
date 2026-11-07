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
task files guard themselves. On Debian it provisions the declared
dev-services layer (`specs/dev-services`); on Darwin it applies only the older
macOS content (the `~/.my.cnf` client defaults, plus colima on the `personal`
host) and none of the declared services. Install, enable, start and verify
are driven from the declaration and name no service, so a new service is an
entry rather than a task edit.

## Unattended runs: `playbook.sh --user-config`

A run with nobody at the keyboard cannot answer a sudo prompt, and on Linux
the `linux` baseline and the services lifecycle escalate on every run, so the
full playbook (`./scripts/playbook.sh -K`) cannot apply even a config-only
change unattended there. `./scripts/playbook.sh --user-config`, on either
platform, runs only what needs no escalation:

- the roles `main.yml` tags `user-config` (every role except `osx` and
  `linux`, which keep their `os_family` guards and carry no such tag);
- minus tasks tagged `privileged` (the services role's Debian lifecycle, which
  escalates even on a converged host) and `upgrade`;
- with Ansible's become method set to `become_plugins/refuse_privilege.py`, so
  any task in the selection that would still escalate fails with a message
  naming the full run, rather than prompting. A task whose `when:` is false
  never escalates, so fish's login-shell tasks pass on a host already
  converged.

It must be the first argument, and only options that narrow or preview the
run may follow (the allow-list is in `scripts/playbook.sh`): anything that
could widen the selection, retarget the run or supply a sudo password is
refused.

A refusal ends the run at that task: the tasks before it stay applied (all
unprivileged and idempotent), and every later task and role is left unapplied
until the full run repairs the drift. A `--check` preview can miss a refusal
the real run would hit, since check mode skips the unprivileged drift probes
the escalating tasks are gated on. Escalation is not the only thing an
unattended run cannot answer: the 1Password reads in the `ssh`, `git` and
`claude` roles need a service-account token or an unlocked desktop app.

When adding a role, tag it `user-config` in `main.yml` unless it escalates by
design. A task that escalates inside one either runs only when there is drift
to repair (check unprivileged first, as `roles/fish/tasks/shell.yml` does) or
carries the `privileged` tag. `scripts/user-config-selection-test.sh` pins the
selection and the refusal; `scripts/playbook-alias-test.sh` pins the argument
handling.

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
