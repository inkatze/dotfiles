# What one hosted reviewer wrote on a PR, read off all three surfaces it can
# write to: reviews, issue comments and inline review comments. A vendor may put
# its run marker, reviewed head or finding keys on any of them, so each regex is
# matched on every surface; assuming one surface per marker misses vendors that
# split them.
#
# Input: {reviews, issue_comments, review_comments}, each the flat array the
# REST endpoint returns. $cfg is one reviewer entry of the review config.

def _surface_items($cfg):
  "^(?:\($cfg.login_pattern))$" as $login
  | ([.reviews[]? | {surface: "review", at: (.submitted_at // "")} + .],
     [.issue_comments[]? | {surface: "issue_comment", at: (.updated_at // .created_at // "")} + .],
     [.review_comments[]? | select(.in_reply_to_id == null)
      | {surface: "review_comment", at: (.updated_at // .created_at // "")} + .])
  | map(select((.user.login // "") | test($login)) | .body = (.body // ""));

# The value a match yields: its first capture group, or the whole match when
# the regex has no group. A group that exists but did not take part yields
# nothing, so an alternation never hands back its surrounding text.
def _value:
  if (.captures | length) == 0 then .string else .captures[0].string // empty end;

# The latest item whose body the regex matches, with its value.
def _latest_marker($items; $re):
  if ($re // "") == "" then null
  else [$items[] | select(.body | test($re))] | sort_by(.at, .id) | last
    | if . == null then null
      else ([.body | match($re; "g") | _value] | last) as $v
        | if $v == null then null else {value: $v, surface, id, at} end end
  end;

def bot_surfaces($cfg):
  if ($cfg | type) != "object" or ($cfg.login_pattern // "") == ""
  then error("no such reviewer in the config, or it has no login_pattern") else . end
  | [_surface_items($cfg)] as [$reviews, $issue, $inline]
  | ($reviews + $issue + $inline) as $all
  | _latest_marker($all; $cfg.build_id_regex) as $build
  | _latest_marker($all; $cfg.errored_review_regex) as $error
  | [ $all[] as $i
      | if ($cfg.finding_key_regex // "") == "" then empty
        else $i.body | match($cfg.finding_key_regex; "g") | _value end
      | {surface: $i.surface, id: $i.id, key: ., at: $i.at,
         key_ok: test("^[A-Za-z0-9._:-]{1,128}$")}
        + (if $i.surface == "review_comment"
           then {path: $i.path, original_line: $i.original_line,
                 original_commit_id: $i.original_commit_id}
           else {} end) ] as $keyed
  # A summary that lists a key its inline comment also carries is the same
  # finding, kept once, as the inline one.
  | ([$keyed[] | select(.surface == "review_comment") | .key]) as $inline_keys
  | ([$keyed[] | select(.surface == "review_comment"
                        or (.key as $k | $inline_keys | index([$k]) | not))]) as $findings
  | {
      counts: {reviews: ($reviews | length), issue_comments: ($issue | length),
               review_comments: ($inline | length),
               inline_findings: ([$findings[] | select(.surface == "review_comment")] | length),
               description_level_findings: ([$findings[] | select(.surface != "review_comment")] | length)},
      build_id: $build,
      reviewed_head: _latest_marker($all; $cfg.reviewed_head_regex),
      # Errored when the error text is at least as new as the latest run
      # marker, so a later clean run clears an old failure.
      errored: ($error != null and ($build == null or $error.at >= $build.at)),
      findings: $findings
    };
