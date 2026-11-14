#!/usr/bin/env bash
# Render one machine-local file from a committed template and one 1Password
# item (for a JSON template, optionally a second), then validate it before it
# lands.
#
# Usage: op-render.sh [--work-account] <template> <item> <output>
#
# A template reference is `{{ op://__OP_VAULT__/__OP_ITEM__/<field> }}`, the
# shape scripts/ssh-lan-config-sync.sh uses, resolved against <item> in the
# vault DOTFILES_OP_VAULT names (Dotfiles Service Account when unset). The item
# is read once and substituted with jq rather than `op inject`, because inject
# pastes values raw: a regex like
# `\[bot\]` inside a JSON string would need hand-escaping in 1Password, and a
# missed one (`\b`) parses fine and means something else.
#
# JSON templates (`*.json.tpl`): a reference is a whole string value. With
# ` | json` before the closing braces the field's value is parsed and lands
# typed (a list, a map, a boolean); without, it lands as a string. A field
# left empty in the item drops its key from the output, and an object or list
# left with nothing in it drops in turn, so one template serves entries that
# use different optional fields. Text templates: references are substituted raw,
# and a value holding a line break is refused, except that in the planwright
# overlay a line holding only a reference expands to the field's lines.
#
# A JSON template may also reference
# `{{ op://__OP_WORK_VAULT__/__OP_WORK_ITEM__/<field> }}`, the second item
# DOTFILES_OP_WORK_ACCOUNT, DOTFILES_OP_WORK_VAULT and DOTFILES_OP_WORK_ITEM
# name (docs/machine-local-files.md). It is read with --account and never the
# service-account token, which cannot reach another account; with the three
# unset, every such reference resolves empty.
#
# --work-account reads <item> itself from that account and the vault
# DOTFILES_OP_WORK_VAULT names, in the same way, and refuses to run with the
# three unset rather than fall back to the service-account vault: it is how a
# host keeps a file whose values must never sit in a personal item.
#
# The template's basename picks the validation rule; a template with none is
# refused rather than rendered unchecked.
#
# Prints OK when the output already matches, CHANGED when it (or, for the
# overlay, the supplement or snapshot below) is (re)written, removed or its
# mode tightened, and exits non-zero with a FAILED: line otherwise; Ansible
# gates changed_when on CHANGED. A plain regular file at the output is
# overwritten; a symlink or any other kind of path is refused. The planwright
# overlay alone also keeps mission control's own keys across renders, in two
# files under ~/.config/dotfiles/ (docs/machine-local-files.md). A key the
# supplement keeps that has gone from the live overlay since the last render
# is ambiguous (mission control removed it, or an older backup of the overlay
# was restored), so the render refuses, writing nothing, until
# OP_RENDER_ACCEPT_REMOVALS=1 says the removal was real.

set -eu
# Every file this writes holds private values, and a caller's umask that drops
# the owner's read or write bit would otherwise break the scratch files too.
umask 077

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

from_work=false
if [ "${1:-}" = --work-account ]; then
  from_work=true
  shift
fi
[ "$#" -eq 3 ] || fail "usage: op-render.sh [--work-account] <template> <item> <output>"
template="$1"
item="$2"
output="$3"

[ -f "$template" ] && [ -r "$template" ] || fail "template not readable: $template"
case "${template##*/}" in
  bot-review.json.tpl) rule=review-config format=json ;;
  sibling-repos.json.tpl) rule=sibling-map format=json ;;
  planwright.yml.tpl) rule=planwright-overlay format=text ;;
  git-work-orgs.tpl) rule=work-orgs format=text ;;
  authorized_keys.offload.tpl) rule=offload-key format=text ;;
  *) fail "no validation rule for ${template##*/}; refusing to render it unchecked" ;;
esac

# A name reaches op as one argv element, never a shell word, but one that reads
# as a flag or carries a path separator is a typo worth stopping on. The rule is
# scripts/playbook.sh's plain_name (an explicit list, not a range, since ranges
# follow the locale, and an alphanumeric first character) plus, as its
# op-work-item reader adds, no trailing space. The
# message never repeats the value: a misplaced secret is the likeliest bad one.
alnum='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
check_name() { # check_name <what> <value> <allowed after the first character, `-` last>
  case "$2" in
    '' | [!$alnum]* | *[!$alnum$3]* | *' ') fail "$1 is not a plain name: [A-Za-z0-9] then [A-Za-z0-9$3], no trailing space" ;;
  esac
}
check_name "the item name" "$item" '._ -'

