#!/usr/bin/env bash
# Tests for scripts/op-render.sh.
#
# 1Password is stubbed with a fake `op` on PATH that prints a canned item, so
# this runs anywhere: no vault, no network, no session. Each case gets a
# throwaway HOME and PATH shim directory.

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repo="$(CDPATH='' cd -- "$script_dir/.." && pwd)"
subject="$script_dir/op-render.sh"
review_tpl="$repo/roles/claude/files/skills/bot-review/bot-review.json.tpl"
sibling_tpl="$repo/roles/claude/files/skills/review-shared/sibling-repos.json.tpl"
overlay_tpl="$repo/roles/claude/files/planwright/planwright.yml.tpl"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }

ORIG_PATH="$PATH"
unset OP_SERVICE_ACCOUNT_TOKEN DOTFILES_OP_TOKEN_FILE DOTFILES_OP_VAULT
unset DOTFILES_OP_WORK_ACCOUNT DOTFILES_OP_WORK_VAULT DOTFILES_OP_WORK_ITEM

root="$(mktemp -d)"
trap 'rm -rf "$root"' EXIT

new_sandbox() {
  sandbox="$(mktemp -d "$root/case.XXXXXX")"
  mkdir -p "$sandbox/home/.config/dotfiles" "$sandbox/bin" "$sandbox/tpl"
  export HOME="$sandbox/home"
  export PATH="$sandbox/bin:$ORIG_PATH"
  export OP_STUB_ITEM="$sandbox/item.json"
  export OP_STUB_ARGV="$sandbox/argv"
  export OP_STUB_ENV="$sandbox/env"
  unset OP_STUB_FAIL OP_STUB_FAIL_WORK OP_STUB_MKDIR OP_STUB_WORK_ITEM
  out="$HOME/.config/dotfiles/bot-review.json"
  install_fake_op
}

# `op item get <item> --vault <v> --format json --reveal` prints the canned
# item; argv and the token it was handed are recorded for the leak checks.
install_fake_op() {
  cat >"$sandbox/bin/op" <<'FAKE'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$OP_STUB_ARGV"
printf '%s\n' "${OP_SERVICE_ACCOUNT_TOKEN:-}" >>"$OP_STUB_ENV"
# Stands in for whatever else writes the output path while op is running.
[ -z "${OP_STUB_MKDIR:-}" ] || mkdir -p "$OP_STUB_MKDIR"
if [ -n "${OP_STUB_FAIL:-}" ]; then
  echo "[ERROR] stubbed op failure" >&2
  exit 1
fi
[ "$1 $2" = "item get" ] || exit 2
case " $* " in
  *" --account "*)
    if [ -n "${OP_STUB_FAIL_WORK:-}" ]; then
      echo "[ERROR] stubbed work-account failure" >&2
      exit 1
    fi
    cat "${OP_STUB_WORK_ITEM:?the work item was read with no stub for it}"
    ;;
  *) cat "$OP_STUB_ITEM" ;;
esac
FAKE
  chmod +x "$sandbox/bin/op"
}

# label=value lines on stdin -> the canned item, in op's JSON shape, at
# $OP_STUB_ITEM or the given path.
to_item() {
  jq -R -s '
    split("\n") | map(select(length > 0) | capture("^(?<label>[^=]+)=(?<value>.*)$"))
    | {id: "stub", title: "stub", fields: map({id: .label, type: "STRING", label, value})}' \
    >"${1:-$OP_STUB_ITEM}"
}
item_from() { printf '%s\n' "$@" | to_item; }

# A complete review item for the tracked template, one entry per re-request
# method the schema takes. The backslashes are the point of the regex values: they
# must land in the JSON verbatim, with no hand-escaping in the item.
full_review_fields() {
  local v
  for v in cubic copilot; do
    printf '%s\n' \
      "${v}_login_pattern=${v}-bot\\[bot\\]" \
      "${v}_reviewed_head_regex=Reviewed commit ([0-9a-f]{7,40})" \
      "${v}_finding_key_regex=<!-- key:([A-Za-z0-9]+) -->" \
      "${v}_build_id_regex=Review ID: (\\w+)" \
      "${v}_draft_policy=skips-drafts" \
      "${v}_draft_setting=the reviewer's draft toggle" \
      "${v}_opt_out_label=no-${v}" \
      "${v}_addressed_marker_format=<!-- ack:{key} -->" \
      "${v}_opt_in_label=" \
      "${v}_gating_checks=[\"${v}/review\"]" \
      "${v}_requirement_level_hint=" \
      "${v}_repo_config_path=" \
      "${v}_reply_suffix=" \
      "${v}_feedback_reaction=" \
      "${v}_errored_review_regex=" \
      "${v}_quota_refusal_regex=" \
      "${v}_request_notes="
  done
  printf '%s\n' \
    "cubic_rerequest_method=comment" \
    "cubic_rerequest_login=" \
    "cubic_rerequest_command=@reviewer review this" \
    "cubic_rerequest_incremental_command=@reviewer incremental" \
    "copilot_rerequest_method=request" \
    "copilot_rerequest_login=requester-placeholder" \
    "copilot_rerequest_command=" \
    "copilot_rerequest_incremental_command="
}

# with_overrides <fields function> [<label=value> overrides...]
with_overrides() {
  local fields pair
  fields="$("$1")"
  shift
  for pair in "$@"; do
    fields="$(printf '%s\n' "$fields" | grep -v "^${pair%%=*}=")"$'\n'"$pair"
  done
  printf '%s\n' "$fields"
}
full_review_item() { with_overrides full_review_fields "$@" | to_item; }

