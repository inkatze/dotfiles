# Dotfiles

Personal dotfiles managed by Ansible: the source of truth for `~/.claude/`,
`~/.config/fish/`, tmux, mise and related surfaces. Edit files here, then run
Ansible to propagate; never edit a materialized file directly. Rationale for
the rules below lives in [docs/](docs/); planned work in `specs/README.md`.

## How Claude config is materialized

The tracked Claude sources live under `roles/claude/files/`, not where they
appear at runtime:

| Runtime path | Tracked source | Mechanism |
|---|---|---|
| `~/.claude/CLAUDE.md` | `roles/claude/files/CLAUDE.md` | Symlink |
| `~/.claude/skills/<name>` | `roles/claude/files/skills/<name>/` | One symlink per tracked directory, `review-shared/` included (`roles/claude/tasks/skills.yml`); foreign entries are left alone |
| `~/.claude/scripts/*` | `roles/claude/files/scripts/` | Symlink (hooks and the status line `settings.json` invokes) |
| `~/.claude/output-styles/*` | `roles/claude/files/output-styles/` | Symlink, resolved by name from `outputStyle` |
| `~/.claude/settings.json` | `roles/claude/files/settings.json` | jq merge by `scripts/claude-settings-merge.sh`, not a symlink |

- Always edit the tracked source; `readlink` a `~/.claude/` file first if in
  doubt.
- Keep `keep-coding-instructions: true` in
  `roles/claude/files/output-styles/compact.md`: without it the custom style
  replaces Claude Code's built-in coding instructions. A style change needs
  `/clear` or a new session.
- The merge only adds or overwrites keys. To remove a hook, declare its event
  as `[]`; removing `statusLine` means editing each live `settings.json`.
- Declare any Claude Code behaviour meant to be shared in the tracked
  `settings.json` (including `permissions.defaultMode`), never by toggling it
  in the app: an undeclared key silently differs per machine. Audit by diffing
  a live `~/.claude/settings.json` against the tracked file.

See [docs/claude-config.md](docs/claude-config.md).

## Permissions

Durable cross-project allows and the deny list go in the tracked
`roles/claude/files/settings.json`. A project's own durable allows go in its
tracked `.claude/settings.json`, ephemeral ones in its gitignored
`.claude/settings.local.json`, which stays near-empty. This repo gitignores
`.claude/`, so its durable rules belong in the global tracked file.

## Adding a new Claude skill

1. Create `roles/claude/files/skills/<name>/SKILL.md` with front matter
   (`name`, `description`, and `disable-model-invocation: true` for a
   slash-invoked review skill). Mechanics more than one skill uses go in
   `roles/claude/files/skills/review-shared/`, linked by relative path.
2. A review skill also joins `SKILL_NAMES` and `expected_hint` in
   `roles/claude/files/scripts/skill-contracts.sh`, with a fixture.
3. Declare its word budget (below), commit, and run Ansible from the main
   checkout: the links point into whichever checkout Ansible ran from. Verify
   in a fresh session.

A new tracked directory under `roles/claude/files/` other than a skill needs
a matching symlink task in `roles/claude/tasks/main.yml`.

## Contract and budget guards

- `roles/claude/files/scripts/skill-contracts.sh` literal-matches
  load-bearing sentences in the review skills, the global `CLAUDE.md` and
  itself. A reword that trips it means the contract moved: update the checker
  and the fixture that plants that drift in the same commit.
- `roles/claude/files/scripts/instruction-budget.sh` holds per-surface word
  budgets. A change that grows or adds a surface re-derives its row there, in
  the same commit. Its suite also holds this file to the line ceiling
  `specs/claude-context` sets and checks every link and repo path here
  resolves.

## Hooks

- Write the script under `roles/claude/files/scripts/`, `chmod +x` it, and
  reference it from the tracked `settings.json` under `hooks.<Event>` as
  `$HOME/.claude/scripts/<name>.sh`. Only entries invoking that path are
  rebuilt from the tracked file; other tools' entries on the event are kept.
- Keep both `PreToolUse` entries in the tracked `settings.json`: dropping the
  `Read|Edit|Write` one silently unwires `path-guard`, and the `Bash` one runs
  `worker-guard-gate.sh`, user-scope by design and gated on
  `PLANWRIGHT_WORKER_HANDLE`. Do not move it to per-project settings.
- Never wire planwright's hooks (`tool-discovery`, `tasks-pr-sync`, and the
  rest of its `hooks/hooks.json`) in the tracked `settings.json`; the plugin
  wires them and a second entry double-fires.
- `worktree-bootstrap.sh` runs a repo's `.claude/worktree-bootstrap`
  unsandboxed: inspect it before opening a checkout you did not author. Its
  header documents the marker and how to force a re-run.

See [docs/claude-hooks.md](docs/claude-hooks.md).

## MCP servers

Register any secret-bearing MCP server through a sync script under `scripts/`,
so the secret stays in 1Password: mirror `scripts/claude-mcp-sync-github.sh`,
with a task in both `roles/osx/tasks/homebrew.yml` and
`roles/osx/tasks/upgrade.yml` behind the same `CI` guard. Sign in to `op`
before running them on a non-CI machine. Nothing provisions the Slack MCP
server the review skills DM through; register it by hand where wanted. See
[docs/mcp-servers.md](docs/mcp-servers.md).

## Review backends

The resolver and every backend invocation are stated once, in
`roles/claude/files/skills/review-shared/backends.md`; change them there. An
unresolved host alias must fall back to `work`, matching `scripts/playbook.sh`.
The Gemini key sync addresses its 1Password item with an explicit `--vault`,
and the item id in that script is the id in that vault. Ollama and its
backends are retired; restoring them is in [docs/ollama.md](docs/ollama.md).
See [docs/review-backends.md](docs/review-backends.md).

