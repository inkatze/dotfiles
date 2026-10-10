#!/usr/bin/env bash
# Fixture suite for how scripts/playbook.sh picks the inventory host it passes
# to `ansible-playbook -l`, and the OP_ACCOUNT it exports.
#
# The property that matters most is the empty case: `-l ""` is read by Ansible
# as no limit at all, so an alias file that exists but names nothing would run
# every inventory host's configuration against this machine. An empty or
# whitespace-only file has to behave like an absent one.
#
# Driven end to end with stubs for ansible-playbook and hostname first on PATH,
# so nothing is provisioned and the hostname branch is deterministic.
set -uo pipefail

here="$(cd -- "$(dirname "$0")" && pwd -P)"
playbook="$here/playbook.sh"
work="$(mktemp -d)" || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM HUP
fails=0

ok()   { printf 'ok[%s]: %s\n' "$1" "$2"; }
skip() { printf 'skip[%s]: %s\n' "$1" "$2"; }
fail() { printf 'FAIL[%s]: %s\n' "$1" "$2"; fails=$((fails + 1)); }

mkdir -p "$work/bin"
cat >"$work/bin/ansible-playbook" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_ARGV"
printf '%s' "${OP_ACCOUNT-<unset>}" >"$STUB_OP_ACCOUNT"
printf '%s|%s|%s' "${DOTFILES_OP_WORK_ACCOUNT-<unset>}" "${DOTFILES_OP_WORK_VAULT-<unset>}" \
    "${DOTFILES_OP_WORK_ITEM-<unset>}" >"$STUB_OP_WORK"
SH
cat >"$work/bin/hostname" <<'SH'
#!/usr/bin/env bash
echo "${STUB_HOSTNAME:-ci-runner}"
SH
real_stat="$(command -v stat)"
cat >"$work/bin/stat" <<SH
#!/usr/bin/env bash
# Reports another owner when the case asks for one; stat is otherwise real.
if [ -e "\$STUB_STAT_UID" ]; then
    for a in "\$@"; do [ "\$a" = %u ] && { cat "\$STUB_STAT_UID"; exit 0; }; done
fi
exec "$real_stat" "\$@"
SH
chmod +x "$work/bin/ansible-playbook" "$work/bin/hostname" "$work/bin/stat"
# Without both stubs in place, PATH would resolve to the real ansible-playbook
# and the first case would provision this machine.
[ -x "$work/bin/ansible-playbook" ] && [ -x "$work/bin/hostname" ] || {
    echo "playbook-alias-test: stubs under $work/bin are not executable; refusing to run" >&2
    exit 1
}

# Runs playbook.sh with a clean environment apart from what the case sets, then
# prints the value passed to -l. A missing argv file means the stub never ran,
# which is reported as such rather than as an empty limit. The exit status
# lands in a file, since the caller reads this through a substitution.
limit_for() {
    rm -f "$work/argv" "$work/op" "$work/op-work"
    env -i PATH="$work/bin:$PATH" HOME="$work/home" \
        STUB_ARGV="$work/argv" STUB_OP_ACCOUNT="$work/op" STUB_OP_WORK="$work/op-work" \
        DOTFILES_HOST_FILE="$work/host" DOTFILES_OP_ACCOUNT_FILE="$work/op-account" \
        DOTFILES_OP_WORK_ITEM_FILE="$work/op-work-item" STUB_STAT_UID="$work/stat-uid" \
        "$@" bash "$playbook" >/dev/null 2>"$work/stderr"
    echo $? >"$work/rc"
    if [ ! -f "$work/argv" ]; then
        echo "<not run>"
        return
    fi
    awk 'prev == "-l" { print; found = 1; exit } { prev = $0 } END { if (!found) print "<no -l>" }' "$work/argv"
}

expect_limit() {
    name="$1" want="$2"
    shift 2
    got="$(limit_for "$@")"
    if [ "$got" = "$want" ]; then
        ok "$name" "-l '$got'"
    else
        fail "$name" "expected -l '$want', got '$got'"
    fi
}

