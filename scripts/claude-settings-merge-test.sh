#!/usr/bin/env bash
# Fixture suite for claude-settings-merge.sh. The case that matters is
# foreign-hook survival: the old `jq -s '.[0] * .[1]'` replaced hook arrays,
# so any event this repo declared wiped hooks another tool had installed.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
merge="$here/claude-settings-merge.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

run() { # run <live-json> <managed-json> -> writes $work/live.json, echoes status
    printf '%s\n' "$1" >"$work/live.json"
    printf '%s\n' "$2" >"$work/managed.json"
    "$merge" "$work/live.json" "$work/managed.json"
}

FOREIGN='{"hooks":{"PreToolUse":[{"matcher":"","hooks":[{"type":"command","command":"/opt/vendor/agent hook"}]}]}}'
MINE='{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$HOME/.claude/scripts/path-guard.sh"}]}]}}'

# 1. a foreign hook on a declared event survives
run "$FOREIGN" "$MINE" >/dev/null
n=$(jq '[.hooks.PreToolUse[].hooks[].command] | length' "$work/live.json")
if [ "$n" = 2 ] && jq -e '[.hooks.PreToolUse[].hooks[].command] | index("/opt/vendor/agent hook")' "$work/live.json" >/dev/null; then
    ok foreign-survives "both the vendor hook and ours are present"
else
    fail foreign-survives "expected 2 commands including the vendor one, got $n"
fi

# 2. an empty declared array removes ours and keeps theirs
BOTH=$(cat "$work/live.json")
run "$BOTH" '{"hooks":{"PreToolUse":[]}}' >/dev/null
if [ "$(jq -c '[.hooks.PreToolUse[].hooks[].command]' "$work/live.json")" = '["/opt/vendor/agent hook"]' ]; then
    ok empty-removes-only-ours "[] dropped ours, kept the vendor hook"
else
    fail empty-removes-only-ours "got $(jq -c '[.hooks.PreToolUse[].hooks[].command]' "$work/live.json")"
fi

# 3. a foreign hook sharing a matcher group with ours survives, only the
#    owned entry is stripped from that group
SHARED_GROUP='{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"$HOME/.claude/scripts/path-guard.sh"},{"type":"command","command":"/opt/vendor/agent hook"}]}]}}'
run "$SHARED_GROUP" "$MINE" >/dev/null
if [ "$(jq -c '[.hooks.PreToolUse[].hooks[].command]' "$work/live.json")" = '["/opt/vendor/agent hook","$HOME/.claude/scripts/path-guard.sh"]' ]; then
    ok shared-group-survives "foreign entry in a shared matcher group is not dropped with ours"
else
    fail shared-group-survives "got $(jq -c '[.hooks.PreToolUse[].hooks[].command]' "$work/live.json")"
fi

# 3b. our own hook recorded with an expanded $HOME is still recognised as ours,
#     rather than kept as foreign and then duplicated by the tracked copy
EXPANDED="{\"hooks\":{\"PreToolUse\":[{\"matcher\":\"Bash\",\"hooks\":[{\"type\":\"command\",\"command\":\"$HOME/.claude/scripts/path-guard.sh\"}]}]}}"
run "$EXPANDED" "$MINE" >/dev/null
if [ "$(jq '[.hooks.PreToolUse[].hooks[].command] | length' "$work/live.json")" = 1 ]; then
    ok expanded-home-owned "an expanded-path copy of our hook is not duplicated"
else
    fail expanded-home-owned "got $(jq -c '[.hooks.PreToolUse[].hooks[].command]' "$work/live.json")"
fi

# 3c. the live file's mode is asserted, not inherited from whatever wrote it
printf '%s\n' '{}' >"$work/live.json"
printf '%s\n' "$MINE" >"$work/managed.json"
chmod 644 "$work/live.json"
"$merge" "$work/live.json" "$work/managed.json" >/dev/null
if [ "$(stat -f '%Lp' "$work/live.json" 2>/dev/null || stat -c '%a' "$work/live.json")" = 600 ]; then
    ok mode-asserted "settings file left at 0600"
else
    fail mode-asserted "mode is $(stat -f '%Lp' "$work/live.json" 2>/dev/null || stat -c '%a' "$work/live.json")"
fi

# 4. an undeclared event is left completely alone
run '{"hooks":{"PostToolUseFailure":[{"matcher":"","hooks":[{"type":"command","command":"/opt/vendor/agent hook"}]}]}}' "$MINE" >/dev/null
if jq -e '.hooks.PostToolUseFailure[0].hooks[0].command == "/opt/vendor/agent hook"' "$work/live.json" >/dev/null; then
    ok undeclared-untouched "PostToolUseFailure survived"
else
    fail undeclared-untouched "undeclared event was modified"
fi

# 5. non-hook keys still merge with `*`, and app-owned keys survive
run '{"theme":"dark","hooks":{}}' '{"outputStyle":"compact","hooks":{}}' >/dev/null
if jq -e '.theme == "dark" and .outputStyle == "compact"' "$work/live.json" >/dev/null; then
    ok scalar-merge "app-owned theme kept, managed outputStyle applied"
else
    fail scalar-merge "scalar merge lost a key"
fi

# 6. idempotent: a second run reports OK and changes nothing
first=$(cat "$work/live.json")
status=$("$merge" "$work/live.json" "$work/managed.json")
if [ "$status" = OK ] && [ "$first" = "$(cat "$work/live.json")" ]; then
    ok idempotent "second run reported OK and rewrote nothing"
else
    fail idempotent "status=$status, file changed=$([ "$first" = "$(cat "$work/live.json")" ] && echo no || echo yes)"
fi

# 7. malformed live JSON refuses rather than clobbering
printf 'not json\n' >"$work/live.json"
if out=$("$merge" "$work/live.json" "$work/managed.json" 2>&1); then
    fail refuses-malformed "exited 0 on malformed live JSON"
else
    case "$out" in *"not valid JSON"*) ok refuses-malformed "refused, naming the fault" ;;
                   *) fail refuses-malformed "wrong message: $out" ;; esac
fi

# 8. malformed tracked JSON refuses rather than clobbering the live file
printf '{"hooks":{}}\n' >"$work/live.json"
printf 'not json\n' >"$work/managed.json"
before=$(cat "$work/live.json")
if out=$("$merge" "$work/live.json" "$work/managed.json" 2>&1); then
    fail refuses-malformed-tracked "exited 0 on malformed tracked JSON"
else
    case "$out" in
        *"not valid JSON"*)
            if [ "$before" = "$(cat "$work/live.json")" ]; then
                ok refuses-malformed-tracked "refused, live file untouched"
            else
                fail refuses-malformed-tracked "refused but live file was modified"
            fi
            ;;
        *) fail refuses-malformed-tracked "wrong message: $out" ;;
    esac
fi

# 9. a missing live file is created
printf '%s\n' "$MINE" >"$work/managed.json"
rm -f "$work/live.json"
if [ "$("$merge" "$work/live.json" "$work/managed.json")" = CHANGED ] && jq -e . "$work/live.json" >/dev/null; then
    ok creates-missing "absent live file was created and populated"
else
    fail creates-missing "did not create the live file"
fi

if [ "$fails" -ne 0 ]; then
    printf 'claude-settings-merge-test: %d assertion(s) failed\n' "$fails"
    exit 1
fi
printf 'claude-settings-merge-test: all assertions hold\n'
