set -x WORKSPACE_WINDOW 'workspace'
set -x DOT_SESSION 'dotfiles'
set -x DOT_DIR $HOME'/dev/dotfiles'

set -x ZP_SESSION 'zp'
set -x ZP_DIR $HOME'/dev/zenpayroll'
set -x ZP_BACKEND_SESSION 'backend'
set -x ZP_SERVER_WINDOW 'server'

set -x PBB_SESSION 'pbb'
set -x PBB_DIR $HOME'/dev/payroll_building_blocks'
set -x PBB_WINDOW 'workspace'

set -x PCC_SESSION 'pcc'
set -x PCC_WINDOW 'workspace'
set -x PCC_DIR $HOME'/dev/paycheckcity.com'

set -x PCCP_FE_SESSION 'pccp-fe'
set -x PCCP_FE_WINDOW 'workspace'
set -x PCCP_FE_DIR $HOME'/dev/pcc-profiles-client-app'

set -x PCCP_BE_SESSION 'pccp-be'
set -x PCCP_BE_WINDOW 'workspace'
set -x PCCP_BE_DIR $HOME'/dev/pcc-profiles-resource-server'

set -x WBS_FE_SESSION 'wsb-fe'
set -x WBS_FE_WINDOW 'workspace'
set -x WBS_FE_DIR $HOME'/dev/notification-service-ui'

set -x WBS_BE_SESSION 'wsb-be'
set -x WBS_BE_WINDOW 'workspace'
set -x WBS_BE_DIR $HOME'/dev/notification-service'

set -x CMS_SESSION 'cms'
set -x CMS_WINDOW 'workspace'
set -x CMS_DIR $HOME'/dev/symmetry_content_manager'

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
    echo 'Dotfiles: Dotfiles project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $DOT_SESSION $WORKSPACE_WINDOW
    echo 'Dotfiles: Dotfiles workspace already created'
    return 1
  end

  if sessionavailable $DOT_SESSION
    tmux new-session -d -n $WORKSPACE_WINDOW -s $DOT_SESSION
  else
    tmux new-window -n $WORKSPACE_WINDOW -t $DOT_SESSION
  end

  set -xl target $DOT_SESSION':'$WORKSPACE_WINDOW

  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux send-keys -t $target'.left' 'cd '$DOT_DIR Enter C-l
  tmux send-keys -t $target'.right' 'cd '$DOT_DIR Enter C-l
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux select-pane -t $target'.left'

  echo 'Dotfiles: Workspace created'
end

function tmzp
  if not test -d $ZP_DIR
    set -xl clone_command "git clone git@github.com:Gusto/zenpayroll $ZP_DIR"
    echo 'Zenpayroll: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $ZP_SESSION $WORKSPACE_WINDOW
    echo 'Zenpayroll: Workspace already created'
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
  tmux send-keys -t $target 'cd '$ZP_DIR Enter
  tmux send-keys -t $target 'mise install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'Zenpayroll: Workspace created'
end

function tmpbb
  if not test -d $PBB_DIR
    set -xl clone_command "git clone git@github.com:Gusto/payroll_building_blocks $PBB_DIR"
    echo 'PBB: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $PBB_SESSION $PBB_WINDOW
    echo 'PBB: Workspace already created'
    return 1
  end

  if sessionavailable $PBB_SESSION
    echo 'PBB: Creating session and attaching window'
    tmux new-session -d -s $PBB_SESSION -n $PBB_WINDOW
  else
    echo 'PBB: Attaching window to existing session'
    tmux new-window -t $PBB_SESSION -n $PBB_WINDOW
  end

  set -xl target $PBB_SESSION':'$PBB_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$PBB_DIR Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'PBB: Workspace created'
end

function stopservices
  set -xl target $ZP_BACKEND_SESSION':'$ZP_SERVER_WINDOW
  tmux setw synchronize-panes on
  tmux send-keys -t $target C-c Enter C-l
  tmux setw synchronize-panes off
  echo 'Zenpayroll: Backend stopped'
end

function startsrvr
  set -xl target $ZP_BACKEND_SESSION':'$ZP_SERVER_WINDOW
  tmux select-pane -t $target'.top-left'
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$ZP_DIR Enter
  tmux send-keys -t $target 'mise install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.top-left' 'brails s' Enter C-l
  tmux send-keys -t $target'.top-right' 'bundle exec vite dev' C-l Enter
  tmux send-keys -t $target'.bottom-left' 'bin/sidekiq' C-l Enter
  tmux send-keys -t $target'.bottom-right' 'bin/run-hapii' C-l Enter
  tmux select-pane -t $target'.top-left'
  echo 'Zenpayroll: Backend started'
end

function tmzpsrvr
  if not test -d $ZP_DIR
    set -xl clone_command "git clone git@github.com:Gusto/zenpayroll $ZP_DIR"
    echo 'Zenpayroll: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $ZP_BACKEND_SESSION $ZP_SERVER_WINDOW
    echo 'Zenpayroll: Backend already started'
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
    echo 'Zenpayroll: Backend not started'
    return 1
  end

  stopservices
  startsrvr
