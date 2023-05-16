# Shorthands
alias c 'z'
alias v 'vim'
alias vi 'nvim'
alias vim 'nvim'
alias nv 'nvim'
alias nvh 'nvim +checkhealth'
alias nvi 'nvim'
alias tmux 'tmux -2'

# Rails Aliases
alias brails '$PWD/bin/rails'
alias bexec 'bundle exec'
alias brspec 'bin/rspec'
alias bsidekiq 'bundle exec sidekiq'
alias brubocop 'bundle exec rubocop'
alias sorbetup 'brails sorbet:generate_rbi'

if status --is-login
    # Unix and C stuff
    set -xg LC_ALL en_US.UTF-8
    set -xg CODESET UTF-8
    set -xg EDITOR nvim
    set -xg FZF_DEFAULT_COMMAND 'bash -c "ag --files-with-matches --column --no-heading --nocolor --smart-case --ignore *.rbi --ignore node_modules"'
    set -xl OPENSSL_PATH (brew --prefix openssl@1.1)
    set -xl ZLIB_PATH (brew --prefix zlib)
    set -xl LLVM_PATH (brew --prefix llvm)
    set -xl UNIXODBC_PATH (brew --prefix unixodbc)
    set -xl SQLITE_PATH (brew --prefix sqlite3)
    set -xl READLINE_PATH (brew --prefix readline)
    set -xl MYSQL57_PATH /Users/Shared/DBngin/mysql/8.0.27
    set -gx PKG_CONFIG_PATH $ZLIB_PATH/lib/pkgconfig $READLINE_PATH/lib/pkgconfig $OPENSSL_PATH/lib/pkgconfig
    set -gx LDFLAGS '-L'$SQLITE_PATH/lib' -L'$MYSQL57_PATH/lib' -L'$ZLIB_PATH/lib' -L'$LLVM_PATH/lib' -L'$UNIXODBC_PATH/lib' -L'$READLINE_PATH/lib' -L'$OPENSSL_PATH/lib' -Wl,-rpath,'$MYSQL57_PATH/lib' -Wl,-rpath,'$SQLITE_PATH/lib' -Wl,-rpath,'$ZLIB_PATH/lib' -Wl,-rpath,'$LLVM_PATH/lib
    set -gx CPPFLAGS '-I'$SQLITE_PATH/include' -I'$MYSQL57_PATH/include' -I'$ZLIB_PATH/include' -I'$LLVM_PATH/include' -I'$UNIXODBC_PATH/include' -I'$READLINE_PATH/include' -I'$OPENSSL_PATH/include

    # GPG & git fix
    set -xg GPG_TTY (tty)

    # Go stuff
    set -xg GOPATH $HOME/dev/go
    set -xg GOBIN $GOPATH/bin
    set -xg GOROOT (brew --prefix go)/libexec
    mkdir -p $GOPATH

    # Python Stuff
    set -xg PYENV_ROOT $HOME/.pyenv
    set -xg WORKON_HOME $PYENV_ROOT
    set -xg PYENV_VERSION 3.10.3
    set -xg PIPENV_DEFAULT_PYTHON_VERSION $PYENV_VERSION
    set -xg PIPENV_SHELL_FANCY 1

    # Ruby stuff
    set -xg RBENV_ROOT $HOME/.rbenv
    set -xg RBENV_VERSION 3.2.2
    set -xg RUBY_CONFIGURE_OPTS "--with-openssl-dir="$OPENSSL_PATH
    set -xg THOR_SILENCE_DEPRECATION 1

    ## Mysql gem fixes
    set -xg LIBRARY_PATH $LIBRARY_PATH $OPENSSL_PATH/lib
    set -xg CPATH $CPATH $OPENSSL_PATH/include

    # Elixir/Erlang stuff
    set -xg KERL_BUILD_DOCS yes
    set -xg KERL_CONFIGURE_OPTIONS "--with-ssl="$OPENSSL_PATH" --without-wx --with-odbc="$UNIXODBC_PATH

    # Binaries paths
    set -l POSTGRES_BIN /Users/Shared/DBngin/postgresql/14.3/bin
    set -l PYTHON_LIB_EXEC /usr/local/opt/python/libexec/bin
    set -l MYSQL57_BIN_PATH $MYSQL57_PATH/bin
    set -l GLOBAL_NODE_BIN_PATH "$HOME/node_modules/.bin"

    # Rust stuff
    set -l CARGO_BIN $HOME/.cargo/bin

    fish_add_path /opt/homebrew/bin
    fish_add_path /opt/homebrew/sbin
    fish_add_path $SQLITE_PATH/bin
    fish_add_path $MYSQL57_BIN_PATH
    fish_add_path $HOME/dev/zenpayroll/bin
    fish_add_path $GLOBAL_NODE_BIN_PATH
    fish_add_path $GOPATH/bin
    fish_add_path $GOROOT/bin
    fish_add_path $CARGO_BIN
    fish_add_path $POSTGRES_BIN
    fish_add_path $PYTHON_LIB_EXEC
    fish_add_path $LLVM_PATH/bin
    fish_add_path (brew --prefix coreutils)/libexec/gnubin
    fish_add_path /usr/local/bin

    functions -q nvm; and nvm install > /dev/null

    pyenv init --path | source
end

ulimit -Sn 65535

status --is-interactive; and source (pyenv init -|psub)
status --is-interactive; and source (pyenv virtualenv-init -|psub)
status --is-interactive; and source (rbenv init -|psub)
status --is-interactive; and direnv hook fish | source

# Fish Theme
set -xg fish_greeting '¡Hoal!'
set -xg SPACEFISH_CHAR_SUFFIX '  '
starship init fish | source
pyenv init - | source
source (brew --prefix asdf)/libexec/asdf.fish