reset_files() { rm -f "$work/host" "$work/op-account" "$work/op-work-item"; }

# 1. The regression: an empty file must not produce an empty limit.
reset_files
: >"$work/host"
expect_limit empty-file work
if grep -q 'defaulting to' "$work/stderr"; then
    ok empty-file-warns "fallback warning printed"
else
    fail empty-file-warns "no fallback warning on stderr"
fi
if grep -q 'exists but names no alias' "$work/stderr"; then
    ok empty-file-named "the empty file is named on stderr"
else
    fail empty-file-named "stderr does not say the file was found empty"
fi

# 2. Same for whitespace only, which `tr -d '[:space:]'` also trims to nothing.
reset_files
printf ' \n\t\n' >"$work/host"
expect_limit whitespace-file work

# 3. An empty file still falls through to the alt hostname match, not straight
#    to work.
reset_files
: >"$work/host"
expect_limit empty-file-alt-hostname alt STUB_HOSTNAME=ci-panela-stub
if grep -q 'exists but names no alias' "$work/stderr"; then
    ok empty-file-alt-hostname-named "the empty file is named even when alt resolves"
else
    fail empty-file-alt-hostname-named "alt fallback ignored the empty file silently"
fi

# 4. A file naming a host is used, trimmed, with or without a trailing
#    newline, and without the fallback warning.
reset_files
printf 'server\n' >"$work/host"
expect_limit file-names-host server
if grep -q 'defaulting to' "$work/stderr"; then
    fail file-names-host-quiet "fallback warning printed although the file resolved"
else
    ok file-names-host-quiet "no fallback warning"
fi
reset_files
printf 'server' >"$work/host"
expect_limit file-no-newline server

# 5. DOTFILES_HOST wins over the file, but an empty one falls through to it.
reset_files
printf 'server\n' >"$work/host"
expect_limit env-override personal DOTFILES_HOST=personal
reset_files
printf 'server\n' >"$work/host"
expect_limit env-empty-falls-through server DOTFILES_HOST=

# 6. No file and no hostname match falls back to work.
reset_files
expect_limit absent-file work

# 7. DOTFILES_HOST is the escape hatch for a broken file, so the file is not
#    read at all when it is set; without the override, an unreadable file is a
#    misconfiguration and the run stops there rather than falling through to
#    another host. The read guard itself needs no unreadable file: an empty one
#    would print its notice if it were read.
reset_files
: >"$work/host"
expect_limit env-skips-file-read personal DOTFILES_HOST=personal
if grep -q 'names no alias' "$work/stderr"; then
    fail env-skips-file-read-quiet "the file was read although DOTFILES_HOST is set"
else
    ok env-skips-file-read-quiet "the file was not read"
fi

# The stub never starting is the expected outcome here, so the exit status and
# stderr have to say why, or any earlier abort would pass.
expect_abort() {
    name="$1" file="$2"
    shift 2
    got="$(limit_for "$@")"
    if [ "$got" = "<not run>" ] && [ "$(cat "$work/rc")" -ne 0 ] && grep -qF "$file" "$work/stderr"; then
        ok "$name" "aborted on $file with status $(cat "$work/rc")"
    else
        fail "$name" "expected an abort naming $file, got -l '$got' with status $(cat "$work/rc")"
    fi
}

# Root reads a mode-000 file regardless, so these two cannot run there.
if [ "$(id -u)" -eq 0 ]; then
    skip env-skips-unreadable-file "running as root"
    skip unreadable-file-aborts "running as root"
else
    reset_files
    : >"$work/host"
    chmod 000 "$work/host"
    expect_limit env-skips-unreadable-file personal DOTFILES_HOST=personal
    expect_abort unreadable-file-aborts "$work/host"
    chmod 600 "$work/host"
fi

