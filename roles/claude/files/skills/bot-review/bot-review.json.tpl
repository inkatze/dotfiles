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
      "quota_refusal_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_quota_refusal_regex }}",
      "request_notes": "{{ op://__OP_VAULT__/__OP_ITEM__/cubic_request_notes }}"
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
      "quota_refusal_regex": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_quota_refusal_regex }}",
      "request_notes": "{{ op://__OP_VAULT__/__OP_ITEM__/copilot_request_notes }}"
    }
  }
}
