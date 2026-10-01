#!/usr/bin/env bash
# Asserts the planwright fish plumbing: the conf.d snippet exports both state
# paths under $HOME, and the `tower` function launches only when a planwright
# root with its tower profile resolves.
#
# Fail-closed is the property worth pinning. A tower started without
# --settings still runs, just without the profile's deny floor, and nothing
# about that session would look wrong.
#
# Runs fish with --no-config against a scratch HOME and a stub `claude` on
# PATH, so it touches neither the real plugin cache nor a real session.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
repo="$(cd -- "$here/.." && pwd -P)"
snippet="$repo/roles/fish/files/planwright.fish"
fn="$repo/roles/fish/files/fish/functions/tower.fish"
fails=0

if ! command -v fish >/dev/null 2>&1; then
    echo "fish-tower-test: fish not on PATH" >&2
    exit 2
fi

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

mkdir -p "$scratch/bin"
# Records what it was handed, one field per line, so an assertion can tell
# `--settings X` from `--settings` `X` and see the exported root.
cat >"$scratch/bin/claude" <<'STUB'
#!/usr/bin/env bash
{
    printf 'CLAUDE_PLUGIN_ROOT=%s\n' "${CLAUDE_PLUGIN_ROOT-<unset>}"
    printf 'arg=%s\n' "$@"
} >"$STUB_LOG"
STUB
chmod +x "$scratch/bin/claude"

pass() { echo "ok[$1]: $2"; }
fail() { echo "FAIL[$1]: $2" >&2; fails=$((fails + 1)); }

# Runs `tower` under a fresh HOME. Leaves the stub's log at $home/log and the
# function's stderr at $home/err; prints the exit status.
run_tower() {
    local home="$1"
    shift
    HOME="$home" PATH="$scratch/bin:$PATH" STUB_LOG="$home/log" CLAUDE_PLUGIN_ROOT='' \
        fish --no-config -c "source '$fn'; tower \$argv" -- "$@" 2>"$home/err"
    echo $?
}

new_home() {
    local h="$scratch/home-$1"
    mkdir -p "$h"
    echo "$h"
}

add_version() {
    local d="$1/.claude/plugins/cache/planwright/planwright/$2"
    mkdir -p "$d/config"
    if [ "${3:-with-settings}" = with-settings ]; then
        echo '{}' >"$d/config/tower-settings.json"
    fi
}

# --- conf.d snippet ---------------------------------------------------------

h="$(new_home env)"
out="$(HOME="$h" fish --no-config -c "source '$snippet'; fish -c 'printf \"%s\n\" \$PLANWRIGHT_ADOPTER_OVERLAY \$PLANWRIGHT_FLEET_STATE_DIR'")"
want="$h/.claude/plugins/data/planwright-planwright/overlay
$h/.claude/plugins/data/planwright-planwright/fleet"
if [ "$out" = "$want" ]; then
    pass env "both paths exported under \$HOME and inherited by a child"
else
    fail env "expected:
$want
got:
$out"
fi

# A literal home path would publish a username and break every other host.
if grep -q '/home/\|/Users/' "$snippet" "$fn"; then
    fail no-literal-home "a literal home path appears in the snippet or the function"
else
    pass no-literal-home "paths are built from \$HOME"
fi

# --- tower: fail closed -----------------------------------------------------

h="$(new_home none)"
rc="$(run_tower "$h")"
# Exactly one line, the function's own: fish's unmatched-wildcard error would
# otherwise bury the refusal under a stack trace.
if [ "$rc" != 0 ] && [ ! -e "$h/log" ] && [ "$(wc -l <"$h/err")" -eq 1 ] && grep -q '^tower:' "$h/err"; then
    pass no-root "refuses with one clear line, claude not started"
else
    fail no-root "rc=$rc, claude started: $([ -e "$h/log" ] && echo yes || echo no), stderr: $(cat "$h/err")"