run() { # run <template> <item> <output>; sets rc and log
  set +e
  log="$("$subject" "$@" 2>&1)"
  rc=$?
  set -e
}

expect_failed() { # expect_failed <label> <needle>
  if [ "$rc" -eq 0 ]; then ko "$1: exited 0 ($log)"
  elif ! grep -qF "FAILED:" <<<"$log"; then ko "$1: no FAILED: line ($log)"
  elif ! grep -qF -- "$2" <<<"$log"; then ko "$1: expected \"$2\", got: $log"
  else ok "$1"; fi
}

mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

echo "1. tracked review template renders, at 0600, regexes verbatim"
new_sandbox
full_review_item
run "$review_tpl" dotfiles-bot-review "$out"
if [ "$rc" -eq 0 ] && grep -q '^CHANGED:' <<<"$log"; then ok "prints CHANGED"; else ko "prints CHANGED ($log)"; fi
[ -f "$out" ] && [ "$(mode_of "$out")" = 600 ] && ok "mode 0600" || ko "mode 0600"
if [ "$(jq -r '.reviewers.cubic.login_pattern' "$out" 2>/dev/null)" = 'cubic-bot\[bot\]' ]; then
  ok "regex value carried verbatim"
else
  ko "regex value carried verbatim ($(jq -c '.reviewers.cubic.login_pattern' "$out" 2>&1))"
fi
[ "$(jq -r '.default' "$out")" = cubic ] && ok "default is the cubic entry" || ko "default is the cubic entry"
[ "$(jq -c '.reviewers.cubic.gating_checks' "$out")" = '["cubic/review"]' ] && ok "a json reference lands typed" || ko "a json reference lands typed"
if jq -e '.reviewers.cubic | has("opt_in_label") or (.rerequest | has("login"))' "$out" >/dev/null; then
  ko "an empty field is dropped"
else
  ok "an empty field is dropped"
fi
grep -q -- '--vault Dotfiles Service Account' "$OP_STUB_ARGV" && ok "default vault passed to op" || ko "default vault passed to op ($(cat "$OP_STUB_ARGV"))"

echo "2. an unchanged output prints OK"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && grep -q '^OK:' <<<"$log" && ok "prints OK" || ko "prints OK ($log)"

echo "3. same content at a looser mode is tightened and reported"
chmod 644 "$out"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && grep -q '^CHANGED:' <<<"$log" && ok "prints CHANGED" || ko "prints CHANGED ($log)"
[ "$(mode_of "$out")" = 600 ] && ok "mode back to 0600" || ko "mode back to 0600"

echo "4. a hand-written regular file is overwritten"
printf '{"default":"x","reviewers":{"x":{}}}\n' >"$out"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && grep -q '^CHANGED:' <<<"$log" && ok "prints CHANGED" || ko "prints CHANGED ($log)"
[ "$(jq -r .version "$out")" = 1 ] && ok "rendered content replaced it" || ko "rendered content replaced it"

echo "5. a template with an unsubstituted expression fails, nothing written"
new_sandbox
full_review_item
jq '.reviewers.cubic.opt_in_label = "{{ some_other_thing }}"' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "unsubstituted expression" "unsubstituted template expression"
[ -e "$out" ] && ko "output written" || ok "output not written"

echo "6. an unsubstituted expression in a text template fails"
item_from "flight_pr_hosts=[github.com]"
printf 'flight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}\nother: {{ nope }}\n' >"$sandbox/tpl/planwright.yml.tpl"
run "$sandbox/tpl/planwright.yml.tpl" item "$sandbox/home/overlay/planwright.yml"
expect_failed "unsubstituted text expression" "unsubstituted template expression"

echo "7. a reference to a field the item lacks fails naming it"
new_sandbox
full_review_item
jq 'del(.fields[] | select(.label == "cubic_opt_out_label"))' "$OP_STUB_ITEM" >"$sandbox/i" && mv "$sandbox/i" "$OP_STUB_ITEM"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "missing item field" "cubic_opt_out_label"

echo "8. a reference outside the rendered item fails"
jq '.reviewers.cubic.opt_in_label = "{{ op://Private/other/field }}"' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
full_review_item
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "foreign reference" "unsubstituted template expression"

echo "9. a rendered config missing each required field fails naming it"
for field in login_pattern reviewed_head_regex build_id_regex draft_policy opt_out_label; do
  new_sandbox
  full_review_item "cubic_$field="
  run "$review_tpl" dotfiles-bot-review "$out"
  expect_failed "missing $field" "reviewers.cubic: missing required field $field"
  [ -e "$out" ] && ko "missing $field: output written" || true
done
new_sandbox
full_review_item "copilot_rerequest_method="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "missing rerequest method" "reviewers.copilot.rerequest: missing required field method"

