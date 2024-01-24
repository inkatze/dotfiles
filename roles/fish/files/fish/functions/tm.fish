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
    notify 'Dotfiles' 'Dotfiles project not installed' 'https://github.com/inkatze/dotfiles' -sound Sosumi -group tm -execute $clone_command
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
  tmux split-window -t $target -v
  tmux send-keys -t $target'.left' 'cd '$DOT_DIR Enter C-l
  tmux send-keys -t $target'.right' 'cd '$DOT_DIR Enter C-l
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux select-pane -t $target'.left'

  notify 'Dotfiles' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmzp
  if not test -d $ZP_DIR
    set -xl clone_command "git clone git@github.com:Gusto/zenpayroll $ZP_DIR"
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
  tmux send-keys -t $target 'cd '$ZP_DIR Enter
  tmux send-keys -t $target 'asdf install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'Zenpayroll' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmpbb
  if not test -d $PBB_DIR
    set -xl clone_command "git clone git@github.com:Gusto/payroll_building_blocks $PBB_DIR"
    notify 'PBB' 'Project not installed' 'https://github.com/Gusto/payroll_building_blocks' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $PBB_SESSION $PBB_WINDOW
    notify 'PBB' 'Workspace already created' -sound Purr -group tm -execute tm
    return 1
  end

  if sessionavailable $PBB_SESSION
    notify 'PBB' 'Creating session and attaching window' -sound Purr -group tm -execute tm
    tmux new-session -d -s $PBB_SESSION -n $PBB_WINDOW
  else
    notify 'PBB' 'Attaching window to existing session' -sound Purr -group tm -execute tm
    tmux new-window -t $PBB_SESSION -n $PBB_WINDOW
  end

  set -xl target $PBB_SESSION':'$PBB_WINDOW
  tmux split-window -t $target -h
  tmux split-window -t $target -v
  tmux setw synchronize-panes on
  tmux send-keys -t $target 'cd '$PBB_DIR Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'PBB' 'Workspace created' -sound Blow -group tm -execute tm
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
  tmux send-keys -t $target 'cd '$ZP_DIR Enter
  tmux send-keys -t $target 'asdf install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.top-left' 'brails s' Enter C-l
  tmux send-keys -t $target'.top-right' 'bundle exec vite dev' C-l Enter
  tmux send-keys -t $target'.bottom-left' 'bin/sidekiq' C-l Enter
  tmux send-keys -t $target'.bottom-right' 'bin/run-hapii' C-l Enter
  tmux select-pane -t $target'.top-left'
  notify 'Zenpayroll' 'Backend started' -sound Blow -execute tm
end

function tmzpsrvr
  if not test -d $ZP_DIR
    set -xl clone_command "git clone git@github.com:Gusto/zenpayroll $ZP_DIR"
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

function tmpaycheckcity
  if not test -d $PCC_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/paycheckcity.com $PCC_DIR"
    notify 'Paycheckcity.com' 'Project not installed' 'https://github.com/SymmetrySoftware/paycheckcity.com' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $PCC_SESSION $PCC_WINDOW
    notify 'Paycheckcity.com' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux send-keys -t $target 'asdf install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'gatsby develop' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'Paycheckcity.com' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmpccpf
  if not test -d $PCCP_FE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/pcc-profiles-client-app $PCC_FE_DIR"
    notify 'Paycheckcity Payroll' 'Project not installed' 'https://github.com/SymmetrySoftware/paycheckcity.com' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $PCCP_FE_SESSION $PCCP_FE_WINDOW
    notify 'Paycheckcity Payroll' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux send-keys -t $target 'asdf install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'npm run start' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'Paycheckcity Payroll' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmpccpb
  if not test -d $PCCP_BE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/pcc-profiles-resource-server $PCCP_BE_DIR"
    notify 'Paycheckcity Payroll Server' 'Project not installed' 'https://github.com/SymmetrySoftware/pcc-profiles-resource-server' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $PCCP_BE_SESSION $PCCP_BE_WINDOW
    notify 'Paycheckcity Payroll Server' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'Paycheckcity Payroll Server' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmwbsf
  if not test -d $WBS_FE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/notification-service-ui $WBS_FE_DIR"
    notify 'WBS' 'Project not installed' 'https://github.com/SymmetrySoftware/notification-service-ui' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $WBS_FE_SESSION $WBS_FE_WINDOW
    notify 'WBS' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux send-keys -t $target 'asdf install nodejs' Enter C-l
  tmux setw synchronize-panes off
  tmux send-keys -t $target'.bottom-right' 'npm run start' Enter
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'WBS' 'Workspace created' -sound Blow -group tm -execute tm
end

function tmwbsb
  if not test -d $WBS_BE_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/notification-service $WBS_BE_DIR"
    notify 'WBS' 'Project not installed' 'https://github.com/SymmetrySoftware/notification-service' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $WBS_BE_SESSION $WBS_BE_WINDOW
    notify 'WBS' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'WBS' 'Workspace created' -sound Blow -group tm -execute tm
end

function cms
  if not test -d $CMS_DIR
    set -xl clone_command "git clone git@github.com:SymmetrySoftware/symmetry_content_manager $CMS_DIR"
    notify 'CMS' 'Project not installed' 'https://github.com/SymmetrySoftware/symmetry_content_manager' -sound Sosumi -group tm -execute $clone_command
    echo $clone_command
    return 1
  end

  if not windowavailable $CMS_SESSION $CMS_WINDOW
    notify 'CMS' 'Workspace already created' -sound Purr -group tm -execute tm
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
  tmux send-keys -t $target'.bottom-right' 'arttime --nolearn --random all -t "(ง •̀_•́)ง"' Enter
  tmux send-keys -t $target'.left' 'nv' Enter
  tmux select-pane -t $target'.left'

  notify 'CMS' 'Workspace created' -sound Blow -group tm -execute tm
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
      notify 'tmux' "Attaching session $session_name" -sound Blow
      tmux attach -t $session_name
    else
      notify 'tmux' "Creating session $session_name" -sound Blow
      tmux new -s $session_name
    end
  end
end
