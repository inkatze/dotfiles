#!/usr/bin/env bash
# Exercises review-backend-run.sh against stubs: a fake gemini that records its
# argv, working directory and stdin, a fake gitleaks, and a throwaway repository
# and HOME.
set -uo pipefail
unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR \
  GIT_PREFIX GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_CEILING_DIRECTORIES \
  GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/review-backend-run.sh"
pass=0
fail=0
ok() { echo "  ok: $1"; pass=$((pass + 1)); }
ko() { echo "  FAIL: $1"; fail=$((fail + 1)); }
check() { if [ "$2" = "$3" ]; then ok "$1"; else ko "$1 (want '$3', got '$2')"; fi; }

w="$(mktemp -d)" || exit 1
trap 'rm -rf "$w"' EXIT
mkdir -p "$w/home/.gemini" "$w/bin" "$w/repo"
printf 'k' > "$w/home/.gemini/.api-key"
chmod 600 "$w/home/.gemini/.api-key"

cat > "$w/bin/gemini" <<'STUB'
#!/usr/bin/env bash
pwd > "$REC/cwd"
printf '%s\n' "$@" > "$REC/argv"
printf '%s\n' "$GEMINI_API_KEY" > "$REC/key"
cat > "$REC/stdin"
[ -z "${STUB_SLEEP:-}" ] || exec sleep "$STUB_SLEEP"
[ -z "${STUB_EMPTY:-}" ] || exit 0
[ -z "${STUB_BLANK:-}" ] || { printf ' \n\n'; exit 0; }
echo "| Lens | File:Line | Finding | Rule cited | Severity |"
exit "${STUB_EXIT:-0}"
STUB
cat > "$w/bin/gitleaks" <<'STUB'
#!/usr/bin/env bash
[ -z "${STUB_LEAK:-}" ] || { echo leak >&2; exit 1; }
cat "$2"/prompt.txt > "$REC/scanned"
printf '%s\n' "$@" > "$REC/gitleaks-args"
STUB
chmod +x "$w/bin/gemini" "$w/bin/gitleaks"

git -C "$w/repo" init -q -b main
git -C "$w/repo" -c user.email=t@t -c user.name=t commit -q --allow-empty -m base
echo hi > "$w/repo/f.txt"
git -C "$w/repo" add f.txt
git -C "$w/repo" -c user.email=t@t -c user.name=t commit -q -m change

printf 'INSTRUCTION\n' > "$w/instr"
printf 'FORMAT\n' > "$w/fmt"
printf 'TOOLING\n' > "$w/tool"
printf 'EXTRA LENS\n' > "$w/extra"
printf '## Lens checklist\n\n1. Correctness\n\n2. Security\n\n## Next\n' > "$w/lens.md"
mkdir -p "$w/rec"

run() {
  (cd "$w/repo" && env -u GEMINI_API_KEY PANEL_BACKEND_TEST=1 HOME="$w/home" REC="$w/rec" PANEL_GEMINI_BIN="$w/bin/gemini" PANEL_NODE_DIR="$w/bin" \
    PANEL_GITLEAKS_BIN="$w/bin/gitleaks" "$@")
}
args=(--lens-doc "$w/lens.md" --instruction-file "$w/instr" --format-file "$w/fmt" --tooling-file "$w/tool" --base main~1)

out="$(run "$tool" gemini "${args[@]}" --extra-lens-file "$w/extra" 2> "$w/err")"
check "gemini exits 0 and prints the table" "${out%%$'\n'*}" "| Lens | File:Line | Finding | Rule cited | Severity |"
grep -q '^backend_elapsed=[0-9]*s backend_status=0$' "$w/err" && ok "elapsed and status reported" || ko "elapsed line missing"
check "plan mode argv" "$(tr '\n' ' ' < "$w/rec/argv")" "-o text --skip-trust --approval-mode plan "
case "$(cat "$w/rec/cwd")" in "$w/repo"*) ko "gemini ran inside the repository" ;; *) ok "gemini ran outside the repository" ;; esac
check "key read from the mode-600 file" "$(cat "$w/rec/key")" "k"  # placeholder value only
grep -q '^INSTRUCTION$' "$w/rec/stdin" && grep -q '^2\. Security' "$w/rec/stdin" && grep -q 'EXTRA LENS' "$w/rec/stdin" \
  && grep -q '^FORMAT$' "$w/rec/stdin" && grep -q '^+hi$' "$w/rec/stdin" && ok "prompt carries instruction, lenses, extra, format and diff" \
  || ko "prompt missing a part"
n1="$(grep -o '^BEGIN UNTRUSTED [0-9a-f]*' "$w/rec/stdin")"
n2="$(grep -o '^END UNTRUSTED [0-9a-f]*' "$w/rec/stdin")"
check "nonce frames the region" "${n1#BEGIN UNTRUSTED }" "${n2#END UNTRUSTED }"
cmp -s "$w/rec/scanned" "$w/rec/stdin" && ok "gitleaks scanned the same prompt that was sent" || ko "scanned prompt differs from the sent one"

rm -f "$w/rec/stdin"
STUB_LEAK=1 run "$tool" gemini "${args[@]}" > /dev/null 2> "$w/err"
check "a gitleaks hit refuses to send" "$?:$([ -e "$w/rec/stdin" ] && echo sent || echo unsent)" "1:unsent"

run "$tool" gemini "${args[@]}" --base HEAD > /dev/null 2> "$w/err"
check "an empty diff refuses to send" "$?" "1"

