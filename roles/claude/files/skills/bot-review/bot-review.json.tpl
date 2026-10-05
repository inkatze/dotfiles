{
  "version": 1,
  "default": "cubic",
  "reviewers": {
    "cubic": {
      "login_pattern": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_login_pattern }}",
      "rerequest": {
        "method": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_rerequest_method }}",
        "login": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_rerequest_login }}",
        "command": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_rerequest_command }}",
        "incremental_command": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_rerequest_incremental_command }}"
      },
      "reviewed_head_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_reviewed_head_regex }}",
      "finding_key_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_finding_key_regex }}",
      "build_id_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_build_id_regex }}",
      "draft_policy": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_draft_policy }}",
      "draft_setting": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_draft_setting }}",
      "opt_out_label": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_opt_out_label }}",
      "addressed_marker_format": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_addressed_marker_format }}",
      "opt_in_label": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_opt_in_label }}",
      "gating_checks": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_gating_checks | json }}",
      "requirement_level_hint": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_requirement_level_hint }}",
      "repo_config_path": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_repo_config_path }}",
      "reply_suffix": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_reply_suffix }}",
      "feedback_reaction": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_feedback_reaction }}",
      "errored_review_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_errored_review_regex }}",
      "full_review_comment": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_full_review_comment }}",
      "rereview_comment": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_rereview_comment }}",
      "quota_refusal_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_quota_refusal_regex }}",
      "request_notes": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_request_notes }}",
      "cli": {
        "binary": "cubic",
        "install_command": "mise run environments, from the dotfiles checkout",
        "local_invocation": "cubic review --base {base_ref} --json",
        "timeout_seconds": 1200,
        "findings_output": "stdout-json",
        "findings_exit_codes": [1],
        "findings_jq": "if type != \"object\" or (.error // null) != null or (.issues | type) != \"array\" then error(\"not a findings document\") else [.issues[] | {file: (.file // \"\" | tostring), line: (.line | if type == \"number\" then . elif type == \"string\" and test(\"^[0-9]+$\") then tonumber else null end), finding: ([.title, .description] | map(select(type == \"string\" and . != \"\")) | join(\": \")), severity: (.priority | if type == \"string\" then . else null end), rule: null} | if .file == \"\" or .finding == \"\" then error(\"an issue without a file or text\") else . end] end",
        "env_allow": ["CUBIC_API_KEY"],
        "env_files": { "CUBIC_API_KEY": "~/.config/dotfiles/cubic-api-key" },
        "env": {
          "CUBIC_DISABLE_AUTOUPDATE": "1",
          "CUBIC_DISABLE_GIT_AI": "true",
          "CUBIC_DISABLE_LSP_DOWNLOAD": "1"
        },
        "invocation_notes": "The env values are the vendor's opt-outs: no self-update or language-server download mid-review, and no git-ai commit tagger, which writes git notes. The CLI exits 1 whenever it reports issues and also on its own errors, so findings_exit_codes admits 1 and findings_jq refuses the error document. --base takes a ref name, not a SHA (a bare name gains an origin/ prefix), hence {base_ref}. The key file is written by scripts/op-key-sync.sh from the dotfiles-cubic-api-key item."
      }
    },
    "copilot": {
      "login_pattern": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_login_pattern }}",
      "rerequest": {
        "method": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_rerequest_method }}",
        "login": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_rerequest_login }}",
        "command": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_rerequest_command }}",
        "incremental_command": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_rerequest_incremental_command }}"
      },
      "reviewed_head_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_reviewed_head_regex }}",
      "finding_key_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_finding_key_regex }}",
      "build_id_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_build_id_regex }}",
      "draft_policy": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_draft_policy }}",
      "draft_setting": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_draft_setting }}",
      "opt_out_label": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_opt_out_label }}",
      "addressed_marker_format": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_addressed_marker_format }}",
      "opt_in_label": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_opt_in_label }}",
      "gating_checks": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_gating_checks | json }}",
      "requirement_level_hint": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_requirement_level_hint }}",
      "repo_config_path": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_repo_config_path }}",
      "reply_suffix": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_reply_suffix }}",
      "feedback_reaction": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_feedback_reaction }}",
      "errored_review_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_errored_review_regex }}",
      "full_review_comment": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_full_review_comment }}",
      "rereview_comment": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_rereview_comment }}",
      "quota_refusal_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_quota_refusal_regex }}",
      "request_notes": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_request_notes }}"
    }
  }
}