# 8. Anything that is not a plain name, or not a host the inventory lists, is
#    refused outright with a non-zero status, whichever source it came from;
#    that includes values Ansible would split into nothing. `<not run>` means
#    the stub never started, which is the only acceptable outcome here.
expect_refused() {
    name="$1"
    shift
    got="$(limit_for "$@")"
    if [ "$got" = "<not run>" ] && [ "$(cat "$work/rc")" -ne 0 ] && grep -q 'refusing to run' "$work/stderr"; then
        ok "$name" "refused before ansible-playbook ran"
    else
        fail "$name" "expected a refusal, got -l '$got' with status $(cat "$work/rc")"
    fi
}

reset_files
printf ',\n' >"$work/host"
expect_refused separator-only-file

# Under a UTF-8 locale, so the escaping of the echoed value is exercised where
# it would otherwise print raw.
reset_files
printf '\302\240\n' >"$work/host"
expect_refused nbsp-only-file LC_ALL=C.UTF-8
if LC_ALL=C grep -q "$(printf '\302\240')" "$work/stderr"; then
    fail nbsp-escaped "the refused value reached stderr as raw bytes"
else
    ok nbsp-escaped "the refused value is escaped on stderr"
fi

reset_files
printf 'server\n' >"$work/host"
expect_refused whitespace-env DOTFILES_HOST=' '

reset_files
expect_refused separator-env DOTFILES_HOST=work,

# A bad leading character: `-v` would reach ansible-playbook's option parser,
# and `!work` is every host except work.
reset_files
expect_refused leading-hyphen-env DOTFILES_HOST=-v

reset_files
expect_refused negation-env DOTFILES_HOST='!work'

# A valid first line must not carry a second pattern past a line-oriented
# check: `work<LF>all` reaches Ansible as every host.
reset_files
expect_refused newline-env DOTFILES_HOST="$(printf 'work\nall')"

# A group name is a plain name that still means several hosts.
reset_files
printf 'all\n' >"$work/host"
expect_refused all-file

reset_files
expect_refused group-env DOTFILES_HOST=secrets

reset_files
expect_refused ungrouped-env DOTFILES_HOST=ungrouped

# The accepted set must not widen under a UTF-8 locale.
reset_files
expect_refused non-ascii-utf8-env DOTFILES_HOST="$(printf 'caf\303\251')" LC_ALL=C.UTF-8

# An escape sequence is the refused value that could actually drive the terminal.
reset_files
expect_refused esc-env DOTFILES_HOST="$(printf 'a\033[2Jb')"
if LC_ALL=C grep -q "$(printf '\033')" "$work/stderr"; then
    fail esc-escaped "a raw ESC reached stderr"
else
    ok esc-escaped "the ESC is escaped on stderr"
fi

# 9. OP_ACCOUNT: an empty or whitespace-only file exports nothing, a populated
#    one exports its trimmed value unless that isn't an account name, in which
#    case the run is refused, a non-empty already-exported value wins and
#    an empty one falls through to the file. An unreadable file is skipped
#    when OP_ACCOUNT is set and fatal otherwise, as for the host alias.
op_for() {
    limit_for "$@" >/dev/null
    cat "$work/op" 2>/dev/null || echo "<not run>"
}
expect_op() {
    name="$1" want="$2"
    shift 2
    got="$(op_for "$@")"
    if [ "$got" = "$want" ]; then
        ok "$name" "OP_ACCOUNT=$got"
    else
        fail "$name" "expected OP_ACCOUNT=$want, got $got"
    fi
}

reset_files
: >"$work/op-account"
expect_op op-empty-file '<unset>'

reset_files
printf '  \n' >"$work/op-account"
expect_op op-whitespace-file '<unset>'

reset_files
printf 'my.1password.com\n' >"$work/op-account"
expect_op op-file my.1password.com

reset_files
printf 'my.1password.com\n' >"$work/op-account"
expect_op op-env-wins other.1password.com OP_ACCOUNT=other.1password.com

reset_files
printf 'my.1password.com\n' >"$work/op-account"
expect_op op-empty-env-uses-file my.1password.com OP_ACCOUNT=

reset_files
expect_op op-absent-file '<unset>'

