#!/usr/bin/env bash
# Fixture tests for skill-contracts.sh: prove each check class actually
# fires when its anchor drifts, and stays quiet on benign edits. The
# checker's body comments document two historical ways grep-based checks
# silently no-op (a shared alternation regex masked by an unrelated match,
# and a `set -e && `-chain that dies before err runs); this suite is the
# negative side. Each failing case copies the real tracked inputs into a
# temp tree, plants exactly one drift, verifies the drift actually changed
# the tree (a fixture whose pattern no longer matches must fail as "did not
# apply", not masquerade as a checker regression), and asserts the checker
# exits non-zero mentioning the expected message. Passing cases plant a
# benign edit and assert the checker stays green.
#
# Runs from the dotfiles checkout only (pre-commit via lefthook, and CI);
# mutations use perl -pi for BSD/GNU portability across the CI runners.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
# Through the materialized ~/.claude/scripts symlink this resolves outside
# the repo; refuse with a hint instead of dying on a bare cp error.
[ -f "$ROOT/lefthook.yml" ] || {
  echo "skill-contracts-test: must run from the dotfiles checkout (ROOT resolved to $ROOT)"
  exit 1
}
failures=0
tmp=""

setup() {
  tmp="$(mktemp -d -t skill-contracts-test.XXXXXX)"
  mkdir -p "$tmp/roles/claude/files/scripts"
  cp -r "$ROOT/roles/claude/files/commands" "$tmp/roles/claude/files/"
  cp "$ROOT/roles/claude/files/CLAUDE.md" "$tmp/roles/claude/files/"
  cp "$ROOT/roles/claude/files/scripts/skill-contracts.sh" \
    "$tmp/roles/claude/files/scripts/"
}

teardown() { rm -rf "$tmp" || true; tmp=""; }
trap '[ -n "$tmp" ] && rm -rf "$tmp"' EXIT

run_checker() { (cd "$tmp" && bash roles/claude/files/scripts/skill-contracts.sh); }

# Tree fingerprint, used to prove a mutation actually changed something.
# Paths in this tree are controlled (no whitespace), so plain xargs is safe.
tree_sum() {
  (cd "$tmp" && find roles -type f | LC_ALL=C sort | xargs cksum | cksum)
}

# The unmutated tree must pass; without that every case below is
# meaningless, so a baseline failure aborts instead of letting ten cases
# "pass" against a checker that rejects everything.
baseline() {
  setup
  local out
  if ! out="$(run_checker 2>&1)"; then
    echo "FAIL baseline: checker rejects the tracked files: $out"
    teardown
    echo "skill-contracts-test: baseline failed; aborting"
    exit 1
  fi
  teardown
}

# expect_fail <name> <mutation command run from $tmp> <expected message fragment>
expect_fail() {
  local name="$1" mutation="$2" fragment="$3" out pre post
  setup
  pre="$(tree_sum)"
  if ! (cd "$tmp" && eval "$mutation"); then
    echo "FAIL $name: mutation command errored"
    failures=$((failures + 1))
    teardown
    return
  fi
  post="$(tree_sum)"
  if [ "$pre" = "$post" ]; then
    echo "FAIL $name: mutation did not change the tree (stale fixture: its pattern no longer matches the tracked files)"
    failures=$((failures + 1))
    teardown
    return
  fi
  if out="$(run_checker 2>&1)"; then
    echo "FAIL $name: checker passed after mutation"
    failures=$((failures + 1))
  elif ! printf '%s' "$out" | grep -qF "$fragment"; then
    echo "FAIL $name: expected message containing \"$fragment\", got: $out"
    failures=$((failures + 1))
  fi
  teardown
}

# expect_pass <name> <benign mutation run from $tmp>
expect_pass() {
  local name="$1" mutation="$2" out pre post
  setup
  pre="$(tree_sum)"
  if ! (cd "$tmp" && eval "$mutation"); then
    echo "FAIL $name: mutation command errored"
    failures=$((failures + 1))
    teardown
    return
  fi
  post="$(tree_sum)"
  if [ "$pre" = "$post" ]; then
    echo "FAIL $name: mutation did not change the tree (stale fixture)"
    failures=$((failures + 1))
    teardown
    return
  fi
  if ! out="$(run_checker 2>&1)"; then
    echo "FAIL $name: checker rejected a benign edit: $out"
    failures=$((failures + 1))
  fi
  teardown
}