fi

h="$(new_home nosettings)"
add_version "$h" 0.49.0 without-settings
rc="$(run_tower "$h")"
if [ "$rc" != 0 ] && [ ! -e "$h/log" ] && grep -q 'tower-settings.json' "$h/err"; then
    pass no-settings "refuses when the newest root has no tower profile"
else
    fail no-settings "rc=$rc, claude started: $([ -e "$h/log" ] && echo yes || echo no), stderr: $(cat "$h/err")"
fi

# An older root that still has a profile must not be borrowed: mixing versions
# would pair one release's deny floor with another's guard and skill.
h="$(new_home newest-lacks)"
add_version "$h" 0.48.0
add_version "$h" 0.49.0 without-settings
rc="$(run_tower "$h")"
if [ "$rc" != 0 ] && [ ! -e "$h/log" ]; then
    pass no-fallback "does not fall back to an older root's profile"
else
    fail no-fallback "rc=$rc, launched against an older root"
fi

# --- tower: launch ----------------------------------------------------------

h="$(new_home launch)"
add_version "$h" 0.9.0
add_version "$h" 0.10.0
add_version "$h" 0.49.0
rc="$(run_tower "$h" --model opus "two words")"
root="$h/.claude/plugins/cache/planwright/planwright/0.49.0"
want="CLAUDE_PLUGIN_ROOT=$root
arg=--settings
arg=$root/config/tower-settings.json
arg=/planwright:tower
arg=--model
arg=opus
arg=two words"
if [ "$rc" = 0 ] && [ "$(cat "$h/log" 2>/dev/null)" = "$want" ]; then
    pass launch "newest root by version order, root exported, args passed through intact"
else
    fail launch "rc=$rc, expected:
$want
got:
$(cat "$h/log" 2>/dev/null)
stderr: $(cat "$h/err")"
fi

# Version order, not lexical: 0.10.0 sorts before 0.9.0 as a string.
h="$(new_home semver)"
add_version "$h" 0.9.0
add_version "$h" 0.10.0
rc="$(run_tower "$h")"
if [ "$rc" = 0 ] && grep -qx "CLAUDE_PLUGIN_ROOT=$h/.claude/plugins/cache/planwright/planwright/0.10.0" "$h/log"; then
    pass version-order "0.10.0 wins over 0.9.0"
else
    fail version-order "rc=$rc, log: $(cat "$h/log" 2>/dev/null)"
fi

# Only version-named directories are installs: a stray copy sorts after every
# version under -V and would otherwise pair a stale profile with the session.
h="$(new_home stray)"
add_version "$h" 0.49.0
add_version "$h" old-backup
add_version "$h" 0.49.0.bak
rc="$(run_tower "$h")"
if [ "$rc" = 0 ] && grep -qx "CLAUDE_PLUGIN_ROOT=$h/.claude/plugins/cache/planwright/planwright/0.49.0" "$h/log"; then
    pass stray-dirs "non-version directories are ignored"
else
    fail stray-dirs "rc=$rc, log: $(cat "$h/log" 2>/dev/null)"
fi

# Claude Code marks a superseded or un-pinned version .orphaned_at and keeps
# it on disk, so newest-on-disk is not what it loads after a downgrade.
h="$(new_home orphaned)"
add_version "$h" 0.48.0
add_version "$h" 0.49.0
touch "$h/.claude/plugins/cache/planwright/planwright/0.49.0/.orphaned_at"
rc="$(run_tower "$h")"
if [ "$rc" = 0 ] && grep -qx "CLAUDE_PLUGIN_ROOT=$h/.claude/plugins/cache/planwright/planwright/0.48.0" "$h/log"; then
    pass orphaned "an orphaned version is skipped"
else
    fail orphaned "rc=$rc, log: $(cat "$h/log" 2>/dev/null)"
fi

