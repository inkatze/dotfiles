# Machine-local files under `~/.config/dotfiles/`

Rationale behind the machine-local table in the repo-root `CLAUDE.md`. None of
these files is created by Ansible (the osx health role's generated
`pushover-credentials` aside) and none lives in the repo, because this repo is
public.

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

## The service account

- **Service accounts cannot access the Personal or Private vault.** Both items
  that need the token (`dotfiles-lan-ssh` and the Gemini API key) therefore
  live in the `Dotfiles Service Account` vault, which is both scripts' default.
  One file on the headless host thereby reaches the LAN ssh topology *and* a
  billable API key; splitting them across two service accounts is the move if
  that stops being an acceptable trade.
- **Moving an item into that vault reassigns its id.** That only matters for
  `scripts/claude-gemini-auth-sync.sh`, which addresses its item by id;
  `scripts/ssh-lan-config-sync.sh` addresses its item by name.
- **Both scripts resolve the token through `scripts/op-token.sh`**, tested by
  `scripts/op-token-test.sh`, so a fix to the checks lands in both. Its
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
