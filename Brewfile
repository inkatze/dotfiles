# Core utilities
brew "ack"
# gtimeout, which planwright's ready-guard hook requires to bound its GitHub
# queries. macOS ships no timeout binary under either name.
brew "coreutils"
brew "fd"
brew "fzf"
brew "fzy"
brew "gnu-tar"
brew "htop"
brew "make"
brew "readline"
brew "ripgrep"
brew "the_silver_searcher"
brew "tree"
brew "unzip"
brew "wget"

# Shell
brew "fish"
brew "starship"

# Terminal
brew "tmux"
brew "urlview"

# Git
brew "git"
brew "git-extras"
brew "gh"
brew "lazygit"

# Development dependencies
brew "mkcert"
brew "nss"
brew "libxslt"
brew "llvm"
brew "wxwidgets"
brew "ruby-build"
brew "libsodium"
brew "watchman"

# Linters and language servers
brew "ansible-lint"
# Not editor tooling despite the neighbours: roles/claude/files/settings.json
# enables the lua-lsp Claude Code plugin on both platforms, and that plugin
# shells out to this binary. It fails silently when absent.
brew "lua-language-server"

# Version manager
brew "mise"

# Misc tools
brew "ansible"
brew "arttime"
brew "ddgr"
brew "direnv"
brew "fop"
brew "jq"
brew "mosh"
brew "nnn"
brew "pinentry-mac"
brew "pngpaste"
brew "redis"
brew "terminal-notifier"

# Databases
brew "mariadb@10.6"
brew "mysql@8.0"
brew "postgresql@18"

# AI tools (panel review / pairing backends)
brew "ollama"
brew "gemini-cli"
cask "codex"

# Common casks (all hosts)
# The 1Password desktop app is deliberately absent here. On the `work` host it
# is an MDM-forced install (munki `GustoManagedManifest`), so `brew bundle`
# aborts with "It seems there is already an App at
# /Applications/1Password.app" and takes the whole `osx` role down with it.
# The unmanaged hosts carry the cask in their own Brewfile instead.
#
# The CLI is a separate cask that munki does not ship on any host, so it stays
# common: roles/osx (health-signal Pushover sync) and roles/ssh both probe for
# `op` and degrade visibly when it is missing.
cask "1password-cli"
cask "firefox"
cask "font-fantasque-sans-mono"
cask "font-fira-code-nerd-font"
cask "keycastr"
cask "kitty"
cask "logi-options+"
# Microsoft Office is not installed on the `work` host: the company provides its
# own productivity suite, and the cask is a `.pkg` that needs sudo, which a
# `brew bundle` run from the playbook cannot supply non-interactively. Lives in
# the per-host Brewfiles instead.
#
# Notion is absent for the same reason as 1Password: a managed install on
# `work` makes `brew bundle` abort on the cask.
