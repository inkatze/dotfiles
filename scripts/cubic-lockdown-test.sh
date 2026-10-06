#!/usr/bin/env bash
# Proves, from the pinned cubic CLI binary's own code, that the switches the
# review config template sets for reviewer:cubic are honoured: the review
# agent loses its shell and web-fetch tools, every built-in language server
# is disabled, and the global instruction file the CLI uploads is the empty
# one the claude role creates, not ~/.claude/CLAUDE.md.
#
# The binary is not run (it needs an account); its bundled JavaScript is read
# as text. The platform package is fetched at the version the tracked mise
# config pins and checked against the integrity reviewed below, so a version
# bump fails here until someone re-reads these code paths and updates
# reviewed_version and reviewed_integrity. Needs network; offline it fails
# rather than passing unchecked.
set -uo pipefail

reviewed_version="1.14.2"
reviewed_integrity="sha512-LXPU7MQmVrEC6wYVYRtyIq8dh3AS3zuUFfffQpsdLrLzSk7Mzl1h8lh+S41xC4+QcS4BiurdNIvmQFbJXbIIYw=="

repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
pins="$repo/roles/environments/files/mise.toml"
tpl="$repo/roles/claude/files/skills/bot-review/bot-review.json.tpl"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }
die() { echo "cubic-lockdown-test: $1"; exit 1; }

work="$(mktemp -d)" || die "could not create a scratch directory"
trap 'rm -rf "$work"' EXIT

echo "1. the pinned version is the reviewed one"
pinned="$(sed -n 's/^"npm:@cubic-dev-ai\/cli" = "\([^"]*\)"$/\1/p' "$pins")"
[ "$pinned" = "$reviewed_version" ] && ok "mise pins $pinned" \
  || ko "mise pins ${pinned:-nothing} but the lockdown was reviewed at $reviewed_version; re-read the code paths below and update this test"

echo "2. the fetched binary is the reviewed one"
curl -fsSL --connect-timeout 10 --max-time 300 -o "$work/pkg.tgz" \
  "https://registry.npmjs.org/@cubic-dev-ai/cli-linux-x64/-/cli-linux-x64-$reviewed_version.tgz" \
  || die "could not fetch the platform package (offline?); nothing was checked"
got="sha512-$(openssl dgst -sha512 -binary "$work/pkg.tgz" | openssl base64 -A)"
[ "$got" = "$reviewed_integrity" ] && ok "integrity matches" || ko "integrity $got is not the reviewed $reviewed_integrity"
tar -xzOf "$work/pkg.tgz" package/bin/cubic | strings -n 6 >"$work/code" \
  || die "could not read package/bin/cubic"
code="$work/code"

# has <label> <fixed string>: the binary's code holds the line.
has() {
  if grep -qF -- "$2" "$code"; then ok "$1"; else ko "$1 (no longer finds: $2)"; fi
}
# block_has <label> <block start> <lines> <fixed string>: the string sits
# within that many lines after the block's first line.
block_has() {
  local start
  start="$(grep -nF -- "$2" "$code" | head -n 1 | cut -d: -f1)"
  if [ -n "$start" ] && sed -n "${start},$((start + $3))p" "$code" | grep -qF -- "$4"; then
    ok "$1"
  else
    ko "$1 (no longer finds \"$4\" after \"$2\")"
  fi
}

echo "3. CUBIC_PERMISSION removes the review agent's shell and web fetch"
has "the variable is read as a flag" 'Flag.CUBIC_PERMISSION = env3("PERMISSION");'
has "it is merged into the config's permission" 'result.permission = D2(result.permission ?? {}, JSON.parse(Flag.CUBIC_PERMISSION));'
block_has "the code-review agent's permission is merged with the config's" \
  'const codeReviewPermission = mergeAgentPermissions({' 6 '}, cfg.permission ?? {});'
block_has "the code-review agent uses that permission" '"code-review": {' 6 'permission: codeReviewPermission,'
block_has "a bare \"deny\" for bash becomes {\"*\": \"deny\"}" 'function mergeAgentPermissions(basePermission, overridePermission) {' 10 '"*": overridePermission.bash'
block_has "the merged bash keeps the override's \"*\"" 'function mergeAgentPermissions(basePermission, overridePermission) {' 22 'mergedBash = D2({'
block_has "bash is removed when its only rule is \"*\": \"deny\"" 'async function enabled(_providerID, _modelID, agent) {' 8 \
  'if (agent.permission.bash["*"] === "deny" && Object.keys(agent.permission.bash).length === 1) {'
block_has "webfetch is removed when denied" 'async function enabled(_providerID, _modelID, agent) {' 10 'if (agent.permission.webfetch === "deny") {'
permission="$(jq -r '.reviewers.cubic.cli.env.CUBIC_PERMISSION' "$tpl")"
if jq -e '.bash == "deny" and .webfetch == "deny"' <<<"$permission" >/dev/null 2>&1; then
  ok "the template denies bash and webfetch"
else
  ko "the template's CUBIC_PERMISSION does not deny bash and webfetch: $permission"
fi

echo "4. CUBIC_CONFIG_CONTENT disables every built-in language server"
has "the variable is read as a flag" 'Flag.CUBIC_CONFIG_CONTENT = env3("CONFIG_CONTENT");'
has "it is merged into the config" 'result = D2(result, JSON.parse(Flag.CUBIC_CONFIG_CONTENT));'
block_has "a disabled server is dropped" 'for (const [name2, item] of Object.entries(cfg.lsp ?? {})) {' 4 'delete servers[name2];'
servers="$(awk '/^  LSPServer\.[A-Za-z]+ = \{$/ { getline; if (match($0, /id: "[a-z-]+"/)) print substr($0, RSTART + 5, RLENGTH - 6) }' "$code" | sort -u)"
[ -n "$servers" ] || ko "no built-in language server found; the code changed shape"
disabled="$(jq -r '.reviewers.cubic.cli.env.CUBIC_CONFIG_CONTENT | fromjson | .lsp | to_entries[] | select(.value.disabled == true) | .key' "$tpl" | sort -u)"
missing="$(comm -23 <(printf '%s\n' "$servers") <(printf '%s\n' "$disabled") | tr '\n' ' ')"
if [ -n "$servers" ] && [ -z "$missing" ]; then
  ok "the template disables every built-in server ($(printf '%s\n' "$servers" | wc -l | tr -d ' ') in this version)"
else
  ko "the template leaves these servers on: $missing"
fi

echo "5. the global instruction file read first is the one the role empties"
block_has "the CLI's config directory is XDG config's cubic" 'var app = "cubic", data, cache, config, state' 6 'config = path2.join(xdgConfig, app);'
block_has "its AGENTS.md is read before ~/.claude/CLAUDE.md" 'const GLOBAL_RULE_FILES = [' 2 'path19.join(Global.Path.config, "AGENTS.md"),'
block_has "only the first global file found is read" 'for (const globalRuleFile of GLOBAL_RULE_FILES) {' 4 'break;'
if [ "$(jq -r '.reviewers.cubic.cli.require_empty | index("~/.config/cubic/AGENTS.md") != null' "$tpl")" = true ]; then
  ok "the template requires that file to exist and be empty"
else
  ko "the template's cli.require_empty does not name ~/.config/cubic/AGENTS.md"
fi

echo
echo "cubic-lockdown-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
