#!/usr/bin/env bash
# Shared state for the review skills: the per-worktree evidence record, the
# writer lock, the session registry, the inbox, the loop artifact and the
# decision ledger. The contract lives in skills/review-shared/state.md; this is
# its one writer, so no skill needs a shell redirect to touch any of it.
#
# Usage:
#   review-state.sh key
#   review-state.sh evidence lookup --command <key> [--tree <hash>]
#   review-state.sh evidence record --command <key> --exit <n> --started <epoch>
#       --ended <epoch> [--source <text>] [--tree <hash>]      (output on stdin)
#   review-state.sh evidence run --command <key> [--tree <hash>] -- <argv>...
#   review-state.sh evidence ci --head <sha> --command <key>   (check runs on stdin)
#   review-state.sh session-pid
#   review-state.sh register --name <n> --skill <s> --repo <owner/repo>
#       (--pr <n> | --branch <b>) --worktree <dir>
#   review-state.sh unregister --session <token>
#   review-state.sh sessions
#   review-state.sh lock acquire --session <token> --repo <owner/repo>
#       (--pr <n> | --branch <b>) [--wait <seconds>]
#   review-state.sh lock release --session <token> --token <lock-token>
#       --repo <owner/repo> (--pr <n> | --branch <b>)
#   review-state.sh lock handover --session <token> --token <branch-token>
#       --repo <owner/repo> --branch <b> --pr <n>
#   review-state.sh lock status --repo <owner/repo> (--pr <n> | --branch <b>)
#   review-state.sh inbox send --to <session-token> --from <name>   (body on stdin)
#   review-state.sh inbox read --session <token>
#   review-state.sh loop mark --skill <s> --iteration <n> --phase <start|end> [--base <ref>]
#   review-state.sh loop append --skill <s>                         (body on stdin)
#   review-state.sh ledger record --repo <owner/repo> --pr <n> --key <k> --anchor <a>
#       --disposition <fixed|rejected|deferred|suppressed> --head <sha> --reply <url>
#       [--follow-up <record>] [--reason <text>]                (evidence on stdin)
#   review-state.sh ledger lookup --repo <owner/repo> --pr <n> --key <k> --anchor <a> --head <sha>
#   review-state.sh ledger show --repo <owner/repo> --pr <n>
#   review-state.sh encode <segment>
#
# Exit status: 0 success or hit; 1 a miss, a held lock, not this session's
# lock, no CI evidence, or an inbox recipient whose process is gone; 2 an
# error. `evidence run` is the exception: it exits with the wrapped command's
# own status once the command has run.
#
# Bash 3.2 compatible: the Macs run it under /bin/bash, which has no
# inherit_errexit. So a function that can fail hands its result back in a
# global rather than through $(...), where set -e would not reach it.
#
# The opt_<name> variables are assigned by parse_opts through printf -v.
# shellcheck disable=SC2154
set -euo pipefail
# The caller's locale, restored for a command `evidence run` wraps.
CALLER_LC_ALL="${LC_ALL-}"
CALLER_LC_ALL_SET="${LC_ALL+set}"
LC_ALL=C
export LC_ALL
NL=$'\n'

VERSION=1
# Both overrides are test seams; the review skills never set them.
STATE_ROOT="${REVIEW_STATE_ROOT:-$HOME/.config/dotfiles/review}"
SESSION_COMM="${REVIEW_SESSION_COMM:-claude}"
EVIDENCE_DIR=".claude/review-evidence"
INBOX_CAP=262144
EVIDENCE_CAP=4096

die() { echo "review-state: $1" >&2; exit 2; }
note() { echo "review-state: $1" >&2; }

need() {
  local tool="$1"
  command -v "$tool" > /dev/null 2>&1 || die "$tool is required but not on PATH"
}

now() { date +%s; }

HEX=""
rand_hex() {
  HEX="$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')" || HEX=""
  [ "${#HEX}" -eq 8 ] || die "could not read /dev/urandom"
}

# --- Option parsing -----------------------------------------------------------
# parse_opts <allowed names> -- <args>: clears every opt_<name>, sets one for
# each --<name> <value> (a hyphen in the name becomes an underscore in the variable),
# and leaves anything after a literal -- in rest_args.
OPT_NAMES="anchor base branch command disposition ended exit follow_up from head iteration key name phase pr reason repo reply session skill source started to token tree wait worktree"
for _n in $OPT_NAMES; do printf -v "opt_$_n" '%s' ""; done
rest_args=()
parse_opts() {
  local allowed=" $1 " name
  shift 2
  for name in $OPT_NAMES; do printf -v "opt_$name" '%s' ""; done
  rest_args=()
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --)
        # Only a command that wraps another takes arguments after --.
        case "$allowed" in *" -- "*) ;; *) die "unexpected --; this command takes no trailing arguments" ;; esac
        shift; rest_args=("$@"); return 0 ;;
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
  var="opt_$name"
  [ -n "${!var:-}" ] || die "--$name is required"
}

# One printable line, so nothing a session supplies can forge another line of
# this helper's output.
single_line() {
  local name="$1" value="$2"
  case "$value" in *[[:cntrl:]]*) die "--$name must be one printable line" ;; esac
  # UTF-8 C1 controls and bidirectional overrides, which [[:cntrl:]] does not
  # see byte-wise and which can make a notice display something it does not say.
  case "$value" in
    *$'\xc2'[$'\x80'-$'\x9f']*|*$'\xe2\x80'[$'\x8e'$'\x8f'$'\xaa'-$'\xae']*|*$'\xe2\x81'[$'\xa6'-$'\xa9']*)
      die "--$name must not carry control or text-direction characters" ;;
  esac
  [ "${#value}" -le 256 ] || die "--$name is longer than 256 bytes"
}

