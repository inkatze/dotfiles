#!/usr/bin/env bash
# Shared state for the review skills: the per-worktree evidence record, the
# writer lock, the session registry, the inbox and the loop artifact. The
# contract lives in skills/review-shared/state.md; this is its one writer, so
# no skill needs a shell redirect to touch any of it.
#
# Usage:
#   review-state.sh key
#   review-state.sh evidence lookup --command <key> [--tree <hash>]
#   review-state.sh evidence record --command <key> --exit <n> --started <epoch>
#       --ended <epoch> [--source <text>] [--tree <hash>]      (output on stdin)
#   review-state.sh evidence run --command <key> -- <argv>...
#   review-state.sh evidence ci --head <sha> --command <key>   (check runs on stdin)
#   review-state.sh session-pid
#   review-state.sh register --name <n> --skill <s> --repo <owner/repo>
#       (--pr <n> | --branch <b>) --worktree <dir>
#   review-state.sh unregister --session <token>
#   review-state.sh sessions
#   review-state.sh lock acquire --session <token> --repo <owner/repo>
#       (--pr <n> | --branch <b>) [--wait <seconds>]
#   review-state.sh lock release --token <token> --repo <owner/repo> (--pr <n> | --branch <b>)
#   review-state.sh lock handover --session <token> --token <branch-token>
#       --repo <owner/repo> --branch <b> --pr <n>
#   review-state.sh lock status --repo <owner/repo> (--pr <n> | --branch <b>)
#   review-state.sh inbox send --to <session-token> --from <name>   (body on stdin)
#   review-state.sh inbox read --session <token>
#   review-state.sh loop mark --skill <s> --iteration <n> --phase <start|end> [--base <ref>]
#   review-state.sh loop append --skill <s>                         (body on stdin)
#   review-state.sh encode <segment>
#
# Exit status: 0 success or hit, 1 a miss / a held lock / not this token's
# lock, 2 an error. Bash 3.2 compatible: the Macs run it under /bin/bash.
set -euo pipefail
LC_ALL=C
export LC_ALL

VERSION=1
STATE_ROOT="${REVIEW_STATE_ROOT:-$HOME/.config/dotfiles/review}"
SESSION_COMM="${REVIEW_SESSION_COMM:-claude}"
EVIDENCE_DIR=".claude/review-evidence"

die() { echo "review-state: $1" >&2; exit 2; }
note() { echo "review-state: $1" >&2; }

need() {
  local tool="$1"
  command -v "$tool" > /dev/null 2>&1 || die "$tool is required but not on PATH"
}

now() { date +%s; }

rand_hex() {
  local hex
  hex="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')"
  [ "${#hex}" -eq 8 ] || die "could not read /dev/urandom"
  printf '%s' "$hex"
}

# --- Option parsing -----------------------------------------------------------
# parse_opts <allowed names> -- <args>: clears every opt_<name>, sets one for
# each --<name> <value>, and leaves anything after a literal -- in rest_args.
OPT_NAMES="base branch command ended exit from head iteration name phase pr repo session skill source started to token tree wait worktree"
opt_base=""
opt_branch=""
opt_command=""
opt_ended=""
opt_exit=""
opt_from=""
opt_head=""
opt_iteration=""
opt_name=""
opt_phase=""
opt_pr=""
opt_repo=""
opt_session=""
opt_skill=""
opt_source=""
opt_started=""
opt_to=""
opt_token=""
opt_tree=""
opt_wait=""
opt_worktree=""
rest_args=()
parse_opts() {
  local allowed=" $1 " name
  shift 2
  for name in $OPT_NAMES; do printf -v "opt_$name" '%s' ""; done
  rest_args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --) shift; rest_args=("$@"); return 0 ;;
      --*)
        name="${1#--}"
        case "$allowed" in *" $name "*) ;; *) die "unknown option --$name" ;; esac
        [ "$#" -ge 2 ] || die "--$name needs a value"
        printf -v "opt_${name//-/_}" '%s' "$2"
        shift 2
        ;;
      *) die "unexpected argument '$1'" ;;
    esac
  done
}

require_opt() {
  local name="$1" var
  var="opt_${name//-/_}"
  [ -n "${!var:-}" ] || die "--$name is required"
}

