#!/usr/bin/env bash
# Proves, by reading the cubic CLI package's install scripts rather than
# running them, that the git-ai installer its postinstall can pipe to bash is
# unreachable under the opt-out the environments role sets up: the flag file
# it writes, and the variables on its install task.
#
# The package is fetched from the npm registry at the version the tracked mise
# config pins and checked against the integrity reviewed below, so a version
# bump fails here until someone re-reads the new install scripts and license
# and updates reviewed_version, reviewed_integrity and reviewed_license. Needs
# network; offline it fails rather than passing unchecked.
set -uo pipefail

reviewed_version="1.14.2"
reviewed_license="UNLICENSED"
reviewed_integrity="sha512-it0WRlLhD5pEWRVek6zyuGKtxKisJXsWZNqxJYPn5hrWmZwcvsdBRlUYQTiN8ti4tAnijEPlPl3Tyuenkzlm5g=="

repo="$(cd -- "$(dirname -- "$0")/.." && pwd -P)"
pins="$repo/roles/environments/files/mise.toml"
tasks="$repo/roles/environments/tasks/main.yml"
defaults="$repo/roles/environments/defaults/main.yml"

pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }
die() { echo "cubic-postinstall-optout-test: $1"; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "1. the pinned version is the reviewed one"
pinned="$(sed -n 's/^"npm:@cubic-dev-ai\/cli" = "\([^"]*\)"$/\1/p' "$pins")"
[ -n "$pinned" ] || die "no npm:@cubic-dev-ai/cli pin in $pins"
if [ "$pinned" = "$reviewed_version" ]; then
  ok "mise pins $pinned"
else
  ko "mise pins $pinned but the postinstall was reviewed at $reviewed_version; read the new one and update this test"
fi

echo "2. the fetched tarball is the reviewed one"
curl -fsSL --connect-timeout 10 --max-time 60 -o "$work/pkg.tgz" \
  "https://registry.npmjs.org/@cubic-dev-ai/cli/-/cli-$reviewed_version.tgz" \
  || die "could not fetch the package tarball (offline?); nothing was checked"
got="sha512-$(openssl dgst -sha512 -binary "$work/pkg.tgz" | openssl base64 -A)"
if [ "$got" = "$reviewed_integrity" ]; then ok "integrity matches"; else ko "integrity $got is not the reviewed $reviewed_integrity"; fi
tar -xzf "$work/pkg.tgz" -C "$work" package/postinstall.mjs package/preinstall.mjs package/package.json \
  || die "the tarball has no package/postinstall.mjs, preinstall.mjs or package.json"
js="$work/package/postinstall.mjs"

# body_of <function name>: the function's lines, from its declaration to the
# closing brace at column 0.
body_of() {
  awk -v fn="$1" '
    $0 ~ "^(async )?function " fn "\\(" { on = 1; print; next }
    on { print }
    on && /^}/ { exit }' "$js"
}

if [ "$(jq -r '.license' "$work/package/package.json")" = "$reviewed_license" ]; then
  ok "license is the reviewed $reviewed_license"
else
  ko "license changed to $(jq -r '.license' "$work/package/package.json"); confirm the terms and update reviewed_license"
fi

echo "3. the installer sits behind the opt-out check"
scripts_json="$(jq -c '.scripts' "$work/package/package.json")"
if [ "$scripts_json" = '{"preinstall":"bun ./preinstall.mjs || node ./preinstall.mjs","postinstall":"bun ./postinstall.mjs || node ./postinstall.mjs"}' ]; then
  ok "preinstall.mjs and postinstall.mjs are the only install scripts"
else
  ko "package.json's install scripts changed: $scripts_json"
fi
if grep -qE 'child_process|spawn|exec|fetch|https?:|require\(' "$work/package/preinstall.mjs"; then
  ko "preinstall.mjs now runs or fetches something; read it"
else
  ok "preinstall.mjs runs and fetches nothing"
fi
installer_lines="$(grep -n 'git-ai-project/git-ai/releases/download' "$js" | cut -d: -f1)"
[ -n "$installer_lines" ] || ko "no installer URL found; the script changed shape"
setup_start="$(grep -n '^function setupGitAi()' "$js" | cut -d: -f1)"
setup_len="$(body_of setupGitAi | wc -l | tr -d ' ')"
[ -n "$setup_start" ] || die "no setupGitAi function; the script changed shape"
for n in $installer_lines; do
  if [ "$n" -gt "$setup_start" ] && [ "$n" -lt $((setup_start + setup_len)) ]; then
    ok "installer at line $n is inside setupGitAi"
  else
    ko "installer at line $n is outside setupGitAi"
  fi
done
first_statement="$(body_of setupGitAi | sed -n '2,4p' | tr -s '[:space:]' ' ')"
if [ "$first_statement" = " if (gitAiOptedOut()) { return } " ]; then
  ok "setupGitAi returns first thing when opted out"
else
  ko "setupGitAi no longer opens with the opt-out return: $first_statement"
fi
for helper in runGitAi applyGitAiConfig; do
  grep -qE "^(async )?function $helper\\(" "$js" || { ko "$helper no longer exists; read the new postinstall"; continue; }
  # A call outside any function body is attributed to "top level".
  callers="$(awk -v h="$helper" '
    /^(async )?function [A-Za-z]+\(/ { match($0, /function [A-Za-z]+/); cur = substr($0, RSTART + 9, RLENGTH - 9) }
    /^}/ { cur = "top-level"; next }
    index($0, h "(") && $0 !~ "^(async )?function " h "\\(" { print (cur == "" ? "top-level" : cur) }' "$js" | sort -u | tr '\n' ' ')"
  case "$callers" in
    'setupGitAi ' | 'applyGitAiConfig ' | 'applyGitAiConfig setupGitAi ') ok "$helper is reached only through setupGitAi" ;;
    *) ko "$helper is called from: ${callers:-nowhere}" ;;
  esac
