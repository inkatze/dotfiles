#!/usr/bin/env bash
# Fixture suite for skills/bot-review/surfaces.jq, the filter /bot-review runs
# over everything a hosted reviewer wrote on a PR: its reviews, its issue
# comments and its inline review comments. A vendor may put its run marker,
# its reviewed head or its finding keys on any of the three, so every marker is
# matched on every surface; these cases plant each marker on one surface only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ -f "$ROOT/lefthook.yml" ] || {
  echo "bot-review-surfaces-test: must run from the dotfiles checkout (ROOT resolved to $ROOT)"
  exit 1
}
LIB="$ROOT/roles/claude/files/skills/bot-review"
failures=0
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

CFG='{
  "login_pattern": "acme-bot\\[bot\\]",
  "build_id_regex": "acme:run=([0-9]+)",
  "finding_key_regex": "acme:v=([A-Za-z0-9/._-]+)",
  "reviewed_head_regex": "reviewed ([0-9a-f]{40})",
  "errored_review_regex": "unable to review"
}'
HEAD_A=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
HEAD_B=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb

# surfaces <reviews> <issue comments> <inline comments>: the filter's output.
surfaces() {
  jq -n -L "$LIB" --argjson cfg "$CFG" --argjson r "$1" --argjson i "$2" --argjson c "$3" \
    'include "surfaces"; {reviews: $r, issue_comments: $i, review_comments: $c} | bot_surfaces($cfg)'
}
check() {
  local name="$1" out="$2" expr="$3"
  jq -e "$expr" <<< "$out" > /dev/null || fail "$name" "output fails $expr: $out"
}

bot='{"login": "acme-bot[bot]"}'
human='{"login": "someone"}'

# Every marker on an inline comment or a review only; the issue comments hold
# nothing of the bot's.
out="$(surfaces \
  "[{\"id\": 10, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": \"Summary: reviewed $HEAD_A\"}]" \
  "[{\"id\": 20, \"user\": $human, \"updated_at\": \"2026-01-01T00:00:09Z\", \"body\": \"acme:run=999 reviewed $HEAD_B\"}]" \
  "[{\"id\": 30, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:06Z\", \"path\": \"a.sh\", \"original_line\": 3,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"Guard missing. <!-- acme:run=41 --> <!-- acme:v=k1 -->\"}]")"
check build-id-inline-only "$out" '.build_id.value == "41" and .build_id.surface == "review_comment"'
check reviewed-head-review-only "$out" ".reviewed_head.value == \"$HEAD_A\" and .reviewed_head.surface == \"review\""
check finding-key-inline-only "$out" '.findings | length == 1 and .[0].key == "k1" and .[0].surface == "review_comment"
  and .[0].id == 30 and .[0].path == "a.sh" and .[0].original_line == 3 and .[0].key_ok'
check human-markers-ignored "$out" '.build_id.value != "999" and (.reviewed_head.value // "" | startswith("b") | not)'
check counts-every-surface "$out" '.counts == {reviews: 1, issue_comments: 0, review_comments: 1,
  inline_findings: 1, description_level_findings: 0}'