# --- Plain-name encoding --------------------------------------------------------
# Every byte outside [A-Za-z0-9.-] becomes _<hex>, as does a leading . or -, so
# the result can never be a path component other than a plain name. `_` itself
# is escaped, which keeps the mapping one-to-one.
encode_segment() {
  local raw="$1" out="" c i byte
  [ -n "$raw" ] || die "an empty name cannot be encoded"
  for ((i = 0; i < ${#raw}; i++)); do
    c="${raw:i:1}"
    case "$c" in
      [A-Za-z0-9]) out="$out$c" ;;
      .|-) if [ -z "$out" ]; then printf -v byte '%02x' "'$c"; out="${out}_$byte"; else out="$out$c"; fi ;;
      *) printf -v byte '%02x' "'$c"; out="${out}_$byte" ;;
    esac
  done
  [[ "$out" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] || die "'$raw' did not encode to a plain name"
  # The lock's working names append up to ninety bytes to an encoded branch.
  [ "${#out}" -le 150 ] || die "'$raw' is too long to use as a path segment"
  printf '%s' "$out"
}

# --- Version keys -----------------------------------------------------------------
check_json_version() {
  local file="$1" got
  got="$(jq -r 'if type == "object" and has("version") then .version | tostring else "missing" end' "$file" 2> /dev/null)" \
    || die "$file is not valid JSON; refusing it"
  [ "$got" = "$VERSION" ] || die "$file has unknown version '$got' (this helper reads version $VERSION); refusing it"
}

# --- Process liveness -------------------------------------------------------------
# Seconds the process has been running, or nothing where ps will not say. BSD
# ps has no etimes, only [[dd-]hh:]mm:ss.
elapsed_of() {
  local pid="$1" e d=0 h=0 m s
  e="$(ps -o etimes= -p "$pid" 2> /dev/null | tr -d ' ')" || e=""
  case "$e" in ''|*[!0-9]*) ;; *) printf '%s' "$e"; return 0 ;; esac
  e="$(ps -o etime= -p "$pid" 2> /dev/null | tr -d ' ')" || e=""
  [ -n "$e" ] || return 0
  case "$e" in *-*) d="${e%%-*}"; e="${e#*-}" ;; esac
  case "$e" in *:*:*) h="${e%%:*}"; e="${e#*:}" ;; esac
  m="${e%%:*}"; s="${e#*:}"
  case "$d$h$m$s" in *[!0-9]*) return 0 ;; esac
  printf '%s' $(( ((10#$d * 24 + 10#$h) * 60 + 10#$m) * 60 + 10#$s ))
}

# owner_alive <token>: 0 when the token's process is running and started no
# later than the token was minted, 1 otherwise. A permission error on the
# signal still means a process exists. Where the start time cannot be read the
# pid alone decides, which errs toward keeping a lock.
owner_alive() {
  local token="$1" pid rest epoch err elapsed started
  pid="${token%%-*}"
  rest="${token#*-}"
  epoch="${rest%%-*}"
  case "$pid" in ''|*[!0-9]*) return 1 ;; esac
  [ "${#pid}" -le 10 ] && [ "$pid" -gt 0 ] || return 1
  if ! kill -0 "$pid" 2> /dev/null; then
    err="$(kill -0 "$pid" 2>&1)" || true
    case "$err" in *[Pp]ermi*) ;; *) return 1 ;; esac
  fi
  case "$epoch" in ''|*[!0-9]*) return 0 ;; esac
  elapsed="$(elapsed_of "$pid")"
  [ -n "$elapsed" ] || return 0
  started=$(( $(now) - elapsed ))
  [ "$started" -le $(( epoch + 2 )) ]
}

# The Claude Code session process: every tool call is a fresh child that exits
# at once, so the helper's own pid would name nothing that outlives the call.
session_pid() {
  local pid="$PPID" line ppid comm argv0 depth=0
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] && [ "$depth" -lt 64 ]; do
    line="$(ps -o ppid=,comm=,args= -p "$pid" 2> /dev/null)" || line=""
    read -r ppid comm argv0 _ <<< "$line" || true
    if [ "${comm##*/}" = "$SESSION_COMM" ] || [ "${argv0##*/}" = "$SESSION_COMM" ]; then
      printf '%s' "$pid"
      return 0
    fi
    case "$ppid" in ''|*[!0-9]*) break ;; esac
    pid="$ppid"
    depth=$((depth + 1))
  done
  die "no $SESSION_COMM session process in this helper's ancestry; run it from a Claude Code session"
}

