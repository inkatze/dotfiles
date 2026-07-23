#!/usr/bin/env bash
# Test for the repo's custom gitleaks rules (REQ-F1.1 backstop, Task 4 of
# specs/linux-migration). Verifies that .gitleaks.toml:
#   1. flags a NEW RFC1918 LAN IP that stock rulesets ignore,
#   2. flags a NEW internal (.local/.lan/.home/.internal/.corp) hostname,
#   3. passes clean content (loopback + public IP + ordinary prose),
#   4. does NOT flag the repo's known-intentional allowlisted values
#      (the documented Ollama work-host reservation and the existing
#      macOS hostnames).
#
# Not wired into CI/lefthook (those run the scanner itself, not this test);
# run manually: `scripts/gitleaks-rules-test.sh`. Exit 0 = all assertions
# pass.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
config="$repo_root/.gitleaks.toml"

if [[ ! -f "$config" ]]; then
    echo "FAIL: $config does not exist" >&2
    exit 1
fi

if ! command -v gitleaks >/dev/null 2>&1; then
    echo "FAIL: gitleaks not on PATH (pin it via mise.toml)" >&2
    exit 1
fi

fails=0
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# scan_dir <dir> -> prints matched rule IDs, returns gitleaks exit code
scan_dir() {
    local dir="$1" report
    report="$workdir/report.json"
    local rc=0
    gitleaks dir "$dir" --config "$config" --no-banner \
        --report-format json --report-path "$report" >/dev/null 2>&1 || rc=$?
    if [[ -s "$report" ]]; then
        grep -o '"RuleID": *"[^"]*"' "$report" | sed 's/.*"\([^"]*\)"$/\1/' | sort -u
    fi
    return "$rc"
}

assert_flags_rule() {
    local name="$1" dir="$2" rule="$3" rules rc
    rc=0
    rules=$(scan_dir "$dir") || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "FAIL[$name]: expected a leak but gitleaks exited 0" >&2
        fails=$((fails + 1))
        return
    fi
    if ! grep -qx "$rule" <<<"$rules"; then
        echo "FAIL[$name]: expected rule '$rule' to fire; fired: ${rules//$'\n'/, }" >&2
        fails=$((fails + 1))
        return
    fi
    echo "ok[$name]: rule '$rule' fired"
}

assert_clean() {
    local name="$1" dir="$2" rc rules
    rc=0
    rules=$(scan_dir "$dir") || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        echo "FAIL[$name]: expected clean but rules fired: ${rules//$'\n'/, }" >&2
        fails=$((fails + 1))
        return
    fi
    echo "ok[$name]: clean, no findings"
}

# 1. New LAN IP (RFC1918) that stock rules ignore.
d="$workdir/lan-ip"; mkdir -p "$d"
printf 'server reachable at 192.168.77.13 on the LAN\n' >"$d/notes.md" # gitleaks:allow
assert_flags_rule "lan-ip" "$d" "lan-ip-rfc1918"

# 2. New internal hostname.
d="$workdir/hostname"; mkdir -p "$d"
printf 'ssh into mediabox.local to unlock\n' >"$d/notes.md" # gitleaks:allow
assert_flags_rule "internal-hostname" "$d" "internal-hostname"

# 3. Clean content: loopback and a public IP are not private LAN IPs.
d="$workdir/clean"; mkdir -p "$d"
printf 'ansible_host=127.0.0.1 ansible_connection=local\nDNS 8.8.8.8 is public.\n' >"$d/notes.md"
assert_clean "clean" "$d"

# 4. Allowlisted known-intentional repo values must not fire.
d="$workdir/allowlist"; mkdir -p "$d"
printf 'Ollama work host reservation 192.168.1.20\nhosts crojtini and panela\n' >"$d/notes.md"
assert_clean "allowlist" "$d"

if [[ "$fails" -ne 0 ]]; then
    echo "gitleaks-rules-test: $fails assertion(s) failed" >&2
    exit 1
fi
echo "gitleaks-rules-test: all assertions passed"
