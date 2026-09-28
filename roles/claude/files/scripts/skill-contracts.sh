#!/usr/bin/env bash
# Contract-consistency checker for the dotfiles-local review command files
# (panel-review, peer-review, copilot-review, code-review, bot-review) and
# the tracked global CLAUDE.md they share contracts with. Asserted invariant
# classes:
# the three-bucket presentation contract (and code-review's deliberate
# inverse of it: severity tiers, no buckets), the panel-pairing /
# copilot-pairing retirement into --nested, the retired Ollama backend
# names, copilot-review's mark-ready confirmation gate, bot-review's
# single-mutation safety sentences, JSON validity of commands/*.json,
# code-review's review-submission gate, the /code-review
# option-set literals mirrored in CLAUDE.md, the code-review/panel-review
# backend-resolver sync lines, panel-review's reviewer-backend containment
# lines, and the Slack notification contract. Runs as
# a lefthook pre-commit job (glob in lefthook.yml: the command files,
# CLAUDE.md, this script, and its fixture suite) and in CI alongside
# skill-contracts-test.sh, which plants drifts to prove these checks fire.
#
# The spec-driven pipeline skills (orchestrate, execute-task, spec-draft,
# spec-kickoff, polish, self-review, resume) moved to the planwright plugin,
# which carries its own contract tests; only the review commands that stay in
# this repo are checked here.
set -euo pipefail

CMDS="roles/claude/files/commands"
GLOBAL_MD="roles/claude/files/CLAUDE.md"
errors=0

err() { echo "ERROR: $1"; errors=$((errors + 1)); }

# require_phrases <file> <array-name> <label> <phrase>... : each phrase must appear verbatim in $CMDS/<file>.
require_phrases() {
  local file="$1" name="$2" label="$3" phrase
  shift 3
  if [ -f "$CMDS/$file" ]; then
    # One read and builtin matching: a grep per phrase dominated the fixture
    # suite's runtime once the reviewer-backend anchors grew.
    local body=""
    IFS= read -r -d "" body < "$CMDS/$file" || true
    for phrase in "$@"; do
      if [[ "$body" != *"$phrase"* ]]; then
        err "$file missing expected $label: \"$phrase\""
      fi
    done
  else
    err "$file referenced by $name but does not exist at $CMDS/$file"
  fi
}

