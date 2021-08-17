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
    set -xg PYENV_VERSION 3.9.6
    set -xg PIPENV_DEFAULT_PYTHON_VERSION $PYENV_VERSION
    set -xg PIPENV_SHELL_FANCY 1

    ## Pyenv fixes
    set -xl ZLIB_PATH (brew --prefix zlib)
    set -gx PKG_CONFIG_PATH $ZLIB_PATH/lib/pkgconfig
    set -gx LDFLAGS '-L'$ZLIB_PATH/lib
    set -gx CPPFLAGS '-I'$ZLIB_PATH/include

    # Ruby stuff
    set -xg RBENV_ROOT $HOME/.rbenv
    set -xg THOR_SILENCE_DEPRECATION 1

    ## Mysql gem fixes
    set -xl OPENSSL_PATH (brew --prefix openssl@1.1)
    set -xg LIBRARY_PATH $LIBRARY_PATH $OPENSSL_PATH/lib
    set -xg CPATH $CPATH $OPENSSL_PATH/include

    # Binaries paths
    set -l POSTGRES_BIN /Applications/Postgres.app/Contents/Versions/latest/bin
    set -l PYTHON_LIB_EXEC /usr/local/opt/python/libexec/bin
    set -l MYSQL57_BIN_PATH /Users/Shared/DBngin/mysql/5.7.23/bin
    set -l GLOBAL_NODE_BIN_PATH "$HOME/node_modules/.bin"

    # Rust stuff
    set -l CARGO_BIN $HOME/.cargo/bin

    set -e fish_user_paths
    set -U fish_user_paths $MYSQL57_BIN_PATH
    set -U fish_user_paths $fish_user_paths $GLOBAL_NODE_BIN_PATH
    set -U fish_user_paths $fish_user_paths /usr/local/bin /usr/local/sbin
    set -U fish_user_paths $fish_user_paths $GOPATH/bin $GOROOT/bin $CARGO_BIN
    set -U fish_user_paths $fish_user_paths $POSTGRES_BIN $PYTHON_LIB_EXEC

    functions -q nvm; and nvm install > /dev/null

    pyenv init --path | source
end

function tm
  echo
  if set -q $argv[1]
    tmux a
  else
    tmux new -s $argv
  end
end

function gitpersonal
  git config user.email 'jd@inkatze.com'
  git config user.signingkey 'FF6211FF90D065A7'
  git config github.user 'inkatze'
end

function gitgusto
  git config user.email 'diego.romero@gusto.com'
  git config user.signingkey '75C52BBF1189578C'
  git config github.user 'diego-romero-gusto'
end

status --is-interactive; and source (pyenv init -|psub)
status --is-interactive; and source (pyenv virtualenv-init -|psub)
status --is-interactive; and source (rbenv init -|psub)
status --is-interactive; and direnv hook fish | source

# Fish Theme
set -xg fish_greeting '¡Hoal!'
set -xg SPACEFISH_CHAR_SUFFIX '  '
starship init fish | source
pyenv init - | source
