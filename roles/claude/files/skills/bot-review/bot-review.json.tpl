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
        "refuse_paths": ["cubic.json", "cubic.jsonc", ".cubic"],
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
          "CUBIC_DISABLE_LSP_DOWNLOAD": "1",
          "CUBIC_PERMISSION": "{\"bash\":\"deny\",\"webfetch\":\"deny\",\"edit\":\"deny\"}",
          "CUBIC_CONFIG_CONTENT": "{\"lsp\":{\"astro\":{\"disabled\":true},\"clangd\":{\"disabled\":true},\"csharp\":{\"disabled\":true},\"deno\":{\"disabled\":true},\"elixir-ls\":{\"disabled\":true},\"eslint\":{\"disabled\":true},\"gopls\":{\"disabled\":true},\"jdtls\":{\"disabled\":true},\"lua-ls\":{\"disabled\":true},\"pyright\":{\"disabled\":true},\"ruby-lsp\":{\"disabled\":true},\"rust\":{\"disabled\":true},\"sourcekit-lsp\":{\"disabled\":true},\"svelte\":{\"disabled\":true},\"typescript\":{\"disabled\":true},\"vue\":{\"disabled\":true},\"zls\":{\"disabled\":true}},\"tools\":{\"grep\":false,\"websearch\":false,\"codesearch\":false}}"
        },
        "require_empty": ["~/.config/cubic/AGENTS.md"],
        "require_json": { "~/.local/share/cubic/preferences.json": ".preferredProvider == \"cubic\"" },
        "require_json_if_present": { "~/.local/share/cubic/auth.json": "[.[]? | objects | select(.type == \"wellknown\")] | length == 0" },
        "require_only": { "~/.config/cubic": ["AGENTS.md"] },
        "value_patterns": { "CUBIC_API_KEY": "^cbk_" },
        "env_allow_refuse": ["CUBIC_*", "XDG_CONFIG_HOME", "XDG_DATA_HOME"],
        "invocation_notes": "The env values are the vendor's opt-outs: no self-update or language-server download mid-review, and no git-ai commit tagger, which writes git notes. The CLI exits 1 whenever it reports issues and also on its own errors, so findings_exit_codes admits 1 and findings_jq refuses the error document. --base takes a ref name, not a SHA (a bare name gains an origin/ prefix), hence {base_ref}. The CLI loads cubic.json, cubic.jsonc and .cubic/ (plugins included) from the tree it reviews, so refuse_paths refuses a repository carrying any of them, and a PR's copy never runs with the key. CUBIC_PERMISSION takes the review agent's shell and web-fetch tools away and CUBIC_CONFIG_CONTENT disables every built-in language server, since both would run or fetch on the reviewed tree's behalf with the key in their environment. The CLI uploads the first global instruction file it finds, ~/.config/cubic/AGENTS.md before ~/.claude/CLAUDE.md, so require_empty keeps the first one present and empty; the claude role creates it. CUBIC_CONFIG_CONTENT also turns off the grep tool (its path argument reaches ripgrep as an option, so --pre runs a command) and the web and code search tools. require_json pins the review to cubic's own provider: with another one preferred, or cubic's auth missing, the CLI hands the review to Claude Code, Cursor or Codex, with their own settings and the key in their environment; value_patterns keeps a key the CLI would ignore, and so fall back, from being passed. require_json_if_present refuses a wellknown login in auth.json, whose remote config the CLI merges after CUBIC_CONFIG_CONTENT and which can re-enable any tool or override the review agent's permission. CUBIC_PERMISSION also denies edit, which is off by default but would run the repo's own formatter (bun x prettier --write) on every edit if a later version turned it on. require_only refuses global agents, tools, plugins and config, which load after the lockdown and can undo it, and env_allow_refuse keeps a CUBIC_ switch or a relocated config or data home from reaching the CLI. The agent can still read any file you can and send it to cubic, so run this only on branches whose contents you trust. scripts/cubic-lockdown-test.sh checks all of this against the pinned binary. The key file is written by scripts/op-key-sync.sh from the dotfiles-cubic-api-key item."
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