echo "10. the schema's value rules"
new_sandbox
full_review_item "cubic_rerequest_method=carrier-pigeon"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "unknown re-request method" "reviewers.cubic.rerequest.method: must be one of"
full_review_item "copilot_rerequest_login="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "request without login" "method request needs login"
full_review_item "cubic_rerequest_command="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "comment without command" "method comment needs command"
full_review_item "copilot_rerequest_incremental_command=@x again"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "incremental form on a non-comment method" "incremental_command applies only to method comment"
full_review_item "cubic_draft_setting="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "skips-drafts without the setting" "needs draft_setting"
full_review_item "cubic_draft_policy=sometimes"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "unknown draft policy" "reviewers.cubic.draft_policy: must be one of"
full_review_item "cubic_addressed_marker_format=<!-- ack -->"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "constant marker" "must contain {key}"
full_review_item "cubic_finding_key_regex=key:(["
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "regex that does not compile" "reviewers.cubic.finding_key_regex: does not compile"
full_review_item "cubic_gating_checks={\"a\":1}"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "gating checks not a list" "gating_checks: must be an array of non-empty strings"
full_review_item "cubic_gating_checks=[not json"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "json reference that does not parse" "cubic_gating_checks does not hold valid JSON"
[ -e "$out" ] && ko "a failing render wrote output" || ok "no failing render wrote output"

echo "11. unknown or missing version refused, naming the file and the version"
new_sandbox
full_review_item
jq '.version = 2' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "unknown version" "$out: unknown version 2"
jq 'del(.version)' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "no version key" "$out: no version key"
item_from 'repos={}'
printf '{"version": "1", "repos": "{{ op://__OP_VAULT__/__OP_ITEM__/repos | json }}"}\n' >"$sandbox/tpl/sibling-repos.json.tpl"
run "$sandbox/tpl/sibling-repos.json.tpl" item "$HOME/.config/dotfiles/sibling-repos.json"
expect_failed "sibling map with an unknown version" "sibling-repos.json: unknown version \"1\""

echo "12. output path guards"
new_sandbox
full_review_item
ln -s "$sandbox/elsewhere" "$out"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "symlinked output" "is a symlink"
[ -e "$sandbox/elsewhere" ] && ko "wrote through the symlink" || ok "did not write through the symlink"
rm "$out" && mkdir "$out"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "directory at the output" "not a regular file"

echo "13. tracked sibling map template renders and is checked"
new_sandbox
sib="$HOME/.config/dotfiles/sibling-repos.json"
item_from 'repos={"acme/web":{"acme/api":"~/src/api","acme/schema":"/srv/schema"}}'
run "$sibling_tpl" dotfiles-sibling-repos "$sib"
[ "$rc" -eq 0 ] && grep -q '^CHANGED:' <<<"$log" && ok "renders" || ko "renders ($log)"
# shellcheck disable=SC2088 # the literal tilde is the value under test
[ "$(jq -r '.repos["acme/web"]["acme/api"]' "$sib" 2>/dev/null)" = '~/src/api' ] && ok "map content typed" || ko "map content typed"
[ -f "$sib" ] && [ "$(mode_of "$sib")" = 600 ] && ok "mode 0600" || ko "mode 0600"
rm -f "$sib"
item_from 'repos={"acme/web":{"acme/api":"relative/path"}}'
run "$sibling_tpl" dotfiles-sibling-repos "$sib"
expect_failed "relative clone path" "repos.acme/web.acme/api: clone path must be absolute or start with ~/"
item_from 'repos=["acme/api"]'
run "$sibling_tpl" dotfiles-sibling-repos "$sib"
expect_failed "repos not a map" "repos: must be an object"

echo "14. overlay template: no step list, renders, refuses a steps_ key"
if grep -Eq '^[[:space:]]*steps_' "$overlay_tpl"; then ko "tracked overlay template sets a steps_ key"; else ok "tracked overlay template sets no steps_ key"; fi
new_sandbox
ov="$HOME/.claude/plugins/data/planwright-planwright/overlay/planwright.yml"
item_from 'flight_pr_hosts=[github.com/acme]'
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
[ "$rc" -eq 0 ] && grep -q '^CHANGED:' <<<"$log" && ok "renders, creating the directory" || ko "renders ($log)"
grep -qx 'flight_pr_hosts: \[github.com/acme\]' "$ov" 2>/dev/null && ok "value substituted raw" || ko "value substituted raw"
[ -f "$ov" ] && [ "$(mode_of "$ov")" = 600 ] && ok "mode 0600" || ko "mode 0600"
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
grep -q '^OK:' <<<"$log" && ok "second run prints OK" || ko "second run prints OK ($log)"
printf 'steps_convergence: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}\n' >"$sandbox/tpl/planwright.yml.tpl"
run "$sandbox/tpl/planwright.yml.tpl" item "$sandbox/ov.yml"
expect_failed "steps_ key in the overlay" "sets steps_convergence"
printf 'nested:\n  key: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}\n' >"$sandbox/tpl/planwright.yml.tpl"
run "$sandbox/tpl/planwright.yml.tpl" item "$sandbox/ov.yml"
expect_failed "non-flat overlay" "not a flat key: value line"
item_from 'flight_pr_hosts=x'
jq '.fields[0].value = "a\nsteps_x: b"' "$OP_STUB_ITEM" >"$sandbox/i" && mv "$sandbox/i" "$OP_STUB_ITEM"
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
expect_failed "multi-line value in a text template" "flight_pr_hosts holds a line break"