# JSON validity for any example config shipped alongside a command (currently
# bot-review.config.example.json). Nothing else in this repo's CI or hooks
# reads these files, so a malformed edit would otherwise go undetected until
# someone tried to use it as a template.
if command -v jq >/dev/null 2>&1; then
  for f in "$CMDS"/*.json; do
    [ -e "$f" ] || continue
    if ! jq empty "$f" >/dev/null 2>&1; then
      err "$f is not valid JSON"
    fi
  done
else
  err "jq is required to validate $CMDS/*.json but is not on PATH"
fi

# Three-bucket presentation contract (Finding Categorization). Anchored to
# each file's own specific declarative sentence rather than a shared
# alternation-regex across files: a shared regex lets an unrelated match
# elsewhere in the same file (e.g. "three-pass" validation prose) mask a real
# regression in the sentence that actually declares the bucket count. This is
# the exact gap the v1-retrospective (specs/pair-flow/research/v1-retrospective.md:89)
# already caught once ("three findings tables" drifted to four undetected).
#
# panel-review.md carries two anchor sentences, not one, both inside the
# shared Steps 1-6 pipeline that standalone and --nested both run identically
# (step 5's "bucket out of three" phrasing and step 6's "three findings
# tables" phrasing); neither is nested-only. copilot-review.md carries a
# third, analogous anchor for its own adjacent-findings output ("Three
# adjacent-findings tables"). All three must independently hold.
#
# NOTE: each check below is an explicit if-block, not a `cond && ! grep &&
# err` chain. Under `set -e`, a chain like that exits the script silently
# the moment grep SUCCEEDS (the good case): the short-circuited `&&` list
# evaluates to non-zero as the last command run, and errexit kills the
# script before `err` (or anything after it) ever runs. Bare-loop chains of
# that shape happened not to trip it in testing, but it's fragile either
# way; explicit ifs are unambiguous under set -e.
bucket_checks=(
  "panel-review.md|three findings tables in fixed order"
  "panel-review.md|bucket out of three: Auto-applicable, Needs sign-off, or Needs human judgment"
  "peer-review.md|the validated threads as three tables"
  "copilot-review.md|Three adjacent-findings tables"
  "bot-review.md|Present all three tables, in fixed order"
)
# Derived from bucket_checks, not hand-maintained, so the Agent-resolvable
# guard below can never drift out of sync with the files bucket_checks
# actually covers (a malformed entry is reported by the main loop below;
# this pass just skips it rather than double-reporting).
bucket_files=""
for check in "${bucket_checks[@]}"; do
  case "$check" in
    *'|'*) f="${check%%|*}" ;;
    *) continue ;;
  esac
  case " $bucket_files " in
    *" $f "*) ;;
    *) bucket_files="$bucket_files $f" ;;
  esac
done
for check in "${bucket_checks[@]}"; do
  case "$check" in
    *'|'*) ;;
    *) err "malformed bucket_checks entry (missing '|' separator): \"$check\""; continue ;;
  esac
  f="${check%%|*}"
  phrase="${check#*|}"
  if [ -f "$CMDS/$f" ]; then
    if ! grep -qF "$phrase" "$CMDS/$f"; then
      err "$f missing expected bucket-count sentence: \"$phrase\""
    fi
  else
    err "$f referenced in bucket_checks but does not exist at $CMDS/$f"
  fi
done
# Guard against the retired bucket being reintroduced under wording the
# sentence checks above wouldn't catch.
for f in $bucket_files; do
  if [ -f "$CMDS/$f" ] && grep -q 'Agent-resolvable' "$CMDS/$f"; then
    err "$f references the retired Agent-resolvable bucket"
  fi
done

# Retired-files guard. panel-pairing.md and copilot-pairing.md were folded
# into panel-review.md / copilot-review.md's --nested flag; if either
# reappears, the fold either regressed or is being silently duplicated.
for retired in panel-pairing.md copilot-pairing.md; do
  if [ -f "$CMDS/$retired" ]; then
    err "$retired exists but was retired into --nested; remove it or update this guard if reintroducing it is intentional"
  fi
done

# Retired-backend sweep. The Ollama-backed qwen-coder / gpt-oss backends were
# dropped from /panel-review along with the daemon that served them, and
# OLLAMA_BASE_URL was the knob only they read; a name reappearing in a command
# file or the tracked CLAUDE.md re-advertises a backend that can only fail
# with connection-refused.
for retired_name in qwen-coder gpt-oss OLLAMA_BASE_URL; do
  for path in "$CMDS"/*.md "$GLOBAL_MD"; do
    [ -f "$path" ] || continue
    if grep -qF "$retired_name" "$path"; then
      err "$(basename "$path") references the retired backend name '$retired_name'; nothing provisions Ollama any more (see the dotfiles CLAUDE.md), so remove it or update this sweep if reintroducing it is intentional"
    fi
  done
done

# Mark-ready safety anchor. copilot-review.md's nested loop may flip a PR
# ready only at convergence and only after an explicit per-run confirmation;
# this is the one PR-lifecycle mutation the loop is allowed, so its two
# guarding sentences must not silently drift or disappear.
mark_ready_checks=(
  "This confirmation-gated ready-flip is the only PR-lifecycle action this loop takes, and only on this exit path."
  "Never automatically, never on a diminishing-returns/stop-condition/iteration-cap exit, and never for create or merge"
)
require_phrases copilot-review.md mark_ready_checks "mark-ready safety sentence" "${mark_ready_checks[@]}"

# Single-mutation safety anchors for bot-review.md. It permits exactly three
# PR-lifecycle mutations (a confirmation-gated opt-in label add, an applied
# Auto-applicable fix, and a Needs-sign-off deferral reply) and forbids
# everything else (auto-adding a label speculatively, applying a Needs-sign-off
# code change while nested, force-pushing, merging, marking ready); these are
# the same class of guarantee mark_ready_checks protects for copilot-review.md,
# so bot-review.md gets the same drift protection.
bot_review_safety_checks=(
  "Never apply the code change in this bucket while nested."
  "force-push, push to a protected branch, mark the PR ready, or merge"
  "Do not add the opt-in label speculatively"
)
require_phrases bot-review.md bot_review_safety_checks "safety sentence" "${bot_review_safety_checks[@]}"

# Containment for panel-review's reviewer:<name> backend, which runs a vendor
# CLI from the repo root rather than an empty scratch dir. Each anchor pins the
# guard itself, not just its message: bounded with a kill-after, argv built by
# a whitespace split (no eval, no globbing), the resolved binary exec'd, the
# split EXIT/INT traps, the empty, multi-document and row-shape stops that
# keep a silent or partial run from reading as zero findings, the env -i
# allowlist read through printenv, the PATH filter and in-repo checks on the
# binary and timeout, the jq and realpath probes, the git-setup checksum and
# isolated git calls, the working-tree check, the findings file's realpath
# containment, and the egress consent asked once per repo and reviewer
# (binary-bound, under a bounded lock, private directory, exit 2 to stop,
# never overwriting a file that is unreadable, not a regular file, or not a
# single JSON object).
reviewer_backend_checks=(
  '"$tbin" -k 30 "$secs" "${argv[@]}" < /dev/null'
  "IFS=\$' \\t' read -r -a words <<< \"\$tpl\""
  'argv[0]="$bin_abs"'
  "trap 'rm -rf \"\$work\"' EXIT"
  '[ -f "$src" ] && [ -s "$src" ] || { echo "reviewer CLI exited 0 but left no findings'
  "jq -e -s 'length == 1' \"\$src\""
  'cli.findings_jq must yield one array of {file, line, finding, severity, rule}'
  '/usr/bin/env -i "${env_kept[@]}" "$tbin"'
  '[ "$v" != PATH ] && val="$(printenv "$v")" && env_kept+=("$v=$val")'
  'and test("^[A-Za-z_][A-Za-z0-9_]*$")) then .[] else error("") end'
  '|| { echo "cli.env_allow must be a list of variable names" >&2; exit 1; }'
  'x="$(cd "$1" 2>/dev/null && pwd -P)" || return 2'
  'while [ -n "$x" ]; do [ "$x" -ef "$top" ] && return 0; x="${x%/*}"; done'
  'in_repo "$dir"; [ "$?" -eq 1 ] || continue'
  'command -v realpath > /dev/null ||'
  '  PATH="$safe_path"'
  'env_kept=("PATH=$safe_path")'
  'bin_real="$(realpath "$bin_abs")" ||'
  'in_repo "${bin_real%/*}/"; [ "$?" -eq 1 ] ||'
  '[ "$bin_abs" = "$approved" ] ||'
  'tbin_real="$(realpath "$tbin")" ||'
  'in_repo "${tbin_real%/*}/"; [ "$?" -eq 1 ] ||'
  'case "$tbin" in *=*|[!/]*)'
  'git_isolated status --porcelain --untracked-files=all || exit 1'
  'git_isolated diff HEAD --binary --no-ext-diff --no-textconv | cksum || exit 1'
  'git_isolated ls-files -v | cksum || exit 1'
  'git_isolated ls-files -oz --exclude-standard > "$list" || exit 1'
  'done < "$list" | xargs -0 cksum -- || exit 1'
  '    set -o pipefail'
  'if [ -L "./$p" ]; then printf'
  'git_isolated rev-parse HEAD || exit 1'
  'git_isolated symbolic-ref -q HEAD || echo detached'
  '/usr/bin/env -i "${env_kept[@]}" GIT_CONFIG_NOSYSTEM=1'
  'git -c core.fsmonitor=false -c core.untrackedCache=false -c core.hooksPath=/dev/null -C "$top" "$@"'
  '"$git_dir/commondir" "$git_dir/gitdir" "$top/.git"'
  'if [ -f "$path" ]; then printf '"'"'%s %s %s\n'"'"' "$path" "$([ -x "$path" ] && echo exec)"'
  'git rev-parse --path-format=absolute --git-path hooks)"'
  '"$git_hooks" "$git_hooks"/*; do'
  '"$git_common/info/exclude" "$git_common/info/attributes"'
  '"$(readlink "$path")"; fi'
  'this run cannot continue without it" >&2; exit 2; }'
  "jq -n --arg k \"\$key\" --arg v \"\$val\" '{(\$k): \$v}'"
  "grep -q '[^[:space:]]' \"\$f\"; }; }; then seed=1; fi"
  '&& [ -s "$tmp" ] && chmod 600 "$tmp" && mv "$tmp" "$f"; }; then'
  'elif [ ! -f "./$p" ] || [ ! -r "./$p" ]; then printf'
  'command -v jq > /dev/null || { echo "jq is not on the filtered PATH"'
  'command -v printenv > /dev/null || { echo "printenv is not on the filtered PATH"'
  'elif [ "$tree_after" != "$tree_before" ]; then'
  '[ -z "$tree_msg" ] || { echo "$tree_msg" >&2; exit 1; }'
  'case "$(realpath "$src")" in "$(realpath "$out")"/*) ;;'
  '6. **Egress consent, once per repo and reviewer (`reviewer:<name>` only).**'
  'it reads the whole repo tree, not just the diff, and uploads it to that vendor'
  'Anything other than a yes stops the run.'
  'key="reviewer:<name>:<owner>/<repo>"'
  "jq --arg k \"\$key\" --arg v \"\$val\" '.[\$k] = \$v' \"\$f\""
  'or one naming a different binary'
  'while [ "$n" -lt "$tries" ]; do'
  'dir="${f%/*}"; tries=50; n=0;'
  'if [ -e "$path" ] && [ ! -r "$path" ]; then echo "cannot read $path" >&2; exit 1; fi'
  'setup_before="$(git_setup_sum)" || { echo "cannot checksum'
  'if [ -L "$f.lock" ] || { [ -e "$f.lock" ] && [ ! -d "$f.lock" ]; }; then'
  'case "$git_common$git_hooks" in /*) ;; *) echo "cannot resolve git'"'"'s directories'
  'git_common="$(git -C "$top" rev-parse --path-format=absolute --git-common-dir)"'
  'LC_ALL=C; unset CDPATH'
  '[ -n "${HOME:-}" ] || { echo "HOME is unset'
  'case "$effort" in -*|*[!A-Za-z0-9_-]*)'
  'case "$name" in '"''"'|*[!A-Za-z0-9_-]*)'
  'case "$base" in '"''"'|-*|*[!A-Za-z0-9._/-]*)'
  'jq -e '"'"'type == "object" and (.reviewers | type == "object")'"'"' "$cfg"'
  '<<< "$rows" > /dev/null \'
  'if [ "$backend_status" -ne 0 ]; then'
  'select(type == "number" and . == floor and . > 0 and . <= 86400)'
  'case "$src" in */..|*/../*) echo'
  'why="$f.lock exists and is not a lock directory"; n=$tries'
  'if [ -d "$dir" ] && [ -w "$dir" ]; then'
  'if ! setup_after="$(git_setup_sum)" || [ "$setup_after" != "$setup_before" ]; then'
  'n=$((n + 1)); sleep 0.2'
  'mkdir "$f.lock" 2>/dev/null && { locked=1; break; }'
  'if [ -z "$locked" ]; then'
  '(umask 077; mkdir -p "$dir")'
  'if [ ! -L "$f" ] && { [ ! -e "$f" ] || { [ -f "$f" ] && [ -r "$f" ] && ! LC_ALL=C grep -q'
  'if [ -z "$seed" ] && { [ -L "$f" ] || [ ! -f "$f" ] || ! jq -e -s '"'"'length == 1 and (.[0] | type == "object")'"'"' "$f"'
  'echo "$f is a symlink, unreadable, not a regular file, or not a single JSON object; nothing recorded or overwritten" >&2; rc=2'
  '   exit "$rc"'
  'Run every "## Pre-flight" item above before entering the loop'
)
require_phrases panel-review.md reviewer_backend_checks "reviewer-backend containment line" "${reviewer_backend_checks[@]}"
# The consent lock is released after the write whether or not it succeeded,
# so the rmdir must sit after the failure branch's fi, not inside it.
if [ -f "$CMDS/panel-review.md" ] \
  && ! perl -0ne 'exit(index($_, "     fi\n     rmdir \"\$f.lock\"\n   fi") < 0 ? 1 : 0)' "$CMDS/panel-review.md"; then
  err "panel-review.md missing expected reviewer-backend containment line: the consent lock's release after the write"
fi
# The combined trap shape resumes after Ctrl-C with $work already deleted.
if [ -f "$CMDS/panel-review.md" ] && grep -qF "trap 'rm -rf \"\$work\"' EXIT INT" "$CMDS/panel-review.md"; then
  err "panel-review.md combines the reviewer backend's EXIT and INT traps; keep them split"
fi

# Severity-tier contract for code-review.md. It is checked against its OWN
# anchors rather than being added to bucket_checks: per CLAUDE.md, commands that
# only draft output for elsewhere skip the finding categorization and present
# severity-grouped instead, so both the bucket-count sentence and the
# Agent-resolvable guard would be wrong for it. Before this, code-review.md was
# globbed by the lefthook job but matched by no check at all.
severity_checks=(
  "**Blockers**"
  "**Concerns**"
  "**Suggestions**"
  "**Nits**"
  "each as its own table in fixed order: Blockers, Concerns, Suggestions, Nits"
)
require_phrases code-review.md severity_checks "severity tier" "${severity_checks[@]}"

# code-review presentation contract: severity-grouped, deliberately NOT the
# three-bucket categorization. The declaring sentence must not silently
# invert, and the retired bucket must not sneak in here either (this file is
# outside bucket_files, so the sweep above does not cover it).
if [ -f "$CMDS/code-review.md" ]; then
  if ! grep -qF 'does **not** use the three-bucket categorization' "$CMDS/code-review.md"; then
    err "code-review.md missing its no-bucket-categorization sentence"
  fi
  if grep -q 'Agent-resolvable' "$CMDS/code-review.md"; then
    err "code-review.md references the retired Agent-resolvable bucket"
  fi
else
  err "code-review.md referenced by the no-bucket-categorization check but does not exist at $CMDS/code-review.md"
fi

# The /code-review option sets are stated verbatim in both CLAUDE.md and the
# command file; two copies of one contract, so both must carry the literals.
optset_checks=(
  "Post inline / Post as PR-level / Defer to follow-up / Dismiss"
  "Post all inline / Post all as PR-level / Defer all to follow-up / Dismiss all / Pick individually"
)
[ -f "$CMDS/code-review.md" ] || err "code-review.md referenced by optset_checks but does not exist at $CMDS/code-review.md"
[ -f "$GLOBAL_MD" ] || err "CLAUDE.md referenced by optset_checks but does not exist at $GLOBAL_MD"
for phrase in "${optset_checks[@]}"; do
  if [ -f "$CMDS/code-review.md" ] && ! grep -qF "$phrase" "$CMDS/code-review.md"; then
    err "code-review.md missing option-set literal: \"$phrase\""
  fi
  if [ -f "$GLOBAL_MD" ] && ! grep -qF "$phrase" "$GLOBAL_MD"; then
    err "CLAUDE.md missing /code-review option-set literal: \"$phrase\""
  fi
done

# Backend-resolver sync: code-review.md mirrors panel-review.md's Pre-flight
# resolver line for line (the trailing case mapping is code-review-only).
# These are the shared load-bearing lines; a drift in either file breaks the
# documented sync invariant.
resolver_lines=(
  'alias_file="${DOTFILES_HOST_FILE:-$HOME/.config/dotfiles/host}"'
  '[ -n "$from_file" ]'
  'hostname | grep -q panela'
)
for f in code-review.md panel-review.md; do
  if [ -f "$CMDS/$f" ]; then
    for lineph in "${resolver_lines[@]}"; do
      if ! grep -qF "$lineph" "$CMDS/$f"; then
        err "$f missing shared resolver line: \"$lineph\""
      fi
    done
  else
    err "$f referenced by resolver_lines but does not exist at $CMDS/$f"
  fi
done

# Submit-gate safety anchor for code-review.md. The command submits the
# review to GitHub itself, which is its one outward mutation of someone
# else's PR; the sentences gating that submission on an explicit human
# verdict, and keeping unapproved comments out of it, must not silently
# drift or disappear. Same posture as copilot-review's mark-ready anchor.
submit_gate_checks=(
  "never submit any review without an explicitly chosen verdict"
  "never choose approval on my behalf"
  "deferred and dismissed items are never posted"
)
if [ -f "$CMDS/code-review.md" ]; then
  # Whitespace-normalized match: these sentences sit inside hard-wrapped
  # paragraphs, so a routine reflow must not break the anchor.
  normalized="$(tr -s '[:space:]' ' ' < "$CMDS/code-review.md")"
  for phrase in "${submit_gate_checks[@]}"; do
    case "$normalized" in
      *"$phrase"*) ;;
      *) err "code-review.md missing expected submit-gate sentence: \"$phrase\"" ;;
    esac
  done
else
  err "code-review.md referenced by submit_gate_checks but does not exist at $CMDS/code-review.md"
fi

# Slack notification contract. Any command citing the shared mechanism must cite
# a heading that actually resolves, and must carry the exact sign-off, because
# both reach a colleague rather than staying in the repo.
#
# The sign-off's leading character is an EN DASH (U+2013). A hyphen or em dash
# there is invisible in review and lands in someone's DMs.
SIGNOFF='– clanky'
SLACK_SECTION='Slack Notifications (review workflows)'
slack_citers=""
for path in "$CMDS"/*.md; do
  [ -f "$path" ] || continue
  if grep -qF "$SLACK_SECTION" "$path"; then
    slack_citers="$slack_citers $(basename "$path")"
  fi
done
if [ -n "$slack_citers" ]; then
  if [ ! -f "$GLOBAL_MD" ]; then
    err "commands cite \"$SLACK_SECTION\" but $GLOBAL_MD does not exist"
  elif ! grep -qF "## $SLACK_SECTION" "$GLOBAL_MD"; then
    err "commands cite \"$SLACK_SECTION\" but no such heading exists in $GLOBAL_MD"
  fi
  for f in $slack_citers; do
    # Every sign-off-shaped line must be exactly the canonical literal:
    # EN DASH (U+2013), space, clanky, nothing decorating the name. Three
    # counts, so one drifted occurrence among several correct ones is
    # caught (a boolean grep would wave it through). The multibyte dashes
    # appear only inside alternation groups, never a bracket expression: a
    # byte-wise matcher (BSD grep in a non-UTF-8 locale) splits a bracketed
    # multibyte character into garbage bytes, while alternation of literal
    # strings stays byte-exact in any locale. The wrong-dash pattern
    # requires the exact sign-off shape (line ends after clanky) so a prose
    # bullet like "- clanky never ..." cannot false-positive; the residual
    # blind spot (a wrong dash AND a decoration on the same line) is
    # accepted for that. grep -c prints 0 on no matches (exit 1) and prints
    # nothing on a read error (exit 2), so an empty capture means the file
    # could not be read, not a clean pass.
    exact=$(grep -cE '^[[:space:]]*– clanky[[:space:]]*$' "$CMDS/$f" || true)
    wrongdash=$(grep -cE '^[[:space:]]*(-|—)[[:space:]]*clanky[[:space:]]*$' "$CMDS/$f" || true)
    decorated=$(grep -cE '^[[:space:]]*–[[:space:]]*clanky[[:space:]]+[^[:space:]]' "$CMDS/$f" || true)
    if [ -z "$exact" ] || [ -z "$wrongdash" ] || [ -z "$decorated" ]; then
      err "$f: grep could not read the file while checking sign-offs"
      continue
    fi
    if [ "$exact" -eq 0 ]; then
      err "$f cites the Slack section but carries no \"$SIGNOFF\" sign-off literal"
    fi
    if [ "$wrongdash" -gt 0 ]; then
      err "$f has a sign-off with a wrong dash (hyphen or em dash); every occurrence must be exactly \"$SIGNOFF\" on its own line"
    fi
    if [ "$decorated" -gt 0 ]; then
      err "$f has a decoration after clanky; the sign-off is exactly \"$SIGNOFF\" on its own line with nothing after the name"
    fi
  done
fi

if [ "$errors" -gt 0 ]; then
  echo ""
  echo "skill-contracts: $errors invariant(s) broken"
  exit 1
fi
echo "skill-contracts: all invariants hold"
