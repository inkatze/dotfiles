# The review config's schema rule, in one place for both of its checks:
# scripts/op-render.sh runs review_config_errors over the rendered file before
# it lands, and skill-contracts.sh runs review_template_errors over the
# committed template. Each emits one message per violation; none means valid.

def required_hosted:
  ["login_pattern", "rerequest", "reviewed_head_regex", "finding_key_regex",
   "build_id_regex", "draft_policy", "opt_out_label", "addressed_marker_format"];
def optional_hosted:
  ["draft_setting", "opt_in_label", "gating_checks", "requirement_level_hint",
   "repo_config_path", "reply_suffix", "feedback_reaction",
   "errored_review_regex"];
def rerequest_methods: ["request", "comment", "push"];
def draft_policies: ["reviews-drafts", "skips-drafts"];
def op_reference:
  "^\\{\\{ op://__OP_VAULT__/__OP_ITEM__/[A-Za-z0-9_.-]+( \\| json)? \\}\\}$";

def _one_of($p; $allowed):
  if (. as $v | $allowed | index([$v])) then empty
  else "\($p): must be one of \($allowed | join(", ")), got \(tojson)" end;

def _rendered_value_errors($p):
  . as $e
  | ( (keys - ["rerequest", "gating_checks", "cli"])[] as $k
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
    ( .addressed_marker_format | select(type == "string")
      | if contains("{key}") then empty
        else "\($p).addressed_marker_format: must contain {key}" end ),
    ( if has("gating_checks")
        and ((.gating_checks | type) != "array"
             or (.gating_checks | map(type == "string") | all | not))
      then "\($p).gating_checks: must be an array of strings" else empty end );

def _template_value_errors($p):
  ( if (.rerequest | type) == "object" and (.rerequest | has("method"))
    then empty else "\($p).rerequest: needs a method reference" end ),
  ( del(.cli) | paths(scalars) as $path | getpath($path) as $v
    | select(($v | type) != "string" or ($v | test(op_reference) | not))
    | "\($p).\($path | map(tostring) | join(".")): not an op:// reference" );

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