echo "15. preconditions"
new_sandbox
full_review_item
run "$sandbox/tpl/unknown.json.tpl" item "$out"
expect_failed "unreadable template" "template not readable"
printf '{}\n' >"$sandbox/tpl/mystery.json.tpl"
run "$sandbox/tpl/mystery.json.tpl" item "$out"
expect_failed "template with no validation rule" "no validation rule for mystery.json.tpl"
run "$review_tpl" 'bad;item' "$out"
expect_failed "item name outside the charset" "item name"
run "$review_tpl"
expect_failed "wrong argument count" "usage"
export OP_STUB_FAIL=1 DOTFILES_OP_VAULT=VaultValue7
run "$review_tpl" itemvalue7 "$out"
expect_failed "op failure" "op item get failed reading the item argument from the vault DOTFILES_OP_VAULT names (Dotfiles Service Account when unset)"
grep -qE 'itemvalue7|VaultValue7' <<<"$log" && ko "op failure: a setting's value reached the message" || ok "op failure: the values stay off stderr"
[ -e "$out" ] && ko "op failure wrote output" || ok "op failure wrote nothing"
unset OP_STUB_FAIL DOTFILES_OP_VAULT
item_from 'cubic_login_pattern=a' 'cubic_login_pattern=b'
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "duplicate field label" "more than one field labelled cubic_login_pattern"

echo "16. op missing"
new_sandbox
rm "$sandbox/bin/op"
for tool in bash dirname jq mktemp; do ln -s "$(command -v "$tool")" "$sandbox/bin/$tool"; done
set +e
log="$(PATH="$sandbox/bin" "$subject" "$review_tpl" dotfiles-bot-review "$out" 2>&1)"
rc=$?
set -e
expect_failed "op not installed" "1Password CLI (op) not installed"

echo "17. the token reaches op through its environment, never argv"
new_sandbox
full_review_item
export OP_SERVICE_ACCOUNT_TOKEN="ops_teststubtoken123"
run "$review_tpl" dotfiles-bot-review "$out"
unset OP_SERVICE_ACCOUNT_TOKEN
grep -q ops_teststubtoken123 "$OP_STUB_ENV" && ok "token in op's environment" || ko "token in op's environment"
grep -q ops_teststubtoken123 "$OP_STUB_ARGV" && ko "token in argv" || ok "token not in argv"
[ "$rc" -eq 0 ] && ok "renders with a token" || ko "renders with a token ($log)"

echo "18. empty fields drop their keys, and an entry left wholly empty drops out"
new_sandbox
# A while-read loop, not mapfile: the macOS CI leg runs bash 3.2.
empty_copilot=()
while IFS= read -r field; do empty_copilot+=("$field"); done \
  < <(full_review_fields | grep '^copilot_' | sed 's/=.*/=/')
full_review_item "${empty_copilot[@]}"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "renders with the copilot entry unset" || ko "renders with the copilot entry unset ($log)"
if jq -e '.reviewers | has("copilot")' "$out" >/dev/null 2>&1; then ko "empty entry dropped"; else ok "empty entry dropped"; fi
rm -f "$out"
full_review_item "cubic_gating_checks="
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "an empty json reference renders" || ko "an empty json reference renders ($log)"
if jq -e '.reviewers.cubic | has("gating_checks")' "$out" >/dev/null 2>&1; then ko "empty json reference dropped"; else ok "empty json reference dropped"; fi
rm -f "$out"
full_review_item 'cubic_gating_checks=[""]'
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "an empty check name" "gating_checks: must be an array of non-empty strings"
sib="$HOME/.config/dotfiles/sibling-repos.json"
item_from 'repos={"acme/web":{"acme/api":""}}'
run "$sibling_tpl" dotfiles-sibling-repos "$sib"
expect_failed "an empty string inside a json value is kept for the rule" "repos.acme/web.acme/api: clone path must be absolute"

echo "19. text templates: empty values drop their line, values are not template"
new_sandbox
ov="$HOME/.claude/plugins/data/planwright-planwright/overlay/planwright.yml"
item_from 'flight_pr_hosts='
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
[ "$rc" -eq 0 ] && ok "renders with the value unset" || ko "renders with the value unset ($log)"
if grep -q '^flight_pr_hosts' "$ov" 2>/dev/null; then ko "the empty key's line is dropped"; else ok "the empty key's line is dropped"; fi
item_from 'flight_pr_hosts=[a {{ b }}]'
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
grep -qxF 'flight_pr_hosts: [a {{ b }}]' "$ov" 2>/dev/null && ok "a value holding {{ lands as data" || ko "a value holding {{ lands as data ($log)"
item_from 'flight_pr_hosts=x'
jq '.fields[0].value = "a\rb"' "$OP_STUB_ITEM" >"$sandbox/i" && mv "$sandbox/i" "$OP_STUB_ITEM"
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
expect_failed "carriage return in a text value" "flight_pr_hosts holds a line break"
printf '{"id":"stub"}\n' >"$OP_STUB_ITEM"
run "$overlay_tpl" dotfiles-planwright-overlay "$ov"
expect_failed "op output with no fields" "holds no fields"

echo "20. the output's type is checked again just before the rename"
new_sandbox
full_review_item
export OP_STUB_MKDIR="$out"
run "$review_tpl" dotfiles-bot-review "$out"
unset OP_STUB_MKDIR
expect_failed "a directory appearing at the output mid-run" "not a regular file"
if find "$HOME/.config/dotfiles" -name '.bot-review.json.*' | grep -q .; then
  ko "a temp file was left beside the output"
else
  ok "no temp file left beside the output"
fi

echo "21. guards a deletion used to leave green"
new_sandbox
full_review_item
for bad in -flag a/b a@b .item "item "; do
  run "$review_tpl" "$bad" "$out"
  expect_failed "item name $bad" "is not a plain name"
