# The editor is not provisioned by a role

The neovim role is gone and a replacement has not been chosen. `EDITOR`,
git's `core.editor`, and the `v` / `vim` / `nv` fish aliases name `vi`: the
Linux host carries only `vim.tiny` (exposed as `/usr/bin/vi`), and macOS ships
`/usr/bin/vi`, so `vi` is the one name that resolves on both.

`vim-tiny` is declared in `linux_apt_packages` for that reason. It is
priority:important, so the base system usually supplies it and the
declaration looks redundant, until a minbase chroot or a cloud image does not
and `git commit` dies with "cannot run vi".

`nv` is a call site, not a convenience: the `tm.fish` workspace functions type
that literal string into the left pane of every session they build, so
deleting the alias breaks them and no search for `nvim` finds the cause.

The removal un-declared; it did not uninstall. Nothing removes what the old
role installed, so a Mac that ran it keeps `nvim`, its install tree, its
plugin tree and the Brewfile packages, with `~/.config/nvim` dangling. `brew
bundle install` never removes, `mise install` never prunes, and the
`default-*` package lists only apply when a runtime is newly installed. Only
the Linux host was cleaned, by hand.

The language servers the old config drove were removed with it; the only one
still declared is `lua-language-server`.