# The opposite placement: run marker on a review, reviewed head on an inline
# comment, keys on a review body (a description-level finding).
out="$(surfaces \
  "[{\"id\": 11, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": \"acme:run=7 acme:v=k2 acme:v=k3\"}]" \
  '[]' \
  "[{\"id\": 31, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:04Z\", \"path\": \"b.sh\", \"original_line\": 1,
     \"original_commit_id\": \"$HEAD_B\", \"body\": \"reviewed $HEAD_B\"}]")"
check build-id-review-only "$out" '.build_id.value == "7" and .build_id.surface == "review"'
check reviewed-head-inline-only "$out" ".reviewed_head.value == \"$HEAD_B\" and .reviewed_head.surface == \"review_comment\""
check finding-keys-review-body "$out" '[.findings[] | select(.surface == "review") | .key] == ["k2", "k3"]'
check inline-without-key "$out" '[.findings[] | select(.surface == "review_comment")] | length == 0'

# The latest marker wins across surfaces, an edited summary by its edit time.
out="$(surfaces \
  "[{\"id\": 12, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": \"acme:run=1 reviewed $HEAD_A\"}]" \
  "[{\"id\": 21, \"user\": $bot, \"created_at\": \"2026-01-01T00:00:01Z\", \"updated_at\": \"2026-01-01T00:00:08Z\",
     \"body\": \"acme:run=2 reviewed $HEAD_B\"}]" \
  '[]')"
check latest-across-surfaces "$out" ".build_id.value == \"2\" and .build_id.surface == \"issue_comment\"
  and .reviewed_head.value == \"$HEAD_B\""

# Login matched in full, replies in a thread are not findings, an unsafe key is
# flagged for hashing, and an errored latest summary is reported.
out="$(surfaces \
  "[{\"id\": 13, \"user\": {\"login\": \"acme-bot[bot]-impostor\"}, \"submitted_at\": \"2026-01-01T00:00:09Z\", \"body\": \"acme:run=666\"},
    {\"id\": 14, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:07Z\", \"body\": \"acme:run=8 I was unable to review this PR\"}]" \
  '[]' \
  "[{\"id\": 32, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:03Z\", \"path\": \"c.sh\", \"original_line\": 2,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"acme:v=../../etc/passwd\"},
    {\"id\": 33, \"user\": $bot, \"in_reply_to_id\": 32, \"updated_at\": \"2026-01-01T00:00:04Z\", \"path\": \"c.sh\",
     \"original_line\": 2, \"original_commit_id\": \"$HEAD_A\", \"body\": \"acme:v=k9\"}]")"
check login-full-match "$out" '.build_id.value == "8" and .counts.reviews == 1'
check reply-not-finding "$out" '[.findings[].id] == [32]'
check unsafe-key-flagged "$out" '.findings[0].key_ok == false'
check errored-latest "$out" '.errored == true'

# Nothing from the bot: every marker null, no findings, not errored.
out="$(surfaces '[]' '[]' '[]')"
check empty "$out" '.build_id == null and .reviewed_head == null and .findings == [] and .errored == false'

# A bot body that is null (a review with no summary) is read as empty text.
out="$(surfaces "[{\"id\": 15, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": null}]" '[]' '[]')"
check null-body "$out" '.build_id == null and .counts.reviews == 1'

# A key on an issue comment is a description-level finding; the same key on a
# summary and on its inline comment is one finding, the inline one.
out="$(surfaces \
  "[{\"id\": 17, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": \"Summary lists acme:v=k5\"}]" \
  "[{\"id\": 22, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:06Z\", \"body\": \"Also acme:v=k6\"}]" \
  "[{\"id\": 34, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:04Z\", \"path\": \"d.sh\", \"original_line\": 4,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"acme:v=k5\"}]")"
check key-on-issue-comment "$out" '[.findings[] | select(.surface == "issue_comment") | .key] == ["k6"]'
check summary-key-deduped "$out" '[.findings[] | select(.key == "k5") | .surface] == ["review_comment"]
  and .counts.description_level_findings == 1 and .counts.inline_findings == 1'

# A later clean run clears an older errored summary, wherever the new run
# marker lands; error text on an inline finding is never a failed review.
out="$(surfaces \
  "[{\"id\": 18, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:01Z\", \"body\": \"acme:run=1 unable to review\"},
    {\"id\": 19, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:09Z\", \"body\": \"All good.\"}]" \
  '[]' \
  "[{\"id\": 35, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:08Z\", \"path\": \"e.sh\", \"original_line\": 1,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"<!-- acme:run=2 -->\"}]")"
check errored-cleared-by-later-run "$out" '.errored == false and .build_id.value == "2"'
out="$(surfaces \
  "[{\"id\": 20, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:01Z\", \"body\": \"acme:run=3\"}]" \
  '[]' \
  "[{\"id\": 36, \"user\": $bot, \"updated_at\": \"2026-01-01T00:00:08Z\", \"path\": \"e.sh\", \"original_line\": 1,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"I was unable to review this file\"}]")"
check errored-inline-ignored "$out" '.errored == false'
# The errored summary carries the latest run marker, which an inline comment
# of the same run repeats later: still errored.
out="$(surfaces \
  "[{\"id\": 23, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:01Z\", \"body\": \"acme:run=6 unable to review\"}]" \
  '[]' \
  "[{\"id\": 37, \"user\": $bot, \"updated_at\": \"2026-01-01T00:01:00Z\", \"path\": \"e.sh\", \"original_line\": 1,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"<!-- acme:run=6 -->\"}]")"
check errored-same-run "$out" '.errored == true'
out="$(surfaces \
  "[{\"id\": 26, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:01Z\", \"body\": \"acme:run=6 unable to review\"},
    {\"id\": 27, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:09Z\", \"body\": \"acme:run=6 All good.\"}]" \
  '[]' \
  "[{\"id\": 38, \"user\": $bot, \"updated_at\": \"2026-01-01T00:01:00Z\", \"path\": \"e.sh\", \"original_line\": 1,
     \"original_commit_id\": \"$HEAD_A\", \"body\": \"<!-- acme:run=6 -->\"}]")"
check errored-same-run-retried "$out" '.errored == false'

# A key repeated across summaries is one description-level finding, the latest.
out="$(surfaces \
  "[{\"id\": 24, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:01Z\", \"body\": \"acme:v=k10 and again acme:v=k10\"},
    {\"id\": 25, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:09Z\", \"body\": \"acme:v=k10\"}]" '[]' '[]')"
check summary-key-once "$out" '[.findings[] | [.key, .id]] == [["k10", 25]] and .counts.description_level_findings == 1'

# An alternation whose group did not take part yields no key, never the
# surrounding text.
CFG_SAVED="$CFG"
CFG="$(jq '.finding_key_regex = "acme:v=([a-z0-9]+)|acme:none|acme:id=([0-9]+)"' <<< "$CFG")"
out="$(surfaces "[{\"id\": 21, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": \"acme:none acme:v=k7 acme:id=42\"}]" '[]' '[]')"
check alternation-group "$out" '[.findings[].key] == ["42", "k7"]'
CFG="$CFG_SAVED"

# A reviewer missing from the config is an error, never an empty PR.
for entry in null '{"build_id_regex": "x"}'; do
  if jq -n -L "$LIB" --argjson e "$entry" 'include "surfaces"; {reviews: [], issue_comments: [], review_comments: []} | bot_surfaces($e)' \
    > /dev/null 2>&1; then
    fail "unknown-reviewer ($entry)" "a missing reviewer, or one with no login_pattern, read as a PR with no activity"
  fi
done

# The command the skill runs: paginated pages slurped per surface, the config
# read from its file.
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
printf '[{"id": 40, "user": %s, "submitted_at": "2026-01-01T00:00:05Z", "body": "acme:run=5"}][]' "$bot" > "$scratch/reviews.json"
printf '[]' > "$scratch/issue_comments.json"
printf '[{"id": 41, "user": %s, "updated_at": "2026-01-01T00:00:01Z", "path": "f.sh", "original_line": 2, "original_commit_id": "%s", "body": "acme:v=k8"}][{"id": 42, "user": %s, "updated_at": "2026-01-01T00:00:02Z", "path": "f.sh", "original_line": 3, "original_commit_id": "%s", "body": "acme:v=k9"}]' \
  "$bot" "$HEAD_A" "$bot" "$HEAD_A" > "$scratch/review_comments.json"
jq -n --argjson e "$CFG" '{version: 1, default: "acme", reviewers: {acme: $e}}' > "$scratch/bot-review.json"
out="$(jq -n -L "$LIB" --slurpfile rv "$scratch/reviews.json" --slurpfile ic "$scratch/issue_comments.json" \
  --slurpfile rc "$scratch/review_comments.json" --slurpfile cfg "$scratch/bot-review.json" --arg name acme \
  'include "surfaces"; {reviews: ($rv | add // []), issue_comments: ($ic | add // []), review_comments: ($rc | add // [])} | bot_surfaces($cfg[0].reviewers[$name])')"
check skill-command-pages "$out" '.build_id.value == "5" and [.findings[].key] == ["k8", "k9"]'

# No errored pattern configured: errored is false, never an error.
CFG="$(jq 'del(.errored_review_regex)' <<< "$CFG")"
out="$(surfaces "[{\"id\": 16, \"user\": $bot, \"submitted_at\": \"2026-01-01T00:00:05Z\", \"body\": \"unable to review\"}]" '[]' '[]')"
check errored-unconfigured "$out" '.errored == false'

if [ "$failures" -gt 0 ]; then
  echo ""
  echo "bot-review-surfaces-test: $failures case(s) failed"
  exit 1
fi
echo "bot-review-surfaces-test: all cases pass"