done
run "$review_tpl" "" "$out"
expect_failed "an empty item name" "item name"
export DOTFILES_OP_VAULT="Other Vault"
run "$review_tpl" dotfiles-bot-review "$out"
unset DOTFILES_OP_VAULT
grep -q -- '--vault Other Vault' "$OP_STUB_ARGV" && ok "vault override reaches op" || ko "vault override reaches op"
rm -f "$out"
jq '.reviewers.cubic["{{ op://__OP_VAULT__/__OP_ITEM__/k }}"] = "x"' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "a reference in a key" "unsubstituted template expression in a key"
sib="$HOME/.config/dotfiles/sibling-repos.json"
item_from 'repos={"acme/web":{"acme/api":7}}'
run "$sibling_tpl" dotfiles-sibling-repos "$sib"
expect_failed "a non-string clone path" "repos.acme/web.acme/api: clone path must be absolute"
item_from 'repos={"acme/web":["~/src/api"]}'
run "$sibling_tpl" dotfiles-sibling-repos "$sib"
expect_failed "producers not a map" "repos.acme/web: must map producer repositories to clone paths"
item_from 'repos={}'
printf '{"version": 1, "extra": 1, "repos": "{{ op://__OP_VAULT__/__OP_ITEM__/repos | json }}"}\n' >"$sandbox/tpl/sibling-repos.json.tpl"
run "$sandbox/tpl/sibling-repos.json.tpl" item "$sib"
expect_failed "sibling map unknown field" "unknown top-level field extra"
printf '{"repos": "{{ op://__OP_VAULT__/__OP_ITEM__/repos | json }}"}\n' >"$sandbox/tpl/sibling-repos.json.tpl"
run "$sandbox/tpl/sibling-repos.json.tpl" item "$sib"
expect_failed "sibling map with no version" "sibling-repos.json: no version key"

echo "22. the review schema's structural rules"
schema_dir="$repo/roles/claude/files/skills/bot-review"
new_sandbox
full_review_item
run "$review_tpl" dotfiles-bot-review "$out"
valid="$(jq -c '.' "$out")"
# schema_says <label> <jq edit on a valid rendered config> <expected message>
schema_says() {
  local got
  got="$(jq -r -L "$schema_dir" "include \"config-schema\"; $2 | review_config_errors" <<<"$valid" 2>&1 || true)"
  if grep -qF -- "$3" <<<"$got"; then ok "$1"; else ko "$1: expected \"$3\", got: $got"; fi
}
[ -z "$(jq -r -L "$schema_dir" 'include "config-schema"; review_config_errors' <<<"$valid")" ] \
  && ok "the rendered fixture config is valid" || ko "the rendered fixture config is valid"
schema_says "unknown hosted field" '.reviewers.cubic.colour = "x"' "reviewers.cubic: unknown field colour"
schema_says "non-string value" '.reviewers.cubic.opt_out_label = 3' "reviewers.cubic.opt_out_label: not a string"
schema_says "login pattern that does not compile" '.reviewers.cubic.login_pattern = "a(["' "reviewers.cubic.login_pattern: does not compile"
schema_says "unknown rerequest field" '.reviewers.cubic.rerequest.when = "x"' "reviewers.cubic.rerequest: unknown field when"
schema_says "a non-string rerequest value" '.reviewers.copilot.rerequest.login = 5' "reviewers.copilot.rerequest.login: not a string"
schema_says "default not under reviewers" '.default = "nobody"' "config: default names nobody"
schema_says "empty reviewers" '.reviewers = {}' "config: reviewers must be a non-empty object"
schema_says "unknown top-level field" '.extra = 1' "config: unknown top-level field extra"
schema_says "cli not an object" '.reviewers.cubic.cli = "x"' "reviewers.cubic.cli: not an object"
schema_says "an entry with nothing" '.reviewers.copilot = {}' "reviewers.copilot: carries neither hosted mechanics nor a cli block"
got="$(jq -r -L "$schema_dir" 'include "config-schema"; .reviewers.copilot = {cli: {}} | review_config_errors' <<<"$valid")"
[ -z "$got" ] && ok "a cli-only entry is valid" || ko "a cli-only entry is valid: $got"
schema_says "gating checks holding a number" '.reviewers.cubic.gating_checks = [1]' "gating_checks: must be an array of non-empty strings"

echo "23. arrays of references, documents, text-mode gaps, write failures"
new_sandbox
{ full_review_fields; printf '%s\n' a= b= c=x; } | to_item
jq '.reviewers.cubic.gating_checks = ["{{ op://__OP_VAULT__/__OP_ITEM__/a }}", "{{ op://__OP_VAULT__/__OP_ITEM__/b }}"]' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
if [ "$rc" -eq 0 ] && ! jq -e '.reviewers.cubic | has("gating_checks")' "$out" >/dev/null; then
  ok "an array whose references are all empty drops its key"
else
  ko "an array whose references are all empty drops its key ($log)"
