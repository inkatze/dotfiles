# mkdir is atomic across processes (unlike test -f + touch), which is what
# makes it safe as a lock primitive for concurrent tmux-offload invocations.
function __tmux_offload_lock --description "Acquire a mkdir-based lock, retrying until timeout_ms"
    set -l dir $argv[1]
    set -l timeout_ms $argv[2]
    set -l waited 0
    while not mkdir $dir 2>/dev/null
        if test $waited -ge $timeout_ms
            return 1
        end
        sleep 0.05
        set waited (math $waited + 50)
    end
    return 0
end

function __tmux_offload_unlock --description "Release a lock acquired by __tmux_offload_lock"
    rmdir $argv[1] 2>/dev/null
end

# C0 controls, DEL, and C1 controls (\x80-\x9f) can drive a terminal
# underneath the receiving program (title/prompt spoofing, cursor tricks)
# even when written via send-keys -l, which only stops keybinding
# interpretation, not raw control-byte interpretation by the pty. Used on
# every user-controlled value that ends up in the pty or in --list's output.
function __tmux_offload_strip_controls --description "Strip C0/C1 control and escape bytes"
    string replace -ra '[\x00-\x1f\x7f-\x9f]' '' -- $argv[1]
end

function tmux-offload --description "Bootstrap a full interactive claude session in a new tmux window for this session to drive and manage"
    argparse 'n/name=' 'm/model=' 'p/permission-mode=' 'd/dir=' l/list -- $argv
    or begin
        echo "tmux-offload: if the task description itself contains a hyphen-prefixed word (e.g. \"--verbose\" or \"-5\"), insert a literal -- to stop flag parsing before it: tmux-offload [flags] -- <task description>" >&2
        return 1
    end

    set -l log_dir ~/.claude/tmux-offload
    set -l log $log_dir/sessions.jsonl

    if set -q _flag_list
        if test (count $argv) -gt 0; or set -q _flag_name; or set -q _flag_model; or set -q _flag_permission_mode; or set -q _flag_dir
            echo "tmux-offload: --list takes no additional arguments or flags" >&2
            return 1
        end
        if not test -f $log
            echo "tmux-offload: no sessions logged yet" >&2
            return 1
        end
        set -l log_lock $log_dir/sessions.lock
        set -l have_lock 0
        if __tmux_offload_lock $log_lock 2000
            set have_lock 1
        else
            echo "tmux-offload: could not acquire session log lock; reading without it" >&2
        end
        if type -q jq
            set -l rows (jq -r '[.ts, .target, .window_id, .dir, .model, .permission_mode, .session_id, .task] | @tsv' $log)
            set -l jq_status $status
            if test $have_lock -eq 1
                __tmux_offload_unlock $log_lock
            end
            if test $jq_status -ne 0
                echo "tmux-offload: $log appears corrupted or unreadable (jq exited $jq_status)" >&2
                return 1
            end
            if test -z "$rows"
                echo "tmux-offload: no sessions logged yet" >&2
                return 1
            end
            printf '%s\n' $rows | column -t -s \t
            if test $status -ne 0
                echo "tmux-offload: failed to format the session list" >&2
                return 1
            end
        else
            cat $log
            set -l cat_status $status
            if test $have_lock -eq 1
                __tmux_offload_unlock $log_lock
            end
            if test $cat_status -ne 0
                echo "tmux-offload: failed to read $log" >&2
                return 1
            end
        end
        return 0
    end

    if not set -q TMUX
        echo "tmux-offload: run this from inside a tmux session" >&2
        return 1
    end

    if test (count $argv) -eq 0
        echo "usage: tmux-offload [-n <name>] [-m <model>] [-p <mode>] [-d <dir>] <task description>" >&2
        echo "       tmux-offload --list" >&2
        return 1
    end

    # A single fish list->string->list round trip (join, recapture, rejoin):
    # any embedded newline inside an $argv element causes the first command
    # substitution to split $task into multiple list elements (fish splits
    # captured command output on newlines), which corrupts both the jq
    # --arg call and the send-keys delivery below. The second join collapses
    # that split back into one line.
    set -l task (string join ' ' -- $argv)
    set task (string join ' ' -- $task)
    set task (string trim -- $task)
    # tmux send-keys -l writes these bytes into the pane's pty verbatim (that's
    # what -l means: no keyname interpretation). Strip them before use.
    set task (__tmux_offload_strip_controls $task)
    if test -z "$task"
        echo "tmux-offload: task description must not be empty or whitespace-only" >&2
        return 1
    end

    if set -q _flag_dir; and test -z "$_flag_dir"
        echo "tmux-offload: -d/--dir must not be empty" >&2
        return 1
    end
    set -l work_dir $_flag_dir
    if test -z "$work_dir"
        set work_dir (pwd)
    end
    if not test -d $work_dir
        echo "tmux-offload: -d $work_dir is not a directory" >&2
        return 1
    end
    set work_dir (realpath $work_dir)
    if test (count $work_dir) -ne 1
        echo "tmux-offload: -d resolves to a path containing embedded newlines; refusing to use it" >&2
        return 1
    end
    if test -z "$work_dir"
        echo "tmux-offload: failed to resolve a real path for the working directory" >&2
        return 1
    end
    # work_dir ends up in --list's displayed output (the .dir field) and in the
    # tmux -c argument, the same exposure other user-controlled values get
    # sanitized for above -- reject rather than silently transform, since a
    # stripped value could point tmux -c at a directory that no longer exists.
    if test (__tmux_offload_strip_controls $work_dir) != "$work_dir"
        echo "tmux-offload: -d resolves to a path containing control characters; refusing to use it" >&2
        return 1
    end

    if set -q _flag_permission_mode; and test -z "$_flag_permission_mode"
        echo "tmux-offload: -p/--permission-mode must not be empty" >&2
        return 1
    end
    set -l perm_mode $_flag_permission_mode
    if not set -q _flag_permission_mode
        set perm_mode acceptEdits
        echo "tmux-offload: no -p/--permission-mode given; defaulting to acceptEdits (auto-approves file edits in the launched session) — pass -p explicitly to silence this" >&2
    end
    set perm_mode (__tmux_offload_strip_controls $perm_mode)
    if test -z "$perm_mode"
        echo "tmux-offload: -p/--permission-mode must not consist only of control characters" >&2
        return 1
    end

    if set -q _flag_name; and test -z "$_flag_name"
        echo "tmux-offload: -n/--name must not be empty" >&2
        return 1
    end
    set -l session (tmux display-message -p '#S')
    set -l win_name ""
    if set -q _flag_name
        set win_name (__tmux_offload_strip_controls $_flag_name)
    end
    if test -z "$win_name"
        set win_name "offload-"(date +%H%M%S)"-"(random 100 999)
    end

    if set -q _flag_model; and test -z "$_flag_model"
        echo "tmux-offload: -m/--model must not be empty" >&2
        return 1
    end
    set -l model ""
    if set -q _flag_model
        set model (__tmux_offload_strip_controls $_flag_model)
        if test -z "$model"
            echo "tmux-offload: -m/--model must not consist only of control characters" >&2
            return 1
        end
    end
    set -l claude_args --permission-mode $perm_mode
    if set -q _flag_model
        set -a claude_args --model $model
    end

    # Snapshot the project's transcript directory before launch so session-id
    # discovery below can diff against it instead of trusting mtimes alone:
    # a sibling transcript from an already-running or concurrently-launched
    # session in the same dir can satisfy a `-newer` check just as easily as
    # this one's, misattributing someone else's session id rather than merely
    # missing one.
    set -l slug (string replace -a '/' '-' -- (string replace -a '.' '-' -- $work_dir))
    set -l project_dir ~/.claude/projects/$slug
    set -l before_files
    if test -d $project_dir
        set before_files (find $project_dir -maxdepth 1 -name '*.jsonl' 2>/dev/null)
    end

    # Ghost-text (inline autosuggestion) in the input box is visually
    # indistinguishable from real typed input in a plain capture-pane dump,
    # which is exactly what this session polls to drive the child. Disable it.
    #
    # The launch command is passed as discrete argv tokens, never a single
    # shell-string: tmux execs argv directly with no shell re-parsing, so a
    # crafted -m/-p value can't inject shell metacharacters regardless of
    # what default-shell resolves to (it isn't pinned to fish anywhere, and
    # falls back to whatever $SHELL the tmux server itself started under).
    set -l window_id (tmux new-window -d -P -F '#{window_id}' -t $session -n $win_name -c $work_dir -- \
        env CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false claude $claude_args)

    if test -z "$window_id"
        echo "tmux-offload: failed to create tmux window" >&2
        return 1
    end

    # remain-on-exit must be set immediately: without it, a claude that exits
    # right away (missing binary, rejected --model/--permission-mode value)
    # closes the window before we can ever observe that it died. If setting
    # it fails, the pane is almost certainly already gone -- treat that the
    # same as the dead branch below rather than proceeding to poll a window
    # this session can no longer observe.
    if not tmux set-option -p -t $window_id remain-on-exit on 2>/dev/null
        echo "tmux-offload: claude exited immediately in $window_id; task not delivered" >&2
        return 1
    end

    # Poll for the pane entering the alternate screen, which claude's main
    # chat UI (but not its startup banners or the first-run folder-trust
    # prompt) switches into. A blind fixed sleep here previously sent the
    # task text into whatever was on screen and then unconditionally pressed
    # Enter -- on an untrusted directory that silently answered "yes, trust
    # this folder" on the human's behalf and dropped the task entirely,
    # since the trust prompt is a selection menu, not a text field.
    set -l ready 0
    set -l dead 0
    set -l waited 0
    while test $waited -lt 15000
        # tmux display-message doesn't error for a window-id that's gone --
        # it exits 0 with empty stdout, which would otherwise satisfy
        # neither `= 1` comparison below and just burn the full timeout.
        # #{pane_dead} is always "0" or "1" for a window that still exists,
        # so empty output unambiguously means the window vanished.
        set -l pane_dead (tmux display-message -p -t $window_id '#{pane_dead}' 2>/dev/null)
        if test -z "$pane_dead"; or test "$pane_dead" = 1
            set dead 1
            break
        end
        # Same vanished-window race as the #{pane_dead} check above, but for
        # a window that disappears between that check and this one: empty
        # output here means gone, not "not yet in the alternate screen".
        set -l alternate_on (tmux display-message -p -t $window_id '#{alternate_on}' 2>/dev/null)
        if test -z "$alternate_on"
            set dead 1
            break
        end
        if test "$alternate_on" = 1
            set ready 1
            break
        end
        sleep 0.3
        set waited (math $waited + 300)
    end

    if test $dead -eq 1
        echo "tmux-offload: claude exited immediately in $window_id; task not delivered" >&2
        return 1
    end

    if test $ready -ne 1
        echo "tmux-offload: claude in $window_id hasn't reached its chat UI yet (it may be waiting on a trust or permission prompt) — task not sent; inspect with 'tmux capture-pane -p -t $window_id' and drive it manually" >&2
        echo $window_id
        return 1
    end

    tmux send-keys -t $window_id -l -- $task
    or begin
        echo "tmux-offload: failed to deliver the task to $window_id" >&2
        return 1
    end
    tmux send-keys -t $window_id Enter
    or begin
        echo "tmux-offload: task was typed but not submitted in $window_id -- press Enter manually or inspect with 'tmux capture-pane -p -t $window_id'" >&2
        return 1
    end

    # Best-effort session-id discovery: wait for a transcript file to appear
    # that wasn't in the pre-launch snapshot. Ambiguous (more than one new
    # file) or absent just means `--list` won't be able to `--resume` it
    # later; nothing else depends on it. Skipped entirely without jq: the
    # discovered id would never be logged (the write below is jq-gated too),
    # so running it anyway would just leave orphaned claim directories under
    # $log_dir/claims for a run that can't record sessions in the first place.
    set -l session_id ""
    if type -q jq
        set -l waited 0
        while test $waited -lt 5000
            set -l after_files
            if test -d $project_dir
                set after_files (find $project_dir -maxdepth 1 -name '*.jsonl' 2>/dev/null)
            end
            set -l new_files
            for f in $after_files
                if not contains -- $f $before_files
                    set -a new_files $f
                end
            end
            if test (count $new_files) -eq 1
                # Claim the transcript atomically before trusting it: a second
                # tmux-offload racing against this same work_dir could observe
                # the identical new file and, without this, both invocations
                # would attribute the same session_id to two different windows.
                set -l candidate (basename $new_files[1] .jsonl)
                set -l claims_dir $log_dir/claims
                mkdir -p $claims_dir 2>/dev/null
                if not chmod 700 $claims_dir 2>/dev/null
                    echo "tmux-offload: could not tighten permissions on $claims_dir" >&2
                end
                if mkdir $claims_dir/$candidate.claimed 2>/dev/null
                    set session_id $candidate
                end
                break
            end
            sleep 0.5
            set waited (math $waited + 500)
        end
    end

    set -l old_umask (umask)
    umask 077
    if not mkdir -p $log_dir 2>/dev/null
        echo "tmux-offload: could not create $log_dir; session not recorded" >&2
    else if type -q jq
        # umask only governs newly-created paths; a directory/file that
        # predates this logic (or was touched by something else) keeps
        # whatever permissions it already had. Tighten explicitly so the
        # guarantee doesn't depend on creation order.
        if not chmod 700 $log_dir 2>/dev/null
            echo "tmux-offload: could not tighten permissions on $log_dir" >&2
        end
        set -l log_lock $log_dir/sessions.lock
        set -l have_lock 0
        if __tmux_offload_lock $log_lock 2000
            set have_lock 1
        else
            echo "tmux-offload: could not acquire session log lock; writing without it" >&2
        end
        jq -nc --arg ts (date -u +%Y-%m-%dT%H:%M:%SZ) \
            --arg target "$session:$win_name" \
            --arg window_id $window_id \
            --arg dir $work_dir \
            --arg model "$model" \
            --arg mode $perm_mode \
            --arg session_id "$session_id" \
            --arg task "$task" \
            '{ts:$ts,target:$target,window_id:$window_id,dir:$dir,model:$model,permission_mode:$mode,session_id:$session_id,task:$task}' >>$log
        or echo "tmux-offload: failed to write session log entry to $log" >&2
        if test $have_lock -eq 1
            __tmux_offload_unlock $log_lock
        end
        if not chmod 600 $log 2>/dev/null
            echo "tmux-offload: could not tighten permissions on $log" >&2
        end
    else
        echo "tmux-offload: jq not installed; session not recorded in $log" >&2
    end
    umask $old_umask

    echo $window_id
end
