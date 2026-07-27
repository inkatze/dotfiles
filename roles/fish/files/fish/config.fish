# Shorthands
for abbr_name in (abbr --list)
    abbr --erase $abbr_name
end

alias c 'z'
alias v 'vim'
alias vi 'nvim'
alias vim 'nvim'
alias nv 'nvim'
alias nvh 'nvim +checkhealth'
alias nvi 'nvim'
alias tmux 'tmux -2'
alias lg 'lazygit'
# `sshc` used to hardcode a real LAN hostname; the target now comes from a
# machine-local indirection so no hostname is committed (linux-migration
# REQ-F1.1). Resolution mirrors scripts/playbook.sh: the DOTFILES_SSH_HOST
# env var first, then the untracked ~/.config/dotfiles/ssh-host file.
function sshc --description 'kitten ssh to the machine-local SSH host, with ANTHROPIC_API_KEY from 1Password'
    set -l _ssh_host_file $HOME/.config/dotfiles/ssh-host
    set -l _ssh_host $DOTFILES_SSH_HOST
    if test -z "$_ssh_host"; and test -f $_ssh_host_file
        set _ssh_host (tr -d '[:space:]' <$_ssh_host_file)
    end
    if test -z "$_ssh_host"
        echo "sshc: no SSH host configured; set DOTFILES_SSH_HOST or write the hostname to $_ssh_host_file" >&2
        return 1
    end
    env ANTHROPIC_API_KEY=(op read "op://Private/Anthropic API key/credential" --no-newline) kitten ssh $_ssh_host $argv
end
abbr -a kssh 'kitten ssh'

# Rails Aliases
abbr -a brails 'bin/rails'
abbr -a bexec 'bundle exec'
abbr -a brspec 'bin/rspec'
abbr -a gfilings 'bin/rails pufferfish:generate_filing_artifacts'

# Homebrew prefix lookup that stays silent where Homebrew does not exist
# (Linux), instead of erroring on every login shell. Callers that need a real
# prefix are guarded on `uname` below; this only keeps the lookups quiet.
function __brew_prefix --description 'brew --prefix, or nothing when brew is unavailable'
    if type -q brew
        brew --prefix $argv
    end
end

if status --is-login
    # Unix and C stuff
    set -xg LC_ALL en_US.UTF-8
    set -xg CODESET UTF-8
    set -xg EDITOR nvim
    set -xg FZF_DEFAULT_COMMAND 'bash -c "ag --files-with-matches --column --no-heading --nocolor --smart-case --ignore *.rbi --ignore node_modules"'
    # Homebrew-provided library prefixes. Empty on Linux (no brew), where the
    # system toolchain already resolves these; every consumer below that would
    # otherwise derive a bogus path from an empty prefix is guarded on `uname`.
    set -xl OPENSSL_PATH (__brew_prefix openssl@3)
    set -xl ZLIB_PATH (__brew_prefix zlib)
    set -xl SQLITE_PATH (__brew_prefix sqlite)
    set -xl READLINE_PATH (__brew_prefix readline)
    set -xl MYSQL_PATH (__brew_prefix mysql@8.0)
    set -xl POSTGRESQL_PATH (__brew_prefix postgresql@18)
    set -xl MARIADB_PATH (__brew_prefix mariadb@10.6)
    if test (uname) = Darwin
        set -gx PKG_CONFIG_PATH $SQLITE_PATH/lib/pkgconfig $POSTGRESQL_PATH/lib/pkgconfig $MYSQL_PATH/lib/pkgconfig $MARIADB_PATH/lib/pkgconfig $ZLIB_PATH/lib/pkgconfig $READLINE_PATH/lib/pkgconfig $OPENSSL_PATH/lib/pkgconfig
        set -gx LDFLAGS '-L'$SQLITE_PATH/lib' -L'$POSTGRESQL_PATH/lib' -L'$MYSQL_PATH/lib' -L'$MARIADB_PATH/lib' -L'$ZLIB_PATH/lib' -L'$READLINE_PATH/lib' -L'$OPENSSL_PATH/lib
        set -gx CPPFLAGS '-I'$SQLITE_PATH/include' -I'$POSTGRESQL_PATH/include' -I'$MYSQL_PATH/include' -I'$MARIADB_PATH/include' -I'$ZLIB_PATH/include' -I'$READLINE_PATH/include' -I'$OPENSSL_PATH/include
        # DYLD_FALLBACK_LIBRARY_PATH is a macOS dyld concept; no Linux analogue
        # is set (the system linker finds these libraries on its own).
        set -gx DYLD_FALLBACK_LIBRARY_PATH $OPENSSL_PATH/lib
    end

    # Go stuff
    set -xg GOPATH $HOME/dev/go
    set -xg GOBIN $GOPATH/bin
    if test (uname) = Darwin
        set -xg GOROOT (brew --prefix go)/libexec
    end
    mkdir -p $GOPATH

    # Ruby stuff
    if test (uname) = Darwin
        set -xg RUBY_CONFIGURE_OPTS "--with-openssl-dir="$OPENSSL_PATH
    end
    set -xg THOR_SILENCE_DEPRECATION 1

    # Elixir/Erlang stuff
    set -xg KERL_BUILD_DOCS yes
    set -xg KERL_INSTALL_MANPAGES yes
    set -xg KERL_USE_AUTOCONF 0
    set -xg EGREP egrep
    if test (uname) = Darwin
        set -xg KERL_CONFIGURE_OPTIONS "--with-javac --with-ssl="$OPENSSL_PATH
    end

    # Binaries paths (Homebrew-provided; empty on Linux, and only consumed by
    # the Darwin arm of the fish_add_path block below)
    set -l POSTGRES_BIN $POSTGRESQL_PATH/bin
    set -l MYSQL_BIN_PATH $MYSQL_PATH/bin
    set -l MARIADB_BIN_PATH $MARIADB_PATH/bin

    # Rust stuff
    set -l CARGO_BIN $HOME/.cargo/bin

    # Python stuff
    set -xg PYENV_ROOT $HOME/.pyenv

    # Node stuff
    set -xg MISE_NODE_COREPACK 1

    # Terraform stuff
    set -xg MISE_HASHICORP_SKIP_VERIFY 1

    if test (uname) = Darwin
        fish_add_path $PYENV_ROOT/bin
        fish_add_path $SQLITE_PATH/bin
        fish_add_path -m $MYSQL_BIN_PATH
        fish_add_path $GOPATH/bin
        fish_add_path $GOROOT/bin
        fish_add_path $CARGO_BIN
        fish_add_path $POSTGRES_BIN
        fish_add_path $HOME/.local/bin
        fish_add_path /usr/local/bin
        fish_add_path -m $OPENSSL_PATH/bin
        fish_add_path -a (brew --prefix)/bin
        fish_add_path -a (brew --prefix)/sbin
        fish_add_path -a (brew --prefix)/sbin
        fish_add_path -a $MARIADB_BIN_PATH
        fish_add_path -a /usr/bin
    else
        # Same relative order as the Darwin arm, minus every Homebrew-provided
        # entry (those prefixes are empty here, so keeping them would prepend
        # bare /bin, /sbin, ... to PATH).
        fish_add_path $PYENV_ROOT/bin
        fish_add_path $GOPATH/bin
        fish_add_path $CARGO_BIN
        fish_add_path $HOME/.local/bin
        fish_add_path /usr/local/bin
        fish_add_path -a /usr/bin
    end
