set -x WORKSPACE_WINDOW 'workspace'
set -x DOT_SESSION 'dotfiles'
set -x DOT_DIR $HOME'/dev/dotfiles'
set -x NV_DIR $HOME'/dev/ansible-neovim'

set -x ZP_SESSION 'zp'
set -x ZP_DIR $HOME'/dev/zenpayroll'
set -x ZP_BACKEND_SESSION 'backend'
set -x ZP_SERVER_WINDOW 'server'

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
  if not test -d $DOT_DIR
    set -xl clone_command "git clone git@github.com:inkatze/dotfiles.git $DOT_DIR"
    notify 'Dotfiles' 'Dotfiles project not installed' 'https://github.com/inkatze/dotfiles' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not test -d $NV_DIR
    set -xl clone_command "git clone git@github.com:inkatze/ansible-neovim.git $NV_DIR"
    notify 'Dotfiles' 'Neovim ansible project not installed' 'https://github.com/inkatze/ansible-neovim' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $DOT_SESSION $WORKSPACE_WINDOW
    notify 'Dotfiles' 'Dotfiles workspace already created' -sound Purr -group tm -execute tm
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

  notify 'Dotfiles' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmzp
  if not test -d $ZP_DIR
    set -xl clone_command "git clone git@github.com:Gusto/zenpayroll $NV_DIR"
    notify 'Zenpayroll' 'Project not installed' 'https://github.com/Gusto/zenpayroll' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $ZP_SESSION $WORKSPACE_WINDOW
    notify 'Zenpayroll' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux clock-mode -t $target'.bottom-right'
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'Zenpayroll' 'Workspace created' -sound Blow -group tm -execute tm
end

function stopservices
  set -xl target $ZP_BACKEND_SESSION':'$ZP_SERVER_WINDOW
  tmux setw synchronize-panes on
  tmux send-keys -t $target C-c Enter C-l
  tmux setw synchronize-panes off
  notify 'Zenpayroll' 'Backend stopped' -sound Purr
end

function startsrvr
  set -xl target $ZP_BACKEND_SESSION':'$ZP_SERVER_WINDOW
  tmux select-pane -t $target'.top-left'
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$ZP_DIR Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.top-left' 'brails s' Enter C-l
  tmux send-keys -t $target'.top-right' 'bin/sidekiq' C-l Enter
  tmux send-keys -t $target'.bottom-left' 'bin/run-hapii' C-l Enter
  tmux clock-mode -t $target'.bottom-right'
  tmux select-pane -t $target'.top-left'
  notify 'Zenpayroll' 'Backend started' -sound Blow -execute tm
end

function tmzpsrvr
  if not test -d $ZP_DIR
    set -xl clone_command "git clone git@github.com:Gusto/zenpayroll $NV_DIR"
    notify 'Zenpayroll' 'Project not installed' 'https://github.com/Gusto/zenpayroll' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $ZP_BACKEND_SESSION $ZP_SERVER_WINDOW
    notify 'Zenpayroll' 'Backend already started' -sound Purr -group tm -execute tm
    return 1
  end

  if sessionavailable $ZP_BACKEND_SESSION
    tmux new-session -d -s $ZP_BACKEND_SESSION -n $ZP_SERVER_WINDOW
  else
    tmux new-window -t $ZP_BACKEND_SESSION -n $ZP_SERVER_WINDOW
  end

  set -xl target $ZP_BACKEND_SESSION':'$ZP_SERVER_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux split-window -t $target'.left' -v

  startsrvr
end

function tmrssrvr
  if not panecount $ZP_BACKEND_SESSION $ZP_SERVER_WINDOW 4
    notify 'Zenpayroll' 'Backend not started' -sound Sosumi
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
      notify 'tmux' "Attaching session $session_name" -sound Blow
      tmux attach -t $session_name
    else
      notify 'tmux' "Creating session $session_name" -sound Blow
      tmux new -s $session_name
    end
  end
end
