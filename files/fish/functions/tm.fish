set -x WORKSPACE_WINDOW 'workspace'
set -x DOT_SESSION 'dotfiles'
set -x DOT_DIR $HOME'/dev/dotfiles'
set -x NV_DIR $HOME'/dev/ansible-neovim'

set -x ZP_SESSION 'zp'
set -x ZP_DIR $HOME'/dev/zenpayroll'
set -x ZP_BACKEND_WINDOW 'backend'

function sessionavailable
  set -xl session_name $argv[1]
  set -xl window_list (tmux list-windows -t $session_name 2>&1)

  if test $status -eq 1; return; end

  return 1
end

function windowavailable
  set -xl session_name $argv[1]
  set -xl window_name $argv[2]
  set -xl window_list (tmux list-windows -t $session_name 2>&1)

  if test $status -eq 1; return; end
  if string match -q '*'$window_name'*' $window_list; return 1; end
end

function tmdot
  echo 'Initializing dotfiles workspace'

  if not test -d $DOT_DIR
    echo 'Dotfiles not installed'
    echo 'git clone git@github.com:inkatze/dotfiles.git '$DOT_DIR
    return 1
  end

  if not test -d $NV_DIR
    echo 'Neovim dofiles not installed'
    echo 'git clone git@github.com:inkatze/ansible-neovim.git '$NV_DIR
    return 1
  end

  if not windowavailable $DOT_SESSION $WORKSPACE_WINDOW
    echo 'Dotfiles workspace already exists'
    return 1
  end

  if sessionavailable $DOT_SESSION
    tmux new-session -d -n $WORKSPACE_WINDOW -s $DOT_SESSION
  else
    tmux new-window -n $WORKSPACE_WINDOW -t $DOT_SESSION
  end

  tmux send-keys -t $DOT_SESSION':'$WORKSPACE_WINDOW'.1' 'cd '$DOT_DIR C-m C-l
  tmux split-window -h
  tmux send-keys -t $DOT_SESSION':'$WORKSPACE_WINDOW'.2' 'cd '$NV_DIR C-m C-l
  tmux select-pane -t $DOT_SESSION':'$WORKSPACE_WINDOW'.1'
end

function tmzp
  echo 'Initializing ZP workspace'

  if not test -d $ZP_DIR
    echo 'Zenpayroll folder does not exist'
    return 1
  end

  if not windowavailable $ZP_SESSION $WORKSPACE_WINDOW
    echo 'Zenpayroll workspace already exists'
    return 1
  end

  if sessionavailable $ZP_SESSION
    tmux new-session -d -s $ZP_SESSION -n $WORKSPACE_WINDOW
  else
    tmux new-window -t $ZP_SESSION -n $WORKSPACE_WINDOW
  end

  tmux split-window -h
  tmux split-window -v
  tmux setw synchronize-panes on
  tmux send-keys 'cd '$ZP_DIR C-m C-l
  tmux setw synchronize-panes off
  tmux select-pane -t 3
  tmux send-keys 'brails c' C-m C-l
  tmux select-pane -t 1
  tmux send-keys 'nv' C-m
end

function tmzpsrvr
  echo 'Initializing Zenpayroll backend'

  if not test -d $ZP_DIR
    echo 'Zenpayroll folder does not exist'
    return 1
  end

  if not windowavailable $ZP_SESSION $ZP_BACKEND_WINDOW
    echo 'Zenpayroll backend already started'
    return 1
  end

  if sessionavailable $ZP_SESSION
    tmux new-session -d -s $ZP_SESSION -n $ZP_BACKEND_WINDOW
  else
    tmux new-window -t $ZP_SESSION -n $ZP_BACKEND_WINDOW
  end

  tmux split-window -h
  tmux split-window -v
  tmux select-pane -t 1
  tmux split-window -v
  tmux setw synchronize-panes on
  tmux send-keys 'cd '$ZP_DIR C-m C-l
  tmux setw synchronize-panes off
  tmux select-pane -t 1
  tmux send-keys 'spring stop' C-m C-l
  tmux send-keys 'brails s' C-m
  tmux select-pane -t 2
  tmux send-keys 'yarn start' C-m
  tmux select-pane -t 3
  tmux send-keys 'bsidekiq' C-m
  tmux select-pane -t 4
  tmux send-keys 'bin/run-hapii' C-m
  tmux select-pane -t 1
end

function tm
  if test (count $argv) -eq 0; tmux attach; return; end

  set -xl session_name $argv[1]

  if test $session_name = 'dot'
    tmdot
  else if test $session_name = 'zp'
    tmzp
  else if test $session_name = 'srvr'
    tmzpsrvr
  else
    if sessionavailable $session_name
      echo 'Attaching session '$session_name
      tmux attach -t $session_name
    else
      echo 'Creating session '$session_name
      tmux new -s $session_name
    end
  end
end