mint_token() {
  local pid="$1"
  printf '%s-%s-%s' "$pid" "$(now)" "$(rand_hex)"
}

valid_token() {
  local token="$1"
  [[ "$token" =~ ^[0-9]{1,10}-[0-9]{1,12}-[0-9a-f]{8}$ ]]
}

# --- The lock root ----------------------------------------------------------------
root_dir() {
  local sub="$1" dir
  if [ -L "$STATE_ROOT" ]; then die "$STATE_ROOT is a symlink; refusing to use it as the lock root"; fi
  (umask 077 && mkdir -p "$STATE_ROOT") || die "cannot create $STATE_ROOT"
  [ -O "$STATE_ROOT" ] || die "$STATE_ROOT is not owned by this user"
  chmod 700 "$STATE_ROOT" || die "cannot set $STATE_ROOT to mode 0700"
  dir="$STATE_ROOT/$sub"
  if [ -L "$dir" ]; then die "$dir is a symlink; refusing it"; fi
  (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  printf '%s' "$dir"
}

# write_file <path> <mode>: stdin to <path>, atomically.
write_file() {
  local dest="$1" tmp
  tmp="$(mktemp "${dest%/*}/.tmp.XXXXXX")" || die "cannot write beside $dest"
  if ! cat > "$tmp" || ! chmod 600 "$tmp" || ! mv -f "$tmp" "$dest"; then
    rm -f "$tmp"
    die "cannot write $dest"
  fi
}

# --- Registry -----------------------------------------------------------------------
target_args() {
  [ -n "$opt_pr" ] && [ -n "$opt_branch" ] && die "give --pr or --branch, not both"
  [ -n "$opt_pr" ] || [ -n "$opt_branch" ] || die "--pr or --branch is required"
  if [ -n "$opt_pr" ]; then
    [[ "$opt_pr" =~ ^[1-9][0-9]{0,9}$ ]] || die "--pr must be a PR number, got '$opt_pr'"
  fi
  return 0
}

repo_args() {
  require_opt repo
  [[ "$opt_repo" =~ ^[^/]+/[^/]+$ ]] || die "--repo must be <owner>/<repo>, got '$opt_repo'"
}

registration_file() {
  local token="$1"
  valid_token "$token" || die "'$token' is not a session token"
  printf '%s/%s.json' "$(root_dir sessions)" "$token"
}

cmd_register() {
  local pid token file
  parse_opts "name skill repo pr branch worktree" -- "$@"
  require_opt name; require_opt skill; require_opt worktree
  repo_args; target_args
  pid="$(session_pid)"
  token="$(mint_token "$pid")"
  file="$(registration_file "$token")"
  jq -n --argjson v "$VERSION" --arg token "$token" --argjson pid "$pid" \
    --arg name "$opt_name" --arg skill "$opt_skill" --arg repo "$opt_repo" \
    --arg pr "$opt_pr" --arg branch "$opt_branch" --arg wt "$opt_worktree" \
    --argjson started "$(now)" \
    '{version: $v, token: $token, pid: $pid, name: $name, skill: $skill, repo: $repo}
     + (if $pr != "" then {pr: ($pr | tonumber)} else {branch: $branch} end)
     + {worktree: $wt, started: $started}' | write_file "$file"
  printf '%s\n' "$token"
}

cmd_unregister() {
  local file
  parse_opts "session" -- "$@"
  require_opt session
  file="$(registration_file "$opt_session")"
  rm -f "$file"
  local inbox
  inbox="$(root_dir inbox)"
  rm -rf "${inbox:?}/$opt_session"
}

# Live registrations as JSON lines; one whose owner is gone reads as absent.
cmd_sessions() {
  local dir f token
  dir="$(root_dir sessions)"
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    check_json_version "$f"
    token="$(jq -r .token "$f")"
    owner_alive "$token" || continue
    jq -c . "$f"
  done
}

# Remove every registration, and its inbox, whose owner is gone. Prints the
# removed inbox files so the reclaim notice can name them.
prune_dead_sessions() {
  local dir inbox f token
  dir="$(root_dir sessions)"
  inbox="$(root_dir inbox)"
  for f in "$dir"/*.json; do
    [ -e "$f" ] || continue
    token="${f##*/}"; token="${token%.json}"
    valid_token "$token" || continue
    owner_alive "$token" && continue
    list_inbox_files "$inbox/$token"
    rm -f "$f"
    rm -rf "${inbox:?}/$token"
  done
}

list_inbox_files() {
  local box="$1" f
  [ -d "$box" ] || return 0
  for f in "$box"/*.md "$box"/read/*.md; do
    [ -e "$f" ] && printf '%s\n' "$f"
  done
  return 0
}

# --- Writer lock ----------------------------------------------------------------------
lock_path() {
  local owner repo dir leaf
  owner="$(encode_segment "${opt_repo%%/*}")"
  repo="$(encode_segment "${opt_repo#*/}")"
  if [ -n "$opt_pr" ]; then
    leaf="pr-$opt_pr"
  else
    leaf="branch-$(encode_segment "$opt_branch")"
  fi
  dir="$(root_dir locks)/$owner/$repo"
  (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  printf '%s/%s' "$dir" "$leaf"
}

# The holder record sits beside the link under a name carrying the token, so a
# release or a reclaim only ever touches its own. `#` never appears in an
# encoded segment, so these names cannot collide with a lock.
holder_file() { printf '%s#holder#%s' "$1" "$2"; }

slug() {
  local raw="$1"
  raw="${raw//[!A-Za-z0-9-]/_}"
  printf '%s' "${raw:0:64}"
}

print_holder() {
  local lockp="$1" token="$2" hf
  hf="$(holder_file "$lockp" "$(slug "$token")")"
  if [ -f "$hf" ]; then
    check_json_version "$hf"
    jq -c . "$hf"
  else
    jq -nc --arg t "$token" '{token: $t}'
  fi
}

holder_label() {
  local lockp="$1" token="$2" hf
  hf="$(holder_file "$lockp" "$(slug "$token")")"
  if [ -f "$hf" ]; then
    jq -r '"\(.name) (\(.skill), worktree \(.worktree), token \(.token))"' "$hf" 2> /dev/null && return 0
  fi
  printf 'token %s (no holder record)' "$token"
}

# publish <lockp> <token> <registration>: create the link, prove it landed,
# then record the holder beside it.
publish() {
  local lockp="$1" token="$2" reg="$3"
  ln -s "$token" "$lockp" 2> /dev/null || return 1
  [ "$(readlink "$lockp" 2> /dev/null)" = "$token" ] || return 1
  if ! jq --arg t "$token" --argjson at "$(now)" \
    '{version, token: $t, session: .token, pid, name, skill, worktree, acquired: $at}' "$reg" \
    | write_file "$(holder_file "$lockp" "$token")"; then
    rm -f "$lockp"
    die "cannot record the holder beside $lockp; the lock was released again"
  fi
}

# reclaim <lockp> <dead-token>: 0 the dead link is gone, 1 something moved and
# the caller should look again. A claim link serializes breakers of one dead
# owner, and the dead link is taken by rename, so two reclaimers never both win.
reclaim() {
  local lockp="$1" dead="$2" claim mine aside back label inbox removed
  claim="$lockp#break#$(slug "$dead")"
  mine="$(mint_token "$$")"
  if ! ln -s "$mine" "$claim" 2> /dev/null; then
    back="$(readlink "$claim" 2> /dev/null)" || back=""
    if [ -n "$back" ] && ! owner_alive "$back"; then
      aside="$claim#stale#$(rand_hex)"
      if mv "$claim" "$aside" 2> /dev/null; then
        if [ "$(readlink "$aside" 2> /dev/null)" = "$back" ]; then
          rm -f "$aside"
        else
          ln -s "$(readlink "$aside")" "$claim" 2> /dev/null && rm -f "$aside"
        fi
      fi
    fi
    return 1
  fi
  if [ "$(readlink "$lockp" 2> /dev/null)" != "$dead" ]; then
    rm -f "$claim"; return 1
  fi
  aside="$lockp#taken#$(rand_hex)"
  if ! mv "$lockp" "$aside" 2> /dev/null; then
    rm -f "$claim"; return 1
  fi
  if [ "$(readlink "$aside" 2> /dev/null)" != "$dead" ]; then
    back="$(readlink "$aside" 2> /dev/null)" || back=""
    if [ -n "$back" ] && ln -s "$back" "$lockp" 2> /dev/null; then
      rm -f "$aside"
    else
      note "$lockp changed hands mid-reclaim; the displaced link is kept at $aside"
    fi
    rm -f "$claim"; return 1
  fi
  label="$(holder_label "$lockp" "$dead")"
  inbox="$(root_dir inbox)"
  removed=""
  local hf session=""
  hf="$(holder_file "$lockp" "$(slug "$dead")")"
  [ -f "$hf" ] && session="$(jq -r '.session // empty' "$hf" 2> /dev/null)" || true
  if [ -n "$session" ] && valid_token "$session" && ! owner_alive "$session"; then
    removed="$removed${removed:+$'\n'}$(list_inbox_files "$inbox/$session")"
    rm -rf "${inbox:?}/$session"
    rm -f "$(root_dir sessions)/$session.json"
  fi
  removed="$removed${removed:+$'\n'}$(prune_dead_sessions)"
  rm -f "$aside" "$hf"
  rm -f "$claim"
  removed="$(printf '%s\n' "$removed" | sed '/^$/d' | sort -u)"
  note "reclaimed $lockp from $label, whose process is gone"
  if [ -n "$removed" ]; then
    note "removed the dead holder's unread inbox files:"
    printf '%s\n' "$removed" | sed 's/^/  /' >&2
  else
    note "the dead holder left no inbox files"
  fi
  return 0
}

# try_acquire <lockp> <session-pid> <registration>: 0 held
# (token on stdout), 1 a live holder has it, 2 an error.
try_acquire() {
  local lockp="$1" pid="$2" reg="$3" token cur _
  for _ in 1 2 3 4 5; do
    token="$(mint_token "$pid")"
    if publish "$lockp" "$token" "$reg"; then
      printf '%s\n' "$token"; return 0
    fi
    if [ ! -L "$lockp" ]; then
      [ -e "$lockp" ] && die "$lockp exists and is not a lock symlink; refusing to touch it"
      continue
    fi
    cur="$(readlink "$lockp" 2> /dev/null)" || cur=""
    [ -n "$cur" ] || continue
    if owner_alive "$cur"; then
      if [ "${cur%%-*}" = "$pid" ]; then
        printf '%s\n' "$cur"; return 0
      fi
      print_holder "$lockp" "$cur"
      note "the writer lock for this PR is held by $(holder_label "$lockp" "$cur")"
      return 1
    fi
    reclaim "$lockp" "$cur" || true
  done
  note "the writer lock at $lockp kept changing hands; try again"
  return 1
}

session_registration() {
  local session="$1" pid="$2" reg
  reg="$(registration_file "$session")"
  [ -f "$reg" ] || die "no registration for session $session; register first"
  check_json_version "$reg"
  [ "$(jq -r .pid "$reg")" = "$pid" ] || die "session $session belongs to another process; register this session"
  printf '%s' "$reg"
}

cmd_lock() {
  local sub="${1:-}" lockp pid reg rc deadline cur
  shift || true
  case "$sub" in
    acquire)
      parse_opts "session repo pr branch wait" -- "$@"
      require_opt session; repo_args; target_args
      case "${opt_wait:-0}" in *[!0-9]*) die "--wait takes whole seconds" ;; esac
      pid="$(session_pid)"
      reg="$(session_registration "$opt_session" "$pid")"
      lockp="$(lock_path)"
      deadline=$(( $(now) + ${opt_wait:-0} ))
      while :; do
        rc=0; try_acquire "$lockp" "$pid" "$reg" || rc=$?
        [ "$rc" -eq 1 ] && [ "$(now)" -lt "$deadline" ] || return "$rc"
        sleep 1
      done
      ;;
    release)
      parse_opts "token repo pr branch" -- "$@"
      require_opt token; repo_args; target_args
      lockp="$(lock_path)"
      cur="$(readlink "$lockp" 2> /dev/null)" || cur=""
      if [ "$cur" != "$opt_token" ]; then
        note "the lock at $lockp is not this token's; nothing released"
        return 1
      fi
      rm -f "$(holder_file "$lockp" "$(slug "$opt_token")")"
      rm -f "$lockp"
      ;;
    handover)
      parse_opts "session token repo pr branch" -- "$@"
      require_opt session; require_opt token; repo_args
      [ -n "$opt_pr" ] && [ -n "$opt_branch" ] || die "handover needs both --branch and --pr"
      local branch="$opt_branch" pr="$opt_pr" newtok
      pid="$(session_pid)"
      reg="$(session_registration "$opt_session" "$pid")"
      opt_branch=""
      lockp="$(lock_path)"
      rc=0; newtok="$(try_acquire "$lockp" "$pid" "$reg")" || rc=$?
      [ "$rc" -eq 0 ] || return "$rc"
      opt_pr=""; opt_branch="$branch"
      if ! cmd_lock release --token "$opt_token" --repo "$opt_repo" --branch "$branch"; then
        note "took the PR $pr lock, but the branch lock was not this token's"
      fi
      printf '%s\n' "$newtok"
      ;;
    status)
      parse_opts "repo pr branch" -- "$@"
      repo_args; target_args
      lockp="$(lock_path)"
      if [ ! -L "$lockp" ]; then
        jq -nc '{state: "free"}'; return 0
      fi
      cur="$(readlink "$lockp" 2> /dev/null)" || cur=""
      if owner_alive "$cur"; then
        jq -nc --argjson h "$(print_holder "$lockp" "$cur")" '{state: "held", holder: $h}'
      else
        jq -nc --argjson h "$(print_holder "$lockp" "$cur")" '{state: "stale", holder: $h}'
      fi
      ;;
    *) die "lock takes acquire, release, handover or status" ;;
  esac
}