# --- Plain-name encoding --------------------------------------------------------
# Every byte outside [A-Za-z0-9.-] becomes _<hex>, as does a leading . or -, so
# the result can never be a path component other than a plain name. `_` itself
# is escaped, which keeps the mapping one-to-one. Sets ENC.
ENC=""
encode_segment() {
  local raw="$1" out="" c i byte
  [ -n "$raw" ] || die "an empty name cannot be encoded"
  # The encoding never shortens a name, so the cap below can be checked first.
  [ "${#raw}" -le 150 ] || die "'$raw' is too long to use as a path segment"
  for ((i = 0; i < ${#raw}; i++)); do
    c="${raw:i:1}"
    case "$c" in
      [A-Za-z0-9]) out="$out$c" ;;
      .) if [ -z "$out" ]; then out="_2e"; else out="$out$c"; fi ;;
      -) if [ -z "$out" ]; then out="_2d"; else out="$out$c"; fi ;;
      *) byte="$(printf '%s' "$c" | od -An -tx1 | tr -d ' \n')"; out="${out}_$byte" ;;
    esac
  done
  [[ "$out" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] || die "'$raw' did not encode to a plain name"
  # Leaves room under the filesystem's name limit for the claim and aside
  # names derived from a lock.
  [ "${#out}" -le 150 ] || die "'$raw' is too long to use as a path segment"
  ENC="$out"
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
  case "$d$h$m$s" in ''|*[!0-9]*) return 0 ;; esac
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
  [ "${#pid}" -le 10 ] && [ "$((10#$pid))" -gt 0 ] || return 1
  if ! kill -0 "$pid" 2> /dev/null; then
    err="$(kill -0 "$pid" 2>&1)" || true
    case "$err" in *[Pp]ermi*) ;; *) return 1 ;; esac
  fi
  # An exited process its parent has not reaped still answers kill -0.
  case "$(ps -o stat= -p "$pid" 2> /dev/null)" in *Z*) return 1 ;; esac
  case "$epoch" in ''|*[!0-9]*) return 0 ;; esac
  [ "${#epoch}" -le 12 ] || return 0
  elapsed="$(elapsed_of "$pid")"
  [ -n "$elapsed" ] || return 0
  started=$(( $(now) - elapsed ))
  [ "$started" -le $(( 10#$epoch + 2 )) ]
}

# The Claude Code session process: every tool call is a fresh child that exits
# at once, so the helper's own pid would name nothing that outlives the call.
# comm and args are read apart because either may contain spaces.
SESSION_PID=""
find_session_pid() {
  local pid="$PPID" ppid comm argv0 depth=0
  while [ -n "$pid" ] && [ "$pid" -ge 1 ] && [ "$depth" -lt 64 ]; do
    comm="$(ps -o comm= -p "$pid" 2> /dev/null)" || comm=""
    argv0="$(ps -o args= -p "$pid" 2> /dev/null)" || argv0=""
    argv0="${argv0%% *}"
    if [ "${comm##*/}" = "$SESSION_COMM" ] || [ "${argv0##*/}" = "$SESSION_COMM" ]; then
      SESSION_PID="$pid"
      return 0
    fi
    [ "$pid" -gt 1 ] || break
    ppid="$(ps -o ppid= -p "$pid" 2> /dev/null | tr -d ' ')" || ppid=""
    case "$ppid" in ''|*[!0-9]*) break ;; esac
    pid="$ppid"
    depth=$((depth + 1))
  done
  die "no $SESSION_COMM session process in this helper's ancestry; run it from a Claude Code session"
}

TOKEN=""
mint_token() {
  local pid="$1" stamp
  stamp="$(now)"
  rand_hex
  TOKEN="$pid-$stamp-$HEX"
}

valid_token() {
  local token="$1"
  [[ "$token" =~ ^[0-9]{1,10}-[0-9]{1,12}-[0-9a-f]{8}$ ]]
}

# --- The lock root ----------------------------------------------------------------
ROOT_READY=""
DIR=""
root_dir() {
  local sub="$1"
  if [ -z "$ROOT_READY" ]; then
    if [ -L "$STATE_ROOT" ]; then die "$STATE_ROOT is a symlink; refusing to use it as the lock root"; fi
    (umask 077 && mkdir -p "$STATE_ROOT") || die "cannot create $STATE_ROOT"
    [ -O "$STATE_ROOT" ] || die "$STATE_ROOT is not owned by this user"
    chmod 700 "$STATE_ROOT" || die "cannot set $STATE_ROOT to mode 0700"
    ROOT_READY=1
  fi
  DIR="$STATE_ROOT/$sub"
  if [ -L "$DIR" ]; then die "$DIR is a symlink; refusing it"; fi
  [ -d "$DIR" ] || (umask 077 && mkdir -p "$DIR") || die "cannot create $DIR"
}

# write_file <path>: stdin to <path>, atomically, at mode 0600.
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
  [ -z "$opt_pr" ] || valid_pr "$opt_pr"
}

valid_pr() {
  local pr="$1"
  [[ "$pr" =~ ^[1-9][0-9]{0,9}$ ]] || die "--pr must be a PR number, got '$pr'"
}

repo_args() {
  require_opt repo
  [[ "$opt_repo" =~ ^[^/]+/[^/]+$ ]] || die "--repo must be <owner>/<repo>, got '$opt_repo'"
  # GitHub names are case-insensitive, so o/r and O/R must share one lock.
  opt_repo="$(printf '%s' "$opt_repo" | tr '[:upper:]' '[:lower:]')"
}

REG=""
registration_file() {
  local token="$1"
  valid_token "$token" || die "'$token' is not a session token"
  root_dir sessions
  REG="$DIR/$token.json"
}

cmd_register() {
  local token file
  parse_opts "name skill repo pr branch worktree" -- "$@"
  require_opt name; require_opt skill; require_opt worktree
  single_line name "$opt_name"; single_line worktree "$opt_worktree"
  [[ "$opt_skill" =~ ^[a-z][a-z0-9-]{0,63}$ ]] || die "--skill must be a skill name, got '$opt_skill'"
  repo_args; target_args
  single_line branch "$opt_branch"; single_line repo "$opt_repo"
  # Refused here rather than at unregister, where it would strand the entry.
  encode_segment "${opt_repo%%/*}"; encode_segment "${opt_repo#*/}"
  [ -z "$opt_branch" ] || encode_segment "$opt_branch"
  find_session_pid
  mint_token "$SESSION_PID"; token="$TOKEN"
  registration_file "$token"; file="$REG"
  jq -n --argjson v "$VERSION" --arg token "$token" --argjson pid "$SESSION_PID" \
    --arg name "$opt_name" --arg skill "$opt_skill" --arg repo "$opt_repo" \
    --arg pr "$opt_pr" --arg branch "$opt_branch" --arg wt "$opt_worktree" \
    --argjson started "$(now)" \
    '{version: $v, token: $token, pid: $pid, name: $name, skill: $skill, repo: $repo}
     + (if $pr != "" then {pr: ($pr | tonumber)} else {branch: $branch} end)
     + {worktree: $wt, started: $started}' | write_file "$file"
  printf '%s\n' "$token"
}

# own_registration <session>: the registration exists, carries a version this
# helper reads, and belongs to the calling session process. Sets REG.
own_registration() {
  local session="$1" pid
  registration_file "$session"
  [ -f "$REG" ] || die "no registration for session $session; register first"
  check_json_version "$REG"
  pid="$(jq -r .pid "$REG" 2> /dev/null)" || die "registration $REG vanished or is unreadable"
  find_session_pid
  [ "$pid" = "$SESSION_PID" ] || die "session $session belongs to another process; register this session"
}

