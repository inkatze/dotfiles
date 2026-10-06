#!/usr/bin/env bash
# Proves, from the pinned cubic CLI binary's own code, that the switches the
# review config template sets for reviewer:cubic are honoured: the review
# agent loses its shell, edit, grep, web-fetch and search tools, every
# built-in language server is disabled, the review runs on cubic's own
# provider, a wellknown login's remote config cannot undo any of it, and the
# global instruction file the CLI uploads is the empty one the claude role
# creates, not ~/.claude/CLAUDE.md.
#
# The binary is not run (it needs an account); its bundled JavaScript is read
# as text. The platform package is fetched at the version the tracked mise
# config pins and checked against the integrity reviewed below, so a version
# bump fails here until someone re-reads these code paths and updates
# reviewed_version and reviewed_integrity. A first run needs the network, and
# offline it fails rather than passing unchecked; later runs use the cached
# tarball, re-hashed every time.
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
# The reviewed tarball is cached by version and re-hashed on every run, so a
# hit is as trustworthy as a fresh fetch and a template edit needs no network.
cache_home="${XDG_CACHE_HOME:-}"
case "$cache_home" in /*) ;; *) cache_home="$HOME/.cache" ;; esac
cache_dir="$cache_home/dotfiles/cubic-lockdown"
cached="$cache_dir/cli-linux-x64-$reviewed_version.tgz"

echo "1. the pinned version is the reviewed one"
pinned="$(sed -n 's/^"npm:@cubic-dev-ai\/cli" = "\([^"]*\)"$/\1/p' "$pins")"
[ "$pinned" = "$reviewed_version" ] && ok "mise pins $pinned" \
  || ko "mise pins ${pinned:-nothing} but the lockdown was reviewed at $reviewed_version; re-read the code paths below and update this test"

echo "2. the fetched binary is the reviewed one"
integrity_of() { printf 'sha512-%s' "$(openssl dgst -sha512 -binary "$1" | openssl base64 -A)"; }
mode_of() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null; }
# Only a cache directory of the user's own that nobody else can write is used.
cache_ok() {
  local m
  [ -d "$cache_dir" ] && [ ! -L "$cache_dir" ] && [ -O "$cache_dir" ] || return 1
  m="$(mode_of "$cache_dir")" || return 1
  case "$m" in [0-7] | [0-7][0-7] | [0-7][0-7][0-7] | [0-7][0-7][0-7][0-7]) ;; *) return 1 ;; esac
  m="00$m"
  case "${m#"${m%??}"}" in ?[2367] | [2367]?) return 1 ;; esac
}
got=""
if [ -f "$cached" ] && [ ! -L "$cached" ] && cache_ok && cp "$cached" "$work/pkg.tgz"; then
  got="$(integrity_of "$work/pkg.tgz")"
fi
if [ "$got" != "$reviewed_integrity" ]; then
  cache_ok || [ ! -e "$cache_dir" ] || echo "  note: ignoring $cache_dir, which is not a private directory of yours"
  if { [ -e "$cached" ] || [ -L "$cached" ]; } && { [ -L "$cached" ] || [ ! -f "$cached" ]; }; then
    echo "  note: $cached is not a plain file, so it is neither used nor replaced; remove it"
  fi
  curl -fsSL --connect-timeout 10 --max-time 300 -o "$work/pkg.tgz" \
    "https://registry.npmjs.org/@cubic-dev-ai/cli-linux-x64/-/cli-linux-x64-$reviewed_version.tgz" \
    || die "could not fetch the platform package and no usable reviewed copy is cached; nothing was checked"
  got="$(integrity_of "$work/pkg.tgz")"
  if [ "$got" = "$reviewed_integrity" ] && (umask 077; mkdir -p "$cache_dir") && cache_ok \
    && { [ ! -e "$cached" ] && [ ! -L "$cached" ] || { [ -f "$cached" ] && [ ! -L "$cached" ]; }; }; then
    staged="$(mktemp "$cache_dir/.tgz.XXXXXX")" || staged=""
    if [ -n "$staged" ] && cp "$work/pkg.tgz" "$staged" && mv -f "$staged" "$cached"; then
      # A staged copy under an hour old may belong to another run still writing it;
      # fetches are capped well below that.
      find "$cache_dir" -maxdepth 1 -type f \( -name 'cli-linux-x64-*.tgz' ! -name "${cached##*/}" \
        -o -name '.tgz.*' -mmin +60 \) -delete
    else
      [ -z "$staged" ] || rm -f "$staged"
    fi
  fi