CMDS="roles/claude/files/commands"

baseline

# --- bucket_checks: one fixture per anchor ---
expect_fail bucket-panel-tables \
  "perl -pi -e 's/three findings tables in fixed order/four findings tables in fixed order/' $CMDS/panel-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-panel-out-of-three \
  "perl -pi -e 's/bucket out of three: Auto-applicable, Needs sign-off, or Needs human judgment/bucket out of four/' $CMDS/panel-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-peer-tables \
  "perl -pi -e 's/the validated threads as three tables/the validated threads as tables/' $CMDS/peer-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-copilot-adjacent \
  "perl -pi -e 's/Three adjacent-findings tables/Adjacent-findings tables/' $CMDS/copilot-review.md" \
  "missing expected bucket-count sentence"

expect_fail bucket-bot-review-tables \
  "perl -pi -e 's/Present all three tables, in fixed order/Present the tables/' $CMDS/bot-review.md" \
  "missing expected bucket-count sentence"

# --- retired-bucket sweep: panel (original), copilot (bucket_files), and
# code-review (its own separate guard outside bucket_files) ---
expect_fail retired-bucket \
  "echo 'Agent-resolvable' >> $CMDS/panel-review.md" \
  "retired Agent-resolvable bucket"

expect_fail retired-bucket-copilot \
  "echo 'Agent-resolvable' >> $CMDS/copilot-review.md" \
  "copilot-review.md references the retired Agent-resolvable bucket"

expect_fail retired-bucket-code-review \
  "echo 'Agent-resolvable' >> $CMDS/code-review.md" \
  "code-review.md references the retired Agent-resolvable bucket"

# A missing jq must be reported as missing, not as every config being invalid.
setup
nojq="$(mktemp -d)"
for t in bash grep tr cat sort cksum find xargs basename dirname; do
  p="$(command -v "$t")" && ln -s "$p" "$nojq/$t"
done
if out="$(cd "$tmp" && PATH="$nojq" bash roles/claude/files/scripts/skill-contracts.sh 2>&1)"; then
  echo "FAIL missing-jq: checker passed without jq"; failures=$((failures + 1))
elif ! printf '%s' "$out" | grep -qF "jq is required"; then
  echo "FAIL missing-jq: expected \"jq is required\", got: $out"; failures=$((failures + 1))
elif printf '%s' "$out" | grep -qF "is not valid JSON"; then
  echo "FAIL missing-jq: still blamed the config"; failures=$((failures + 1))
fi
rm -rf "$nojq"
teardown

expect_fail example-config-json \
  "echo 'not json' >> $CMDS/bot-review.config.example.json" \
  "is not valid JSON"

expect_fail retired-bucket-bot-review \
  "echo 'Agent-resolvable' >> $CMDS/bot-review.md" \
  "bot-review.md references the retired Agent-resolvable bucket"

expect_fail retired-file \
  "touch $CMDS/panel-pairing.md" \
  "was retired into --nested"

# --- retired-backend sweep: a command file and the tracked CLAUDE.md, since
# the sweep covers both ---
expect_fail retired-backend-name \
  "echo 'qwen-coder' >> $CMDS/panel-review.md" \
  "retired backend name"

expect_fail retired-backend-name-global \
  "echo 'OLLAMA_BASE_URL' >> roles/claude/files/CLAUDE.md" \
  "retired backend name"

expect_fail mark-ready \
  "perl -pi -e 's/This confirmation-gated ready-flip is the only PR-lifecycle action this loop takes, and only on this exit path\\.//' $CMDS/copilot-review.md" \
  "mark-ready safety sentence"

# --- bot-review's own single-mutation safety anchors ---
expect_fail bot-review-safety-nested-apply \
  "perl -pi -e 's/Never apply the code change in this bucket while nested\\.//' $CMDS/bot-review.md" \
  "bot-review.md missing expected safety sentence"