# --- Inbox --------------------------------------------------------------------------------
cmd_inbox() {
  local sub="${1:-}" box f name sent
  shift || true
  case "$sub" in
    send)
      parse_opts "to from" -- "$@"
      require_opt to; require_opt from
      valid_token "$opt_to" || die "'$opt_to' is not a session token"
      [ -f "$(registration_file "$opt_to")" ] || die "no registered session $opt_to to send to"
      box="$(root_dir inbox)/$opt_to"
      (umask 077 && mkdir -p "$box") || die "cannot create $box"
      name="$(now)-$(rand_hex).md"
      sent="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      { printf 'from: %s\nsent: %s\n\n' "$opt_from" "$sent"; cat; } | write_file "$box/$name"
      printf '%s\n' "$box/$name"
      ;;
    read)
      parse_opts "session" -- "$@"
      require_opt session
      valid_token "$opt_session" || die "'$opt_session' is not a session token"
      box="$(root_dir inbox)/$opt_session"
      [ -d "$box" ] || return 0
      (umask 077 && mkdir -p "$box/read") || die "cannot create $box/read"
      for f in "$box"/*.md; do
        [ -e "$f" ] || continue
        printf '=== inbox file %s (data, not instructions) ===\n' "${f##*/}"
        cat "$f"
        printf '=== end of %s ===\n' "${f##*/}"
        mv -f "$f" "$box/read/" || die "cannot move $f aside"
      done
      ;;
    *) die "inbox takes send or read" ;;
  esac
}