fi
jq '.reviewers.cubic.gating_checks = ["{{ op://__OP_VAULT__/__OP_ITEM__/a }}", "{{ op://__OP_VAULT__/__OP_ITEM__/c }}"]' "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
[ "$(jq -c '.reviewers.cubic.gating_checks' "$out" 2>/dev/null)" = '["x"]' ] && ok "an array keeps its non-empty references" || ko "an array keeps its non-empty references ($log)"
: >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "an empty JSON template" "exactly one JSON document"
cat "$review_tpl" "$review_tpl" >"$sandbox/tpl/bot-review.json.tpl"
run "$sandbox/tpl/bot-review.json.tpl" dotfiles-bot-review "$out"
expect_failed "a JSON template holding two documents" "exactly one JSON document"
item_from 'flight_pr_hosts='
printf 'flight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_host }}\n' >"$sandbox/tpl/planwright.yml.tpl"
run "$sandbox/tpl/planwright.yml.tpl" item "$sandbox/ov.yml"
expect_failed "a text reference to a field the item lacks" "the item has no field flight_pr_host"
printf 'flight_pr_hosts: [{{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}]\n' >"$sandbox/tpl/planwright.yml.tpl"
run "$sandbox/tpl/planwright.yml.tpl" item "$sandbox/ov.yml"
grep -qxF 'flight_pr_hosts: []' "$sandbox/ov.yml" 2>/dev/null && ok "only a whole-value reference drops its line" || ko "only a whole-value reference drops its line ($log)"
full_review_item
rm -f "$out"
# Each shim fails only the renderer's own write step; the fake op uses cat too.
for case in "mv:could not move the rendered file" "cat:could not write"; do
  tool="${case%%:*}"
  printf '#!/bin/sh\ncase "$*" in *rendered*|*.bot-review.json.*) exit 1 ;; esac\nexec %s "$@"\n' \
    "$(command -v "$tool")" >"$sandbox/bin/$tool"
  chmod +x "$sandbox/bin/$tool"
  run "$review_tpl" dotfiles-bot-review "$out"
  rm "$sandbox/bin/$tool"
  expect_failed "a failing $tool" "${case#*:}"
  if [ -e "$out" ] || find "$HOME/.config/dotfiles" -name '.bot-review.json.*' | grep -q .; then
    ko "a failing $tool left a file behind"
  else
    ok "a failing $tool left nothing behind"
  fi
done
(umask 0477 && "$subject" "$review_tpl" dotfiles-bot-review "$out" >/dev/null 2>&1) || true
[ -f "$out" ] && [ "$(mode_of "$out")" = 600 ] && ok "mode 0600 under a restrictive umask" || ko "mode 0600 under a restrictive umask ($( [ -e "$out" ] && mode_of "$out"))"

echo "24. the quota-stop keys"
new_sandbox
full_review_item "cubic_quota_refusal_regex=(usage|review) limit" "cubic_request_notes=first pass full, later ones incremental"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "renders the two keys" || ko "renders the two keys ($log)"
[ "$(jq -r '.reviewers.cubic | [.quota_refusal_regex, .request_notes] | join("|")' "$out" 2>/dev/null)" \
  = '(usage|review) limit|first pass full, later ones incremental' ] \
  && ok "each lands as a string" || ko "each lands as a string"
if jq -e '.reviewers.copilot | has("quota_refusal_regex")' "$out" >/dev/null 2>&1; then ko "left empty, a key drops"; else ok "left empty, a key drops"; fi
full_review_item "cubic_quota_refusal_regex=limit (["
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a quota pattern that does not compile" "reviewers.cubic.quota_refusal_regex: does not compile"

echo "25. output shape and early refusals"
new_sandbox
full_review_item "cubic_opt_out_label="
run "$review_tpl" dotfiles-bot-review "$out"
grep -q '^FAILED: ' <<<"$log" && ok "FAILED starts its own line after a violation list" || ko "FAILED starts its own line ($log)"
grep -qx '  - reviewers.cubic: missing required field opt_out_label' <<<"$log" && ok "each violation on its own line" || ko "each violation on its own line ($log)"
ln -s "$sandbox/elsewhere" "$out"
: >"$OP_STUB_ARGV"
run "$review_tpl" dotfiles-bot-review "$out"
[ -s "$OP_STUB_ARGV" ] && ko "a symlinked output still reached op" || ok "a symlinked output is refused before op runs"
rm -f "$out"
item_from 'flight_pr_hosts=[a]'
printf -- '---\nflight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}\n' >"$sandbox/tpl/planwright.yml.tpl"
run "$sandbox/tpl/planwright.yml.tpl" item "$sandbox/ov.yml"
[ "$rc" -eq 0 ] && ok "a --- document marker is allowed in the overlay" || ko "a --- document marker is allowed ($log)"
schema_dir="$repo/roles/claude/files/skills/bot-review"
got="$(jq -n -r -L "$schema_dir" 'include "config-schema"; {reviewers: {a: {cli: {}}}} | review_config_errors')"
grep -qF 'config: missing required field default' <<<"$got" && ok "a missing default is named" || ko "a missing default is named ($got)"

echo "26. the finding key and its marker are optional together"
new_sandbox
full_review_item "cubic_finding_key_regex=" "cubic_addressed_marker_format="
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "renders with neither" || ko "renders with neither ($log)"
full_review_item "cubic_finding_key_regex="
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "a marker without a key regex renders" || ko "a marker without a key regex renders ($log)"
full_review_item "cubic_addressed_marker_format="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a key regex without its marker" "reviewers.cubic: finding_key_regex needs addressed_marker_format"