fi
[ "$got" = "$reviewed_integrity" ] && ok "integrity matches" || ko "integrity $got is not the reviewed $reviewed_integrity"
tar -xzOf "$work/pkg.tgz" package/bin/cubic | LC_ALL=C tr -c '\11\40-\176' '\n' | LC_ALL=C grep -E '.{6}' >"$work/code" \
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

echo "3. CUBIC_PERMISSION removes the review agent's shell, web fetch and edit"
has "the variable is read as a flag" 'Flag.CUBIC_PERMISSION = env3("PERMISSION");'
has "it is merged into the config's permission" 'result.permission = D2(result.permission ?? {}, JSON.parse(Flag.CUBIC_PERMISSION));'
block_has "the code-review agent's permission is merged with the config's" \
  'const codeReviewPermission = mergeAgentPermissions({' 6 '}, cfg.permission ?? {});'
block_has "the code-review agent uses that permission" '"code-review": {' 6 'permission: codeReviewPermission,'
has "the subagents' permission is merged with the config's too" 'const agentPermission = mergeAgentPermissions(defaultPermission, cfg.permission ?? {});'
block_has "the general subagent uses it" '      general: {' 12 'permission: agentPermission,'
block_has "the design-quality subagent uses it" '"design-quality": {' 12 'permission: agentPermission,'
has "review runs the code-review agent" 'agent: "code-review",'
block_has "a bare \"deny\" for bash becomes {\"*\": \"deny\"}" 'function mergeAgentPermissions(basePermission, overridePermission) {' 10 '"*": overridePermission.bash'
block_has "bash is removed when its only rule is \"*\": \"deny\"" 'async function enabled(_providerID, _modelID, agent) {' 8 \
  'if (agent.permission.bash["*"] === "deny" && Object.keys(agent.permission.bash).length === 1) {'
block_has "webfetch is removed when denied" 'async function enabled(_providerID, _modelID, agent) {' 10 'if (agent.permission.webfetch === "deny") {'
block_has "edit is removed when denied" 'async function enabled(_providerID, _modelID, agent) {' 5 'if (agent.permission.edit === "deny") {'
has "write is never enabled" 'result["write"] = false;'
block_has "the review agent's edit is denied by default" 'const codeReviewPermission = mergeAgentPermissions({' 1 'edit: "deny",'
block_has "an edit publishes a file-edited event" 'var EditTool = Tool2.define("edit", {' 60 'await Bus.publish(File2.Event.Edited, {'
block_has "a file-edited event runs the formatters" 'Bus.subscribe(File2.Event.Edited, async (payload) => {' 5 'for (const item of await getFormatter(ext)) {'
has "one formatter runs bun x prettier --write" 'command: [BunProc.which(), "x", "prettier", "--write", "$FILE"],'
permission="$(jq -r '.reviewers.cubic.cli.env.CUBIC_PERMISSION' "$tpl")"
if jq -e '.bash == "deny" and .webfetch == "deny" and .edit == "deny"' <<<"$permission" >/dev/null 2>&1; then
  ok "the template denies bash, webfetch and edit"
else
  ko "the template's CUBIC_PERMISSION does not deny bash, webfetch and edit: $permission"
fi