end

function tmpaycheckcity
  if not test -d $PCC_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/paycheckcity.com $PCC_DIR"
    echo 'Paycheckcity.com: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $PCC_SESSION $PCC_WINDOW
    echo 'Paycheckcity.com: Workspace already created'
    return 1
  end

  if sessionavailable $PCC_SESSION
    tmux new-session -d -s $PCC_SESSION -n $PCC_WINDOW
  else
    tmux new-window -t $PCC_SESSION -n $PCC_WINDOW
  end

  set -xl target $PCC_SESSION':'$PCC_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$PCC_DIR Enter
  tmux send-keys -t $target 'mise install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'gatsby develop' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'Paycheckcity.com: Workspace created'
end

function tmpccpf
  if not test -d $PCCP_FE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/pcc-profiles-client-app $PCC_FE_DIR"
    echo 'Paycheckcity Payroll: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $PCCP_FE_SESSION $PCCP_FE_WINDOW
    echo 'Paycheckcity Payroll: Workspace already created'
    return 1
  end

  if sessionavailable $PCCP_FE_SESSION
    tmux new-session -d -s $PCCP_FE_SESSION -n $PCCP_FE_WINDOW
  else
    tmux new-window -t $PCCP_FE_SESSION -n $PCCP_FE_WINDOW
  end

  set -xl target $PCCP_FE_SESSION':'$PCCP_FE_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$PCCP_FE_DIR Enter
  tmux send-keys -t $target 'mise install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'npm run start' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'Paycheckcity Payroll: Workspace created'
end

function tmpccpb
  if not test -d $PCCP_BE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/pcc-profiles-resource-server $PCCP_BE_DIR"
    echo 'Paycheckcity Payroll Server: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $PCCP_BE_SESSION $PCCP_BE_WINDOW
    echo 'Paycheckcity Payroll Server: Workspace already created'
    return 1
  end

  if sessionavailable $PCCP_BE_SESSION
    tmux new-session -d -s $PCCP_BE_SESSION -n $PCCP_BE_WINDOW
  else
    tmux new-window -t $PCCP_BE_SESSION -n $PCCP_BE_WINDOW
  end

  set -xl target $PCCP_BE_SESSION':'$PCCP_BE_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$PCCP_BE_DIR Enter
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' './gradlew bootRun' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'Paycheckcity Payroll Server: Workspace created'
end

function tmwbsf
  if not test -d $WBS_FE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/notification-service-ui $WBS_FE_DIR"
    echo 'WBS: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $WBS_FE_SESSION $WBS_FE_WINDOW
    echo 'WBS: Workspace already created'
    return 1
  end

  if sessionavailable $WBS_FE_SESSION
    tmux new-session -d -s $WBS_FE_SESSION -n $WBS_FE_WINDOW
  else
    tmux new-window -t $WBS_FE_SESSION -n $WBS_FE_WINDOW
  end

  set -xl target $WBS_FE_SESSION':'$WBS_FE_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$WBS_FE_DIR Enter
  tmux send-keys -t $target 'mise install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'npm run start' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'WBS: Workspace created'
end

function tmwbsb
  if not test -d $WBS_BE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/notification-service $WBS_BE_DIR"
    echo 'WBS: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $WBS_BE_SESSION $WBS_BE_WINDOW
    echo 'WBS: Workspace already created'
    return 1
  end

  if sessionavailable $WBS_BE_SESSION
    tmux new-session -d -s $WBS_BE_SESSION -n $WBS_BE_WINDOW
  else
    tmux new-window -t $WBS_BE_SESSION -n $WBS_BE_WINDOW
  end

  set -xl target $WBS_BE_SESSION':'$WBS_BE_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$WBS_BE_DIR Enter
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' './gradlew bootRun' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'WBS: Workspace created'
end

function cms
  if not test -d $CMS_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/symmetry_content_manager $CMS_DIR"
    echo 'CMS: Project not installed'
    echo $clone_command
    return 1
  end

  if not windowavailable $CMS_SESSION $CMS_WINDOW
    echo 'CMS: Workspace already created'
    return 1
  end

  if sessionavailable $CMS_SESSION
    tmux new-session -d -s $CMS_SESSION -n $CMS_WINDOW
  else
    tmux new-window -t $CMS_SESSION -n $CMS_WINDOW
  end

  set -xl target $CMS_SESSION':'$CMS_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$CMS_DIR Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'iex -S mix phx.server' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  echo 'CMS: Workspace created'
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
  else if test $session_name = 'pbb'
    tmpbb
  else if test $session_name = 'pcc'
    tmpaycheckcity
  else if test $session_name = 'pccpf'
    tmpccpf
  else if test $session_name = 'pccpb'
    tmpccpb
  else if test $session_name = 'wbsf'
    tmwbsf
  else if test $session_name = 'wbsb'
    tmwbsb
  else if test $session_name = 'cms'
    cms
  else
    if sessionavailable $session_name
      echo "tmux: Attaching session $session_name"
      tmux attach -t $session_name
    else
      echo "tmux: Creating session $session_name"
      tmux new -s $session_name
    end
  end
end