done
setup_mentions="$(grep -c 'setupGitAi()' "$js")"
if [ "$setup_mentions" = 2 ]; then
  ok "setupGitAi is declared once and called once"
else
  ko "setupGitAi() appears $setup_mentions times; expected one declaration and one call"
fi
wizard="$(body_of shouldRunInstallWizard | sed -n '2p' | tr -s '[:space:]' ' ')"
if [ "$wizard" = ' if (process.env.CUBIC_DISABLE_INSTALL_WIZARD === "true") return false ' ]; then
  ok "CUBIC_DISABLE_INSTALL_WIZARD=true skips the install-time setup wizard first thing"
else
  ko "the install wizard's opt-out changed: $wizard"
fi

echo "4. the opt-out condition matches what the role sets"
optout_env="$(body_of gitAiOptOutEnv | tr -s '[:space:]' ' ')"
case "$optout_env" in
  *'(process.env.CUBIC_DISABLE_GIT_AI || "").toLowerCase()'*'return value === "true" || value === "1"'*)
    ok "CUBIC_DISABLE_GIT_AI=true opts out" ;;
  *) ko "the variable's condition changed: $optout_env" ;;
esac
flag="$(body_of gitAiDisabledFlag | tr -s '[:space:]' ' ')"
case "$flag" in
  *'process.env.XDG_STATE_HOME || path.join(os.homedir(), ".local", "state")'*'path.join(state, "cubic", "git-ai-disabled")'*)
    ok "the flag file is \$XDG_STATE_HOME/cubic/git-ai-disabled, default ~/.local/state" ;;
  *) ko "the flag file's location changed: $flag" ;;
esac
opted="$(body_of gitAiOptedOut | tr -s '[:space:]' ' ')"
case "$opted" in
  *'return gitAiOptOutEnv() || fs.existsSync(gitAiDisabledFlag())'*) ok "either one opts out" ;;
  *) ko "the opt-out combination changed: $opted" ;;
esac
install_task="$(awk '/^- name: Install default tool versions$/ { on = 1; print; next } on && /^- name: / { exit } on { print }' "$tasks")"
if grep -qF 'dest: "{{ environments_xdg_state_home }}/cubic/git-ai-disabled"' "$tasks"; then
  ok "the environments role writes that flag file"
else
  ko "the environments role no longer writes the flag file"
fi
if grep -qF "{{ ansible_facts.env.XDG_STATE_HOME | default(ansible_facts.env.HOME ~ '/.local/state', true) }}" "$defaults"; then
  ok "the role's state directory is \$XDG_STATE_HOME, default ~/.local/state, as the postinstall's"
else
  ko "environments_xdg_state_home no longer matches the postinstall's state directory"
fi
for v in CUBIC_DISABLE_GIT_AI CUBIC_DISABLE_INSTALL_WIZARD; do
  if grep -qF "$v: \"true\"" <<<"$install_task"; then
    ok "the install task sets $v"
  else
    ko "the install task no longer sets $v"
  fi
done
link_line="$(grep -n '^- name: Link the mise global config' "$tasks" | cut -d: -f1)"
flag_line="$(grep -n '^- name: Opt out of the cubic CLI' "$tasks" | cut -d: -f1)"
if [ -n "$flag_line" ] && [ -n "$link_line" ] && [ "$flag_line" -lt "$link_line" ]; then
  ok "the flag file is written before the config link declares the pin"
else
  ko "the flag file task must come before the mise config link"
fi

echo
echo "cubic-postinstall-optout-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
