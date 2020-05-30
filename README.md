# .dotfiles ![Test ansible playbook](https://github.com/inkatze/dotfiles/workflows/Test%20ansible%20playbook/badge.svg?branch=master)

Installs almost everything I need in my local environment. It's unlikely that you want your
setup exactly as mine; feel free to fork it or change the variables described below.

## Requirements

- Homebrew
- Ansible 2.7+
- Xcode or Xcode command line tools
- Run `sudo installer -pkg /Library/Developer/CommandLineTools/Packages/macOS_SDK_headers_for_macOS_10.14.pkg -target /`
if you're using Mojave or higher (10.14+)
- If installing apps from the Mac App Store, you need to log into the store manually before running the role (This is not needed if you used an AppleID while doing the first setup)

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
- `neovim_dependencies`: List of packages to be installed with `brew install` required by vim to work correctly.

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

The one true editor.

- `neovim__python3_version`: Python 3 version used by neovim's python host program.
- `neovim_python3_virtualenv`: Name of the Python 3 virtual env to be crated with neovim's host program.
- `neovim__python2_version`: Python 2 version used by neovim's python host program.
- `neovim_python2_virtualenv`: Name of the Python 2 virtual env to be crated with neovim's host program.
- `neovim__ruby_version`: Ruby version used by neovim's ruby host program.
- `neovim_ruby_gemset`: Name of the gemset where neovim's gems are going to be installed.
- `neovim_plugins`: List of key-value pairs with the `name` of the plugin and the `repo`'s url.'
- `neovim_colorschemes`: List of repos containing neovim's color schemes.

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
- `iterm2_config_path`
- `neovim_init`
- `gitconfig_path`
- `pylintrc_path`
- `npmrc_path`

## License

BSD


[osx_defaults]: https://docs.ansible.com/ansible/2.6/modules/osx_defaults_module.html "osx_defaults Ansible module docs"