expect_fail bot-review-safety-never-mutate \
  "perl -pi -e 's/force-push, push to a protected branch, mark the PR ready, or merge/land whatever it likes/' $CMDS/bot-review.md" \
  "bot-review.md missing expected safety sentence"

expect_fail bot-review-safety-no-speculative-label \
  "perl -pi -e 's/Do not add the opt-in label speculatively//' $CMDS/bot-review.md" \
  "bot-review.md missing expected safety sentence"

# --- panel-review's reviewer:<name> backend containment ---
expect_fail reviewer-backend-no-kill-after \
  "perl -pi -e 's/ -k 30 \"/ \"/' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

expect_fail reviewer-backend-glob-split \
  "perl -pi -e 's/IFS=\\\$. \\\\t. read -r -a words <<< \"\\\$tpl\"/words=(\\\$tpl)/' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

expect_fail reviewer-backend-bare-binary \
  "perl -pi -e 's/^  argv\\[0\\]=\"\\\$bin_abs\"\n//' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

expect_fail reviewer-backend-no-cleanup \
  "perl -pi -e 's/trap .rm -rf \"\\\$work\". EXIT//' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

expect_fail reviewer-backend-combined-trap \
  "perl -pi -e 's/(trap .rm -rf \"\\\$work\". EXIT)/\$1 INT TERM HUP/' $CMDS/panel-review.md" \
  "combines the reviewer backend's EXIT and INT traps"

expect_fail reviewer-backend-empty-output \
  "perl -pi -e 's/\\[ -f \"\\\$src\" \\] && \\[ -s \"\\\$src\" \\] \\|\\| //' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

expect_fail reviewer-backend-multi-doc \
  "perl -pi -e 's/jq -e -s .length == 1. \"\\\$src\"/true/' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

expect_fail reviewer-backend-row-shape \
  "perl -pi -e 's/cli\\.findings_jq must yield one array/rows look fine/' $CMDS/panel-review.md" \
  "panel-review.md missing expected reviewer-backend containment line"

