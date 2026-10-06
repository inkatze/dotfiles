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

# The latest item whose body the regex matches, with its first capture group
# (or the whole match when the regex has none).
def _latest_marker($items; $re):
  if ($re // "") == "" then null
  else [$items[] | select(.body | test($re))] | sort_by(.at, .id) | last
    | if . == null then null
      else (.body | [match($re; "g")] | last | (.captures[0].string // .string)) as $v
        | {value: $v, surface, id, at} end
  end;

def bot_surfaces($cfg):
  [_surface_items($cfg)] as [$reviews, $issue, $inline]
  | ($reviews + $issue + $inline) as $all
  | {
      counts: {reviews: ($reviews | length), issue_comments: ($issue | length),
               review_comments: ($inline | length)},
      build_id: _latest_marker($all; $cfg.build_id_regex),
      reviewed_head: _latest_marker($all; $cfg.reviewed_head_regex),
      # The latest summary (a review or issue comment carrying the run marker
      # or the error text) reports an errored review rather than a clean one.
      errored: (($cfg.errored_review_regex // "") as $err
        | if $err == "" then false
          else [($reviews + $issue)[]
                | select(.body as $b | ($b | test($err))
                    or (($cfg.build_id_regex // "") != "" and ($b | test($cfg.build_id_regex))))]
            | sort_by(.at, .id) | last | (.body // "") | test($err) end),
      findings: [
        $all[] as $i
        | if ($cfg.finding_key_regex // "") == "" then empty
          else $i.body | match($cfg.finding_key_regex; "g") | (.captures[0].string // .string) end
        | {surface: $i.surface, id: $i.id, key: ., at: $i.at,
           key_ok: test("^[A-Za-z0-9._:-]{1,128}$")}
          + (if $i.surface == "review_comment"
             then {path: $i.path, original_line: $i.original_line,
                   original_commit_id: $i.original_commit_id}
             else {} end)
      ]
    };
