# Review backends: codex vs gemini

Rationale behind the review-backend rules in the repo-root `CLAUDE.md`. The
resolver and the codex and gemini invocations are stated once in
`roles/claude/files/skills/review-shared/backends.md`; the opt-in
`reviewer:<name>` backend is in
`roles/claude/files/skills/panel-review/reviewer-backend.md`.

## Which host defaults to which backend

`/panel-review` and `/code-review` run their discovery pass through a
non-Anthropic CLI. The machine picks the default; a run can override it with
`--backends` (one backend for `/code-review`, a list for `/panel-review`) or
`PANEL_REVIEW_PROFILE`. The opt-in `reviewer:<name>` backend is never
chosen automatically.

| Alias | Backend | CLI comes from | Key comes from |
|---|---|---|---|
| `work` | `codex` | `Brewfile` (`cask "codex"`) | `codex login`, interactive |
| `personal`, `alt` | `gemini` | `Brewfile` (`brew "gemini-cli"`) | `scripts/claude-gemini-auth-sync.sh` |
| `server` | `gemini` | mise, pinned in `roles/linux/files/mise/linux.toml` | same script, service-account path |

## Why the profile is the inventory alias

It used to be only `PANEL_REVIEW_PROFILE`, defaulting to `personal`. Nothing
sets that variable, so the work Mac resolved to `personal` and reached for
gemini on every review, the opposite of the table. Keying on the alias the
rest of the repo already uses means the work host is right with nothing to
remember.

These resolver clauses are easy to drop, and the first cut dropped them all:

- Without the `alt` hostname branch, an `alt` Mac (which legitimately has no
  alias file) resolves to `work` and reaches for codex, which it never logs
  into.
- Without the non-whitespace test, a `touch`ed alias file yields an empty
  profile, which is not `work` and therefore selects gemini on the work host.
- Without `DOTFILES_HOST_FILE`, a host that relocates its alias file has
  `scripts/playbook.sh` and the review skills disagreeing about which machine
  it is.

The fallback direction matters too: an unresolved alias must resolve to
`work`, matching `playbook.sh`, because `work` is the host that does not write
an alias file.

## The Linux CLI comes from mise

apt has no gemini package and mise's registry offers one backend for it
(`npm:@google/gemini-cli`). That backend looks like it needs a node the
`linux` role does not install, since `roles/environments` owns the node pin
and runs later. It does not: measured with a throwaway `MISE_DATA_DIR` and no
node on PATH, `mise install npm:<pkg>` bootstraps its own node. The first cut
split the pin from its install across two roles to route around an ordering
problem that does not exist.

## The key sync is cross-platform

The sync lives in `roles/claude`, not a platform role. It was in the
Darwin-guarded `roles/osx`, which is why the Linux host once had
`gemini.fish` exporting `GEMINI_API_KEY` from a file nothing wrote. Its tasks
carry the `claude` tag, so `mise run claude` syncs the key, and also `osx` and
`linux`, so both platform runs sync it too. Those two tags are the only place
a platform tag names tasks outside its platform role: on a Mac,
`mise run linux` runs them (behind its sudo prompt), and on the Linux host
`mise run osx` does. Both are harmless.

The sync is preceded by an `op --version` probe, the split `roles/ssh` uses: a
host without the 1Password CLI is skipped with a notice, while a host that has
`op` and still fails is a real error. Without the probe, a not-yet-provisioned
host aborts the last role in `main.yml` partway through, taking the planwright
plugin install with it.

## The headless host and the service account

There is no 1Password desktop app on a headless host, so
`claude-gemini-auth-sync.sh` falls back to the service-account token through
`scripts/op-token.sh`. A service account cannot be granted the Personal or
Private vault, so the key item lives in `Dotfiles Service Account` and must be
addressed with an explicit `--vault`: without one, `op` refuses every field
with "a vault query must be provided when this command is called by a service
account", which reads like a missing item and is not. Moving an item between
vaults reassigns its id; the comment above `ITEM_UUID` in the script owns the
current one.

## Gemini under untrusted content

Gemini CLI needs `--skip-trust` for any headless run (measured on 0.54.4):
without it the CLI downgrades `--approval-mode plan` to `default` and *then*
aborts with "not running in a trusted directory". `--approval-mode plan` is
what holds the run read-only, and the downgrade-before-abort ordering means a
future version that stops aborting would otherwise run with that guard already
stripped.

Folder trust gates the CLI loading project-supplied configuration from the
current directory. A direct test on 0.54.4 (a `.gemini/settings.json`
declaring an MCP server whose command writes a marker file, run under
`--skip-trust --approval-mode plan`) did not execute it, so this is not
drive-by code execution. It is still a gate switched off over untrusted
content (for `/code-review`, someone else's PR), so the skills run the CLI
from a freshly `mktemp -d`'d empty directory in a subshell, with the diff on
stdin. Not `/tmp` itself, which is world-writable and so pre-seedable with a
`GEMINI.md`; a subshell because the Bash tool keeps its cwd between calls.
None of this covers user-level `~/.gemini/` config, which loads regardless of
cwd.

## The Copilot CLI backend is retired

`/panel-review` had an opt-in `copilot` backend with a bespoke view-only
sandbox. Copilot is now used only where a repository runs the hosted reviewer,
so the backend and its checker anchors are gone and nothing declares its cask
or Linux mise pin any more (a host that already installed the CLI keeps it until
it is removed by hand). A run given `--backends copilot` stops and names the
replacement: a Copilot CLI, if wanted again, runs as a `reviewer:<name>`
entry's `cli` block like any other vendor, added to the review template the
config is rendered from (a hand edit to the rendered file is overwritten on
the next role run; see `docs/machine-local-files.md`). The contract checker's
retired-backend sweep keeps the name out of the skills.

With the last consumer gone, the OAuth credential under
`~/.config/github-copilot/` was left on disk on every host that ever signed
in, world-readable where it was found (the Linux host). `roles/claude/tasks/copilot-credential.yml` deletes that directory
and nothing else (the Copilot CLI's own `~/.copilot/` stays), and is temporary:
once every host has run the role it can go. Deleting the directory does not
revoke the token, so also revoke the Copilot entries on GitHub, under Settings →
Applications → Authorized OAuth Apps.
