# .dotfiles ![test](https://github.com/inkatze/dotfiles/workflows/test/badge.svg?branch=main)

Installs almost everything I need in my local environment. It's unlikely that you want your
setup exactly as mine; feel free to fork it or change the variables described below.

## Requirements

- Homebrew
- Ansible 2.7+
- Xcode or Xcode command line tools
- Run `sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /`
if you're using Mojave or higher (10.14+)
- If installing apps from the Mac App Store, you need to log into the store manually before running the role (This is not needed if you used an AppleID while doing the first setup)

## Linux host bootstrap

The migrated Linux host (`specs/linux-migration`) is managed by the same
playbook through the `linux` platform role (apt baseline: fish, tmux, core
CLI, `openssh-server`; mise; sshd hardening drop-in; Tailscale; the
1Password CLI). The `os_family` guards in `main.yml` run `linux` on Debian
-family hosts and skip the macOS `osx` role.

1. Install Ansible and mise (`curl https://mise.run | sh`), then run
   `mise install` in the repo to get the pinned tooling (lefthook,
   gitleaks).
2. Name this machine's inventory alias without committing its hostname
   (REQ-F1.1): `mkdir -p ~/.config/dotfiles && echo server >
   ~/.config/dotfiles/host` (or export `DOTFILES_HOST=server`).
3. Run `./scripts/playbook.sh` (or `mise run install`). It reads the alias
   file and targets the `server` inventory host.

Driving the first run's failures to zero (apt-lock contention,
cross-platform config roles) is the `specs/linux-migration` Task 7
stabilization loop.

## Machine-local files (`~/.config/dotfiles/`)

This repo is public, so `specs/linux-migration` REQ-F1.1 keeps real
hostnames and LAN addresses out of committed artifacts. The values that
name a specific machine live in untracked files under
`~/.config/dotfiles/` instead. None are created by Ansible; each is
optional, and its absence degrades visibly rather than silently.

| File | Read by | Holds |
|---|---|---|
| `host` | `scripts/playbook.sh`, `roles/fish/files/ollama.fish`, the `/panel-review` and `/code-review` commands | This machine's inventory alias: `work`, `personal`, `alt` or `server` |
| `ssh-host` | the `sshc` fish function | Hostname `kitten ssh` connects to |
| `kitty-ssh.conf` | kitty's `ssh.conf`, via `globinclude` | Host-specific kitty `ssh.conf` sections (see that file for an example) |
| `op-service-account-token` | `scripts/ssh-lan-config-sync.sh`, `scripts/claude-gemini-auth-sync.sh` | 1Password service-account token, mode 0600. The only secret here, and the only way these two syncs can authenticate on a headless host, where there is no desktop app to approve them. Both roles probe for `op` first and skip with a notice when it is missing; but on a host that *has* `op` and no token, both syncs fail their task, because from `op`'s side that is indistinguishable from a locked vault. On a Mac with the desktop app unlocked, neither needs this file at all. See the repo `CLAUDE.md` for how to mint one. |

`host` is the one that matters most: `scripts/playbook.sh` uses it to pick
the inventory host, falling back to `work` (with a warning) when nothing
resolves, and `ollama.fish` uses it to decide whether this box is an Ollama
client. Set it on every host except `work`:

```bash
mkdir -p ~/.config/dotfiles && echo personal > ~/.config/dotfiles/host
```

## Quickstart

If you just want to know what you need to install, change and run to get things started,
this is what you're looking for.

### TL;DR

This means you want your Mac setup EXACTLY as mine (- my keys). You're weird, but as you wish:

```bash
# Unless you have a brand new installation, or never touched the terminal before
# this is likely to fail, but is safe to run if you're unsure.
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

# While installing Homebrew, xcode will be installed. The following line should not be needed.
xcode-select --install

# This is the good stuff
brew update
brew install ansible
git clone https://github.com/inkatze/dotfiles.git
cd dotfiles
make
```

### Installing dependencies