# Unregistering releases every lock the session still holds, then drops its
# registration and inbox, unread files included.
cmd_unregister() {
  local hf lockp token repo dir
  parse_opts "session" -- "$@"
  require_opt session
  own_registration "$opt_session"
  repo="$(jq -r .repo "$REG")" || die "cannot read $REG"
  encode_segment "${repo%%/*}"; dir="$ENC"
  encode_segment "${repo#*/}"; dir="$dir/$ENC"
  root_dir locks
  for hf in "$DIR/$dir"/*#holder#*; do
    [ -f "$hf" ] && [ ! -L "$hf" ] || continue
    lockp="${hf%%#holder#*}"; token="${hf#"$lockp"#holder#}"
    valid_token "$token" || continue
    jq -e --arg s "$opt_session" --arg t "$token" '.session == $s and .token == $t' "$hf" > /dev/null 2>&1 || continue
    if [ "$(readlink "$lockp" 2> /dev/null)" = "$token" ]; then
      rm -f "$lockp"
      note "released $lockp, still held at unregister"
    fi
    rm -f "$hf"
  done
  rm -f "$REG"
  root_dir inbox
  rm -rf "${DIR:?}/$opt_session"
}

# Live registrations as JSON lines; one whose owner is gone reads as absent
# and is pruned on the way.
cmd_sessions() {
  local f token j v
  prune_dead_sessions
  if [ -n "$PRUNED" ]; then
    note "removed the inbox files of sessions whose process is gone:"
    printf '%s\n' "$PRUNED" | sed 's/^/  /' >&2
  fi
  root_dir sessions
  for f in "$DIR"/*.json; do
    [ -f "$f" ] || continue
    token="${f##*/}"; token="${token%.json}"
    valid_token "$token" || continue
    owner_alive "$token" || continue
    # Read once: a registration removed by a concurrent unregister is skipped,
    # not an error.
    j="$(jq -c . "$f" 2> /dev/null)" || { [ -e "$f" ] || continue; die "$f is not valid JSON; refusing it"; }
    v="$(jq -r 'if type == "object" and has("version") then .version | tostring else "missing" end' <<< "$j")"
    [ "$v" = "$VERSION" ] || die "$f has unknown version '$v' (this helper reads version $VERSION); refusing it"
    printf '%s\n' "$j"
  done
}

