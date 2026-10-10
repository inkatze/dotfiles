# The review config's schema rule, for both of its checks: scripts/op-render.sh
# runs review_config_errors over the rendered file before it lands (after its
# own version check, which every rendered JSON file shares), and
# skill-contracts.sh runs review_template_errors over the committed template.
# Each emits one message per violation; none means valid.

def required_hosted:
  ["login_pattern", "rerequest", "reviewed_head_regex", "build_id_regex",
   "draft_policy", "opt_out_label"];
def optional_hosted:
  ["finding_key_regex", "addressed_marker_format", "reviewed_head_check",
   "draft_setting", "opt_in_label", "auto_opt_in", "gating_checks",
   "requirement_level_hint", "repo_config_path", "reply_suffix",
   "feedback_reaction", "errored_review_regex", "quota_refusal_regex",
   "request_notes"];
# Fields a template references with ` | json`, so they land typed.
def json_hosted: ["gating_checks", "auto_opt_in"];
def rerequest_methods: ["request", "comment", "push"];
def draft_policies: ["reviews-drafts", "skips-drafts"];
# The template reference syntax, for scripts/op-render.sh too: `w` captures
# the work source's prefix (null for the default item), `f` the item field,
# `j` the suffix that parses its value as JSON. Text templates take the
# default item only.
def op_reference_inline:
  "\\{\\{ op://__OP_VAULT__/__OP_ITEM__/(?<f>[A-Za-z0-9_.-]+) \\}\\}";
def op_reference:
  "^\\{\\{ op://(?:__OP_VAULT__/__OP_ITEM__|(?<w>__OP_WORK_VAULT__/__OP_WORK_ITEM__))/(?<f>[A-Za-z0-9_.-]+)(?<j> \\| json)? \\}\\}$";

def _one_of($p; $allowed):
  if (. as $v | $allowed | index([$v])) then empty
  else "\($p): must be one of \($allowed | join(", ")), got \(tojson)" end;

def _rendered_value_errors($p):
  . as $e
  | ( (keys - ["rerequest", "gating_checks", "auto_opt_in", "cli"])[] as $k
      | select(($e[$k] | type) != "string")
      | "\($p).\($k): not a string" ),
    ( (keys[] | select(test("_regex$|^login_pattern$"))) as $k
      | select(($e[$k] | type) == "string")
      | try ("" | test($e[$k]) | empty) catch "\($p).\($k): does not compile as a regex" ),
    ( .rerequest
      | if type != "object" then "\($p).rerequest: not an object"
        else
          ( (keys - ["method", "login", "command", "incremental_command"])[]
            | "\($p).rerequest: unknown field \(.)" ),
          ( to_entries[] | select(.value | type != "string")
            | "\($p).rerequest.\(.key): not a string" ),
          ( if has("method") | not then "\($p).rerequest: missing required field method"
            else
              (.method | _one_of("\($p).rerequest.method"; rerequest_methods)),
              ( if .method == "request" and ((.login // "") == "")
                then "\($p).rerequest: method request needs login" else empty end ),
              ( if .method == "comment" and ((.command // "") == "")
                then "\($p).rerequest: method comment needs command" else empty end ),
              ( if has("incremental_command") and .method != "comment"
                then "\($p).rerequest: incremental_command applies only to method comment"
                else empty end )
            end )
        end ),
    ( .draft_policy | select(type == "string") | _one_of("\($p).draft_policy"; draft_policies) ),
    ( if .draft_policy == "skips-drafts" and ((.draft_setting // "") == "")
      then "\($p): draft_policy skips-drafts needs draft_setting naming the repository-side setting"
      else empty end ),
    ( if has("finding_key_regex") and (has("addressed_marker_format") | not)
      then "\($p): finding_key_regex needs addressed_marker_format" else empty end ),
    ( if has("auto_opt_in") and (.auto_opt_in | type) != "boolean"
      then "\($p).auto_opt_in: must be true or false" else empty end ),
    ( if (.auto_opt_in == true) and ((.opt_in_label // "") == "")
      then "\($p): auto_opt_in needs opt_in_label" else empty end ),
    ( .addressed_marker_format | select(type == "string")
      | if contains("{key}") then empty
        else "\($p).addressed_marker_format: must contain {key}" end ),
    ( if has("gating_checks")
        and ((.gating_checks | type) != "array"
             or (.gating_checks | map(type == "string" and . != "") | all | not))
      then "\($p).gating_checks: must be an array of non-empty strings" else empty end );

def _template_value_errors($p):
  ( if (.rerequest | type) == "object" and (.rerequest | has("method"))
    then empty else "\($p).rerequest: needs a method reference" end ),
  ( del(.cli) | paths(scalars) as $path | getpath($path) as $v
    | "\($p).\($path | map(tostring) | join("."))" as $at
    | if ($v | type) != "string" or ($v | test(op_reference) | not)
      then "\($at): not an op:// reference"
      elif (json_hosted | index([$path[0]]) != null) != ($v | capture(op_reference).j != null)
      then "\($at): a list takes a | json reference and a string a plain one, auto_opt_in a | json one too"
      else empty end ),
  ( [del(.cli) | paths(scalars) as $path | getpath($path) | strings
     | select(test(op_reference)) | capture(op_reference).w != null] | unique
    | if length > 1 then "\($p): references both the default item and the work item" else empty end );

def _entry_errors($name; $mode):
  "reviewers.\($name)" as $p
  | if type != "object" then "\($p): not an object"
    else
      . as $e
      | ( (keys - required_hosted - optional_hosted - ["cli"])[]
          | "\($p): unknown field \(.)" ),
        ( if (keys - ["cli"] | length) == 0 then
            (if has("cli") then empty
             else "\($p): carries neither hosted mechanics nor a cli block" end)
          else
            ( required_hosted[] as $k
              | select(($e[$k] // "") == "")
              | select($k != "reviewed_head_regex" or (($e.reviewed_head_check // "") == ""))
              | "\($p): missing required field \($k)" ),
            ( if $mode == "rendered" then _rendered_value_errors($p)
              else _template_value_errors($p) end )
          end ),
        ( if has("cli") and (.cli | type) != "object"
          then "\($p).cli: not an object" else empty end )
    end;

def _config_errors($mode):
  if type != "object" then "config: not a JSON object"
  else
    ( (keys - ["version", "default", "reviewers"])[]
      | "config: unknown top-level field \(.)" ),
    ( if (.reviewers | type) != "object" or (.reviewers | length) == 0
      then "config: reviewers must be a non-empty object"
      else .reviewers | to_entries[] | .key as $n | .value | _entry_errors($n; $mode)
      end ),
    ( if (.default | type) != "string" or .default == ""
      then "config: missing required field default"
      elif (.reviewers | type) == "object" and (.default as $d | .reviewers | has($d) | not)
      then "config: default names \(.default), which is not under reviewers"
      else empty end )
  end;

def review_config_errors: _config_errors("rendered");

def review_template_errors:
  ( if .version == 1 then empty else "template: version must be 1" end ),
  _config_errors("template"),
  ( if .default == "cubic" then empty else "template: default must name the cubic entry" end ),
  ( if (.reviewers | type) == "object" and (.reviewers | has("copilot")) then empty
    else "template: no copilot entry" end );