h="$(new_home all-orphaned)"
add_version "$h" 0.49.0
touch "$h/.claude/plugins/cache/planwright/planwright/0.49.0/.orphaned_at"
rc="$(run_tower "$h")"
if [ "$rc" != 0 ] && [ ! -e "$h/log" ]; then
    pass all-orphaned "refuses when every version is orphaned"
else
    fail all-orphaned "rc=$rc, launched against an orphaned root"
fi

# A trailing slash flips -V's order here: `0.10.0/` sorts after `0.10.0.1/`.
h="$(new_home slash-order)"
add_version "$h" 0.10.0
add_version "$h" 0.10.0.1
rc="$(run_tower "$h")"
if [ "$rc" = 0 ] && grep -qx "CLAUDE_PLUGIN_ROOT=$h/.claude/plugins/cache/planwright/planwright/0.10.0.1" "$h/log"; then
    pass slash-order "ordered on the bare version, not the globbed path"
else
    fail slash-order "rc=$rc, log: $(cat "$h/log" 2>/dev/null)"
fi

# The root is scoped to the launched process, never left in the caller's shell.
h="$(new_home scoped)"
add_version "$h" 0.49.0
leak="$(HOME="$h" PATH="$scratch/bin:$PATH" STUB_LOG="$h/log" CLAUDE_PLUGIN_ROOT='' \
    fish --no-config -c "source '$fn'; tower; printf '%s' \"\$CLAUDE_PLUGIN_ROOT\"")"
if [ -z "$leak" ]; then
    pass scoped "CLAUDE_PLUGIN_ROOT does not outlive the launch"
else
    fail scoped "caller's shell kept CLAUDE_PLUGIN_ROOT=$leak"
fi

# In a real shell `claude` is the repo's wrapper function, and a function gets
# a fresh scope: the root must still reach the binary behind it.
h="$(new_home wrapper)"
add_version "$h" 0.49.0
HOME="$h" PATH="$scratch/bin:$PATH" STUB_LOG="$h/log" CLAUDE_PLUGIN_ROOT='' \
    fish --no-config -c "source '$repo/roles/fish/files/fish/functions/claude.fish'; source '$fn'; tower" 2>/dev/null
if grep -qx "CLAUDE_PLUGIN_ROOT=$h/.claude/plugins/cache/planwright/planwright/0.49.0" "$h/log" 2>/dev/null; then
    pass wrapper "root reaches claude through the wrapper function"
else
    fail wrapper "log: $(cat "$h/log" 2>/dev/null)"
fi

# Passed-through flags that would replace or disable the profile. claude keeps
# the last --settings it is given, so `tower --settings '{}'` alone would start
# a tower with no deny floor.
h="$(new_home override)"
add_version "$h" 0.49.0
for flag in --settings --settings={} --dangerously-skip-permissions \
    --allow-dangerously-skip-permissions --permission-mode \
    --permission-mode=bypassPermissions --permission-prompt-tool --bare; do
    rm -f "$h/log"
    rc="$(run_tower "$h" --model opus "$flag" x)"
    if [ "$rc" != 0 ] && [ ! -e "$h/log" ] && grep -q '^tower:' "$h/err"; then
        pass "refuse $flag" "refused, claude not started"
    else
        fail "refuse $flag" "rc=$rc, claude started: $([ -e "$h/log" ] && echo yes || echo no)"
    fi
done

# claude's own exit status is the function's.
cat >"$scratch/bin/claude" <<'STUB'
#!/usr/bin/env bash
exit 7
STUB
h="$(new_home status)"
add_version "$h" 0.49.0
rc="$(run_tower "$h")"
if [ "$rc" = 7 ]; then
    pass status "claude's exit status is returned"
else
    fail status "rc=$rc, expected 7"
fi

if [ "$fails" -eq 0 ]; then
    echo "fish-tower-test: all assertions hold"
else
    echo "fish-tower-test: $fails assertion(s) failed"
    exit 1
fi