echo "4. CUBIC_CONFIG_CONTENT turns off grep, web and code search, and every built-in language server"
has "the config's tools seed every agent's tools" 'const defaultTools = cfg.tools ?? {};'
block_has "the code-review agent takes them" '"code-review": {' 4 'tools: { ...defaultTools },'
has "an agent's tools set a session's enabled tools" 'const enabledTools = C3(input.agent.tools, D2(await ToolRegistry.enabled("cubic", "cubic", input.agent)), D2(input.tools ?? {}));'
has "a tool set to false is skipped" 'if (Wildcard.all(item.id, enabledTools) === false) {'
block_has "review passes no tool override" 'agent: "code-review",' 3 'parts: texts.map((text2) => ({ type: "text", text: text2 }))'
for tool in grep websearch codesearch; do
  has "the $tool tool's id is $tool" "Tool2.define(\"$tool\", {"
  if [ "$(jq -r --arg t "$tool" '.reviewers.cubic.cli.env.CUBIC_CONFIG_CONTENT | fromjson | .tools[$t]' "$tpl")" = false ]; then
    ok "the template turns $tool off"
  else
    ko "the template leaves $tool on"
  fi
done
block_has "grep hands its path to ripgrep after the pattern, with no --" 'const args2 = ["-nH", "--field-match-separator=|", "--regexp", params.pattern];' 3 'args2.push(searchPath);'
has "the variable is read as a flag" 'Flag.CUBIC_CONFIG_CONTENT = env3("CONFIG_CONTENT");'
has "it is merged into the config" 'result = D2(result, JSON.parse(Flag.CUBIC_CONFIG_CONTENT));'
block_has "a disabled server is dropped" 'for (const [name2, item] of Object.entries(cfg.lsp ?? {})) {' 4 'delete servers[name2];'
servers="$(awk '/^  LSPServer\.[A-Za-z]+ = \{$/ { getline; if (match($0, /id: "[a-z-]+"/)) print substr($0, RSTART + 5, RLENGTH - 6) }' "$code" | sort -u)"
[ -n "$servers" ] || ko "no built-in language server found; the code changed shape"
assigned="$(grep -oE '^  LSPServer\.[A-Za-z]+ = ' "$code" | sort -u | wc -l | tr -d ' ')"
[ "$assigned" = "$(printf '%s\n' "$servers" | wc -l | tr -d ' ')" ] && ok "every built-in server's id was read" \
  || ko "$assigned servers are defined but only some ids were read; the code changed shape"
disabled="$(jq -r '.reviewers.cubic.cli.env.CUBIC_CONFIG_CONTENT | fromjson | .lsp | to_entries[] | select(.value.disabled == true) | .key' "$tpl" | sort -u)"
missing="$(comm -23 <(printf '%s\n' "$servers") <(printf '%s\n' "$disabled") | tr '\n' ' ')"
if [ -n "$servers" ] && [ -z "$missing" ]; then
  ok "the template disables every built-in server ($(printf '%s\n' "$servers" | wc -l | tr -d ' ') in this version)"
else
  ko "the template leaves these servers on: $missing"
fi

echo "5. the global instruction file read first is the one the role empties"
block_has "the CLI's config directory is XDG config's cubic" 'var app = "cubic", data, cache, config, state' 6 'config = path2.join(xdgConfig, app);'
block_has "its AGENTS.md is read before ~/.claude/CLAUDE.md" 'const GLOBAL_RULE_FILES = [' 1 'path19.join(Global.Path.config, "AGENTS.md"),'
block_has "only the first global file found is read" 'for (const globalRuleFile of GLOBAL_RULE_FILES) {' 4 'break;'
if [ "$(jq -r '.reviewers.cubic.cli.require_empty | index("~/.config/cubic/AGENTS.md") != null' "$tpl")" = true ]; then
  ok "the template requires that file to exist and be empty"
else
  ko "the template's cli.require_empty does not name ~/.config/cubic/AGENTS.md"
fi

