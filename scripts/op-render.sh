#!/usr/bin/env bash
# Render one machine-local file from a committed template and one 1Password
# item, then validate it before it lands.
#
# Usage: op-render.sh <template> <item> <output>
#
# A template reference is `{{ op://__OP_VAULT__/__OP_ITEM__/<field> }}`, the
# shape scripts/ssh-lan-config-sync.sh uses, resolved against <item> in the
# vault DOTFILES_OP_VAULT names. The item is read once and substituted with jq
# rather than `op inject`, because inject pastes values raw: a regex like
# `\[bot\]` inside a JSON string would need hand-escaping in 1Password, and a
# missed one (`\b`) parses fine and means something else.
#
# JSON templates (`*.json.tpl`): a reference is a whole string value. With
# ` | json` before the closing braces the field's value is parsed and lands
# typed (a list, a map); without, it lands as a string. A key left empty in the
# item drops its key from the output, so one template serves entries that use
# different optional fields. Text templates: references are substituted raw,
# and a value holding a line break is refused.
#
# The template's basename picks the validation rule; a template with none is
# refused rather than rendered unchecked.
#
# Prints OK when the output already matches, CHANGED when it is (re)written or
# its mode tightened, and exits non-zero with a FAILED: line otherwise; Ansible
# gates changed_when on CHANGED. A plain regular file at the output is
# overwritten; a symlink or any other kind of path is refused.

set -eu

fail() {
  echo "FAILED: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fail "usage: op-render.sh <template> <item> <output>"
template="$1"
item="$2"
output="$3"

[ -f "$template" ] && [ -r "$template" ] || fail "template not readable: $template"
case "${template##*/}" in
  bot-review.json.tpl) rule=review-config format=json ;;
  sibling-repos.json.tpl) rule=sibling-map format=json ;;
  planwright.yml.tpl) rule=planwright-overlay format=text ;;
  *) fail "no validation rule for ${template##*/}; refusing to render it unchecked" ;;
esac

# The name reaches op as one argv element, never a shell word, but a name that
# reads as a flag or carries a path separator is a typo worth stopping on.
case "$item" in
  '' | -* | *[!A-Za-z0-9._\ -]*) fail "item name '$item' is outside [A-Za-z0-9._ -]" ;;
esac


check_output() {
  if [ -e "$output" ] || [ -L "$output" ]; then
    [ -L "$output" ] && fail "refusing to write $output: it is a symlink"
    [ -f "$output" ] || fail "refusing to write $output: not a regular file"
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

work="$(umask 077 && mktemp -d)" || fail "could not create a scratch directory"
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

if ! op_run item get "$item" --vault "$VAULT" --format json --reveal >"$work/item.json"; then
  fail "op item get failed reading vault='$VAULT' item='$item'; see the op error above (locked session? missing item?)"
fi

jq_or_fail "could not read item '$item'" -c '
  [.fields[]? | select((.label // "") != "")] as $f
  | ($f | group_by(.label) | map(select(length > 1) | .[0].label)) as $dup
  | if ($f | length) == 0 then error("op returned an item that holds no fields")
    elif ($dup | length) > 0
    then error("the item holds more than one field labelled \($dup[0])")
    else $f | map({key: .label, value: (.value // "")}) | from_entries end' \
  "$work/item.json" >"$work/fields.json"

if [ "$format" = json ]; then
  # Walks the template's own structure only, so a value parsed from a ` | json`
  # field is never pruned: an empty string inside it reaches the rule intact.
  jq_or_fail "could not render $template" -L "$schema_dir" --slurpfile m "$work/fields.json" '
    include "config-schema";
    def none: {"__op_render_none__": true};
    def resolve($fields):
      capture(op_reference) as $c
      | if ($fields | has($c.f) | not) then error("the item has no field \($c.f)")
        elif $fields[$c.f] == "" then none
        elif $c.j == null then $fields[$c.f]
        else $fields[$c.f]
          | try fromjson catch error("item field \($c.f) does not hold valid JSON")
        end;
    def render($fields):
      if type == "object" then
        if any(keys[]; contains("{{"))
        then error("unsubstituted template expression in a key") else . end
        | length as $n
        | with_entries(.value |= render($fields)) | with_entries(select(.value != none))
        | if length == 0 and $n > 0 then none else . end
      elif type == "array" then map(render($fields)) | map(select(. != none))
      elif type == "string" and test(op_reference) then resolve($fields)
      elif type == "string" and contains("{{") then
        error("unsubstituted template expression: \(.)")
      else . end;
    $m[0] as $fields | render($fields) | if . == none then {} else . end' \
    "$template" >"$work/rendered"
else
  # The {{ check reads the template line, not the substituted one, so a value
  # that holds {{ is data. A `key: <reference>` line whose value is empty is
  # dropped, as an empty JSON field drops its key.
  jq_or_fail "could not render $template" -R -r -L "$schema_dir" --slurpfile m "$work/fields.json" '
    include "config-schema";
    $m[0] as $fields
    | input_line_number as $n
    | if gsub(op_reference_inline; "") | contains("{{")
      then error("unsubstituted template expression on template line \($n)") else . end
    | if test("^[a-z][a-z0-9_]*: " + op_reference_inline + "$")
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
esac
if [ -n "$errors" ]; then
  printf '%s' "$errors" | sed 's/^/  - /' >&2
  fail "$output would not satisfy its rule; the violations are listed above"
fi

if [ -f "$output" ] && [ ! -L "$output" ] && cmp -s "$work/rendered" "$output" \
  && [ "$(mode_of "$output")" = 600 ]; then
  echo "OK: $output already matches 1Password"
  exit 0
fi

out_dir="$(dirname -- "$output")"
(umask 077 && mkdir -p -- "$out_dir") || fail "could not create $out_dir"
# Beside the output, so the rename is atomic: a reader sees the old file or the
# new one, never a partial write. A mode-only fix goes this way too, so chmod
# never follows a path that changed under it.
tmp_out="$(mktemp "$out_dir/.${output##*/}.XXXXXX")" || fail "could not create a temp file in $out_dir"
cat "$work/rendered" >"$tmp_out" || fail "could not write $tmp_out"
chmod 600 "$tmp_out" || fail "could not set the mode of $tmp_out"
# Again, because the op call takes seconds: GNU mv would move the rendered file
# into a directory that appeared at the output meanwhile.
check_output
mv -f -- "$tmp_out" "$output" || fail "could not move the rendered file into $output"
tmp_out=""
echo "CHANGED: rendered $output from 1Password (item '$item')"