# Remove every registration whose owner is gone, with its inbox, and every
# inbox with no registration at all. PRUNED lists the removed inbox files so a
# notice can name them.
PRUNED=""
prune_dead_sessions() {
  local sessions inbox f token box
  PRUNED=""
  root_dir sessions; sessions="$DIR"
  root_dir inbox; inbox="$DIR"
  for f in "$sessions"/*.json; do
    [ -e "$f" ] || continue
    token="${f##*/}"; token="${token%.json}"
    valid_token "$token" || continue
    owner_alive "$token" && continue
    PRUNED="$PRUNED${PRUNED:+$NL}$(list_inbox_files "$inbox/$token")"
    rm -f "$f"
    rm -rf "${inbox:?}/$token"
  done
  for box in "$inbox"/*; do
    [ -d "$box" ] || continue
    token="${box##*/}"
    valid_token "$token" || continue
    [ -e "$sessions/$token.json" ] && continue
    PRUNED="$PRUNED${PRUNED:+$NL}$(list_inbox_files "$box")"
    rm -rf "${inbox:?}/$token"
  done
  PRUNED="$(printf '%s\n' "$PRUNED" | sed '/^$/d')"
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
LOCKP=""
lock_path() {
  local repo="$1" pr="$2" branch="$3" owner name leaf dir
  encode_segment "${repo%%/*}"; owner="$ENC"
  encode_segment "${repo#*/}"; name="$ENC"
  if [ -n "$pr" ]; then
    valid_pr "$pr"
    leaf="pr-$pr"
  else
    encode_segment "$branch"; leaf="branch-$ENC"
  fi
  root_dir locks
  dir="$DIR/$owner/$name"
  [ -d "$dir" ] || (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  LOCKP="$dir/$leaf"
}

# The holder record sits beside the link under a name carrying the token, so a
# release or a reclaim only ever touches its own. `#` never appears in an
# encoded segment, so these names cannot collide with a lock. A token read off
# a link was written by whoever made the link, so it is slugged before it
# becomes part of a path.
holder_file() {
  local lockp="$1" token="$2"
  printf '%s#holder#%s' "$lockp" "$(slug "$token")"
}

slug() {
  local raw="$1"
  raw="${raw//[!A-Za-z0-9-]/_}"
  printf '%s' "${raw:0:64}"
}

# A holder record that vanishes between the test and the read was released in
# the meantime; it reads as no record rather than as an error.
print_holder() {
  local lockp="$1" token="$2" hf
  hf="$(holder_file "$lockp" "$token")"
  [ -f "$hf" ] && jq -c . "$hf" 2> /dev/null && return 0
  jq -nc --arg t "$token" '{token: $t}'
}

holder_label() {
  local lockp="$1" token="$2" hf
  hf="$(holder_file "$lockp" "$token")"
  [ -f "$hf" ] && jq -r '"\(.name | @json) (skill \(.skill | @json), worktree \(.worktree | @json), session \(.session))"' "$hf" 2> /dev/null && return 0
  printf 'token %s (no holder record)' "$(slug "$token")"
}

# link <target> <path>: create the symlink and prove it landed at that path. A
# directory squatting the path would otherwise take the link inside it.
link() {
  local target="$1" path="$2"
  ln -s "$target" "$path" 2> /dev/null || return 1
  [ "$(readlink "$path" 2> /dev/null)" = "$target" ] && return 0
  [ -d "$path" ] && rm -f "$path/${target##*/}"
  return 1
}

# A fresh name beside <path> for moving something aside; never one in use.
ASIDE=""
aside_name() {
  local path="$1" kind="$2" n=0
  while [ "$n" -lt 16 ]; do
    rand_hex
    ASIDE="$path#$kind#$HEX"
    [ -e "$ASIDE" ] || [ -L "$ASIDE" ] || return 0
    n=$((n + 1))
  done
  die "no free name beside $path"
}

# publish <lockp> <token> <registration>: record the holder, then create the
# link, so a live link always has its record. 0 held, 1 the path was taken.
publish() {
  local lockp="$1" token="$2" reg="$3" hf
  hf="$(holder_file "$lockp" "$token")"
  jq --arg t "$token" --argjson at "$(now)" \
    '{token: $t, session: .token, pid, name, skill, worktree, acquired: $at}' "$reg" | write_file "$hf" \
    || die "cannot record the holder beside $lockp"
  link "$token" "$lockp" && return 0
  rm -f "$hf"
  return 1
}

# reclaim <lockp> <dead-token> <our-token> <registration>: sets RECLAIM to 0
# when the dead link was replaced by ours, 1 when something moved and the
# caller should look again. A claim link serializes breakers of one dead
# owner, the dead link is taken by rename, and ours is published before the
# claim is dropped, so two reclaimers never both win.
RECLAIM=1
reclaim() {
  local lockp="$1" dead="$2" token="$3" reg="$4" claim mine back label removed hf session
  RECLAIM=1
  claim="$lockp#break#$(slug "$dead")"
  mint_token "$$"; mine="$TOKEN"
  if ! link "$mine" "$claim"; then
    back="$(readlink "$claim" 2> /dev/null)" || back=""
    if [ -n "$back" ] && ! owner_alive "$back"; then
      aside_name "$claim" stale
      if mv "$claim" "$ASIDE" 2> /dev/null; then
        if [ "$(readlink "$ASIDE" 2> /dev/null)" = "$back" ] || link "$(readlink "$ASIDE")" "$claim"; then
          rm -f "$ASIDE"
        fi
      fi
    fi
    return 0
  fi
  if [ "$(readlink "$lockp" 2> /dev/null)" != "$dead" ]; then
    rm -f "$claim"; return 0
  fi
  aside_name "$lockp" taken
  if ! mv "$lockp" "$ASIDE" 2> /dev/null; then
    rm -f "$claim"; return 0
  fi
  if [ "$(readlink "$ASIDE" 2> /dev/null)" != "$dead" ]; then
    back="$(readlink "$ASIDE" 2> /dev/null)" || back=""
    if [ -n "$back" ] && link "$back" "$lockp"; then
      rm -f "$ASIDE"
    else
      note "$lockp changed hands mid-reclaim; the displaced link is kept at $ASIDE"
    fi
    rm -f "$claim"; return 0
  fi
  label="$(holder_label "$lockp" "$dead")"
  hf="$(holder_file "$lockp" "$dead")"
  session=""
  [ -f "$hf" ] && session="$(jq -r '.session // empty' "$hf" 2> /dev/null)" || session=""
  removed=""
  if [ -n "$session" ] && valid_token "$session" && ! owner_alive "$session"; then
    root_dir inbox
    removed="$(list_inbox_files "$DIR/$session")"
    rm -rf "${DIR:?}/$session"
    root_dir sessions
    rm -f "$DIR/$session.json"
  fi
  rm -f "$ASIDE" "$hf"
  if publish "$lockp" "$token" "$reg"; then RECLAIM=0; fi
  rm -f "$claim"
  prune_dead_sessions
  removed="$removed${removed:+$NL}$PRUNED"
  removed="$(printf '%s\n' "$removed" | sed '/^$/d' | sort -u)"
  if [ "$RECLAIM" = 0 ]; then
    note "reclaimed $lockp from $label, whose process is gone"
  else
    note "cleared $lockp of $label, whose process is gone, but another session took it first"
  fi
  if [ -n "$removed" ]; then
    note "removed inbox files, read and unread, of the dead holder and of any other session that is gone:"
    printf '%s\n' "$removed" | sed 's/^/  /' >&2
  else
    note "the dead holder left no inbox files"
  fi
}

# try_acquire <lockp> <session> <session-pid> <registration> <report>: sets
# ACQUIRE to 0 held (token in ACQUIRED), 1 a live holder has it, and prints the
# holder on a refusal only when <report> is 1. Never returns non-zero, so set -e
# stays in force inside it.
ACQUIRE=1
ACQUIRED=""
try_acquire() {
  local lockp="$1" session="$2" pid="$3" reg="$4" report="$5" cur _ held ours
  ACQUIRE=1; ACQUIRED=""
  for _ in 1 2 3 4 5; do
    # A held lock is examined before anything is written, so a waiter polling
    # a busy lock costs no holder-record churn.
    if [ ! -L "$lockp" ]; then
      mint_token "$pid"; ours="$TOKEN"
      if publish "$lockp" "$ours" "$reg"; then
        ACQUIRE=0; ACQUIRED="$ours"; return 0
      fi
    fi
    if [ ! -L "$lockp" ]; then
      [ -e "$lockp" ] && die "$lockp exists and is not a lock symlink; refusing to touch it"
      continue
    fi
    cur="$(readlink "$lockp" 2> /dev/null)" || cur=""
    [ -n "$cur" ] || continue
    if owner_alive "$cur"; then
      held="$(jq -r '.session // empty' "$(holder_file "$lockp" "$cur")" 2> /dev/null)" || held=""
      if [ "$held" = "$session" ]; then
        ACQUIRE=0; ACQUIRED="$cur"; return 0
      fi
      if [ "$report" = 1 ]; then
        print_holder "$lockp" "$cur"
        note "the writer lock is held by $(holder_label "$lockp" "$cur")"
      fi
      return 0
    fi
    mint_token "$pid"; ours="$TOKEN"
    reclaim "$lockp" "$cur" "$ours" "$reg"
    if [ "$RECLAIM" = 0 ]; then
      ACQUIRE=0; ACQUIRED="$ours"; return 0
    fi
    sleep 0.2
  done
  if [ "$report" = 1 ]; then
    cur="$(readlink "$lockp" 2> /dev/null)" || cur=""
    [ -z "$cur" ] || print_holder "$lockp" "$cur"
    note "the writer lock at $lockp kept changing hands; try again"
  fi
}

# release <lockp> <session> <token>: 0 released, 1 not this session's lock.
release() {
  local lockp="$1" session="$2" token="$3" hf held
  hf="$(holder_file "$lockp" "$token")"
  held="$(jq -r '.session // empty' "$hf" 2> /dev/null)" || held=""
  if [ "$(readlink "$lockp" 2> /dev/null)" != "$token" ] || [ "$held" != "$session" ]; then
    note "the lock at $lockp is not this session's token; nothing released"
    return 1
  fi
  rm -f "$lockp"
  rm -f "$hf"
}

# A session takes locks only in the repository it registered for, so
# unregister finds every lock it holds.
same_repo() {
  local reg="$1" registered
  registered="$(jq -r .repo "$reg")" || die "cannot read $reg"
  [ "$registered" = "$opt_repo" ] || die "session is registered for $registered, not $opt_repo"
}

cmd_lock() {
  local sub="${1:-}" pid reg deadline cur wait branch_lock now_s
  shift || true
  case "$sub" in
    acquire)
      parse_opts "session repo pr branch wait" -- "$@"
      require_opt session; repo_args; target_args
      wait="${opt_wait:-0}"
      [[ "$wait" =~ ^(0|[1-9][0-9]{0,4})$ ]] || die "--wait takes whole seconds, got '$wait'"
      own_registration "$opt_session"; reg="$REG"; pid="$SESSION_PID"
      same_repo "$reg"
      lock_path "$opt_repo" "$opt_pr" "$opt_branch"
      deadline=$(( $(now) + wait ))
      while :; do
        now_s="$(now)"
        if [ "$now_s" -lt "$deadline" ]; then
          try_acquire "$LOCKP" "$opt_session" "$pid" "$reg" 0
          if [ "$ACQUIRE" = 0 ]; then printf '%s\n' "$ACQUIRED"; return 0; fi
          [ "$((deadline - now_s))" -le 1 ] || sleep 1
        else
          try_acquire "$LOCKP" "$opt_session" "$pid" "$reg" 1
          if [ "$ACQUIRE" = 0 ]; then printf '%s\n' "$ACQUIRED"; return 0; fi
          return 1
        fi
      done
      ;;
    release)
      parse_opts "session token repo pr branch" -- "$@"
      require_opt session; require_opt token; repo_args; target_args
      valid_token "$opt_token" || die "'$opt_token' is not a lock token"
      own_registration "$opt_session"
      lock_path "$opt_repo" "$opt_pr" "$opt_branch"
      release "$LOCKP" "$opt_session" "$opt_token"
      ;;
    handover)
      parse_opts "session token repo pr branch" -- "$@"
      require_opt session; require_opt token; repo_args
      valid_token "$opt_token" || die "'$opt_token' is not a lock token"
      [ -n "$opt_pr" ] && [ -n "$opt_branch" ] || die "handover needs both --branch and --pr"
      valid_pr "$opt_pr"
      own_registration "$opt_session"; reg="$REG"; pid="$SESSION_PID"
      same_repo "$reg"
      lock_path "$opt_repo" "" "$opt_branch"; branch_lock="$LOCKP"
      lock_path "$opt_repo" "$opt_pr" ""
      try_acquire "$LOCKP" "$opt_session" "$pid" "$reg" 1
      [ "$ACQUIRE" = 0 ] || return 1
      printf '%s\n' "$ACQUIRED"
      release "$branch_lock" "$opt_session" "$opt_token" \
        || note "took the PR $opt_pr lock, but the branch lock was not this session's token"
      return 0
      ;;
    status)
      parse_opts "repo pr branch" -- "$@"
      repo_args; target_args
      lock_path "$opt_repo" "$opt_pr" "$opt_branch"
      cur="$(readlink "$LOCKP" 2> /dev/null)" || cur=""
      if [ -z "$cur" ] && [ ! -L "$LOCKP" ] && [ -e "$LOCKP" ]; then
        die "$LOCKP exists and is not a lock symlink"
      elif [ -z "$cur" ]; then
        jq -nc '{state: "free"}'
      elif owner_alive "$cur"; then
        jq -nc --argjson h "$(print_holder "$LOCKP" "$cur")" '{state: "held", holder: $h}'
      else
        jq -nc --argjson h "$(print_holder "$LOCKP" "$cur")" '{state: "stale", holder: $h}'
      fi
      ;;
    *) die "lock takes acquire, release, handover or status" ;;
  esac
}