echo "6. the review runs on cubic's own provider"
has "the provider setting lives in the data directory's preferences.json" 'const filepath = path8.join(Global.Path.data, "preferences.json");'
block_has "the data directory is XDG data's cubic" 'var app = "cubic", data, cache, config, state' 4 'data = path2.join(xdgData, app);'
block_has "a stored preferred provider wins" 'async function preferredProvider() {' 2 'if (data2.preferredProvider)'
block_has "with none stored, cubic is the default only for a cbk_ key" 'async function preferredProvider() {' 5 'if (process.env.CUBIC_API_KEY?.trim().startsWith("cbk_"))'
block_has "a preferred cubic is used whenever its auth is available" 'function resolveAvailableProvider(preferredProvider, availability) {' 4 'return "cubic";'
block_has "the environment's key is cubic's auth" 'async function getCliAuth() {' 2 'const fromEnv = apiKeyAuth();'
block_has "a key without the cbk_ prefix is ignored" 'function apiKeyAuth() {' 5 'if (!key.startsWith(Auth.API_KEY_PREFIX)) {'
has "the prefix is cbk_" 'Auth.API_KEY_PREFIX = "cbk_";'
if jq -e '.reviewers.cubic.cli | (.require_json["~/.local/share/cubic/preferences.json"] == ".preferredProvider == \"cubic\"")
    and (.value_patterns.CUBIC_API_KEY == "^cbk_")' "$tpl" >/dev/null; then
  ok "the template requires cubic as the preferred provider and a cbk_ key"
else
  ko "the template no longer requires cubic as the provider and a cbk_ key"
fi

echo "7. a wellknown login's remote config cannot undo the lockdown"
block_has "a wellknown login's remote config is merged after CUBIC_CONFIG_CONTENT" \
  'result = D2(result, JSON.parse(Flag.CUBIC_CONFIG_CONTENT));' 3 'if (value.type === "wellknown") {'
block_has "that remote config is fetched and merged" 'if (value.type === "wellknown") {' 4 \
  'result = D2(result, await load(JSON.stringify(wellknown.config ?? {}), process.cwd()));'
has "a configured agent's permission overrides the global one" 'item.permission = mergeAgentPermissions(cfg.permission ?? {}, permission ?? {});'
has "logins live in the data directory's auth.json" 'const filepath = path7.join(Global.Path.data, "auth.json");'
pred="$(jq -r '.reviewers.cubic.cli.require_json_if_present["~/.local/share/cubic/auth.json"] // empty' "$tpl")"
if [ -n "$pred" ] \
  && jq -e "$pred" <<<'{"cubic":{"type":"api","key":"x"}}' >/dev/null \
  && ! jq -e "$pred" <<<'{"https://example.invalid":{"type":"wellknown","key":"K","token":"t"}}' >/dev/null; then
  ok "the template refuses an auth.json holding a wellknown login and accepts one without"
else
  ko "the template's require_json_if_present does not refuse wellknown logins in auth.json"
fi

echo "8. global agents, tools and plugins cannot undo the lockdown"
block_has "the global config directory is scanned for agents, modes and plugins" 'const directories2 = [' 2 'Global.Path.config,'
if [ "$(jq -c '.reviewers.cubic.cli.require_only["~/.config/cubic"]' "$tpl")" = '["AGENTS.md"]' ]; then
  ok "the template lets ~/.config/cubic hold only AGENTS.md"
else
  ko "the template's require_only no longer limits ~/.config/cubic to AGENTS.md"
fi
if jq -e '.reviewers.cubic.cli.env_allow_refuse | (index("CUBIC_*") != null) and (index("XDG_CONFIG_HOME") != null) and (index("XDG_DATA_HOME") != null)' "$tpl" >/dev/null; then
  ok "the template refuses CUBIC_ switches and relocated config and data homes in env_allow"
else
  ko "the template's env_allow_refuse no longer covers CUBIC_*, XDG_CONFIG_HOME and XDG_DATA_HOME"
fi

echo
echo "cubic-lockdown-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
