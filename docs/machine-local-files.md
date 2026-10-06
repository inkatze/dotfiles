# Machine-local files under `~/.config/dotfiles/`

Rationale behind the machine-local table in the repo-root `CLAUDE.md`. None
lives in the repo, because this repo is public. Ansible writes only the osx
health role's `pushover-credentials` and the files rendered or synced from
1Password (below); the rest are written by hand or by the skill that reads them.

## Why each kind is untracked

- **`code-review-egress.json`** is a per-machine consent record: it enumerates
  repos (employer and third-party names) this machine has approved for upload
  to an external model provider or review vendor. The skills write it
  read-modify-write under a lock directory, at 0600. Revoking an approval is
  deleting its key while no review is running; stopping all uploads of a repo
  means deleting the bare `owner/repo` key and every
  `reviewer:<name>:owner/repo` key for it. The failure cases are spelled out in
  `roles/claude/files/skills/review-shared/egress.md`.
- **`slack-users.json`** is not a secret, but it holds other people's
  identities, which are not this repo's to publish.
- **`op-service-account-token`** is the only secret you provide by hand
  (`pushover-credentials` is Ansible-written). It exists because the
  1Password desktop integration authorizes per calling process: fine in a
  long-lived terminal, useless under Ansible (a fresh process per task), and
  impossible during a headless boot with no app to approve anything.
- **The identifier file** names the external projects and organizations that
  must not reach committed files; it exists so the check can run without the
  public repo carrying the names it checks for.
- **The instruction inventory directory** is the dated audit snapshot the
  `specs/claude-instructions` tasks read; it carries private-repo detail, so
  the directory is 0700 and its files 0600.

## Rendered from 1Password

`bot-review.json`, `sibling-repos.json` and planwright's adopter overlay
config (`~/.claude/plugins/data/planwright-planwright/overlay/planwright.yml`)
are rendered by `scripts/op-render.sh` from committed templates and the items
`dotfiles-bot-review`, `dotfiles-sibling-repos` and
`dotfiles-planwright-overlay`, through `roles/claude/tasks/op-render.yml`.
Those tasks sit behind the same `op` probe and CI guard as the Gemini key
sync and run last in the claude role, so on a host with `op` a missing item
fails the play rather than degrading, after every other task has run. The
renderer validates each file before it lands (the review config against
`roles/claude/files/skills/bot-review/config-schema.jq`), refuses a `steps_`
key in the overlay since a step list is a per-repository decision, and
overwrites a hand-written file at its output: carry anything worth keeping
into the item before the first run.

An item must hold every field its template references. A field left empty
drops its key, and a reviewer entry whose fields are all empty drops out, so a
host that does not run Copilot leaves the `copilot_` fields blank. A JSON
template's reference ending in `| json` takes the field's value as JSON (a
list or a map) rather than a string. The review template's `cli` blocks are
literal, since they describe how to run a local CLI rather than the hosted
bot's mechanics, so a rendered config carries them as committed, except that
an empty list or map in one drops like any other.

`cubic-api-key` is synced by `scripts/op-key-sync.sh` from the `credential`
field of the `dotfiles-cubic-api-key` item (category API Credential), through a
task in the same file and behind the same guards. It is a raw key, not a
rendered template, so it gets its own script: written at 0600, a blank value
or one holding any whitespace refused, an existing file at any mode but 600
or 400 refused rather than tightened (if others could read it, the fix is a
rotation), and a directory someone else owns, or that other users or any
group but one named after you can write, refused (a shared primary group such
as macOS's `staff` counts as anyone's). No login or interactive shell exports
it; `/panel-review`'s `reviewer:cubic` backend reads it through the entry's
`cli.env_files` and hands it to the CLI on a pipe, never an argv.

## The service account

- **Service accounts cannot access the Personal or Private vault.** Every item
  that needs the token (`dotfiles-lan-ssh`, the Gemini and cubic.dev API
  keys and the three rendered items above) therefore lives in the
  `Dotfiles Service Account` vault, which is every script's default. One
  file on the headless host thereby reaches the LAN ssh topology, the
  billable API keys and the private review configuration; splitting the
  sensitive items onto their own service account is the move if that stops
  being an acceptable trade.
- **Moving an item into that vault reassigns its id.** That only matters for
  `scripts/claude-gemini-auth-sync.sh`, which addresses its item by id;
  `scripts/ssh-lan-config-sync.sh` addresses its item by name.
- **Every script that reads 1Password with it resolves the token through
  `scripts/op-token.sh`**, tested by `scripts/op-token-test.sh` through
  `scripts/ssh-lan-config-sync.sh` and `scripts/claude-gemini-auth-sync.sh`,
  so a fix to the checks lands everywhere. Its
  `resolve_op_token` refuses a file that is a symlink, is not regular, or is
  not mode 0600 or 0400, and a value that is blank or holds anything outside
  the token character set (NUL bytes included). An already-exported
  `OP_SERVICE_ACCOUNT_TOKEN` takes precedence, so CI can supply one without
  the file existing; an exported empty one is treated as absent.

To rotate, write the new token straight to a file so it never reaches a
terminal (it is shown exactly once), then move it into place. Replace
`NEW_ACCOUNT_NAME` with the new service account's name:

```sh
(umask 077; op service-account create NEW_ACCOUNT_NAME \
  --vault 'Dotfiles Service Account':read_items --raw \
  >~/.config/dotfiles/op-service-account-token.new) &&
  mv ~/.config/dotfiles/op-service-account-token.new \
    ~/.config/dotfiles/op-service-account-token
```

Re-run the syncs that use it; once they pass, revoke the old service account
on 1Password.com, since the CLI cannot delete one.