# --- Inbox --------------------------------------------------------------------------------
cmd_inbox() {
  local sub="${1:-}" box f name sent nonce claimed body
  shift || true
  case "$sub" in
    send)
      parse_opts "to from" -- "$@"
      require_opt to; require_opt from
      single_line from "$opt_from"
      valid_token "$opt_to" || die "'$opt_to' is not a session token"
      registration_file "$opt_to"
      [ -f "$REG" ] || die "no registered session $opt_to to send to"
      if ! owner_alive "$opt_to"; then
        note "session $opt_to is gone; nothing delivered, keep the findings"
        return 1
      fi
      root_dir inbox
      box="$DIR/$opt_to"
      if [ -L "$box" ]; then die "$box is a symlink; refusing it"; fi
      [ -d "$box" ] || (umask 077 && mkdir -p "$box") || die "cannot create $box"
      rand_hex
      name="$(now)-$HEX.md"
      sent="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      # Outside the inbox and removed on any exit, so a failed send leaves
      # nothing behind. A writer past the cap gets SIGPIPE; the note says why.
      body="$(mktemp -t review-state-body.XXXXXX)" || die "cannot create a scratch file"
      CAPTURE="$body"; trap cleanup_capture EXIT
      head -c "$((INBOX_CAP + 1))" > "$body" || die "cannot read the message"
      [ -s "$body" ] || die "the message is empty; nothing delivered"
      if [ "$(wc -c < "$body")" -gt "$INBOX_CAP" ]; then
        note "the message was cut at $INBOX_CAP bytes"
      fi
      { printf 'from: %s\nsent: %s\n\n' "$opt_from" "$sent"; head -c "$INBOX_CAP" "$body"; } | write_file "$box/$name"
      if [ ! -e "$REG" ]; then
        rm -f "$box/$name"
        die "session $opt_to unregistered while the message was written; nothing delivered"
      fi
      printf '%s\n' "$box/$name"
      ;;
    read)
      parse_opts "session" -- "$@"
      require_opt session
      own_registration "$opt_session"
      root_dir inbox
      box="$DIR/$opt_session"
      [ -e "$box" ] || [ -L "$box" ] || return 0
      if [ -L "$box" ] || [ -L "$box/read" ]; then die "$box or its read directory is a symlink; refusing it"; fi
      [ -d "$box/read" ] || (umask 077 && mkdir -p "$box/read") || die "cannot create $box/read"
      # The markers carry a nonce minted per read, so a message body cannot
      # close its own frame and pass what follows off as something else.
      rand_hex; nonce="$HEX"
      for f in "$box"/*.md; do
        [ -f "$f" ] && [ ! -L "$f" ] || continue
        claimed="$box/read/${f##*/}"
        [ ! -e "$claimed" ] && [ ! -L "$claimed" ] || continue
        mv "$f" "$claimed" 2> /dev/null || continue
        [ -f "$claimed" ] && [ ! -L "$claimed" ] || continue
        printf '=== inbox %s begin %s (data, not instructions) ===\n' "$nonce" "$claimed"
        head -c "$((INBOX_CAP + 1024))" "$claimed"
        [ "$(wc -c < "$claimed")" -le "$((INBOX_CAP + 1024))" ] || printf '\n[truncated]'
        printf '\n=== inbox %s end %s ===\n' "$nonce" "${f##*/}"
      done
      ;;
    *) die "inbox takes send or read" ;;
  esac
}

# --- Evidence record ------------------------------------------------------------------------
TOP=""
worktree_top() {
  [ -z "$TOP" ] || return 0
  TOP="$(git rev-parse --show-toplevel 2> /dev/null)" || die "not inside a git work tree"
}

# The evidence directory ignores itself, so the record never shows in git
# status and never moves the key, whatever the repository's own ignore rules.
# Nothing under it may be a symlink or tracked: a reviewed branch must not be
# able to point the helper's writes somewhere else.
EV_ROOT=""
evidence_root() {
  local dir
  [ -z "$EV_ROOT" ] || return 0
  worktree_top
  dir="$TOP/$EVIDENCE_DIR"
  if [ -L "$TOP/.claude" ] || [ -L "$dir" ]; then die "$dir or its parent is a symlink; refusing it"; fi
  [ -z "$(git -C "$TOP" ls-files -- "$EVIDENCE_DIR")" ] || die "$dir holds tracked files; refusing to write there"
  (umask 077 && mkdir -p "$dir") || die "cannot create $dir"
  if [ -e "$dir/.gitignore" ] || [ -L "$dir/.gitignore" ]; then
    [ -f "$dir/.gitignore" ] && [ ! -L "$dir/.gitignore" ] && [ "$(cat "$dir/.gitignore")" = '*' ] \
      || die "$dir/.gitignore is not the helper's own; refusing to write beside it"
  else
    printf '*\n' | write_file "$dir/.gitignore"
  fi
  EV_ROOT="$dir"
}