# A populated file that isn't an account is refused, not exported, under a
# UTF-8 locale too, where macOS tr would otherwise strip the NBSP.
reset_files
printf '\302\240\n' >"$work/op-account"
expect_refused op-nbsp-only-file LC_ALL=C.UTF-8
if LC_ALL=C grep -q "$(printf '\302\240')" "$work/stderr"; then
    fail op-nbsp-escaped "the refused value reached stderr as raw bytes"
else
    ok op-nbsp-escaped "the refused value is escaped on stderr"
fi

reset_files
printf ',\n' >"$work/op-account"
expect_refused op-separator-only-file

if [ "$(id -u)" -eq 0 ]; then
    skip op-env-skips-unreadable-file "running as root"
    skip op-unreadable-file-aborts "running as root"
else
    reset_files
    : >"$work/op-account"
    chmod 000 "$work/op-account"
    expect_op op-env-skips-unreadable-file other.1password.com OP_ACCOUNT=other.1password.com
    expect_abort op-unreadable-file-aborts "$work/op-account"
    chmod 600 "$work/op-account"
fi

# 10. The work item: a complete file exports its three values, comments, blank
#     lines and CRLF endings aside; all three exported skip the file and a
#     partial export is refused; a partial, repeated, unknown-key or unsafe
#     line is refused without its value reaching stderr.
expect_work() {
    name="$1" want="$2"
    shift 2
    limit_for "$@" >/dev/null
    got="$(cat "$work/op-work" 2>/dev/null || echo "<not run>")"
    if [ "$got" = "$want" ]; then
        ok "$name" "$got"
    else
        fail "$name" "expected $want, got $got"
    fi
}
expect_work_refused() { # expect_work_refused <name> <stderr fragment> [env...]
    name="$1" fragment="$2"
    shift 2
    expect_refused "$name" "$@"
    if grep -qF -- "$fragment" "$work/stderr"; then
        ok "$name-message" "names: $fragment"
    else
        fail "$name-message" "expected \"$fragment\" in: $(cat "$work/stderr")"
    fi
}
work_file() { printf "$@" >"$work/op-work-item"; chmod 600 "$work/op-work-item"; }
good='DOTFILES_OP_WORK_ACCOUNT=team.example.com\nDOTFILES_OP_WORK_VAULT=Team Vault\nDOTFILES_OP_WORK_ITEM=review-item\n'
reset_files
expect_work work-absent-file '<unset>|<unset>|<unset>'
reset_files
work_file "# work source\n\n   \n  # indented comment\n$good"
expect_work work-file 'team.example.com|Team Vault|review-item'
expect_work work-env-skips-file 'a.example.com|V|I' DOTFILES_OP_WORK_ACCOUNT=a.example.com \
    DOTFILES_OP_WORK_VAULT=V DOTFILES_OP_WORK_ITEM=I
for v in DOTFILES_OP_WORK_ACCOUNT DOTFILES_OP_WORK_VAULT DOTFILES_OP_WORK_ITEM; do
    expect_work_refused "work-partial-env-$v" "together or not at all" "$v=x"
done
expect_work_refused work-partial-env-two "together or not at all" DOTFILES_OP_WORK_ACCOUNT=x DOTFILES_OP_WORK_VAULT=y
reset_files
work_file 'DOTFILES_OP_WORK_ACCOUNT=team.example.com\r\nDOTFILES_OP_WORK_VAULT=Team Vault\r\nDOTFILES_OP_WORK_ITEM=review-item\r\n'
expect_work work-crlf-file 'team.example.com|Team Vault|review-item'
reset_files
work_file 'DOTFILES_OP_WORK_ACCOUNT=team.example.com\nDOTFILES_OP_WORK_VAULT=Team Vault\nDOTFILES_OP_WORK_ITEM=review-item'
expect_work work-no-final-newline 'team.example.com|Team Vault|review-item'
for missing in ACCOUNT VAULT ITEM; do
    reset_files
    work_file "$(printf "$good" | grep -v "^DOTFILES_OP_WORK_$missing=")\n"
    expect_work_refused "work-file-missing-$missing" "must name"