echo "27. the work item: read only when configured, with its own account"
work_fields() {
  printf '%s\n' \
    "work_review_login_pattern=work-bot(-2)?\\[bot\\]" \
    "work_review_rerequest_method=push" "work_review_rerequest_login=" \
    "work_review_rerequest_command=" "work_review_rerequest_incremental_command=" \
    "work_review_reviewed_head_regex=" "work_review_reviewed_head_check=Work Review" \
    "work_review_finding_key_regex=" "work_review_build_id_regex=/builds/([0-9a-f-]+)" \
    "work_review_draft_policy=skips-drafts" "work_review_draft_setting=the opt-in label overrides it" \
    "work_review_opt_out_label=no-review" "work_review_opt_in_label=review-me" \
    "work_review_auto_opt_in=true" "work_review_addressed_marker_format=<!-- ack:{key} -->" \
    "work_review_gating_checks=[\"Work Review\"]" "work_review_requirement_level_hint=" \
    "work_review_repo_config_path=" "work_review_reply_suffix=[ack]" \
    "work_review_feedback_reaction=" "work_review_errored_review_regex=not_reviewed" \
    "work_review_quota_refusal_regex=" "work_review_request_notes="
}
# work_item [<label=value> overrides...]: the stubbed work item.
work_item() {
  export OP_STUB_WORK_ITEM="$sandbox/work-item.json"
  with_overrides work_fields "$@" | to_item "$OP_STUB_WORK_ITEM"
}
new_sandbox
full_review_item
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "unconfigured: renders" || ko "unconfigured: renders ($log)"
[ "$(jq -c '.reviewers | keys' "$out")" = '["copilot","cubic"]' ] && ok "unconfigured: the work entry drops out" || ko "unconfigured: the work entry drops out ($(jq -c '.reviewers | keys' "$out"))"
grep -q -- '--account' "$OP_STUB_ARGV" && ko "unconfigured: op asked for another account" || ok "unconfigured: one op read"
new_sandbox
full_review_item
work_item
export DOTFILES_OP_WORK_ACCOUNT=work.example.com DOTFILES_OP_WORK_VAULT="Work Vault" DOTFILES_OP_WORK_ITEM=work-item
export OP_SERVICE_ACCOUNT_TOKEN="ops_teststubtoken123"
run "$review_tpl" dotfiles-bot-review "$out"
unset OP_SERVICE_ACCOUNT_TOKEN
[ "$rc" -eq 0 ] && ok "configured: renders" || ko "configured: renders ($log)"
[ "$(jq -c '.reviewers | keys' "$out")" = '["copilot","cubic","work-review"]' ] && ok "configured: the work entry lands" || ko "configured: the work entry lands ($log)"
jq -e '.reviewers["work-review"] | .login_pattern == "work-bot(-2)?\\[bot\\]" and .auto_opt_in == true
  and .gating_checks == ["Work Review"] and .reviewed_head_check == "Work Review"
  and (has("finding_key_regex") | not) and (has("reviewed_head_regex") | not)' "$out" >/dev/null \
  && ok "configured: values typed and verbatim, empty ones dropped" || ko "configured: values ($(jq -c '.reviewers["work-review"]' "$out"))"
grep -qx -- 'item get work-item --vault Work Vault --account work.example.com --format json --reveal' "$OP_STUB_ARGV" \
  && ok "configured: the work read names its account" || ko "configured: the work read ($(cat "$OP_STUB_ARGV"))"
[ "$(sed -n 2p "$OP_STUB_ENV")" = "" ] && ok "configured: no token on the work read" || ko "configured: the token reached the work read"
[ "$(jq -c '.reviewers.cubic.gating_checks' "$out")" = '["cubic/review"]' ] && ok "configured: the default item's entries unchanged" || ko "configured: the default item's entries unchanged"
work_item "work_review_auto_opt_in=yes"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a non-JSON boolean" "work item field work_review_auto_opt_in does not hold valid JSON"
work_item "work_review_auto_opt_in=\"true\""
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a string boolean" "reviewers.work-review.auto_opt_in: must be true or false"
work_item "work_review_opt_in_label="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "auto opt-in with no label" "reviewers.work-review: auto_opt_in needs opt_in_label"
work_item "work_review_opt_in_label=" "work_review_auto_opt_in=false"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && [ "$(jq '.reviewers["work-review"].auto_opt_in' "$out")" = false ] \
  && ok "auto opt-in off needs no label, and lands typed" || ko "auto opt-in off needs no label ($log)"
work_item "work_review_auto_opt_in=1"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a number for the boolean" "reviewers.work-review.auto_opt_in: must be true or false"
work_item "work_review_reviewed_head_regex=reviewed ([0-9a-f]{40})"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "both reviewed-head sources" "set reviewed_head_regex or reviewed_head_check, not both"
for padded in "Work Review " " Work Review"; do
  work_item "work_review_reviewed_head_check=$padded"
  run "$review_tpl" dotfiles-bot-review "$out"
  expect_failed "a padded check name ('$padded')" "reviewed_head_check: leading or trailing whitespace"
done
work_item
jq '.fields += [.fields[0]]' "$OP_STUB_WORK_ITEM" >"$sandbox/i" && mv "$sandbox/i" "$OP_STUB_WORK_ITEM"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a work item with a duplicated label" "more than one field labelled"
work_item "work_review_reviewed_head_check=" "work_review_reviewed_head_regex="
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "the work entry still needs its required fields" "reviewers.work-review: missing required field reviewed_head_regex"
work_item
jq 'del(.fields[] | select(.label == "work_review_reply_suffix"))' "$OP_STUB_WORK_ITEM" >"$sandbox/i" && mv "$sandbox/i" "$OP_STUB_WORK_ITEM"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a field the work item lacks" "the work item has no field work_review_reply_suffix"
work_item
export OP_STUB_FAIL_WORK=1
run "$review_tpl" dotfiles-bot-review "$out"
unset OP_STUB_FAIL_WORK
expect_failed "a failing work read" "op item get failed reading the work item DOTFILES_OP_WORK_ACCOUNT, DOTFILES_OP_WORK_VAULT and DOTFILES_OP_WORK_ITEM name"
grep -qE 'work\.example\.com|Work Vault|work-item' <<<"$log" && ko "a failing work read: a setting's value reached the message" || ok "a failing work read: the values stay off stderr"
printf '{"id":"stub"}\n' >"$OP_STUB_WORK_ITEM"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a work item with no fields" "could not read work item 'work-item'"
work_item
for v in DOTFILES_OP_WORK_ACCOUNT DOTFILES_OP_WORK_VAULT DOTFILES_OP_WORK_ITEM; do
  (unset "$v"; run "$review_tpl" dotfiles-bot-review "$out"; expect_failed "a partial work source ($v unset)" "must be set together or not at all"; echo "$pass $fail" >"$sandbox/counts")
  read -r pass fail <"$sandbox/counts"