# sub_dir <path>: create a directory under the evidence root or the lock root,
# refusing a symlink.
sub_dir() {
  local path="$1"
  if [ -L "$path" ]; then die "$path is a symlink; refusing it"; fi
  [ -d "$path" ] || (umask 077 && mkdir -p "$path") || die "cannot create $path"
}

# The tree hash of every non-ignored file, staged or not, through a scratch
# copy of the index so the real one is never touched, and a scratch object
# directory so untracked files never land in the repository's object store.
TREE_KEY=""
tree_key() {
  local index objects tmpidx tmpobj
  worktree_top
  index="$(git -C "$TOP" rev-parse --path-format=absolute --git-path index)" || die "cannot locate the index"
  objects="$(git -C "$TOP" rev-parse --path-format=absolute --git-path objects)" || die "cannot locate the object store"
  tmpobj="$(mktemp -d -t review-state-scratch.XXXXXX)" || die "cannot create a scratch directory"
  tmpidx="$tmpobj/index"
  if [ -f "$index" ]; then
    cp "$index" "$tmpidx" || { rm -rf "$tmpobj"; die "cannot copy the index"; }
  fi
  if ! GIT_INDEX_FILE="$tmpidx" GIT_OBJECT_DIRECTORY="$tmpobj" GIT_ALTERNATE_OBJECT_DIRECTORIES="$objects" \
      git -C "$TOP" add -A -- . \
    || ! TREE_KEY="$(GIT_INDEX_FILE="$tmpidx" GIT_OBJECT_DIRECTORY="$tmpobj" GIT_ALTERNATE_OBJECT_DIRECTORIES="$objects" \
      git -C "$TOP" write-tree)"; then
    rm -rf "$tmpobj"
    die "cannot compute the tree hash"
  fi
  rm -rf "$tmpobj"
}

valid_tree() {
  local tree="$1"
  [[ "$tree" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || die "'$tree' is not a tree hash"
}

ENTRY_DIR=""
ENTRY_ID=""
entry_paths() {
  local cmd="$1" tree="$2"
  evidence_root
  ENTRY_DIR="$EV_ROOT/$tree"
  ENTRY_ID="$(printf '%s' "$cmd" | git hash-object --stdin)" || die "cannot hash the command key"
}

# record_entry <cmd> <tree> <exit> <started> <ended> <source>, output on stdin.
# The first writer for a tree and command wins; a later one is dropped.
record_entry() {
  local cmd="$1" tree="$2" code="$3" started="$4" ended="$5" source="$6" dir id out tmp
  entry_paths "$cmd" "$tree"; dir="$ENTRY_DIR"; id="$ENTRY_ID"
  sub_dir "$dir"
  rand_hex
  out="$id.$HEX.out"
  write_file "$dir/$out"
  tmp="$(mktemp "$dir/.entry.XXXXXX")" || die "cannot write in $dir"
  jq -n --argjson v "$VERSION" --arg c "$cmd" --arg t "$tree" --argjson e "$code" \
    --argjson s "$started" --argjson n "$ended" --arg src "$source" --arg o "$out" \
    '{version: $v, command: $c, tree: $t, exit: $e, started: $s, ended: $n, source: $src, output: $o}' > "$tmp" \
    || { rm -f "$tmp" "$dir/$out"; die "cannot write the entry"; }
  if ln "$tmp" "$dir/$id.json" 2> /dev/null; then
    rm -f "$tmp"
  else
    rm -f "$tmp" "$dir/$out"
    [ -f "$dir/$id.json" ] || die "cannot record the entry in $dir"
    note "an entry for this tree and command already exists; kept the first"
  fi
  printf '%s\n' "$dir/$id.json"
}

int_opt() {
  local name="$1" val="$2"
  [[ "$val" =~ ^-?[0-9]{1,12}$ ]] || die "--$name must be a whole number, got '$val'"
}

CAPTURE=""
cleanup_capture() { [ -z "$CAPTURE" ] || rm -f "$CAPTURE"; }

cmd_evidence() {
  local sub="${1:-}" tree file started rc ended out pipe after
  shift || true
  case "$sub" in
    lookup)
      parse_opts "command tree" -- "$@"
      require_opt command
      if [ -n "$opt_tree" ]; then tree="$opt_tree"; else tree_key; tree="$TREE_KEY"; fi
      valid_tree "$tree"
      entry_paths "$opt_command" "$tree"
      file="$ENTRY_DIR/$ENTRY_ID.json"
      [ -f "$file" ] || return 1
      if [ -L "$ENTRY_DIR" ] || [ -L "$file" ]; then die "$file or its directory is a symlink; refusing it"; fi
      check_json_version "$file"
      jq -e --arg c "$opt_command" --arg t "$tree" \
        '.command == $c and .tree == $t and (.output | test("^[0-9a-f]{40,64}\\.[0-9a-f]{8}\\.out$"))' \
        "$file" > /dev/null 2>&1 || die "$file does not describe this tree and command; refusing it"
      out="$ENTRY_DIR/$(jq -r .output "$file")"
      if [ ! -f "$out" ] || [ -L "$out" ]; then
        rm -f "$file"
        note "$file named an output that is missing or not a regular file; dropped it"
        return 1
      fi
      jq -c --arg d "$ENTRY_DIR" '. + {output_path: ($d + "/" + .output)}' "$file"
      ;;
    record)
      parse_opts "command exit started ended source tree" -- "$@"
      require_opt command; require_opt exit; require_opt started; require_opt ended
      [[ "$opt_exit" =~ ^[0-9]{1,3}$ ]] && [ "$opt_exit" -le 255 ] || die "--exit must be an exit status, 0 to 255, got '$opt_exit'"
      int_opt started "$opt_started"; int_opt ended "$opt_ended"
      single_line source "$opt_source"
      if [ -n "$opt_tree" ]; then tree="$opt_tree"; else tree_key; tree="$TREE_KEY"; fi
      valid_tree "$tree"
      record_entry "$opt_command" "$tree" "$opt_exit" "$opt_started" "$opt_ended" "${opt_source:-local}"
      ;;
    run)
      parse_opts "command tree --" -- "$@"
      require_opt command
      [ "${#rest_args[@]}" -gt 0 ] || die "run needs a command after --"
      if [ -n "$opt_tree" ]; then tree="$opt_tree"; else tree_key; tree="$TREE_KEY"; fi
      valid_tree "$tree"
      # type -P looks on PATH only: command -v also finds this helper's own
      # functions and the shell's builtins, which exec cannot run.
      type -P -- "${rest_args[0]}" > /dev/null 2>&1 \
        || die "${rest_args[0]} is not on PATH; nothing run or recorded"
      CAPTURE="$(mktemp -t review-state-run.XXXXXX)" || die "cannot create a capture file"
      trap cleanup_capture EXIT
      started="$(now)"
      rc=0
      pipe=(0 0)
      # exec runs only a program, never one of this helper's functions or a
      # builtin, and in the caller's locale rather than this helper's C.
      ( if [ -n "$CALLER_LC_ALL_SET" ]; then export LC_ALL="$CALLER_LC_ALL"; else unset LC_ALL; fi
        exec -- "${rest_args[@]}" ) < /dev/null 2>&1 | tee "$CAPTURE" \
        || { pipe=("${PIPESTATUS[@]}"); rc="${pipe[0]}"; }
      ended="$(now)"
      # From here on a failure is reported, never allowed to replace the
      # command's own exit status.
      if [ "${pipe[1]:-0}" != 0 ]; then
        note "the output could not be captured or streamed (tee exited ${pipe[1]}); nothing recorded"
      elif ! after="$(tree_key && printf '%s' "$TREE_KEY")"; then
        note "could not recompute the tree key after the run; nothing recorded"
      elif [ "$after" != "$tree" ]; then
        note "the tree differs from the one the run was keyed on (a stale --tree, or the command changed it); nothing recorded"
      elif ! (record_entry "$opt_command" "$tree" "$rc" "$started" "$ended" local < "$CAPTURE" > /dev/null); then
        note "the run could not be recorded"
      fi
      return "$rc"
      ;;
    ci)
      parse_opts "head command" -- "$@"
      require_opt head; require_opt command
      [[ "$opt_head" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || die "--head must be a full commit hash"
      local runs verdict summary first last
      runs="$(jq -c -s 'if length == 0 then "" elif length == 1 then .[0] else error("several documents") end | if . == "" then . elif type == "array" then map(if type == "object" and has("check_runs") then .check_runs[] else . end)
                     elif type == "object" and has("check_runs") then .check_runs
                     else error("not a check-runs listing") end' 2> /dev/null)" \
        || die "stdin is not one check-runs listing (the API object, a list of runs, or pages joined with gh api --paginate --slurp)"
      [ "$runs" != '""' ] || die "stdin is empty; pipe the head's check runs in"
      verdict="$(jq -r 'map(select(.status != "completed" or (.conclusion != "skipped" and .conclusion != "neutral")))
        | if length == 0 then "none"
          elif any(.status != "completed") then "pending"
          elif any(.conclusion == "failure") then "failed"
          elif all(.conclusion == "success") then "evidence"
          else "unfinished" end' <<< "$runs")" || die "cannot judge the check runs"
      case "$verdict" in
        evidence) ;;
        none) note "no check run that counts on $opt_head (none, or only skipped and neutral ones); no evidence"; return 1 ;;
        pending) note "a check run on $opt_head has not concluded; no evidence yet"; return 1 ;;
        failed) note "a check run on $opt_head failed; no evidence"; return 1 ;;
        unfinished) note "a check run on $opt_head was cancelled, timed out or otherwise did not finish; no evidence yet"; return 1 ;;
        *) die "unexpected verdict '$verdict'" ;;
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
LOOP_FILE=""
loop_file() {
  local skill="$1" dir file header first got tmp
  [[ "$skill" =~ ^[a-z][a-z0-9-]{0,63}$ ]] || die "--skill must be a skill name, got '$skill'"
  evidence_root
  dir="$EV_ROOT/loop"
  sub_dir "$dir"
  file="$dir/$skill.md"
  if [ -L "$file" ]; then die "$file is a symlink; refusing it"; fi
  header="<!-- review-loop version=$VERSION skill=$skill -->"
  if [ ! -e "$file" ]; then
    # Created without overwriting, so two first writers keep one header and
    # neither loses the other's marker.
    tmp="$(mktemp "$dir/.tmp.XXXXXX")" || die "cannot write in $dir"
    printf '%s\n' "$header" > "$tmp" || { rm -f "$tmp"; die "cannot write $tmp"; }
    ln "$tmp" "$file" 2> /dev/null || true
    rm -f "$tmp"
  fi
  first="$(head -n 1 "$file")" || die "cannot read $file"
  got="$(sed -n 's/^<!-- review-loop version=\([^ ]*\) .*/\1/p' <<< "$first")"
  [ "$got" = "$VERSION" ] || die "$file has unknown version '${got:-missing}' (this helper reads version $VERSION); refusing it"
  LOOP_FILE="$file"
}

