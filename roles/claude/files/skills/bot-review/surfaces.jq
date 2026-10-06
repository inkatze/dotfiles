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

# The value a match yields: the first capture group that took part, or the
# whole match when the regex has no group, so an alternation never hands back
# its surrounding text and never loses a branch.
def _value:
  if (.captures | length) == 0 then .string
  else [.captures[].string | select(. != null)] | first // empty end;

# The latest item a regex yields a value on, with that value.
def _latest_marker($items; $re):
  if ($re // "") == "" then null
  else [$items[] | ([.body | match($re; "g") | _value] | last) as $v
        | select($v != null) | {value: $v, surface, id, at}]
    | sort_by(.at, .id) | last
  end;

def bot_surfaces($cfg):
  if ($cfg | type) != "object" or ($cfg.login_pattern // "") == ""
  then error("no such reviewer in the config, or it has no login_pattern") else . end
  | [_surface_items($cfg)] as [$reviews, $issue, $inline]
  | ($reviews + $issue + $inline) as $all
  | _latest_marker($all; $cfg.build_id_regex) as $build
  # Error text is read off summaries only: an inline finding can quote it.
  | ($cfg.errored_review_regex // "") as $err
  | (if $err == "" then null
     else [($reviews + $issue)[] | select(.body | test($err))] | sort_by(.at, .id) | last end) as $error
  | [ $all[] as $i
      | if ($cfg.finding_key_regex // "") == "" then empty
        else $i.body | match($cfg.finding_key_regex; "g") | _value end
      | {surface: $i.surface, id: $i.id, key: ., at: $i.at,
         key_ok: test("^[A-Za-z0-9._:-]{1,128}$")}
        + (if $i.surface == "review_comment"
           then {path: $i.path, original_line: $i.original_line,
                 original_commit_id: $i.original_commit_id}
           else {} end) ] as $keyed
  # A key a summary repeats (twice in one body, or across re-reviews) is one
  # description-level finding, the latest; one its inline comment also
  # carries is the inline finding alone.
  | ([$keyed[] | select(.surface == "review_comment") | .key]) as $inline_keys
  | ([$keyed[] | select(.surface == "review_comment")]
     + ([$keyed[] | select(.surface != "review_comment"
                          and (.key as $k | $inline_keys | index([$k]) | not))]
        | group_by(.key) | map(sort_by(.at, .id) | last))) as $findings
  | {
      counts: {reviews: ($reviews | length), issue_comments: ($issue | length),
               review_comments: ($inline | length),
               inline_findings: ([$findings[] | select(.surface == "review_comment")] | length),
               description_level_findings: ([$findings[] | select(.surface != "review_comment")] | length)},
      build_id: $build,
      reviewed_head: _latest_marker($all; $cfg.reviewed_head_regex),
      # Errored when the latest error summary carries the latest run marker or
      # is at least as new as it, so a later clean run clears an old failure.
      errored: ($error != null
        and ($build == null or $error.at >= $build.at
             or ([$error.body | match($cfg.build_id_regex; "g") | _value] | index([$build.value])) != null)),
      findings: $findings
    };