done
for bad in "DOTFILES_OP_WORK_ACCOUNT=a b.example.com" "DOTFILES_OP_WORK_ACCOUNT=a/b" \
  "DOTFILES_OP_WORK_VAULT=-v" "DOTFILES_OP_WORK_VAULT=v@w" \
  "DOTFILES_OP_WORK_ITEM=a/b" "DOTFILES_OP_WORK_ITEM=-i" "DOTFILES_OP_WORK_ITEM=i@x" \
  "DOTFILES_OP_WORK_VAULT=$(printf 'v\033[31mred')" "DOTFILES_OP_WORK_ACCOUNT=secretvalue=abc" \
  "DOTFILES_OP_WORK_VAULT=Work Vault " "DOTFILES_OP_WORK_VAULT= v" "DOTFILES_OP_WORK_ITEM=.hidden" "DOTFILES_OP_WORK_ITEM=_x"; do
  (export "${bad?}"; run "$review_tpl" dotfiles-bot-review "$out"; expect_failed "bad ${bad%%=*}" "${bad%%=*} is not a plain name"
   if grep -qF -- "${bad#*=}" <<<"$log"; then ko "bad ${bad%%=*}: the value reached the message"; else ok "bad ${bad%%=*}: the value stays out of the message"; fi
   echo "$pass $fail" >"$sandbox/counts")
  read -r pass fail <"$sandbox/counts"
done
unset DOTFILES_OP_WORK_ITEM
export DOTFILES_OP_WORK_ITEM=work-item DOTFILES_OP_WORK_ACCOUNT=--evil
: >"$OP_STUB_ARGV"
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "an account that reads as a flag" "DOTFILES_OP_WORK_ACCOUNT is not a plain name"
[ -s "$OP_STUB_ARGV" ] && ko "a bad work setting still reached op" || ok "a bad work setting is refused before any op call"
export DOTFILES_OP_WORK_ACCOUNT="wörk.example.com"
LC_ALL=en_US.UTF-8 run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a non-ASCII account under a UTF-8 locale" "is not a plain name"
export DOTFILES_OP_WORK_ACCOUNT=work.example.com DOTFILES_OP_WORK_VAULT=a/b
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "a vault with a path separator" "is not a plain name"
export DOTFILES_OP_WORK_VAULT="Work Vault"
: >"$OP_STUB_ARGV"
item_from "flight_pr_hosts=[a]"
run "$overlay_tpl" dotfiles-planwright-overlay "$sandbox/ov.yml"
grep -q -- '--account' "$OP_STUB_ARGV" && ko "a template with no work reference read the work item" || ok "a template with no work reference reads one item"
export DOTFILES_OP_WORK_ITEM=work-item
: >"$OP_STUB_ARGV"
item_from 'repos={"acme/web":{"acme/api":"/src/api"}}'
run "$sibling_tpl" dotfiles-sibling-repos "$HOME/.config/dotfiles/sibling-repos.json"
[ "$rc" -eq 0 ] && ! grep -q -- '--account' "$OP_STUB_ARGV" \
  && ok "a JSON template with no work reference reads one item" || ko "a JSON template with no work reference reads one item ($log)"
unset DOTFILES_OP_WORK_ACCOUNT DOTFILES_OP_WORK_VAULT DOTFILES_OP_WORK_ITEM
schema_dir="$repo/roles/claude/files/skills/bot-review"
got="$(jq -r -L "$schema_dir" 'include "config-schema"; .reviewers.cubic.opt_in_label = "{{ op://__OP_WORK_VAULT__/__OP_WORK_ITEM__/x }}" | review_template_errors' "$review_tpl")"
grep -qF 'reviewers.cubic: references both the default item and the work item' <<<"$got" && ok "one entry draws on one item" || ko "one entry draws on one item ($got)"
got="$(jq -n -r -L "$schema_dir" 'include "config-schema"; {reviewed_head_regex: "", reviewed_head_check: "C", rerequest: {method: "push"}} | _rendered_value_errors("p")')"
grep -q 'not both' <<<"$got" && ko "an empty regex beside a check is refused ($got)" || ok "an empty regex beside a check is not 'both'"
got="$(jq -n -r -L "$schema_dir" 'include "config-schema"; {reviewed_head_check: 5} | _rendered_value_errors("p")')"
grep -qx 'p.reviewed_head_check: not a string' <<<"$got" && ok "a non-string check name is named, not a jq error" || ko "a non-string check name ($got)"
got="$(jq -r -L "$schema_dir" 'include "config-schema"; .reviewers["work-review"].cli = {binary: "{{ op://__OP_VAULT__/__OP_ITEM__/x }}"} | review_template_errors' "$review_tpl")"
[ -z "$got" ] && ok "a cli block is outside the one-item rule" || ko "a cli block is outside the one-item rule ($got)"

echo
echo "op-render: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