# The work item is checked before any op call, so a bad setting costs no read.
work_refs=false
if [ "$format" = json ] && grep -qF '__OP_WORK_VAULT__' "$template"; then
  work_refs=true
fi
work_set=false
if [ "$work_refs" = true ] || [ "$from_work" = true ]; then
  w_account="${DOTFILES_OP_WORK_ACCOUNT:-}"
  w_vault="${DOTFILES_OP_WORK_VAULT:-}"
  w_item="${DOTFILES_OP_WORK_ITEM:-}"
  if [ -n "$w_account$w_vault$w_item" ]; then
    [ -n "$w_account" ] && [ -n "$w_vault" ] && [ -n "$w_item" ] \
      || fail "DOTFILES_OP_WORK_ACCOUNT, DOTFILES_OP_WORK_VAULT and DOTFILES_OP_WORK_ITEM must be set together or not at all"
    check_name DOTFILES_OP_WORK_ACCOUNT "$w_account" '._@-'
    check_name DOTFILES_OP_WORK_VAULT "$w_vault" '._ -'
    check_name DOTFILES_OP_WORK_ITEM "$w_item" '._ -'
    work_set=true
  elif [ "$from_work" = true ]; then
    fail "--work-account needs DOTFILES_OP_WORK_ACCOUNT, DOTFILES_OP_WORK_VAULT and DOTFILES_OP_WORK_ITEM, which scripts/playbook.sh exports from ~/.config/dotfiles/op-work-item; none is set"
  fi
fi
work_on=false
[ "$work_refs" = false ] || [ "$work_set" = false ] || work_on=true

check_output() { # check_output [<path>], the output by default
  local path="${1:-$output}"
  if [ -e "$path" ] || [ -L "$path" ]; then
    [ -L "$path" ] && fail "refusing to write $path: it is a symlink"
    [ -f "$path" ] || fail "refusing to write $path: not a regular file"
  fi
  return 0
}
check_output

