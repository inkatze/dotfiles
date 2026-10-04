# `~/.gitconfig` is a real file, not a symlink

Rationale behind the git rules in the repo-root `CLAUDE.md`.

The git role used to symlink `~/.gitconfig` at the tracked
`roles/git/files/gitconfig`. `git config --global` follows that symlink and
writes the *target* (measured), so every `--global` write on the machine
landed in this public repo: an external provisioner setting an author email,
`gh auth setup-git`, `url.<host>.insteadOf`, `http.<url>.extraheader` (which
carries a base64 credential), and `git maintenance start`, which records the
absolute path of every repository it maintains. Inward it was as bad: the link
went up with `force: true`, clobbering a real `~/.gitconfig` another tool had
written.

So the role ensures `~/.gitconfig` is a real, untracked file holding one
marker-delimited block that includes the tracked config:

```
# BEGIN dotfiles git role
[include]
    path = <clone>/roles/git/files/gitconfig
# END dotfiles git role
```

`blockinfile`, because the marker makes the edit idempotent while keeping the
role from owning anything else in the file; `git config --file` would need
`--replace-all` not to duplicate the key, and appends at the wrong end. The
position is the override order: git takes a key's last-seen value, so the
block goes at the top and everything below it wins, including whatever
`git config --global` appends later.

Per-key declaration cannot replace this. `git config --global` writes
unconditionally rather than consulting includes, and multi-valued keys
accumulate: declaring `credential.helper` does not override an external
value, it adds a second helper that also receives every credential.

## Resolution chain, lowest precedence first

| File | Owner | Holds |
|---|---|---|
| `roles/git/files/gitconfig` | tracked | identity, aliases, shared defaults |
| `~/.gitconfig.local` | the git role, rewritten on every run | host-resolved values: signer path, unattended key paths, credential helper |
| `~/.gitconfig.work` | the git role, included only for repositories under the work directory prefix | the work identity, from the machine-local `git-work-email` file |
| `~/.gitconfig` | you, and every other tool on the machine | whatever `git config --global` writes |

The untracked files are asserted 0600, since a tool writing `--global` can put
a credential in them; a re-run takes the tighter of 0600 and the current mode.

## Migration from the old symlink

The symlink is replaced only when its target ends in
`/roles/git/files/gitconfig`, a suffix match because the link may name a
different clone than the one running. Any other symlink belongs to another
tool, so the role leaves it in place and reports it rather than writing
through it; add the include there by hand. A pre-existing real file keeps
every key and only gains the block.
