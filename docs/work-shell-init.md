# A second config manager's shell init

Rationale behind the fish rules in the repo-root `CLAUDE.md`.

A managed host may carry its own provisioning system that wires only
`~/.bash_profile` and `~/.zshrc`. Since `roles/fish` makes fish the login
shell, none of it loads: mise shims, fork-safety exports and tool completions
all silently absent. `roles/fish/files/work-init.fish` (linked into
`~/.config/fish/conf.d/`) sources an init named by the machine-local
`work-shell-init` pointer, so no real path enters this public repo. A `.fish`
target is sourced natively; anything else is replayed through `edc/bass`,
since fish's own `source` cannot parse bash and bass cannot parse fish.

Two ordering rules are load-bearing:

- **`GIT_DUET_GLOBAL false` is set after the source and outside the guard.**
  The sourced init sets it true, and `~/.gitconfig` resolves into this repo,
  so git-duet would publish colleagues' names and emails. Set before the
  source, it is overwritten; set inside the guard, the protection depends on
  an unrelated file existing.
- **`config.fish` skips its own `mise activate` when the shims directory is
  already on `PATH`.** Hook mode and shims mode together put the install
  directories ahead of the shims, which defeats tooling that asserts a shim
  path. The check is on `PATH` itself because "the init was sourced" is a
  weaker fact than "mise is active in shims mode". For the same reason the
  login block appends rather than prepends runtime bins.
