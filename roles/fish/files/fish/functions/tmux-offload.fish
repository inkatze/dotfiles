function tmux-offload --description "Bootstrap a full interactive claude session in a new tmux window for this session to drive and manage"
    argparse 'n/name=' 'm/model=' 'p/permission-mode=' 'd/dir=' l/list -- $argv
    or return 1

    if set -q _flag_list
        set -l log ~/.claude/tmux-offload/sessions.jsonl
        if not test -f $log
            echo "tmux-offload: no sessions logged yet" >&2
            return 1
        end
        if type -q jq
            jq -r '[.ts, .target, .window_id, .model, .permission_mode, .session_id, .task] | @tsv' $log | column -t -s \t
        else
            cat $log
        end
        return 0
    end

    if not set -q TMUX
        echo "tmux-offload: run this from inside a tmux session" >&2
        return 1
    end

    if test (count $argv) -eq 0
        echo "usage: tmux-offload [-n name] [-m model] [-p permission-mode] [-d dir] <task description>" >&2
        echo "       tmux-offload --list" >&2
        return 1
    end

    set -l task (string join ' ' -- $argv)

    set -l work_dir $_flag_dir
    if test -z "$work_dir"
        set work_dir (pwd)
    end

    set -l perm_mode $_flag_permission_mode
    if test -z "$perm_mode"
        set perm_mode acceptEdits
    end

    set -l session (tmux display-message -p '#S')
    set -l win_name $_flag_name
    if test -z "$win_name"
        set win_name "offload-"(date +%H%M%S)"-"(random 100 999)
    end

    set -l claude_args --permission-mode (string escape -- $perm_mode)
    if set -q _flag_model
        set -a claude_args --model (string escape -- $_flag_model)
    end

    # Ghost-text (inline autosuggestion) in the input box is visually
    # indistinguishable from real typed input in a plain capture-pane dump,
    # which is exactly what this session polls to drive the child. Disable it.
    set -l window_id (tmux new-window -d -P -F '#{window_id}' -t $session -n $win_name -c $work_dir \
        "env CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false claude $claude_args")

    if test -z "$window_id"
        echo "tmux-offload: failed to create tmux window" >&2
        return 1
    end

    sleep 1.5
    tmux send-keys -t $window_id -l -- $task
    tmux send-keys -t $window_id Enter

    # Best-effort session-id discovery: claude's transcript slug replaces
    # every '/' and '.' in the cwd with '-'. Racy if another offload targets
    # the same dir concurrently; a missing id just means `--list` won't be
    # able to `--resume` it later, nothing else depends on it.
    set -l marker (mktemp)
    sleep 2
    set -l slug (string replace -a '/' '-' -- (string replace -a '.' '-' -- $work_dir))
    set -l found (find ~/.claude/projects/$slug -maxdepth 1 -name '*.jsonl' -newer $marker 2>/dev/null)
    set -l session_id ""
    if test -n "$found"
        set session_id (basename $found[1] .jsonl)
    end
    rm -f $marker

    set -l log_dir ~/.claude/tmux-offload
    mkdir -p $log_dir
    if type -q jq
        jq -nc --arg ts (date -u +%Y-%m-%dT%H:%M:%SZ) \
            --arg target "$session:$win_name" \
            --arg window_id $window_id \
            --arg dir $work_dir \
            --arg model "$_flag_model" \
            --arg mode $perm_mode \
            --arg session_id "$session_id" \
            --arg task $task \
            '{ts:$ts,target:$target,window_id:$window_id,dir:$dir,model:$model,permission_mode:$mode,session_id:$session_id,task:$task}' >>$log_dir/sessions.jsonl
    end

    echo $window_id
end
