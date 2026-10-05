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
  unset OP_STUB_FAIL OP_STUB_MKDIR
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
cat "$OP_STUB_ITEM"
FAKE
  chmod +x "$sandbox/bin/op"
}

# label=value lines on stdin -> the canned item, in op's JSON shape.
to_item() {
  jq -R -s '
    split("\n") | map(select(length > 0) | capture("^(?<label>[^=]+)=(?<value>.*)$"))
    | {id: "stub", title: "stub", fields: map({id: .label, type: "STRING", label, value})}' \
    >"$OP_STUB_ITEM"
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
      "${v}_full_review_comment=" \
      "${v}_rereview_comment=" \
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

# full_review_item [<label=value> overrides...]
full_review_item() {
  local fields pair
  fields="$(full_review_fields)"
  for pair in "$@"; do
    fields="$(printf '%s\n' "$fields" | grep -v "^${pair%%=*}=")"$'\n'"$pair"
  done
  printf '%s\n' "$fields" | to_item
}

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
for field in login_pattern reviewed_head_regex finding_key_regex build_id_regex \
  draft_policy opt_out_label addressed_marker_format; do
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
export OP_STUB_FAIL=1
run "$review_tpl" dotfiles-bot-review "$out"
expect_failed "op failure" "op item get failed"
[ -e "$out" ] && ko "op failure wrote output" || ok "op failure wrote nothing"
unset OP_STUB_FAIL
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
mapfile -t empty_copilot < <(full_review_fields | grep '^copilot_' | sed 's/=.*/=/')
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
for bad in -flag a/b; do
  run "$review_tpl" "$bad" "$out"
  expect_failed "item name $bad" "is outside"
done
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

echo "24. the incremental re-review and quota-stop keys"
new_sandbox
full_review_item "cubic_full_review_comment=@reviewer full" "cubic_rereview_comment=@reviewer again" \
  "cubic_quota_refusal_regex=(usage|review) limit" "cubic_request_notes=first pass full, later ones incremental"
run "$review_tpl" dotfiles-bot-review "$out"
[ "$rc" -eq 0 ] && ok "renders the four keys" || ko "renders the four keys ($log)"
[ "$(jq -r '.reviewers.cubic | [.full_review_comment, .rereview_comment, .quota_refusal_regex, .request_notes] | join("|")' "$out" 2>/dev/null)" \
  = '@reviewer full|@reviewer again|(usage|review) limit|first pass full, later ones incremental' ] \
  && ok "each lands as a string" || ko "each lands as a string"
if jq -e '.reviewers.copilot | has("rereview_comment")' "$out" >/dev/null 2>&1; then ko "left empty, a key drops"; else ok "left empty, a key drops"; fi
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

echo
echo "op-render: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
