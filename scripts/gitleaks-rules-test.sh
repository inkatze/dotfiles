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
# Extended by specs/dev-services Task 1 (D-8, D-9) for the private
# project identifier rules, which are the same class of rule and so extend
# this harness rather than starting a parallel one:
#   5-7. the generator refuses visibly for an absent, an empty, and an
#        unparseable source file (REQ-D1.4),
#   8.   its output is independent of the source file's order and case
#        (REQ-D1.5),
#   9.   a NEW occurrence of an identifier is flagged (REQ-D1.2),
#   10.  a pre-existing tracked occurrence is allowlisted by path (REQ-D1.3),
#   11.  --write converges, preserves the config's other rules, and --check
#        rejects a hand edit inside the generated block (REQ-D1.5),
#   12.  the generated config is one gitleaks can actually load,
#   13.  --help prints the header block and no code,
#   14.  the block committed in .gitleaks.toml matches a fresh generation
#        (REQ-D1.5) — skipped, visibly, on a machine with no source file.
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

# scan_dir <dir> [config] -> prints matched rule IDs, returns gitleaks exit
# code. The config defaults to the repo's own; the identifier cases below
# pass a generated one built from a fixture set.
scan_dir() {
    local dir="$1" cfg="${2:-$config}" report
    report="$workdir/report.json"
    local rc=0
    gitleaks dir "$dir" --config "$cfg" --no-banner \
        --report-format json --report-path "$report" >/dev/null 2>&1 || rc=$?
    if [[ -s "$report" ]]; then
        grep -o '"RuleID": *"[^"]*"' "$report" | sed 's/.*"\([^"]*\)"$/\1/' | sort -u
    fi
    return "$rc"
}

