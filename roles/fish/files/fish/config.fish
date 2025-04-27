# Shorthands
alias c 'z'
alias v 'vim'
alias vi 'nvim'
alias vim 'nvim'
alias nv 'nvim'
alias nvh 'nvim +checkhealth'
alias nvi 'nvim'
alias tmux 'tmux -2'
alias lg 'lazygit'

# Rails Aliases
alias brails '$PWD/bin/rails'
alias bexec 'bundle exec'
alias brspec 'bin/rspec'

if status --is-login
    # Unix and C stuff
    set -xg LC_ALL en_US.UTF-8
    set -xg CODESET UTF-8
    set -xg EDITOR nvim
    set -xg FZF_DEFAULT_COMMAND 'bash -c "ag --files-with-matches --column --no-heading --nocolor --smart-case --ignore *.rbi --ignore node_modules"'
    set -xl OPENSSL_PATH (brew --prefix openssl@3)
    set -xl ZLIB_PATH (brew --prefix zlib)
    set -xl SQLITE_PATH (brew --prefix sqlite)
    set -xl READLINE_PATH (brew --prefix readline)
    set -xl MYSQL_PATH (brew --prefix mysql@8.0)
    set -xl POSTGRESQL_PATH (brew --prefix postgresql@17)
    set -xl MARIADB_PATH (brew --prefix mariadb@10.6)
    set -gx PKG_CONFIG_PATH $SQLITE_PATH/lib/pkgconfig $POSTGRESQL_PATH/lib/pkgconfig $MYSQL_PATH/lib/pkgconfig $MARIADB_PATH/lib/pkgconfig $ZLIB_PATH/lib/pkgconfig $READLINE_PATH/lib/pkgconfig $OPENSSL_PATH/lib/pkgconfig
    set -gx LDFLAGS '-L'$SQLITE_PATH/lib' -L'$POSTGRESQL_PATH/lib' -L'$MYSQL_PATH/lib' -L'$MARIADB_PATH/lib' -L'$ZLIB_PATH/lib' -L'$READLINE_PATH/lib' -L'$OPENSSL_PATH/lib
    set -gx CPPFLAGS '-I'$SQLITE_PATH/include' -I'$POSTGRESQL_PATH/include' -I'$MYSQL_PATH/include' -I'$MARIADB_PATH/include' -I'$ZLIB_PATH/include' -I'$READLINE_PATH/include' -I'$OPENSSL_PATH/include
    set -gx DYLD_FALLBACK_LIBRARY_PATH $OPENSSL_PATH/lib

    # Go stuff
    set -xg GOPATH $HOME/dev/go
    set -xg GOBIN $GOPATH/bin
    set -xg GOROOT (brew --prefix go)/libexec
    mkdir -p $GOPATH

    # Ruby stuff
    set -xg RUBY_CONFIGURE_OPTS "--with-openssl-dir="$OPENSSL_PATH
    set -xg THOR_SILENCE_DEPRECATION 1

    # Elixir/Erlang stuff
    set -xg KERL_BUILD_DOCS yes
    set -xg KERL_INSTALL_MANPAGES yes
    set -xg KERL_USE_AUTOCONF 0
    set -xg EGREP egrep
    set -xg KERL_CONFIGURE_OPTIONS "--with-javac --with-ssl="$OPENSSL_PATH

    # Binaries paths
    set -l POSTGRES_BIN $POSTGRESQL_PATH/bin
    set -l MYSQL_BIN_PATH $MYSQL_PATH/bin
    set -l MARIADB_BIN_PATH $MARIADB_PATH/bin

    # Rust stuff
    set -l CARGO_BIN $HOME/.cargo/bin

    # Python stuff
    set -xg PYENV_ROOT $HOME/.pyenv

    # Node stuff
    set -xg MISE_NODEJS_AUTO_ENABLE_COREPACK 1

    # Terraform stuff
    set -xg MISE_HASHICORP_SKIP_VERIFY 1

    fish_add_path $PYENV_ROOT/bin
    fish_add_path $SQLITE_PATH/bin
    fish_add_path -m $MYSQL_BIN_PATH
    fish_add_path $GOPATH/bin
    fish_add_path $GOROOT/bin
    fish_add_path $CARGO_BIN
    fish_add_path $POSTGRES_BIN
    fish_add_path /usr/local/bin
    fish_add_path -m $OPENSSL_PATH/bin
    fish_add_path -a (brew --prefix)/bin
    fish_add_path -a (brew --prefix)/sbin
    fish_add_path -a (brew --prefix)/sbin
    fish_add_path -a $MARIADB_BIN_PATH
    fish_add_path -a /usr/bin
end

ulimit -Sn 65535

starship init fish | source

status --is-interactive; and source $HOME/.config/op/plugins.sh
status --is-interactive; and direnv hook fish | source

# Fish Theme
set -xg fish_greeting '¡Hoal!'
set -xg SPACEFISH_CHAR_SUFFIX '  '