STUB_EXIT=3 run "$tool" gemini "${args[@]}" > /dev/null 2> "$w/err"
check "backend status passes through" "$?" "3"
grep -q 'backend failure, not zero findings' "$w/err" && ok "failure is labelled" || ko "failure not labelled"

STUB_SLEEP=5 run "$tool" gemini "${args[@]}" --timeout 1 > /dev/null 2> "$w/err"
check "the bound stops a stuck backend (124)" "$?" "124"

run "$tool" gemini "${args[@]}" --base --output=x > /dev/null 2> "$w/err"
check "an option-shaped base is refused" "$?:$([ -e "$w/repo/x" ] && echo wrote || echo clean)" "1:clean"
run "$tool" gemini "${args[@]}" --base nosuchrev > /dev/null 2> "$w/err"
check "an unknown base is refused" "$?" "1"
run "$tool" gemini "${args[@]}" --timeout 00 > /dev/null 2> "$w/err"
check "a zero bound is refused" "$?" "1"
run "$tool" gemini "${args[@]}" --timeout 99999999999999999999 > /dev/null 2> "$w/err"
check "an absurd bound is refused" "$?" "1"
run "$tool" gemini "${args[@]}" --timeout 1000000 > /dev/null 2> "$w/err"
check "a seven-digit bound is refused" "$?" "1"
run "$tool" gemini "${args[@]}" > /dev/null 2> "$w/err"
grep -qx -e '--ignore-gitleaks-allow' "$w/rec/gitleaks-args" && ok "the scan ignores inline allow markers" || ko "inline allow markers could skip the scan"
STUB_BLANK=1 run "$tool" gemini "${args[@]}" > /dev/null 2> "$w/err"
check "whitespace-only output is a failure (4)" "$?" "4"
run "$tool" gemini --lens-doc "$w/lens.md" --instruction-file "$w/nope" --format-file "$w/fmt" --tooling-file "$w/tool" --base main~1 > /dev/null 2> "$w/err"
check "a missing input file is refused" "$?" "1"
run "$tool" gemini "${args[@]}" --extra-lens-file "$w/none-such" > /dev/null 2> "$w/err"
check "a missing extra lens file is refused up front" "$?" "1"
grep -q 'extra-lens-file' "$w/err" && ok "the refusal names the flag" || ko "refusal does not name the flag"
printf 'no lens section here\n' > "$w/nolens.md"
run "$tool" gemini --lens-doc "$w/nolens.md" --instruction-file "$w/instr" --format-file "$w/fmt" --tooling-file "$w/tool" --base main~1 > /dev/null 2> "$w/err"
check "a lens doc with no lens list is refused" "$?" "1"
grep -q 'no lens list' "$w/err" && ok "the refusal says why" || ko "no-lens refusal unexplained"
run "$tool" gemini --lens-doc "$w" --instruction-file "$w/instr" --format-file "$w/fmt" --tooling-file "$w/tool" --base main~1 > /dev/null 2> "$w/err"
check "a directory is not an input file" "$?" "1"
grep -q -e '--lens-doc is unset' "$w/err" && ok "the refusal names the flag" || ko "refusal does not name the flag"
run "$tool" preflight --repo 'o/r;x' > /dev/null 2> "$w/err"
check "preflight refuses a malformed repo" "$?" "1"
STUB_EMPTY=1 run "$tool" gemini "${args[@]}" > /dev/null 2> "$w/err"
check "exit 0 with no output is a failure (4)" "$?" "4"
mkdir -p "$w/nofish"
printf '#!/bin/sh\nexit 1\n' > "$w/nofish/fish"
chmod +x "$w/nofish/fish"
env -u GEMINI_API_KEY PATH="$w/nofish:$PATH" PANEL_REVIEW_PROFILE=server HOME="$w/home" REC="$w/rec" PANEL_GEMINI_BIN="$w/bin/gemini" \
  bash -c 'cd "$1" && shift && "$@"' _ "$w/repo" "$tool" preflight > "$w/pre" 2>&1
grep -q '^gemini=missing' "$w/pre" && ok "overrides are ignored without the test marker" || ko "an override took effect without the marker"

chmod 644 "$w/home/.gemini/.api-key"
run "$tool" gemini "${args[@]}" > /dev/null 2> "$w/err"
check "a loose key mode refuses" "$?" "1"
run env PANEL_REVIEW_PROFILE=server "$tool" preflight > "$w/pre" 2>&1
check "preflight exits 1 on a loose key" "$?" "1"
chmod 600 "$w/home/.gemini/.api-key"

printf '{"o/r":"gemini"}' > "$w/egress.json"
pre="$(run env PANEL_REVIEW_PROFILE=server PANEL_EGRESS_FILE="$w/egress.json" "$tool" preflight --repo o/r)"
check "preflight passes with stubs" "$?" "0"
case "$pre" in *$'backend=gemini'*$'key=ok'*$'egress=gemini'*) ok "preflight reports backend, key and egress" ;; *) ko "preflight output: $pre" ;; esac
pre="$(run env PANEL_REVIEW_PROFILE=work PANEL_EGRESS_FILE="$w/egress.json" PANEL_GEMINI_BIN=/nonexistent "$tool" preflight --repo x/y)"
check "work profile does not need gemini" "$?" "0"
case "$pre" in *$'backend=codex'*$'egress=none'*) ok "work profile resolves codex; unknown repo has no consent" ;; *) ko "work preflight: $pre" ;; esac

echo "review-backend-run-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