assert_flags_rule() {
    local name="$1" dir="$2" rule="$3" cfg="${4:-$config}" rules rc
    rc=0
    rules=$(scan_dir "$dir" "$cfg") || rc=$?
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
    local name="$1" dir="$2" cfg="${3:-$config}" rc rules
    rc=0
    rules=$(scan_dir "$dir" "$cfg") || rc=$?
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

# ---------------------------------------------------------------------------
# Private project identifier rules (specs/dev-services Task 1, D-8 and D-9).
# The fixture identifier below is a stand-in: these cases exercise the
# mechanism, so they need no real identifier and this file names none.
# ---------------------------------------------------------------------------

gen="$repo_root/scripts/gitleaks-identifier-rules.sh"

if [[ ! -x "$gen" ]]; then
    echo "FAIL: $gen is missing or not executable" >&2
    exit 1
fi

# gen_refuses <name> <source-path> <fault-substring>
gen_refuses() {
    local name="$1" src="$2" fault="$3" out rc
    rc=0
    out=$("$gen" --source "$src" --stdout 2>&1) || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "FAIL[$name]: generator exited 0; expected a visible refusal" >&2
        fails=$((fails + 1))
        return
    fi
    if ! grep -qi -- "$fault" <<<"$out"; then
        echo "FAIL[$name]: refusal did not name the fault ('$fault'); got: ${out//$'\n'/ }" >&2
        fails=$((fails + 1))
        return
    fi
    echo "ok[$name]: refused with exit $rc, naming the fault"
}

# 5-7. REQ-D1.4: each degraded source refuses rather than emitting a narrower
# rule set. Enumerated separately because an absence check alone passes the
# other two.
gen_refuses "gen-absent" "$workdir/no-such-file" "absent"

printf '# only a comment\n\n' >"$workdir/empty-src"
gen_refuses "gen-empty" "$workdir/empty-src" "no identifiers"

printf 'validname\nnot a valid identifier!\n' >"$workdir/bad-src"
gen_refuses "gen-unparseable" "$workdir/bad-src" "unparseable"

# 8. REQ-D1.5: the byte-for-byte check below is only meaningful if output does
# not depend on incidental input order or case.
printf 'beta\nAlpha\n' >"$workdir/order-a"
printf 'alpha\nbeta\nALPHA\n' >"$workdir/order-b"
if diff -q <("$gen" --source "$workdir/order-a" --stdout) \
    <("$gen" --source "$workdir/order-b" --stdout) >/dev/null 2>&1; then
    echo "ok[gen-deterministic]: same set in two orders produced identical output"
else
    echo "FAIL[gen-deterministic]: output depended on source order or case" >&2
    fails=$((fails + 1))
fi

# 9-10. REQ-D1.2 / REQ-D1.3, both directions of Task 1's Done-when. Run in
# `--staged` mode against a fixture repo, which is the mode lefthook actually
# runs the hook in: rule-level `paths` allowlists are matched against
# repo-relative paths, so a directory scan by absolute path would not
# represent the guard as the hook sees it.
fix="$workdir/fixture"
mkdir -p "$fix/docs" "$fix/src"
git init -q -b main "$fix"
printf 'legacy note mentioning acmeproj throughout\n' >"$fix/docs/legacy.md"
git -C "$fix" add -A
git -C "$fix" -c user.email=test@example.invalid -c user.name=test \
    commit -qm "fixture"

printf 'acmeproj\n' >"$workdir/fixture-src"
{
    printf 'title = "fixture"\n'
    "$gen" --source "$workdir/fixture-src" --repo-root "$fix" --stdout
} >"$workdir/fixture.toml"

# scan_staged <repo> <config> -> prints matched rule IDs, returns exit code
scan_staged() {
    local repo="$1" cfg="$2" report="$workdir/staged.json" rc=0
    rm -f "$report"
    (
        cd "$repo" && gitleaks git --staged --no-banner --config "$cfg" \
            --report-format json --report-path "$report" >/dev/null 2>&1
    ) || rc=$?
    if [[ -s "$report" ]]; then
        grep -o '"RuleID": *"[^"]*"' "$report" | sed 's/.*"\([^"]*\)"$/\1/' | sort -u
    fi
    return "$rc"
}

# Positive: a staged commit introducing an identifier at a new path fails.
printf 'new file naming acmeproj\n' >"$fix/src/new.md"
git -C "$fix" add -A
rc=0
rules=$(scan_staged "$fix" "$workdir/fixture.toml") || rc=$?
if [[ "$rc" -eq 0 ]]; then
    echo "FAIL[identifier-new-occurrence]: staged identifier passed the hook" >&2
    fails=$((fails + 1))
elif ! grep -qx "private-project-identifier" <<<"$rules"; then
    echo "FAIL[identifier-new-occurrence]: wrong rule fired: ${rules//$'\n'/, }" >&2
    fails=$((fails + 1))
else
    echo "ok[identifier-new-occurrence]: staged new occurrence was blocked"
fi

# Negative: a staged edit to an already-tracked file naming an identifier
# passes, so the guard does not become an obstacle that invites disabling.
git -C "$fix" rm -q --cached src/new.md
rm -f "$fix/src/new.md"
printf 'another mention of acmeproj added later\n' >>"$fix/docs/legacy.md"
git -C "$fix" add -A
rc=0
rules=$(scan_staged "$fix" "$workdir/fixture.toml") || rc=$?
if [[ "$rc" -ne 0 ]]; then
    echo "FAIL[identifier-allowlisted-path]: staged edit to an allowlisted path" \
        "was blocked; fired: ${rules//$'\n'/, }" >&2
    fails=$((fails + 1))
else
    echo "ok[identifier-allowlisted-path]: staged edit to a tracked path passed"
fi

# 11. REQ-D1.5: the --write/--check round trip, against a throwaway copy of
# the real config so it runs on every machine rather than only one holding
# the real source file. Case 12 asserts the committed block specifically;
# this asserts the mechanism that keeps it current.
rt="$workdir/roundtrip"
mkdir -p "$rt/docs"
git init -q -b main "$rt"
cp "$config" "$rt/.gitleaks.toml"
printf 'legacy mentioning acmeproj\n' >"$rt/docs/legacy.md"
git -C "$rt" add -A
git -C "$rt" -c user.email=test@example.invalid -c user.name=test \
    commit -qm "roundtrip"

rt_gen() { "$gen" --source "$workdir/fixture-src" --repo-root "$rt" "$@"; }

rt_ok=1
rt_gen --write >/dev/null 2>&1 || rt_ok=0
rt_gen --check >/dev/null 2>&1 || rt_ok=0
if [[ "$rt_ok" -eq 0 ]]; then
    echo "FAIL[gen-roundtrip]: --write followed by --check did not converge" >&2
    fails=$((fails + 1))
elif ! grep -q 'lan-ip-rfc1918' "$rt/.gitleaks.toml"; then
    echo "FAIL[gen-roundtrip]: the splice dropped a pre-existing rule" >&2
    fails=$((fails + 1))
else
    echo "ok[gen-roundtrip]: --write converges and preserves pre-existing rules"
fi

# A hand edit inside the generated block is the drift REQ-D1.5 exists to catch.
sed -i.bak 's/private-project-identifier/private-project-identifierX/' \
    "$rt/.gitleaks.toml"
if rt_gen --check >/dev/null 2>&1; then
    echo "FAIL[gen-detects-hand-edit]: --check passed a hand-edited block" >&2
    fails=$((fails + 1))
else
    echo "ok[gen-detects-hand-edit]: --check rejected a hand-edited block"
fi

# 12. A generated block must be loadable by the scanner, not merely stable.
# --check compares the config against a regeneration of itself, so it would
# certify a block gitleaks cannot parse; the hook would then fail open-ended
# for everyone on the next commit.
rt_gen --write >/dev/null 2>&1
if (cd "$rt" && gitleaks git --staged --no-banner \
    --config "$rt/.gitleaks.toml" >/dev/null 2>&1); then
    echo "ok[gen-config-loads]: gitleaks accepted the generated config"
else
    echo "FAIL[gen-config-loads]: gitleaks rejected the generated config" >&2
    fails=$((fails + 1))
fi

# 13. --help prints the header block and nothing else. Pinned because the
# first implementation used a fixed line range, which started printing code
# as soon as the header grew past it.
help_out=$("$gen" --help 2>&1 || true)
if grep -q 'Usage:' <<<"$help_out" && ! grep -q 'set -euo' <<<"$help_out"; then
    echo "ok[help-header-only]: --help printed the header block and no code"
else
    echo "FAIL[help-header-only]: --help did not print the header block alone" >&2
    fails=$((fails + 1))
fi

# 14. REQ-D1.5: what is committed is what the generator produces. Skipped
# visibly rather than silently where the machine-local source is absent --
# the assertion needs the real set, which by REQ-D1.4 lives off the repo.
identifier_src="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/private-identifiers"
if [[ -f "$identifier_src" ]]; then
    if "$gen" --check >/dev/null 2>&1; then
        echo "ok[committed-block-current]: committed block matches a fresh generation"
    else
        echo "FAIL[committed-block-current]: committed block differs from a fresh" \
            "generation; re-run scripts/gitleaks-identifier-rules.sh --write" >&2
        fails=$((fails + 1))
    fi
else
    echo "skip[committed-block-current]: no identifier file at $identifier_src;" \
        "REQ-D1.5's byte-for-byte check is not exercised on this machine"
fi

if [[ "$fails" -ne 0 ]]; then
    echo "gitleaks-rules-test: $fails assertion(s) failed" >&2
    exit 1
fi
echo "gitleaks-rules-test: all assertions passed"