self="$0"
while [ -L "$self" ]; do
  link="$(readlink -- "$self")" || fail "could not resolve symlink $self"
  case "$link" in
    /*) self="$link" ;;
    *) self="$(dirname -- "$self")/$link" ;;
  esac
done
script_dir="$(CDPATH='' cd -P -- "$(dirname -- "$self")" && pwd -P)" \
  || fail "could not resolve the directory of $self"
[ -r "$script_dir/op-token.sh" ] || fail "helper not readable: $script_dir/op-token.sh"
# shellcheck source-path=SCRIPTDIR source=op-token.sh
. "$script_dir/op-token.sh"
schema_dir="$script_dir/../roles/claude/files/skills/bot-review"

# A service account cannot be granted the Personal or Private vault.
VAULT="${DOTFILES_OP_VAULT:-Dotfiles Service Account}"
resolve_op_token

command -v op >/dev/null 2>&1 || fail "1Password CLI (op) not installed"
command -v jq >/dev/null 2>&1 || fail "jq not installed"

mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

work="$(mktemp -d)" || fail "could not create a scratch directory"
tmp_out=""
cleanup() {
  rm -rf "$work"
  [ -z "$tmp_out" ] || rm -f "$tmp_out"
}
trap cleanup EXIT

# jq_or_fail <label> <jq args...>: run jq, turning its error into a FAILED line
# without jq's location prefix.
jq_or_fail() {
  local label="$1" msg
  shift
  if ! jq "$@" 2>"$work/err"; then
    msg="$(sed -e 's/^jq: error ([^)]*): //' -e 's/^jq: error: //' "$work/err" | head -n 1)"
    fail "$label: ${msg:-jq failed}"
  fi
}

if [ "$from_work" = true ]; then
  if ! op item get "$item" --vault "$w_vault" --account "$w_account" --format json --reveal >"$work/item.json"; then
    fail "op item get failed reading the item argument from the work account and vault DOTFILES_OP_WORK_ACCOUNT and DOTFILES_OP_WORK_VAULT name; see the op error above (locked session? missing item?)"
  fi
elif ! op_run item get "$item" --vault "$VAULT" --format json --reveal >"$work/item.json"; then
  fail "op item get failed reading the item argument from the vault DOTFILES_OP_VAULT names (Dotfiles Service Account when unset); see the op error above (locked session? missing item?)"
fi

# item_fields <item description> <op item json> <output>: the item's fields as
# one label-to-value object.
item_fields() {
  jq_or_fail "could not read $1" -c '
    [.fields[]? | select((.label // "") != "")] as $f
    | ($f | group_by(.label) | map(select(length > 1) | .[0].label)) as $dup
    | if ($f | length) == 0 then error("op returned an item that holds no fields")
      elif ($dup | length) > 0
      then error("the item holds more than one field labelled \($dup[0])")
      else $f | map({key: .label, value: (.value // "")}) | from_entries end' \
    "$2" >"$3"
}
item_fields "item '$item'" "$work/item.json" "$work/fields.json"

echo '{}' >"$work/work-fields.json"
if [ "$work_on" = true ]; then
  if ! op item get "$w_item" --vault "$w_vault" --account "$w_account" --format json --reveal >"$work/work-item.json"; then
    fail "op item get failed reading the work item DOTFILES_OP_WORK_ACCOUNT, DOTFILES_OP_WORK_VAULT and DOTFILES_OP_WORK_ITEM name; see the op error above"
  fi
  item_fields "the work item DOTFILES_OP_WORK_ITEM names" "$work/work-item.json" "$work/work-fields.json"
fi

if [ "$format" = json ]; then
  # Walks the template's own structure only, so a value parsed from a ` | json`
  # field is never pruned: an empty string inside it reaches the rule intact.
  jq_or_fail "could not render $template" -L "$schema_dir" --slurpfile m "$work/fields.json" \
    --slurpfile wm "$work/work-fields.json" --argjson work_on "$work_on" '
    include "config-schema";
    def none: {"__op_render_none__": true};
    def resolve($default):
      capture(op_reference) as $c
      | (if $c.w == null then $default else $wm[0] end) as $fields
      | if $c.w != null and ($work_on | not) then none
        elif ($fields | has($c.f) | not)
        then error("the \(if $c.w == null then "" else "work " end)item has no field \($c.f)")
        elif $fields[$c.f] == "" then none
        elif $c.j == null then $fields[$c.f]
        else $fields[$c.f]
          | try fromjson catch error("\(if $c.w == null then "" else "work " end)item field \($c.f) does not hold valid JSON")
        end;
    def render($fields):
      if type == "object" then
        if any(keys[]; contains("{{"))
        then error("unsubstituted template expression in a key") else . end
        | with_entries(.value |= render($fields)) | with_entries(select(.value != none))
        | if length == 0 then none else . end
      elif type == "array" then
        map(render($fields)) | map(select(. != none)) | if length == 0 then none else . end
      elif type == "string" and test(op_reference) then resolve($fields)
      elif type == "string" and contains("{{") then
        error("unsubstituted template expression: \(.)")
      else . end;
    if length != 1 then error("the template must hold exactly one JSON document")
    else $m[0] as $fields | .[0] | render($fields) | if . == none then {} else . end end' \
    --slurp "$template" >"$work/rendered"
else
  # The {{ check reads the template line, not the substituted one, so a value
  # that holds {{ is data. A `key: <reference>` line whose value is empty is
  # dropped, as an empty JSON field drops its key. One program reads every line
  # (-n with inputs), so an error on any line fails the run; a per-line run
  # exits by the last line alone.
  # In the overlay, a line that is one bare reference expands to the field's
  # lines, so a block whose keys must stay private lives whole in the item; the
  # overlay rule below still checks every expanded line. Other text rules keep
  # one line per reference.
  blocks=false
  [ "$rule" != planwright-overlay ] || blocks=true
  jq_or_fail "could not render $template" -n -R -r -L "$schema_dir" --slurpfile m "$work/fields.json" \
    --argjson blocks "$blocks" '
    include "config-schema";
    $m[0] as $fields
    | inputs
    | input_line_number as $n
    | if gsub(op_reference_inline; "") | contains("{{")
      then error("unsubstituted template expression on template line \($n)") else . end
    | if $blocks and test("^" + op_reference_inline + "$") then
        capture(op_reference_inline).f as $f
        | if ($fields | has($f) | not) then error("the item has no field \($f)")
          elif $fields[$f] | test("\r")
          then error("item field \($f) holds a carriage return")
          elif $fields[$f] == "" then empty
          else $fields[$f] | rtrimstr("\n") | split("\n")[] end
      elif test("^[a-z][a-z0-9_]*: " + op_reference_inline + "$")
        and $fields[capture(op_reference_inline).f] == ""
      then empty
      else gsub(op_reference_inline;
        .f as $f
        | if ($fields | has($f) | not) then error("the item has no field \($f)")
          elif $fields[$f] | test("[\r\n]")
          then error("item field \($f) holds a line break, which a text template cannot carry")
          else $fields[$f] end)
      end' \
    "$template" >"$work/rendered"
fi

# The overlay is also mission control's write target (planwright's
# mc-config.sh), which refuses a file whose header says another tool renders
# it. So its own keys survive the render instead: any it changed since the
# last render (the snapshot) are kept in the supplement, and the supplement is
# applied over the item. Every other key still comes from the item alone.
supplement=""
snapshot=""
live_sum=""
if [ "$rule" = planwright-overlay ]; then
  supplement="$HOME/.config/dotfiles/planwright-overlay.supplement.yml"
  snapshot="$HOME/.config/dotfiles/planwright-overlay.rendered"
  check_output "$supplement"
  check_output "$snapshot"
  harvest=0
  live=/dev/null
  last=/dev/null
  # With no snapshot there is no telling mission control's writes from the
  # item's old values, so nothing is harvested; the run writes the snapshot.
  if [ -f "$output" ] && [ -f "$snapshot" ]; then
    harvest=1
    live="$output"
    last="$snapshot"
    live_sum="$(cksum <"$output")" || fail "could not read $output"
  fi
  sup_in=/dev/null
  [ ! -f "$supplement" ] || sup_in="$supplement"
  if ! awk -v harvest="$harvest" -v last="$last" -v live="$live" -v sup="$sup_in" \
    -v base="$work/rendered" -v sup_out="$work/supplement" -v sup_name="$supplement" \
    -v accept="${OP_RENDER_ACCEPT_REMOVALS:-}" -v live_name="$output" -v snap_name="$snapshot" '
    function key_of(l) { return match(l, /^[a-z][a-z0-9_]*:/) ? substr(l, 1, RLENGTH - 1) : "" }
    function mc_key(k) { return k ~ /^mission_control_[a-z0-9_]+$/ || k ~ /^program_[a-z0-9_]+$/ }
    function set(k, l) { if (!(k in s)) order[++n] = k; s[k] = l }
    # getline reads an unreadable file as an empty one, which would drop kept
    # writes or harvest every key.
    function readable(f) {
      if ((getline l < f) < 0) { printf "could not read %s\n", f > "/dev/stderr"; exit 1 }
      close(f)
    }
    BEGIN {
      readable(last); readable(live); readable(sup); readable(base)
      while ((getline l < last) > 0) {
        k = key_of(l)
        if (mc_key(k)) { if (!(k in p)) porder[++pn] = k; p[k] = l }
      }
      while ((getline l < live) > 0) {
        k = key_of(l)
        if (mc_key(k)) { if (!(k in v)) lorder[++ln] = k; v[k] = l }
      }
      while ((getline l < sup) > 0) {
        ln_no++
        if (l ~ /^[[:space:]]*(#.*)?$/) continue
        k = (l ~ /^remove [a-z][a-z0-9_]*$/) ? substr(l, 8) : key_of(l)
        if (!mc_key(k)) {
          printf "%s line %d is not a `key: value` or `remove <key>` line for a mission_control_ or program_ key\n", sup_name, ln_no > "/dev/stderr"
          bad = 1
          continue
        }
        set(k, l)
      }
      if (bad) exit 1
      if (harvest) {
        for (i = 1; i <= ln; i++) { k = lorder[i]; if (!(k in p) || p[k] != v[k]) set(k, v[k]) }
        for (i = 1; i <= pn; i++) {
          k = porder[i]
          if (k in v) continue
          # A key the supplement still carries, gone from the live file: either
          # mission control removed it or an older copy of the file was put back.
          if (accept != "1" && (k in s) && s[k] !~ /^remove /) lost = lost " " k
          set(k, "remove " k)
        }
        if (lost != "") {
          printf "%s no longer has%s, which %s still keeps and the last render wrote.\n", live_name, lost, sup_name > "/dev/stderr"
          printf "If an older copy of the overlay was restored, copy %s over it and run again.\n", snap_name > "/dev/stderr"
          printf "If mission control removed them, run again with OP_RENDER_ACCEPT_REMOVALS=1.\n" > "/dev/stderr"
          exit 1
        }
      }
      while ((getline l < base) > 0) {
        k = key_of(l)
        if (k != "" && (k in s)) {
          in_base[k] = 1
          if (s[k] == l) done[k] = 1
          if (s[k] !~ /^remove /) print s[k]
        } else print l
      }
      for (i = 1; i <= n; i++) {
        k = order[i]
        if (k in in_base) continue
        if (s[k] ~ /^remove /) done[k] = 1
        else print s[k]
      }
      for (i = 1; i <= n; i++) if (!(order[i] in done)) print s[order[i]] > sup_out
    }' >"$work/merged"; then
    fail "could not apply $supplement; the problem is listed above"
  fi
  mv -f -- "$work/merged" "$work/rendered"
  [ -f "$work/supplement" ] || : >"$work/supplement"
fi

case "$rule" in
  review-config | sibling-map)
    version_error="$(jq -r '
      if type != "object" then "is not a JSON object"
      elif has("version") | not then "no version key"
      elif .version == 1 then empty
      else "unknown version \(.version | tojson)" end' "$work/rendered")"
    [ -z "$version_error" ] || fail "$output: $version_error"
    ;;
esac

case "$rule" in
  review-config)
    errors="$(jq -r -L "$schema_dir" 'include "config-schema"; review_config_errors' "$work/rendered")" \
      || fail "could not apply the review config schema rule"
    ;;
  sibling-map)
    errors="$(jq -r '
      ((keys - ["version", "repos"])[] | "unknown top-level field \(.)"),
      (.repos
       | if type != "object" then "repos: must be an object"
         else to_entries[] | .key as $c | .value
           | if type != "object" then "repos.\($c): must map producer repositories to clone paths"
             else to_entries[]
               | select((.value | type) != "string" or (.value | test("^(/|~/)") | not))
               | "repos.\($c).\(.key): clone path must be absolute or start with ~/"
             end
         end)' "$work/rendered")" || fail "could not apply the sibling map rule"
    ;;
  planwright-overlay)
    # planwright reads this layer as flat `key: value` lines, and a step list is
    # a per-repository decision this machine-wide layer must never make.
    errors=""
    n=0
    flat='^[a-z][a-z0-9_]*:([[:space:]]|$)'
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      case "$line" in
        '' | '#'* | '---') continue ;;
      esac
      if ! [[ "$line" =~ $flat ]]; then
        errors="${errors}line $n is not a flat key: value line"$'\n'
      elif [ "${line#steps_}" != "$line" ]; then
        errors="${errors}sets ${line%%:*}, a step list this layer must not carry"$'\n'
      fi
    done <"$work/rendered"
    ;;
  work-orgs)
    # The git role writes each name into an includeIf pattern, so anything but
    # a GitHub owner name would reach the gitconfig as syntax.
    errors=""
    n=0
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      case "$line" in
        '' | '#'*) continue ;;
      esac
      for org in $line; do
        [[ "$org" =~ ^[A-Za-z0-9-]+$ ]] || errors="${errors}line $n: '$org' is not a GitHub owner name"$'\n'
      done
    done <"$work/rendered"
    ;;
  offload-key)
    # sshd reads this file as a login credential, so it must hold exactly the
    # one restricted key the template shapes: an empty field or a pasted second
    # key would otherwise reach it as an unrestricted or unparseable line.
    errors=""
    n=0
    keys=0
    # An address sshd cannot match (an octet above 255) would pass the shape and
    # then refuse every connection, after the hardening has closed passwords.
    octet='(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])'
    shape="^from=\"(${octet}[.]){3}${octet}\",restrict,pty ssh-ed25519 [A-Za-z0-9+/]+=*( [^[:cntrl:]]*)?$"
    while IFS= read -r line || [ -n "$line" ]; do
      n=$((n + 1))
      case "$line" in
        '' | '#'*) continue ;;
      esac
      keys=$((keys + 1))
      [[ "$line" =~ $shape ]] || errors="${errors}line $n is not one from-restricted ed25519 key"$'\n'
    done <"$work/rendered"
    [ "$keys" -eq 1 ] || errors="${errors}holds $keys keys; exactly one is expected"$'\n'
    if [ -z "$errors" ] && ! ssh-keygen -l -f "$work/rendered" >/dev/null 2>&1; then
      errors="ssh-keygen does not read the key"$'\n'
    fi
    ;;
esac
if [ -n "$errors" ]; then
  printf '%s\n' "$errors" | sed -e '/^$/d' -e 's/^/  - /' >&2
  fail "$output would not satisfy its rule; the violations are listed above"
fi

matches() { # matches <content> <path>: <path> holds <content> at 0600
  [ -f "$2" ] && [ ! -L "$2" ] && cmp -s "$1" "$2" && [ "$(mode_of "$2")" = 600 ]
}

# place <content> <path>: write <content> to <path> through a temp file beside
# it, so the rename is atomic: a reader sees the old file or the new one, never
# a partial write. A mode-only fix goes this way too, so no chmod ever follows a
# path that changed under it.
place() {
  local dir
  dir="$(dirname -- "$2")"
  mkdir -p -- "$dir" || fail "could not create $dir"
  tmp_out="$(mktemp "$dir/.${2##*/}.XXXXXX")" || fail "could not create a temp file in $dir"
  # The umask above makes it 0600, the mode every file this writes must have.
  cat "$1" >"$tmp_out" || fail "could not write $tmp_out"
  # Again, because the op call takes seconds: GNU mv would move the file into
  # a directory that appeared at the path meanwhile.
  check_output "$2"
  # A write mission control landed since the harvest would be lost.
  if [ -n "$live_sum" ] && [ "$2" = "$output" ] && [ "$(cksum <"$output")" != "$live_sum" ]; then
    fail "$output changed while it was rendered; nothing of it was replaced, so run again"
  fi
  mv -f -- "$tmp_out" "$2" || fail "could not move the rendered file into $2"
  tmp_out=""
}