done
reset_files
work_file "${good}OP_SERVICE_ACCOUNT_TOKEN=ops_secretvalue\n"
expect_work_refused work-unknown-key "line 4 names a key other than"
grep -q ops_secretvalue "$work/stderr" && fail work-unknown-key-quiet "the line's value reached stderr" || ok work-unknown-key-quiet "the value stays off stderr"
reset_files
work_file "${good}ops_secretvalue\n"
expect_work_refused work-bare-line "line 4 is not a KEY=value line"
grep -q ops_secretvalue "$work/stderr" && fail work-bare-line-quiet "the line reached stderr" || ok work-bare-line-quiet "the line stays off stderr"
reset_files
work_file "# c\n\n${good}DOTFILES_OP_WORK_ITEM=other\n"
expect_work_refused work-repeated-key "line 6 sets DOTFILES_OP_WORK_ITEM a second time"
for bad in 'ACCOUNT=--account=x' 'ACCOUNT=a b.example.com' 'VAULT=v/w' 'VAULT=v@w' 'ITEM=a/b' 'ITEM=i@x' 'VAULT=Team Vault ' 'ITEM= item'; do
    reset_files
    work_file "$(printf "$good" | grep -v "^DOTFILES_OP_WORK_${bad%%=*}=")\nDOTFILES_OP_WORK_$bad\n"
    expect_work_refused "work-bad-value ($bad)" "not a plain 1Password name"
done
reset_files
work_file 'DOTFILES_OP_WORK_ACCOUNT=a\0b.example.com\nDOTFILES_OP_WORK_VAULT=v\nDOTFILES_OP_WORK_ITEM=i\n'
expect_work_refused work-nul-byte "it holds a NUL byte"
for mode in 644 640 660 604; do
    reset_files
    work_file "$good"
    chmod "$mode" "$work/op-work-item"
    expect_work_refused "work-mode-$mode" "mode $mode; must be 600 or 400"
done
reset_files
work_file "$good"
chmod 400 "$work/op-work-item"
expect_work work-mode-400 'team.example.com|Team Vault|review-item'
chmod 600 "$work/op-work-item"
reset_files
work_file "$good"
mv "$work/op-work-item" "$work/op-work-item.real"
ln -s "$work/op-work-item.real" "$work/op-work-item"
expect_work_refused work-symlink "a symlink"
rm -f "$work/op-work-item" "$work/op-work-item.real"
ln -s "$work/missing-target" "$work/op-work-item"
expect_work_refused work-dangling-symlink "a symlink"
rm -f "$work/op-work-item"
mkdir "$work/op-work-item"
expect_work_refused work-directory "not a regular file"
rmdir "$work/op-work-item"
reset_files
work_file "$good"
echo $(( $(id -u) + 1 )) >"$work/stat-uid"
expect_work_refused work-foreign-owner "not owned by this user"
rm -f "$work/stat-uid"
reset_files
work_file "$good"
if chmod +a "everyone allow write" "$work/op-work-item" 2>/dev/null; then
    expect_work_refused work-acl "carries an access-control list"
    xattr -w org.example.test x "$work/op-work-item" 2>/dev/null || true
    expect_work_refused work-acl-with-xattr "carries an access-control list"
    chmod -N "$work/op-work-item"
    expect_work work-acl-removed 'team.example.com|Team Vault|review-item'
else
    skip work-acl "no chmod +a here"
fi
if [ "$(id -u)" -ne 0 ]; then
    reset_files
    work_file "$good"
    chmod 000 "$work/op-work-item"
    expect_work_refused work-mode-000 "must be 600 or 400"
    chmod 600 "$work/op-work-item"
fi

if [ "$fails" -eq 0 ]; then
    echo "playbook-alias-test: all assertions hold"
else
    echo "playbook-alias-test: $fails assertion(s) failed"
    exit 1
fi
