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
brew "gemini-cli"
cask "codex"

# MAS CLI
brew "mas"

# Common MAS apps (all hosts)
mas "Black Out", id: 1319884285
mas "Fantastical", id: 975937182
mas "Flycut", id: 442160987
# Keynote and Pages moved to their universal ADAM IDs. Apple retired the
# Mac-only listings (Keynote 409183694, Pages 409201541) when the iWork apps
# became universal; `mas info` on either now returns "No apps found in the App
# Store for ADAM ID", which fails the line and takes the whole `brew bundle`
# task down with it. The IDs below are what `mas list` reports for the copies
# macOS 27 ships preinstalled, so these entries are no-ops on a current Mac.
mas "Keynote", id: 361285480
mas "Lungo", id: 1263070803
mas "MindNode 5", id: 1289197285
mas "Moneywiz", id: 1511185140
mas "Pages", id: 361309726
mas "Spark", id: 6445813049
mas "Xcode", id: 497799835

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
