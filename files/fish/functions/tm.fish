set -x WORKSPACE_WINDOW 'workspace'
set -x DOT_SESSION 'dotfiles'
set -x DOT_DIR $HOME'/dev/dotfiles'
set -x NV_DIR $HOME'/dev/ansible-neovim'

set -x ZP_SESSION 'zp'
set -x ZP_DIR $HOME'/dev/zenpayroll'
set -x ZP_BACKEND_WINDOW 'backend'

function panecount
  set -xl session_name $argv[1]
  set -xl window_name $argv[2]
  set -xl expected_count $argv[3]

  set -xl pane_count (tmux display-message -t $session_name':'$window_name -p '#{window_panes}')

  if string match -q '*'$expected_count'*' $pane_count; return; end

  return 1
end

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

  set -xl target $DOT_SESSION':'$WORKSPACE_WINDOW

  tmux split-window -t $target -h
  tmux send-keys -t $target'.left' 'cd '$DOT_DIR Enter C-l
  tmux send-keys -t $target'.right' 'cd '$NV_DIR Enter C-l
  tmux select-pane -t $target'.left'
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

  set -xl target $ZP_SESSION':'$WORKSPACE_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$ZP_DIR Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'brails c' Enter C-l
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'
end

function stopservices
  set -xl target $ZP_SESSION':'$ZP_BACKEND_WINDOW
  tmux setw synchronize-panes on
  tmux send-keys -t $target C-c Enter C-l
  tmux setw synchronize-panes off
end

function startsrvr
  set -xl target $ZP_SESSION':'$ZP_BACKEND_WINDOW
  tmux select-pane -t $target'.top-left'
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$ZP_DIR Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.top-left' 'spring stop' Enter C-l
  tmux send-keys -t $target'.top-left' 'brails s' C-l Enter
  tmux send-keys -t $target'.top-right' 'yarn start' C-l Enter
  tmux send-keys -t $target'.bottom-left' 'bsidekiq' C-l Enter
  tmux send-keys -t $target'.bottom-right' 'bin/run-hapii' C-l Enter
  tmux select-pane -t $target'.top-left'
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

  set -xl target $ZP_SESSION':'$ZP_BACKEND_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux split-window -t $target'.left' -v

  startsrvr
end

function tmrssrvr
  echo 'Restarting Zenpayroll backend'

  if not test -d $ZP_DIR
    echo 'Zenpayroll folder does not exist'
    return 1
  end

  if windowavailable $ZP_SESSION $ZP_BACKEND_WINDOW
    echo 'Zenpayroll backend not started'
    return 1
  end

  if not panecount $ZP_SESSION $ZP_BACKEND_WINDOW 4
    echo 'Unexpected pane count'
    return 1
  end

  stopservices
  startsrvr
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
  else if test $session_name = 'rssrvr'
    tmrssrvr
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
