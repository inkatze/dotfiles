# Pre-split macOS playbook baseline (REQ-D1.2 comparison basis)

Captured **before** any Task 4 platform-split work landed, so the
post-split macOS run can be diffed against it (REQ-D1.2, D-5).

- **Captured:** 2026-07-23
- **Repo state (pre-split HEAD):** `737e59ac787baf0e89656ada6901feff093a3e59`
- **Method:** `ansible-playbook main.yml --syntax-check` and
  `ansible-playbook -l <host> main.yml --list-tasks` (non-mutating;
  no host state changed). `--list-tasks` renders the structural task
  set independent of per-host `when:` evaluation, so a single capture
  is the canonical task inventory for every macOS inventory host
  (`personal`, `work`, `alt`).
- **Syntax check:** pass (rc 0).
- **Task count:** 59 tasks in play `all`.

## Why structural, not a mutating run

This is the operator's live personal machine. A full
mutating `ansible-playbook` run there restarts colima, changes the
login shell, and does network I/O against GPG keyservers, so it is not
run unattended from repo automation. The `--list-tasks` +
`--syntax-check` capture is the reproducible, hygiene-clean structural
basis (REQ-F1.1: it contains task names and tags only, no hostnames,
IPs, or secrets).

The **[manual]** REQ-D1.2 verification — a real macOS-host playbook run
after the split showing no unexpected `changed`/`failed` tasks versus
this baseline — remains operator-owned (test-spec REQ-D1.2), run on the
live machine at review/merge time. The split adds only role-level
`os_family` guards and a fully-skipped `linux` role on macOS, so the
macOS task set is unchanged by construction; this baseline lets the
operator confirm that mechanically.

## Canonical task inventory (play: all)

```
osx : Import macOS tasks  TAGS: [osx]
osx : Import homebrew tasks  TAGS: [osx]
osx : Import upgrade tasks  TAGS: [upgrade]
kitty : Create kitty configuration directory  TAGS: [kitty]
kitty : Symlink kitty configuration directory  TAGS: [kitty]
fish : Get fish directory  TAGS: [always]
fish : Create fish configuration directory  TAGS: [fish]
fish : Symlink fish configuration  TAGS: [fish]
fish : Create fish conf.d directory  TAGS: [fish]
fish : Symlink ollama.fish into fish conf.d  TAGS: [fish]
fish : Symlink gemini.fish into fish conf.d  TAGS: [fish]
fish : Symlink ssh-auth.fish into fish conf.d  TAGS: [fish]
fish : Install fisherman  TAGS: [fish, skip_ansible_lint]
fish : Retrieve installed fisherman packages  TAGS: [fish]
fish : Install fish plugins  TAGS: [fish]
fish : Symlink theme configuration  TAGS: [fish]
fish : Update fisherman plugins  TAGS: [upgrade]
fish : Import tasks to add fish to shells  TAGS: [shell]
services : Symlink my.cnf  TAGS: [services]
services : Start colima service  TAGS: [colima, services]
services : Wait for colima to be ready  TAGS: [colima, services]
services : Check for colima config file  TAGS: [colima, services]
services : Disable colima mountInotify to avoid Gatekeeper verify churn  TAGS: [colima, services]
services : Restart colima to apply mountInotify change  TAGS: [colima, services]
services : Wait for colima to be ready after restart  TAGS: [colima, services]
environments : Get fish directory  TAGS: [always]
environments : Symlink mise configuration file  TAGS: [environments]
environments : Trust mise's config file  TAGS: [environments]
environments : Symlink default initial packages file  TAGS: [environments]
environments : Install mise plugins  TAGS: [environments]
environments : Import Node.js GPG keys  TAGS: [environments]
environments : Install default tool versions  TAGS: [environments]
environments : Symlink npmrc  TAGS: [environments]
environments : Symlink importjs.js  TAGS: [environments]
environments : Reshim mise tools  TAGS: [environments, upgrade]
neovim : Download neovim nightly  TAGS: [neovim]
neovim : Symlink neovim binary  TAGS: [neovim]
neovim : Symlink neovim configuration  TAGS: [neovim]
neovim : Restore neovim plugins  TAGS: [neovim]
neovim : Install neovim plugins  TAGS: [neovim]
neovim : Install treesitter modules  TAGS: [neovim]
neovim : Upgrade neovim plugins  TAGS: [upgrade]
neovim : Upgrade treesitter modules  TAGS: [upgrade]
tmux : Installing tmux Plugin Manager  TAGS: [skip_ansible_lint, tmux]
tmux : Symlink tmux.conf  TAGS: [tmux]
tmux : Symlink tmux scripts directory  TAGS: [tmux]
tmux : Ensuring color profile is installed  TAGS: [tmux]
tmux : Installing color profile  TAGS: [tmux]
tmux : Ensure tmux socket directory exists  TAGS: [tmux]
tmux : Ensure tmux server is running  TAGS: [tmux]
tmux : Clean tpm plugins  TAGS: [tmux]
tmux : Install tpm plugins  TAGS: [tmux]
tmux : Import upgrade tasks  TAGS: [upgrade]
ssh : Create .ssh directory  TAGS: [ssh]
ssh : Symlink ssh config  TAGS: [ssh]
ssh : Symlink known hosts  TAGS: [ssh]
ssh : Symlink allowed signers  TAGS: [ssh]
git : Symlink gitconfig  TAGS: [git]
git : Symlink gitignore  TAGS: [git]
```