# Appends start on a line of their own, whatever the previous body ended with.
ensure_newline() {
  local file="$1"
  [ ! -s "$file" ] || [ -z "$(tail -c 1 "$file")" ] || printf '\n' >> "$file" || die "cannot write $file"
}

cmd_loop() {
  local sub="${1:-}" head_sha base
  shift || true
  case "$sub" in
    mark)
      parse_opts "skill iteration phase base" -- "$@"
      require_opt skill; require_opt iteration; require_opt phase
      [[ "$opt_iteration" =~ ^[1-9][0-9]{0,4}$ ]] || die "--iteration must be a positive number"
      case "$opt_phase" in start|end) ;; *) die "--phase is start or end" ;; esac
      case "$opt_base" in -*) die "--base must be a ref, got '$opt_base'" ;; esac
      loop_file "$opt_skill"
      head_sha="$(git rev-parse --verify --quiet HEAD)" || head_sha="-"
      base="-"
      if [ -n "$opt_base" ]; then
        base="$(git merge-base HEAD "$opt_base" 2> /dev/null)" || base="-"
      fi
      ensure_newline "$LOOP_FILE"
      printf '<!-- iteration %s %s at=%s head=%s merge-base=%s -->\n' \
        "$opt_iteration" "$opt_phase" "$(now)" "$head_sha" "$base" >> "$LOOP_FILE" || die "cannot write $LOOP_FILE"
      printf '%s\n' "$LOOP_FILE"
      ;;
    append)
      parse_opts "skill" -- "$@"
      require_opt skill
      loop_file "$opt_skill"
      ensure_newline "$LOOP_FILE"
      cat >> "$LOOP_FILE" || die "cannot write $LOOP_FILE"
      ensure_newline "$LOOP_FILE"
      ;;
    *) die "loop takes mark or append" ;;
  esac
}

# --- Decision ledger ---------------------------------------------------------------------------
# One file per repository and PR, appended to and never pruned: the latest
# entry for a finding key governs how a re-raise of it routes.
LEDGER=""
ledger_file() {
  local create="$1" owner name dir
  repo_args
  require_opt pr
  valid_pr "$opt_pr"
  encode_segment "${opt_repo%%/*}"; owner="$ENC"
  encode_segment "${opt_repo#*/}"; name="$ENC"
  dir="$STATE_ROOT/ledger/$owner/$name"
  if [ "$create" = create ]; then
    root_dir ledger
    sub_dir "$dir"
  fi
  LEDGER="$dir/pr-$opt_pr.json"
  if [ -L "$LEDGER" ] || [ -L "$LEDGER.lock" ]; then die "$LEDGER or its lock is a symlink; refusing it"; fi
  [ ! -e "$LEDGER" ] || check_json_version "$LEDGER"
}