# The output goes first: its concurrent-write check must pass before the
# supplement records anything this run derived from it.
changed=""
if ! matches "$work/rendered" "$output"; then
  place "$work/rendered" "$output"
  changed="${changed}rendered $output from 1Password (item '$item'); "
fi

if [ -n "$supplement" ]; then
  if [ -s "$work/supplement" ]; then
    {
      echo "# Mission control's writes to the planwright adopter overlay, which"
      echo "# scripts/op-render.sh carries over the 1Password item on every run. An"
      echo "# entry the item comes to match drops out; delete one to let the item win."
      cat "$work/supplement"
    } >"$work/supplement.full"
    if ! matches "$work/supplement.full" "$supplement"; then
      place "$work/supplement.full" "$supplement"
      changed="${changed}kept mission control's writes in $supplement; "
    fi
  elif [ -f "$supplement" ]; then
    rm -f -- "$supplement" || fail "could not remove $supplement"
    changed="${changed}removed $supplement, which the item now matches; "
  fi
fi

if [ -n "$snapshot" ] && ! matches "$work/rendered" "$snapshot"; then
  place "$work/rendered" "$snapshot"
  changed="${changed}recorded the render in $snapshot; "
fi

if [ -z "$changed" ]; then
  echo "OK: $output already matches 1Password"
else
  echo "CHANGED: ${changed%; }"
fi