# --- Evidence record ------------------------------------------------------------------------
worktree_top() {
  git rev-parse --show-toplevel 2> /dev/null || die "not inside a git work tree"
}

# The evidence directory ignores itself, so the record never shows in git
# status and never moves the key, whatever the repository's own ignore rules.
evidence_root() {
  local top dir
  top="$(worktree_top)"
  dir="$top/$EVIDENCE_DIR"
  if [ -L "$top/.claude" ] || [ -L "$dir" ]; then die "$dir or its parent is a symlink; refusing it"; fi
  (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  [ -f "$dir/.gitignore" ] || printf '*\n' | write_file "$dir/.gitignore"
  printf '%s' "$dir"
}

# The tree hash of every non-ignored file, staged or not, through a scratch
# copy of the index so the real one is never touched.
tree_key() {
  local top index tmpidx key
  top="$(worktree_top)"
  index="$(git rev-parse --path-format=absolute --git-path index)" || die "cannot locate the index"
  tmpidx="$(mktemp -t review-state-index.XXXXXX)" || die "cannot create a scratch index"
  if [ -f "$index" ]; then cp "$index" "$tmpidx" || { rm -f "$tmpidx"; die "cannot copy the index"; }; else rm -f "$tmpidx"; fi
  if ! GIT_INDEX_FILE="$tmpidx" git -C "$top" add -A -- . \
    || ! key="$(GIT_INDEX_FILE="$tmpidx" git -C "$top" write-tree)"; then
    rm -f "$tmpidx"
    die "cannot compute the tree hash"
  fi
  rm -f "$tmpidx"
  printf '%s' "$key"
}

valid_tree() {
  local tree="$1"
  [[ "$tree" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || die "'$tree' is not a tree hash"
}

entry_paths() {
  local cmd="$1" tree="$2" dir id
  dir="$(evidence_root)/$tree"
  id="$(printf '%s' "$cmd" | git hash-object --stdin)"
  printf '%s\n%s\n' "$dir" "$id"
}

# record_entry <cmd> <tree> <exit> <started> <ended> <source>, output on stdin.
# The first writer for a tree and command wins; a later one is dropped.
record_entry() {
  local cmd="$1" tree="$2" code="$3" started="$4" ended="$5" source="$6" paths dir id out tmp
  paths="$(entry_paths "$cmd" "$tree")"
  dir="${paths%%$'\n'*}"; id="${paths#*$'\n'}"
  (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  out="$id.$(rand_hex).out"
  write_file "$dir/$out"
  tmp="$(mktemp "$dir/.entry.XXXXXX")" || die "cannot write in $dir"
  jq -n --argjson v "$VERSION" --arg c "$cmd" --arg t "$tree" --argjson e "$code" \
    --argjson s "$started" --argjson n "$ended" --arg src "$source" --arg o "$out" \
    '{version: $v, command: $c, tree: $t, exit: $e, started: $s, ended: $n, source: $src, output: $o}' > "$tmp" \
    || { rm -f "$tmp" "$dir/$out"; die "cannot write the entry"; }
  if ln "$tmp" "$dir/$id.json" 2> /dev/null; then
    rm -f "$tmp"
    printf '%s\n' "$dir/$id.json"
  else
    rm -f "$tmp" "$dir/$out"
    note "an entry for this tree and command already exists; kept the first"
    printf '%s\n' "$dir/$id.json"
  fi
}

int_opt() {
  local name="$1" val="$2"
  [[ "$val" =~ ^-?[0-9]+$ ]] || die "--$name must be a whole number, got '$val'"
}

cmd_evidence() {
  local sub="${1:-}" tree paths dir id file started rc ended
  shift || true
  case "$sub" in
    lookup)
      parse_opts "command tree" -- "$@"
      require_opt command
      tree="${opt_tree:-$(tree_key)}"; valid_tree "$tree"
      paths="$(entry_paths "$opt_command" "$tree")"
      dir="${paths%%$'\n'*}"; id="${paths#*$'\n'}"
      file="$dir/$id.json"
      [ -f "$file" ] || return 1
      check_json_version "$file"
      jq -c --arg d "$dir" '. + {output_path: ($d + "/" + .output)}' "$file"
      ;;
    record)
      parse_opts "command exit started ended source tree" -- "$@"
      require_opt command; require_opt exit; require_opt started; require_opt ended
      int_opt exit "$opt_exit"; int_opt started "$opt_started"; int_opt ended "$opt_ended"
      tree="${opt_tree:-$(tree_key)}"; valid_tree "$tree"
      record_entry "$opt_command" "$tree" "$opt_exit" "$opt_started" "$opt_ended" "${opt_source:-local}"
      ;;
    run)
      parse_opts "command" -- "$@"
      require_opt command
      [ "${#rest_args[@]}" -gt 0 ] || die "run needs a command after --"
      tree="$(tree_key)"
      started="$(now)"
      local capture
      capture="$(mktemp -t review-state-run.XXXXXX)" || die "cannot create a capture file"
      rc=0; "${rest_args[@]}" > "$capture" 2>&1 < /dev/null || rc=$?
      ended="$(now)"
      cat "$capture"
      record_entry "$opt_command" "$tree" "$rc" "$started" "$ended" local < "$capture" > /dev/null \
        || { rm -f "$capture"; exit 2; }
      rm -f "$capture"
      return "$rc"
      ;;
    ci)
      parse_opts "head command" -- "$@"
      require_opt head; require_opt command
      [[ "$opt_head" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || die "--head must be a full commit hash"
      local runs verdict summary first last
      runs="$(jq -c 'if type == "array" then map(if type == "object" and has("check_runs") then .check_runs[] else . end)
                     elif type == "object" and has("check_runs") then .check_runs
                     else error("not a check-runs listing") end' 2> /dev/null)" \
        || die "stdin is not a check-runs listing (the API object, a slurped list of pages, or a list of runs)"
      verdict="$(jq -r 'map(select(.status != "completed" or (.conclusion != "skipped" and .conclusion != "neutral")))
        | if length == 0 then "none"
          elif any(.status != "completed") then "pending"
          elif all(.conclusion == "success") then "evidence"
          else "failed" end' <<< "$runs")"
      case "$verdict" in
        evidence) ;;
        none) note "no check run that counts on $opt_head (none, or only skipped and neutral ones); no evidence"; return 1 ;;
        pending) note "a check run on $opt_head has not concluded; no evidence yet"; return 1 ;;
        *) note "a check run on $opt_head concluded other than success; no evidence"; return 1 ;;
      esac
      tree="$(git rev-parse --verify --quiet "$opt_head^{tree}")" || die "$opt_head is not a commit in this repository"
      summary="$(jq -r '.[] | "\(.name // "?"): \(.conclusion)"' <<< "$runs")"
      first="$(jq '[.[] | .started_at // empty | fromdateiso8601] | min // empty' <<< "$runs" 2> /dev/null)" || first=""
      last="$(jq '[.[] | .completed_at // empty | fromdateiso8601] | max // empty' <<< "$runs" 2> /dev/null)" || last=""
      printf '%s\n' "$summary" | record_entry "$opt_command" "$tree" 0 "${first:-$(now)}" "${last:-$(now)}" "ci:check-runs:$opt_head"
      ;;
    *) die "evidence takes lookup, record, run or ci" ;;
  esac
}

