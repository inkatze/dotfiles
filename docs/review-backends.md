# Review backends: codex vs gemini

Rationale behind the review-backend rules in the repo-root `CLAUDE.md`. The
resolver and the codex, gemini and copilot invocations are stated once in
`roles/claude/files/skills/review-shared/backends.md`; the opt-in
`reviewer:<name>` backend is in
`roles/claude/files/skills/panel-review/reviewer-backend.md`.

## Which host defaults to which backend

`/panel-review` and `/code-review` run their discovery pass through a
non-Anthropic CLI. The machine picks the default; a run can override it with
`--backends` (one backend for `/code-review`, a list for `/panel-review`) or
`PANEL_REVIEW_PROFILE`. The opt-in `copilot` and `reviewer:<name>` backends
are never chosen automatically.

| Alias | Backend | CLI comes from | Key comes from |
|---|---|---|---|
| `work` | `codex` | `Brewfile` (`cask "codex"`) | `codex login`, interactive |
| `personal`, `alt` | `gemini` | `Brewfile` (`brew "gemini-cli"`) | `scripts/claude-gemini-auth-sync.sh` |
| `server` | `gemini` | mise, pinned in `roles/linux/files/mise/linux.toml` | same script, service-account path |

The `copilot` backend is declared the same way (`cask "copilot-cli"` in the
`Brewfile`, `copilot` in `linux.toml` through mise's registry default), and the
skills fall back to the copy `gh copilot` downloads on first use.

The cubic.dev CLI, run as `--backends reviewer:cubic`, is pinned for every
platform in `roles/environments/files/mise.toml` through mise's npm backend,
with its key from `scripts/op-key-sync.sh`; its invocation is the cubic
entry's `cli` block in the review config template. The CLI loads
`cubic.json`, `cubic.jsonc` and `.cubic/` (plugins included) from the tree it
reviews, with no switch to turn that off, so the entry's `cli.refuse_paths`
stops the backend on a repository carrying any of them; the hosted bot still
reviews such a repository through `/bot-review`. Its review agent would also
run shell commands, fetch URLs and start language servers (the TypeScript one
from the reviewed repo's own `node_modules`) with the key in its environment,
and upload the first global instruction file it finds; the entry's `cli.env`
denies the shell and web fetch through `CUBIC_PERMISSION` and disables every
built-in server through `CUBIC_CONFIG_CONTENT`, and `cli.require_empty` keeps
`~/.config/cubic/AGENTS.md`, which it reads before `~/.claude/CLAUDE.md`,
present and empty (the claude role creates it). The grep tool, whose path
argument reaches ripgrep as an option, and the web and code search tools are
off too, and edit stays denied, since a later version that enabled it
would run the repo's own formatter;
`~/.local/share/cubic/preferences.json` (the claude role writes it when
absent) must prefer cubic's own provider and the key carry its `cbk_` prefix,
or the CLI hands the review to Claude Code, Cursor or Codex with their own
settings; `~/.local/share/cubic/auth.json` may hold no wellknown login, whose
remote config the CLI merges after the lockdown; `~/.config/cubic` may hold
nothing but that empty file, since global agents, tools and plugins load
after the lockdown; and
`cli.env_allow` may not name a `CUBIC_` switch or a relocated config or data
home. The agent can still read any file you can read and send it to cubic,
so run it only on branches whose contents you trust.
`scripts/cubic-lockdown-test.sh` reads the pinned binary's code for each of
these, keeping the reviewed tarball (about 50 MB) under
`dotfiles/cubic-lockdown` in an absolute `XDG_CACHE_HOME`, else `~/.cache`,
so later runs need no network; a cache directory that is a symlink, is not
yours, or that group or other can write, is ignored. The package is
proprietary (its license field is `UNLICENSED`, so use is on the vendor's
terms), and its optional dependencies carry one native binary per platform
variant, of which npm may fetch several on one host; `mise prune` reclaims
an old version's directory after a bump.

**Its install opts out of git-ai.** The package's postinstall pipes the
git-ai installer, a commit tagger that writes git notes, to bash unless
`CUBIC_DISABLE_GIT_AI` is set or `$XDG_STATE_HOME/cubic/git-ai-disabled`
(default `~/.local/state`) exists. Several layers keep it from running:

- mise's npm backend skips package lifecycle scripts by default (measured
  on mise 2026.7.13: no postinstall ran);
- the environments role writes the flag file before it links the mise
  config that declares the pin;
- its install task sets the variable, plus `CUBIC_DISABLE_INSTALL_WIZARD`
  so an install never opens the vendor's interactive coding-agent setup.

`scripts/cubic-postinstall-optout-test.sh` reads the pinned version's install
scripts and fails when that condition, the license or the version changes.
The gap is a host that pulls the pin before the role has run, on a mise set
to run lifecycle scripts: none of the layers is in place there, and the
postinstall would pipe the installer to bash. Such a host should check for
`~/.git-ai/`, git hooks it did not install, and `git notes list` in its
repositories. The invocation sets the same variable plus the vendor's
auto-update and language-server download opt-outs, so a review never
fetches a newer binary mid-run.

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