# These anchors are dense with shell and regex metacharacters, so their
# fixtures swap literal text instead of hand-escaping a perl pattern.
swap_fixed() { OLD="$1" NEW="$2" perl -0pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$3"; }
# OLD and NEW reach expect_fail's eval as temporary env vars, so the mutation
# string must stay single-quoted.
reviewer_drift() {
  local name="$1" old="$2" new="$3"
  OLD="$old" NEW="$new" expect_fail "$name" 'swap_fixed "$OLD" "$NEW" "$CMDS/panel-review.md"' \
    "panel-review.md missing expected reviewer-backend containment line"
}

reviewer_drift reviewer-backend-inherited-env '/usr/bin/env -i "${env_kept[@]}" "$tbin"' '"$tbin"'
reviewer_drift reviewer-backend-env-from-shell-vars 'val="$(printenv "$v")"' 'val="${!v}"'
reviewer_drift reviewer-backend-env-allow-unvalidated \
  ' and test("^[A-Za-z_][A-Za-z0-9_]*$")) then' ') then'
reviewer_drift reviewer-backend-env-allow-no-stop \
  '|| { echo "cli.env_allow must be a list of variable names" >&2; exit 1; }' '|| true'
reviewer_drift reviewer-backend-in-repo-textual '[ "$x" -ef "$top" ] && return 0' '[ "$x" = "$top" ] && return 0'
reviewer_drift reviewer-backend-in-repo-no-walk 'x="${x%/*}"; done' 'x=""; done'
reviewer_drift reviewer-backend-in-repo-unresolved \
  'x="$(cd "$1" 2>/dev/null && pwd -P)" || return 2' 'x="$1"'
reviewer_drift reviewer-backend-path-keeps-repo-dirs \
  'in_repo "$dir"; [ "$?" -eq 1 ] || continue' ':'
reviewer_drift reviewer-backend-snippet-path-unfiltered '  PATH="$safe_path"' '  :'
reviewer_drift reviewer-backend-cli-path-unfiltered 'env_kept=("PATH=$safe_path")' 'env_kept=("PATH=$PATH")'
reviewer_drift reviewer-backend-no-realpath-probe 'command -v realpath > /dev/null ||' 'true ||'
reviewer_drift reviewer-backend-binary-unresolved 'bin_real="$(realpath "$bin_abs")" ||' 'bin_real="$bin_abs" ||'
reviewer_drift reviewer-backend-binary-in-repo 'in_repo "${bin_real%/*}/"; [ "$?" -eq 1 ] ||' 'true ||'
reviewer_drift reviewer-backend-binary-not-approved '[ "$bin_abs" = "$approved" ] ||' 'true ||'
reviewer_drift reviewer-backend-timeout-unresolved 'tbin_real="$(realpath "$tbin")" ||' 'tbin_real="$tbin" ||'
reviewer_drift reviewer-backend-timeout-in-repo 'in_repo "${tbin_real%/*}/"; [ "$?" -eq 1 ] ||' 'true ||'
reviewer_drift reviewer-backend-timeout-assignment 'case "$tbin" in *=*|[!/]*)' 'case "$tbin" in [!/]*)'
reviewer_drift reviewer-backend-tree-untracked-collapsed '--porcelain --untracked-files=all' '--porcelain'
reviewer_drift reviewer-backend-tree-no-diff-sum 'git_isolated diff HEAD --binary --no-ext-diff --no-textconv | cksum' 'true'
reviewer_drift reviewer-backend-tree-no-index-flags '    git_isolated ls-files -v | cksum || exit 1' '    true'
reviewer_drift reviewer-backend-tree-no-untracked-list 'git_isolated ls-files -oz --exclude-standard > "$list"' ': > "$list"'
reviewer_drift reviewer-backend-tree-no-untracked-sum 'done < "$list" | xargs -0 cksum -- || exit 1' 'done < "$list" > /dev/null'
reviewer_drift reviewer-backend-tree-no-pipefail $'tree_state() (\n    set -o pipefail' 'tree_state() ('
reviewer_drift reviewer-backend-tree-follows-links 'if [ -L "./$p" ]; then printf' 'if false; then printf'
reviewer_drift reviewer-backend-tree-ignores-head '    git_isolated rev-parse HEAD || exit 1' '    true'
reviewer_drift reviewer-backend-tree-ignores-branch 'git_isolated symbolic-ref -q HEAD || echo detached' 'echo detached'
reviewer_drift reviewer-backend-tree-git-unhardened '-c core.fsmonitor=false -c core.untrackedCache=false -c core.hooksPath=/dev/null' ''
reviewer_drift reviewer-backend-tree-git-inherited-env '/usr/bin/env -i "${env_kept[@]}" GIT_CONFIG_NOSYSTEM=1' ''
reviewer_drift reviewer-backend-git-setup-no-worktree-pointers '"$git_dir/commondir" "$git_dir/gitdir" ' ''
reviewer_drift reviewer-backend-git-setup-no-excludes '"$git_common/info/exclude" "$git_common/info/attributes" ' ''
reviewer_drift reviewer-backend-git-setup-no-modes '"$([ -x "$path" ] && echo exec)" ' ''
reviewer_drift reviewer-backend-git-setup-links-by-name '"$(readlink "$path")"; fi' '"$(readlink "$path")"; continue; fi'
reviewer_drift reviewer-backend-git-setup-hooks-fallback \
  'git rev-parse --path-format=absolute --git-path hooks)"' 'echo "$git_common/hooks")"'
reviewer_drift reviewer-backend-git-setup-hooks-dir-unseen '"$git_hooks" "$git_hooks"/*; do' '"$git_hooks"/*; do'
reviewer_drift reviewer-backend-no-jq-probe 'command -v jq > /dev/null || { echo "jq is not on the filtered PATH"' 'true || { echo "jq is not on the filtered PATH"'
reviewer_drift reviewer-backend-git-setup-unchecked \
  'if ! setup_after="$(git_setup_sum)" || [ "$setup_after" != "$setup_before" ]; then' 'if false; then'
reviewer_drift reviewer-backend-tree-not-compared 'elif [ "$tree_after" != "$tree_before" ]; then' 'elif false; then'
reviewer_drift reviewer-backend-tree-change-not-fatal '[ -z "$tree_msg" ] || { echo "$tree_msg" >&2; exit 1; }' ':'
reviewer_drift reviewer-backend-findings-escape-output \
  'case "$(realpath "$src")" in "$(realpath "$out")"/*) ;;' 'case "$src" in *) ;;'

reviewer_drift reviewer-backend-no-egress-consent \
  '6. **Egress consent, once per repo and reviewer (`reviewer:<name>` only).**' '6. **Notes.**'
reviewer_drift reviewer-backend-consent-diff-only \
  'it reads the whole repo tree, not just the diff, and uploads it' 'it uploads the diff'
reviewer_drift reviewer-backend-consent-not-a-gate 'Anything other than a yes stops the run.' ''
reviewer_drift reviewer-backend-consent-bare-key 'key="reviewer:<name>:<owner>/<repo>"' 'key="<owner>/<repo>"'
reviewer_drift reviewer-backend-consent-not-binary-bound \
  "jq --arg k \"\$key\" --arg v \"\$val\" '.[\$k] = \$v' \"\$f\"" "jq --arg k \"\$key\" '.[\$k] = true' \"\$f\""
reviewer_drift reviewer-backend-consent-binary-change-silent 'or one naming a different binary' ''
reviewer_drift reviewer-backend-consent-unbounded-lock 'while [ "$n" -lt "$tries" ]; do' 'while :; do'
reviewer_drift reviewer-backend-git-setup-unreadable-ignored \
  'if [ -e "$path" ] && [ ! -r "$path" ]; then echo "cannot read $path" >&2; exit 1; fi' ':'
reviewer_drift reviewer-backend-git-setup-before-unchecked \
  'setup_before="$(git_setup_sum)" || { echo "cannot checksum' 'setup_before="$(git_setup_sum)" || true || { echo "cannot checksum'
reviewer_drift reviewer-backend-consent-no-try-limit 'dir="${f%/*}"; tries=50; n=0;' 'dir="${f%/*}"; n=0;'
reviewer_drift reviewer-backend-consent-follows-symlink '{ [ -L "$f" ] || [ ! -f "$f" ] ||' '{ [ ! -f "$f" ] ||'
reviewer_drift reviewer-backend-consent-seeds-symlink 'if [ ! -L "$f" ] && { [ ! -e "$f" ]' 'if true && { [ ! -e "$f" ]'
reviewer_drift reviewer-backend-consent-lock-file-waits '"$f.lock exists and is not a lock directory"; n=$tries' '"$f.lock exists and is not a lock directory"'
reviewer_drift reviewer-backend-consent-dir-unchecked 'if [ -d "$dir" ] && [ -w "$dir" ]; then' 'if true; then'
reviewer_drift reviewer-backend-locale-ranges 'LC_ALL=C; unset CDPATH' 'unset CDPATH'
reviewer_drift reviewer-backend-cdpath-common-dir \
  'git_common="$(git -C "$top" rev-parse --path-format=absolute --git-common-dir)"' 'git_common="$(cd "$top" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"'
reviewer_drift reviewer-backend-home-unset '[ -n "${HOME:-}" ] || { echo "HOME is unset' 'true || { echo "HOME is unset'
reviewer_drift reviewer-backend-effort-leading-dash 'case "$effort" in -*|*[!A-Za-z0-9_-]*)' 'case "$effort" in *[!A-Za-z0-9_-]*)'
reviewer_drift reviewer-backend-name-unchecked "case \"\$name\" in ''|*[!A-Za-z0-9_-]*)" "case \"\$name\" in ''|*[!A-Za-z0-9_./-]*)"
reviewer_drift reviewer-backend-base-leading-dash "case \"\$base\" in ''|-*|*[!A-Za-z0-9._/-]*)" "case \"\$base\" in ''|*[!A-Za-z0-9._/-]*)"
reviewer_drift reviewer-backend-config-shape-unchecked \
  "jq -e 'type == \"object\" and (.reviewers | type == \"object\")' \"\$cfg\"" "true \"\$cfg\""
reviewer_drift reviewer-backend-row-shape-ignored '<<< "$rows" > /dev/null \' '<<< "$rows" > /dev/null || true \'
reviewer_drift reviewer-backend-failure-parsed 'if [ "$backend_status" -ne 0 ]; then' 'if false; then'
reviewer_drift reviewer-backend-timeout-unbounded '. > 0 and . <= 86400)' '. >= 0)'
reviewer_drift reviewer-backend-findings-dotdot 'case "$src" in */..|*/../*) echo' 'case "$src" in */nope) echo'
reviewer_drift reviewer-backend-no-printenv-probe 'command -v printenv > /dev/null ||' 'true ||'
reviewer_drift reviewer-backend-consent-lock-symlink-waits 'if [ -L "$f.lock" ] || {' 'if false || {'
reviewer_drift reviewer-backend-git-hooks-unchecked \
  'case "$git_common$git_hooks" in /*) ;; *) echo' 'case "$git_common$git_hooks" in *) ;; /*) echo'
reviewer_drift reviewer-backend-consent-no-counter 'n=$((n + 1)); sleep 0.2' 'sleep 0.2'
reviewer_drift reviewer-backend-consent-writes-unlocked 'if [ -z "$locked" ]; then' 'if [ -n "$locked" ]; then'
reviewer_drift reviewer-backend-consent-dir-world-readable '(umask 077; mkdir -p "$dir")' 'mkdir -p "$dir"'
reviewer_drift reviewer-backend-consent-reset-on-bad-json \
  '{ [ ! -e "$f" ] || { [ -f "$f" ] && [ -r "$f" ] && ! LC_ALL=C grep -q' '{ [ ! -e "$f" ] || { [ -f "$f" ] && [ -r "$f" ] && ! jq -e . "$f" > /dev/null || grep -q'
reviewer_drift reviewer-backend-consent-overwrites-non-object \
  'if [ -z "$seed" ] && { [ -L "$f" ] ||' 'if false && { [ -L "$f" ] ||'
reviewer_drift reviewer-backend-consent-reads-non-files '|| [ ! -f "$f" ] || ! jq -e' '|| ! jq -e'
reviewer_drift reviewer-backend-consent-multi-doc "jq -e -s 'length == 1 and (.[0] | type == \"object\")'" "jq -e 'type == \"object\"'"
reviewer_drift reviewer-backend-consent-stop-exits-zero '; rc=2' ''
reviewer_drift reviewer-backend-consent-exit-ignores-rc '   exit "$rc"' '   exit 0'
reviewer_drift reviewer-backend-consent-no-jq-continues 'this run cannot continue without it" >&2; exit 2; }' 'this run cannot continue without it" >&2; exit 0; }'
reviewer_drift reviewer-backend-consent-seed-not-binary-bound "'{(\$k): \$v}'" "'{(\$k): true}'"
reviewer_drift reviewer-backend-consent-seed-any-content "grep -q '[^[:space:]]' \"\$f\"; }; }; then seed=1" "grep -q '.' \"\$f\"; }; }; then seed=1"
reviewer_drift reviewer-backend-consent-empty-write '&& [ -s "$tmp" ] && chmod 600' '&& chmod 600'
reviewer_drift reviewer-backend-tree-drops-other-entries \
  'elif [ ! -f "./$p" ] || [ ! -r "./$p" ]; then printf' 'elif false; then printf'
reviewer_drift reviewer-backend-consent-seeds-non-files '[ -f "$f" ] && [ -r "$f" ] && ! LC_ALL=C grep' '[ -r "$f" ] && ! LC_ALL=C grep'
reviewer_drift reviewer-backend-consent-lock-unchecked \
  'mkdir "$f.lock" 2>/dev/null && { locked=1; break; }' 'mkdir "$f.lock" 2>/dev/null; locked=1; break'
reviewer_drift reviewer-backend-consent-not-private '&& chmod 600 "$tmp" && mv' '&& mv'
reviewer_drift reviewer-backend-consent-release-on-failure-only \
  $'     fi\n     rmdir "$f.lock"\n   fi' $'       rmdir "$f.lock"\n     fi\n   fi'
reviewer_drift reviewer-backend-nested-skips-preflight \
  'Run every "## Pre-flight" item above before entering the loop' 'Run "## Pre-flight" items 1-7 above before entering the loop'

# --- require_phrases' missing-file branch, shared by all its callers ---
expect_fail require-phrases-missing-file \
  "rm $CMDS/code-review.md" \
  "code-review.md referenced by severity_checks but does not exist"

# --- severity tiers: a word-presence anchor and the order-declaring sentence ---
expect_fail severity-tier \
  "perl -pi -e 's/\\*\\*Nits\\*\\*/**Notes**/g' $CMDS/code-review.md" \
  "missing expected severity tier"

expect_fail severity-order \
  "perl -pi -e 's/each as its own table in fixed order: Blockers, Concerns, Suggestions, Nits/as tables/' $CMDS/code-review.md" \
  "missing expected severity tier"

expect_fail no-bucket-sentence \
  "perl -pi -e 's/does \\*\\*not\\*\\* use the three-bucket categorization/uses the three-bucket categorization/' $CMDS/code-review.md" \
  "no-bucket-categorization sentence"

# --- option-set literals: both copies of the contract ---
expect_fail option-set \
  "perl -pi -e 's{Post inline / Post as PR-level / Defer to follow-up / Dismiss}{Post / Defer}g' roles/claude/files/CLAUDE.md" \
  "CLAUDE.md missing /code-review option-set literal"

expect_fail option-set-code-review \
  "perl -pi -e 's{Post all inline / Post all as PR-level / Defer all to follow-up / Dismiss all / Pick individually}{Post all / Skip all}g' $CMDS/code-review.md" \
  "code-review.md missing option-set literal"

# --- resolver sync: both sides of the mirror ---
expect_fail resolver-sync \
  "perl -pi -e 's/grep -q panela/grep -q renamed/' $CMDS/code-review.md" \
  "missing shared resolver line"

expect_fail resolver-sync-panel \
  "perl -pi -e 's/grep -q panela/grep -q renamed/' $CMDS/panel-review.md" \
  "missing shared resolver line"

# --- submit gate: the single-line phrase, the hard-wrapped phrase the
# whitespace normalization exists for, and a reflow that must stay green ---
expect_fail submit-gate \
  "perl -0pi -e 's/never choose approval on my behalf/choose approval freely/' $CMDS/code-review.md" \
  "missing expected submit-gate sentence"

expect_fail submit-gate-wrapped \
  "perl -0pi -e 's/never\\s+submit\\s+any\\s+review\\s+without\\s+an\\s+explicitly\\s+chosen\\s+verdict/submit whatever/s' $CMDS/code-review.md" \
  "missing expected submit-gate sentence"

expect_pass submit-gate-reflow \
  "perl -0pi -e 's/explicitly chosen\\s+verdict/explicitly\\nchosen verdict/s' $CMDS/code-review.md"

# --- Slack contract: heading resolution and the sign-off shapes ---
expect_fail slack-heading \
  "perl -pi -e 's/^## Slack Notifications \\(review workflows\\)\$/## Slack Notes/' roles/claude/files/CLAUDE.md" \
  "no such heading exists"

expect_fail signoff-decoration \
  "perl -0pi -e 's/– clanky\\n/– clanky the bot\\n/' $CMDS/code-review.md" \
  "decoration after clanky"

expect_fail signoff-wrong-dash \
  "perl -0pi -e 's/– clanky/— clanky/' $CMDS/code-review.md" \
  "wrong dash"

expect_fail signoff-missing \
  "perl -0pi -e 's/^– clanky[ \\t]*\$//mg' $CMDS/peer-review.md" \
  "carries no"

# --- file-missing guards ---
expect_fail missing-file \
  "rm $CMDS/peer-review.md" \
  "does not exist"

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "skill-contracts-test: $failures case(s) failed"
  exit 1
fi
echo "skill-contracts-test: all cases pass"