# --- Loop artifact ---------------------------------------------------------------------------
loop_file() {
  local skill="$1" dir file header
  [[ "$skill" =~ ^[a-z][a-z0-9-]{0,63}$ ]] || die "--skill must be a skill name, got '$skill'"
  dir="$(evidence_root)/loop"
  (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  file="$dir/$skill.md"
  header="<!-- review-loop version=$VERSION skill=$skill -->"
  if [ ! -e "$file" ]; then
    printf '%s\n' "$header" | write_file "$file"
  else
    local first got
    first="$(head -n 1 "$file")"
    got="$(sed -n 's/^<!-- review-loop version=\([^ ]*\) .*/\1/p' <<< "$first")"
    [ "$got" = "$VERSION" ] || die "$file has unknown version '${got:-missing}' (this helper reads version $VERSION); refusing it"
  fi
  printf '%s' "$file"
}

cmd_loop() {
  local sub="${1:-}" file head base
  shift || true
  case "$sub" in
    mark)
      parse_opts "skill iteration phase base" -- "$@"
      require_opt skill; require_opt iteration; require_opt phase
      [[ "$opt_iteration" =~ ^[1-9][0-9]{0,4}$ ]] || die "--iteration must be a positive number"
      case "$opt_phase" in start|end) ;; *) die "--phase is start or end" ;; esac
      file="$(loop_file "$opt_skill")"
      head="$(git rev-parse --verify --quiet HEAD)" || head="-"
      base="-"
      if [ -n "${opt_base:-}" ]; then
        base="$(git merge-base HEAD "$opt_base" 2> /dev/null)" || base="-"
      fi
      printf '<!-- iteration %s %s at=%s head=%s merge-base=%s -->\n' \
        "$opt_iteration" "$opt_phase" "$(now)" "$head" "$base" >> "$file"
      printf '%s\n' "$file"
      ;;
    append)
      parse_opts "skill" -- "$@"
      require_opt skill
      file="$(loop_file "$opt_skill")"
      cat >> "$file"
      ;;
    *) die "loop takes mark or append" ;;
  esac
}

# --- Dispatch ------------------------------------------------------------------------------------
need jq
need git
cmd="${1:-}"
shift || true
case "$cmd" in
  key) worktree_top > /dev/null; tree_key; echo ;;
  evidence) cmd_evidence "$@" ;;
  session-pid) session_pid; echo ;;
  register) cmd_register "$@" ;;
  unregister) cmd_unregister "$@" ;;
  sessions) cmd_sessions ;;
  lock) cmd_lock "$@" ;;
  inbox) cmd_inbox "$@" ;;
  loop) cmd_loop "$@" ;;
  encode) [ "$#" -eq 1 ] || die "encode takes one segment"; encode_segment "$1"; echo ;;
  *) die "unknown command '${cmd}'; see the usage at the top of this script" ;;
esac