end

ulimit -Sn 65535

starship init fish | source

# op shell plugins let the 1Password CLI stand in for a tool's own credential
# storage (`op plugin init <tool>`). The file it writes is generated per-machine
# and deliberately untracked, so it is absent on every host where no plugin has
# been set up -- which was every host but the one this line was written on.
# Sourcing it unguarded printed "source: No such file or directory" on each
# interactive shell. Guarded rather than removed, because the indirection is
# still wanted wherever a plugin HAS been initialised.
status --is-interactive; and test -f $HOME/.config/op/plugins.sh; and source $HOME/.config/op/plugins.sh
status --is-interactive; and direnv hook fish | source

status --is-interactive; mise activate fish | source
status --is-interactive; and mise completion fish > ~/.config/fish/completions/mise.fish

# Fish Theme
set -xg fish_greeting '¡Hoal!'
set -xg SPACEFISH_CHAR_SUFFIX '  '

# Stabilize SSH_AUTH_SOCK for tmux sessions via a fixed symlink.
# When reconnecting SSH, the new socket is symlinked to a stable path so
# existing tmux panes don't get a stale SSH_AUTH_SOCK. Always prefer the
# 1Password agent (the real key source) and NEVER capture the empty macOS
# launchd agent (0 keys) — capturing it breaks auth + op-ssh-sign signing.
# Mirrors the IdentityAgent logic in ~/.ssh/config.
# The 1Password agent socket lives in a different place per platform: a Group
# Container on macOS, ~/.1password/agent.sock on Linux. The launchd guard
# below is macOS-only and simply never matches on Linux.
if status --is-interactive; and set -q SSH_CONNECTION
    set -l _onep_sock "$HOME/.1password/agent.sock"
    if test (uname) = Darwin
        set _onep_sock "$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    end
    if test -S "$_onep_sock"
        ln -sf "$_onep_sock" ~/.ssh/auth_sock
    else if test -S "$SSH_AUTH_SOCK"; and not string match -q '*com.apple.launchd*' "$SSH_AUTH_SOCK"; and not string match -q '*/.ssh/auth_sock' "$SSH_AUTH_SOCK"
        ln -sf "$SSH_AUTH_SOCK" ~/.ssh/auth_sock
    end
    set -gx SSH_AUTH_SOCK ~/.ssh/auth_sock
end

# Start tnotify watcher for Claude Code notifications (only in tmux, only once)
if status --is-interactive; and set -q TMUX
    set -l _tnotify_pid (cat ~/.cache/tnotify.pid 2>/dev/null)
    if test -z "$_tnotify_pid"; or not kill -0 "$_tnotify_pid" 2>/dev/null
        rm -f ~/.cache/tnotify.pid
        nohup fish -c "tnotify-watch" &>/dev/null &
        disown
    end
end