Before running anything, make sure you have installed all requirements. Follow the instructions
from [homebrew's home page](https://brew.sh/) and run:

```bash
brew update
brew install ansible
xcode-select --install  # This might fail if already installed
git clone https://github.com/inkatze/dotfiles.git
```

From now on, assume everything is run inside the root of the repository.

### What should be changed?

You should take a look at the [default variables](defaults/main.yml) and change the values for
the tools, files or settings you want in your environment. You can find a full reference of
the variables used in this role in the `Role variables` section

You can do that by adding those values to the [vars file](playbook/vars.yml) in the example
playbook.

Finally, you can place your custom files (if any) anywhere inside the role, as long as the relative
path matches with the one defined in the correct variable. More about this in the variables section.
I put mine in the [playbook directory](playbook) in case that's useful for you.

It is also recommended to change the [gitconfig details](files/gitconfig) since it is set to use my information and you may prefer use your own.

### How do I run it

There's a convenient [Makefile](Makefile) which defines all possible tasks that can be run using
this role. You can directly use the ansible command you want, all it does is to run persist all
available ansible tags

If this wasn't run on a fresh install, is possible that some tasks don't finish successfully. Don't
forget to restart after an initial installation (or log out and into your session).

The examples assume you have added your files and setup a custom [vars file](playbook/vars.yml).
If you're an advanced Ansible user, you should check out the [playbook directory](playbook) and go
from there.

```bash
# Examples

# make and make install run everthing
make

# Install fish stuff
make fish

# Update or install your dotfiles
make dotfiles

# check the rest of the Makfile rules, it should be clearer after reading the docs.
cat Makefile
```

## Tasks and variables

To make things easier to understand, variables will be explained within the context of the task
using them.

### Homebrew

Installs all packages and cask applications required for the environment.

- `homebrew_taps`: List of taps to install applications that need a different source.
- `basic_tools`: List of packages that can be installed with `brew install`.
- `homebrew_cask_applications`: List of OS X applications that can be installed using `brew cask install`.
- `programming_environments`: List of programming environments to be installed using `brew install`.

### MAS

Installs apps from the Mac App Store. You need to login to the store manually if using macOS 10.13_+.

- `mas__applications`: Hash list with the ids of the macOS apps to install. The name key is optional and only used as reference to the user.

### OS X

Updates OS X configuration defaults to match your preferences. Things like how to right click,
region, language and so on.

- `osx_defaults`: List of key-value pairs with the parameters used by the [osx_defaults][osx_defaults] ansible module.
- `osx_dict_defaults`: List of dictionary like values that ignore idempotency until supported.

### Fish

Changes the default login shell to fish instead of bash.

- `fish_plugins`: List of plugins to be installed to the fish shell.
- `fish completions`: A file with a series of commands to add autocompletion the configured commands.
- `fish_configs`: Contains a list of paths where fish's local configuration files exists.

### Neovim

The one true editor. Installs the `stable` release tarball under `~/.local`,
links the binary and the config, then drives `nvim` headlessly to restore and
install plugins. Plugins themselves are lazy.nvim's business, pinned by
`roles/neovim/files/nvim/lazy-lock.json`.

- `neovim_os_token` / `neovim_archive`: Build the `nvim-<os>-<arch>` release
  asset name from the platform facts.
- `neovim_install_dir`: Where the archive is extracted.
- `neovim_release_base` / `neovim_download_url`: The release asset to fetch.
- `neovim_archive_cache_dir` / `neovim_archive_cache`: Where the tarball is
  kept between runs, so the extract can be skipped when the release has not
  changed.
- `neovim_install_needed`: Whether to replace the install directory this run.
- `neovim_bin_link`: Where the binary is linked (`/usr/local/bin` on macOS,
  `~/.local/bin` on Linux).
- `neovim_bin`: The extracted binary, used by the tasks that drive nvim
  headlessly.

- `neovim_staging_dir`: Where the archive is extracted before being moved
  into place.

The install directory is **replaced, not written over**: the archive is
extracted into staging and moved in with a rename. Neovim reorganises its
runtime between releases, and `unarchive` on its own leaves everything
upstream renamed or deleted still sitting on `runtimepath`, which
`:checkhealth` reports as "Found old files in $VIMRUNTIME". Staging is what
keeps a failed download or extract from leaving no editor behind at all.

### SSH

Copy your ssh keys and configuration to your local machine.

- `ssh_keys`: List of relative paths to your ssh private and public keys.
- `ssh_config`: Relative path to the file with your ssh configuration.

### GPG

Imports your GPG keys to your local machine.

- `gpg_public_key`: Relative path to the file with your gpg public key.
- `gpg_private_key`: Relative path to the file with your gpg private key.

### Dotfiles

The following list of variables store relative paths to the relevant dorfiles.

- `fish_config_path`
- `gitconfig_path`
- `pylintrc_path`
- `npmrc_path`

## License

BSD


[osx_defaults]: https://docs.ansible.com/ansible/2.6/modules/osx_defaults_module.html "osx_defaults Ansible module docs"