## Machine-local files under `~/.config/dotfiles/`

Untracked, never created by the repo, each optional; absence degrades
visibly. Keep machine-specific values here, never in tracked files.

| File | Read by | Holds |
|---|---|---|
| `host` | `scripts/playbook.sh`, `review-shared/backends.md` | This machine's inventory alias; empty or whitespace-only counts as absent |
| `ssh-host` | the `sshc` function in `roles/fish/files/fish/config.fish` | `kitten ssh` target hostname |
| `kitty-ssh.conf` | `roles/kitty/files/kitty/ssh.conf` (`globinclude`) | Host-specific kitty `ssh.conf` sections |
| `op-account` | `scripts/playbook.sh` | The 1Password account every `op` call uses, where more than one is signed in |
| `op-service-account-token` | `scripts/op-token.sh`, for the two 1Password syncs | Service-account token, the only secret here (0600) |
| `git-work-email` | `roles/git/defaults/main.yml` | The work identity written to `~/.gitconfig.work` |
| `pushover-credentials` | `roles/osx/tasks/health-signal.yml`, `roles/osx/files/health/health-check.sh` | Health-check notification credentials, generated by that role |
| `work-shell-init` | `roles/fish/files/work-init.fish` | Path of a second config manager's shell init to source |
| `slack-users.json` | `review-shared/slack.md` | GitHub login to Slack user ID (0600) |
| `code-review-egress.json` | `review-shared/egress.md` | Per-repo (and per-reviewer) upload consents (0600) |
| `bot-review.json` | the `/bot-review` skill, `/panel-review`'s `reviewer:<name>` backend | Named third-party reviewers; example at `roles/claude/files/skills/bot-review/bot-review.config.example.json` (0600) |
| `private-identifiers` | `scripts/gitleaks-identifier-rules.sh`, `roles/claude/files/scripts/identifier-check.sh` | Names that must never reach a committed file |
| `claude-instructions-inventory/` | the `specs/claude-instructions` tasks, by hand | Dated instruction-surface audit (directory 0700, files 0600) |

Service-account items live in the `Dotfiles Service Account` vault (service
accounts cannot read Personal or Private); moving an item there reassigns its
id. See [docs/machine-local-files.md](docs/machine-local-files.md) for the why
and the rotation procedure.

## Identifier check

Do not wire `scripts/gitleaks-identifier-rules.sh` into a hook or CI without
first amending `specs/dev-services`, which retired that guard. The review-time
check is `roles/claude/files/scripts/identifier-check.sh`, run by hand at task
review; it never blocks a commit. See
[docs/identifier-guard.md](docs/identifier-guard.md).

## Ansible role layout

`main.yml` runs one platform baseline per host by `os_family` guard
(`roles/osx/` on Darwin, `roles/linux/` on Debian); the cross-platform config
roles (`kitty`, `fish`, `environments`, `tmux`, `ssh`, `git`, `claude`) run
everywhere, and Claude config belongs only in `roles/claude/`.

`roles/services/` runs everywhere but guards itself: on Debian (Linux) it
provisions the services declared in `roles/services/defaults/main.yml`, on
Darwin (macOS) only the older `~/.my.cnf` and colima content. Add a dev
service as an entry there, not a task edit; one needing more names its own
file in a `setup:` field.

- Never make `~/.my.cnf` or `~/.npmrc` a symlink into this repo: their
  content is credentials, so the roles insert a marked `blockinfile` block.
- Never commit a real hostname or LAN IP. A host declares itself through
  `DOTFILES_HOST` or the `host` file; `scripts/playbook.sh` refuses any value
  that is not a single host listed in `hosts`.

See [docs/ansible-roles.md](docs/ansible-roles.md).

## Git, fish and the editor

- Never symlink `~/.gitconfig` at the tracked config: `git config --global`
  writes through a symlink into this public repo. The role keeps one marked
  include block at the top of a real file; leave it at the top, since later
  keys win. Declaring a multi-valued key such as `credential.helper` adds a
  value rather than overriding one. When the role reports a foreign symlink,
  add the include there by hand. See [docs/gitconfig.md](docs/gitconfig.md).
- In `roles/fish/files/work-init.fish`, keep `GIT_DUET_GLOBAL false` after the
  source and outside the guard; keep `config.fish` skipping `mise activate`
  when the shims are already on `PATH`, and its login block appending, not
  prepending, runtime bins. See
  [docs/work-shell-init.md](docs/work-shell-init.md).
- Name the editor `vi`, keep `vim-tiny` in `linux_apt_packages`, and never
  delete the `nv` alias: the `tm.fish` workspace functions type it. See
  [docs/editor.md](docs/editor.md).
- On a headless host, `git push` needs an `ssh://` remote and the generated
  key registered as an Authentication key; `gh` needs
  `gh auth login --insecure-storage` once. Do not export `GH_TOKEN` from a
  file, fetch it from 1Password at shell start, or use a GitHub App; a host
  spanning owners needs a classic-scoped token. See
  [docs/github-auth-headless.md](docs/github-auth-headless.md).

## planwright from the shell

`roles/fish/files/planwright.fish` exports `PLANWRIGHT_ADOPTER_OVERLAY` and
`PLANWRIGHT_FLEET_STATE_DIR` for every shell, keeping a non-empty value
already set. `tower` launches `/planwright:tower` under planwright's tower
permission profile and fails closed when that profile is missing or has no
`permissions.deny`; it refuses pass-through flags that would replace or
disable the profile. Never merge that profile into the tracked
`settings.json`. `scripts/fish-tower-test.sh` pins all of it.