# ledger_append <ledger> <repo> <pr> <entry json>: the read-modify-write, run
# only under the ledger's file lock (below), so a concurrent append is never
# lost. The version is checked again inside the lock.
ledger_append() {
  local file="$1" repo="$2" pr="$3" entry="$4" body
  if [ -e "$file" ]; then
    check_json_version "$file"
    body="$(jq --argjson e "$entry" '.entries += [$e]' "$file")" || die "cannot read $file"
  else
    body="$(jq -n --argjson v "$VERSION" --arg repo "$repo" --argjson pr "$pr" --argjson e "$entry" \
      '{version: $v, repo: $repo, pr: $pr, entries: [$e]}')" || die "cannot build $file"
  fi
  printf '%s\n' "$body" | write_file "$file"
}

cmd_ledger() {
  local sub="${1:-}" evidence entry body
  shift || true
  case "$sub" in
    record)
      parse_opts "repo pr key anchor disposition head reply follow-up reason" -- "$@"
      require_opt key; require_opt anchor; require_opt disposition; require_opt head; require_opt reply
      [[ "$opt_key" =~ ^[A-Za-z0-9._:-]{1,128}$ ]] || die "--key must match [A-Za-z0-9._:-]{1,128}; hash any other key first"
      [[ "$opt_anchor" =~ ^[A-Za-z0-9._:-]{1,128}$ ]] || die "--anchor must match [A-Za-z0-9._:-]{1,128}; hash any other anchor first"
      [[ "$opt_head" =~ ^[0-9a-f]{40}([0-9a-f]{24})?$ ]] || die "--head must be a full commit hash, got '$opt_head'"
      single_line reply "$opt_reply"
      single_line follow-up "$opt_follow_up"; single_line reason "$opt_reason"
      case "$opt_disposition" in
        fixed|rejected) ;;
        deferred) [ -n "$opt_follow_up" ] \
          || die "a deferral needs --follow-up naming the record that re-surfaces it (an issue, a spec task or gated deferral, an Awaiting-input entry); halt the run instead of deferring without one" ;;
        suppressed) [ -n "$opt_reason" ] || die "a suppression needs --reason" ;;
        *) die "--disposition is fixed, rejected, deferred or suppressed, got '$opt_disposition'" ;;
      esac
      evidence="$(head -c "$((EVIDENCE_CAP + 1))")" || die "cannot read the evidence summary from stdin"
      [ -n "$evidence" ] || die "the evidence summary on stdin is empty; every entry carries one"
      [ "${#evidence}" -le "$EVIDENCE_CAP" ] || die "the evidence summary is longer than $EVIDENCE_CAP bytes; summarize it"
      need perl
      ledger_file create
      entry="$(jq -n --arg key "$opt_key" --arg anchor "$opt_anchor" --arg disposition "$opt_disposition" \
        --arg reason "$opt_reason" --arg evidence "$evidence" --arg head "$opt_head" \
        --arg date "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg reply "$opt_reply" --arg follow_up "$opt_follow_up" \
        '{key: $key, anchor: $anchor, disposition: $disposition, evidence: $evidence, head: $head,
          date: $date, reply: $reply}
         + (if $reason == "" then {} else {reason: $reason} end)
         + (if $follow_up == "" then {} else {follow_up: $follow_up} end)')" || die "cannot build the ledger entry"
      # perl's flock rather than flock(1), which macOS does not ship; the
      # kernel drops the lock with its holder, so a killed writer leaves none.
      (umask 077 && perl -MFcntl=:flock -e 'open(my $l, ">>", shift) or die "cannot open the ledger lock: $!\n";
          flock($l, LOCK_EX) or die "cannot lock the ledger: $!\n"; exit(system(@ARGV) == 0 ? 0 : 2)' \
        "$LEDGER.lock" "$BASH" "$0" __ledger-append "$LEDGER" "$opt_repo" "$opt_pr" "$entry") \
        || die "could not append to $LEDGER"
      printf '%s\n' "$LEDGER"
      ;;
    lookup)
      parse_opts "repo pr key anchor head" -- "$@"
      require_opt key; require_opt anchor; require_opt head
      ledger_file read
      if [ ! -e "$LEDGER" ]; then
        printf '{"route":"new"}\n'
        return 0
      fi
      # Same head and anchor is a repeat with nothing new: the recorded reply
      # stands. A rejection raised again otherwise goes back to the operator
      # with fix recommended. A deferral or suppression still stands for the
      # same anchor on a later head; anywhere else, like a fixed finding raised
      # again, the finding is new, its prior entry attached.
      jq -c --arg key "$opt_key" --arg anchor "$opt_anchor" --arg head "$opt_head" '
        [.entries[] | select(.key == $key)] | last as $p
        | if $p == null then {route: "new"}
          elif $p.head == $head and $p.anchor == $anchor then {route: "recorded-reply", entry: $p}
          elif $p.disposition == "rejected" then {route: "needs-sign-off", recommended: "fix", rejection: $p}
          elif ($p.disposition == "deferred" or $p.disposition == "suppressed") and $p.anchor == $anchor
          then {route: "recorded-reply", entry: $p}
          else {route: "new", prior: $p} end' "$LEDGER" || die "cannot read $LEDGER"
      ;;
    show)
      parse_opts "repo pr" -- "$@"
      ledger_file read
      [ ! -e "$LEDGER" ] || jq . "$LEDGER" || die "cannot read $LEDGER"
      ;;
    *) die "ledger takes record, lookup or show" ;;
  esac
}

# --- Dispatch ------------------------------------------------------------------------------------
need jq
need git
cmd="${1:-}"
shift || true
case "$cmd" in
  key) [ "$#" -eq 0 ] || die "key takes no arguments"; tree_key; printf '%s\n' "$TREE_KEY" ;;
  evidence) cmd_evidence "$@" ;;
  session-pid) [ "$#" -eq 0 ] || die "session-pid takes no arguments"; find_session_pid; printf '%s\n' "$SESSION_PID" ;;
  register) cmd_register "$@" ;;
  unregister) cmd_unregister "$@" ;;
  sessions) [ "$#" -eq 0 ] || die "sessions takes no arguments"; cmd_sessions ;;
  lock) cmd_lock "$@" ;;
  inbox) cmd_inbox "$@" ;;
  loop) cmd_loop "$@" ;;
  ledger) cmd_ledger "$@" ;;
  # Internal: re-entered by `ledger record` under the ledger's lock.
  __ledger-append) [ "$#" -eq 4 ] || die "__ledger-append is internal"; ledger_append "$@" ;;
  encode) [ "$#" -eq 1 ] || die "encode takes one segment"; encode_segment "$1"; printf '%s\n' "$ENC" ;;
  *) die "unknown command '${cmd}'; see the usage at the top of this script" ;;
esac
