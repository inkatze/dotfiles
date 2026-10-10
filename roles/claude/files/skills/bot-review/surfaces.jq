# What one hosted reviewer wrote on a PR, read off all three surfaces it can
# write to (reviews, issue comments and inline review comments), plus the
# reviewed head off its check runs where it names no commit. A vendor may put
# its run marker, reviewed head or finding keys on any of them, so each regex
# is matched on every surface; assuming one surface per marker misses vendors
# that split them.
#
# Input: {reviews, issue_comments, review_comments, check_runs}, each the flat
# array the REST endpoint returns, check_runs holding the runs of the
# reviewer's reviewed_head_check (empty when it has none). $cfg is one
# reviewer entry of the review config. Order is by time, the id breaking a
# tie. REST reviews carry no edit time, so a review summary edited in place
# keeps its submission time.

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

# For a vendor whose comments name no commit, the reviewed head is the head of
# the latest run of the named check that the bot's own app created and that
# concluded with a review: any app can post a check under that name, and a
# skipped or cancelled run reviewed nothing. The check's details_url is not
# matched to the build id, since a vendor can mark its comments and its check
# with different ids for one run. A run fetched again on a poll keeps its id,
# and only its last-fetched copy counts: the fetches append in time order, and
# group_by keeps that order within an id.
def _own_check_runs($runs; $cfg):
  "^(?:\($cfg.login_pattern))$" as $login
  | [$runs[]? | select(.name == $cfg.reviewed_head_check
                       and ("\(.app.slug // "")[bot]" | test($login)))]
  | group_by(.id) | map(last);
def _check_head($runs; $cfg):
  [_own_check_runs($runs; $cfg)[]
   | select(.status == "completed"
            and (.conclusion | IN("success", "neutral", "failure", "action_required"))
            and (.head_sha | type == "string" and test("^[0-9a-f]{7,64}$")))
   | {value: .head_sha, surface: "check_run", id, at: (.completed_at // "")}]
  | sort_by(.at, .id) | last;
# A run of the check still going that started after the reviewed head's run
# did (or has not started): a poll waits for it rather than reading the head
# as missing. A run stuck from before the head's run is not waited on.
def _check_pending($runs; $cfg; $head):
  _own_check_runs($runs; $cfg) as $own
  | ($own | map(select(.id == $head.id)) | first | .started_at // "") as $since
  | [$own[] | select(.status != "completed")
     | select($head == null or .started_at == null or .started_at > $since)]
  | length > 0;

def bot_surfaces($cfg):
  if ($cfg | type) != "object" or ($cfg.login_pattern // "") == ""
  then error("no such reviewer in the config, or it has no login_pattern") else . end
  | [_surface_items($cfg)] as [$reviews, $issue, $inline]
  | ($reviews + $issue + $inline) as $all
  | _latest_marker($all; $cfg.build_id_regex) as $build
  | (($cfg.reviewed_head_regex // "") == "" and ($cfg.reviewed_head_check // "") != "") as $by_check
  | (if $by_check then _check_head(.check_runs; $cfg)
     else _latest_marker($all; $cfg.reviewed_head_regex) end) as $head
  # Error text is read off summaries only: an inline finding can quote it.
  | ($cfg.errored_review_regex // "") as $err
  | (if $err == "" then null
     else [($reviews + $issue)[] | select(.body | test($err))] | sort_by(.at, .id) | last end) as $error
  | [ $all[] as $i
      | if ($cfg.finding_key_regex // "") == "" then empty
        else $i.body | match($cfg.finding_key_regex; "g") | _value end
      | {surface: $i.surface, id: $i.id, key: ., at: $i.at,
         key_ok: test("\\A[A-Za-z0-9._:-]{1,128}\\z")}
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
      reviewed_head: $head,
      reviewed_head_pending: ($by_check and _check_pending(.check_runs; $cfg; $head)),
      # Errored when the latest error summary is at least as new as the latest
      # run marker, or carries it with no clean summary of that run after it,
      # so a later clean run, or a clean retry of the same one, clears it.
      errored: ($error != null
        and ($build == null or [$error.at, $error.id] >= [$build.at, $build.id]
             or (([$error.body | match($cfg.build_id_regex; "g") | _value] | index([$build.value])) != null
                 and ([($reviews + $issue)[]
                       | select([.at, .id] > [$error.at, $error.id] and (.body | test($err) | not)
                                and ([.body | match($cfg.build_id_regex; "g") | _value] | index([$build.value])) != null)]
                      | length) == 0))),
      findings: $findings
    };
