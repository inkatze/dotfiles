# Catppuccin Mocha syntax highlighting, declared here rather than saved as
# universal variables.
#
# `fish_config theme save` writes into ~/.config/fish/fish_variables, which is
# gitignored and per-machine, so a host that loses those variables silently
# falls back to fish's built-in default theme -- whose fish_color_command is
# `--reset`, i.e. no colour at all. That is not a visible failure: parameters
# and errors keep their colours, only the command word goes plain, which reads
# as a font quirk rather than as missing config. The work Mac sat like that
# while the Linux host, whose fish_variables still held the saved theme, was
# fine.
#
# The values are inlined instead of calling `fish_config theme choose
# catppuccin-mocha`, for two reasons. The theme files are gitignored too
# (fisher owns that directory), so tracked config cannot point at them. And
# fish 4.9 answers `theme choose` by setting each variable to a deferred
# `--theme=<name>` reference that only the interactive highlighter resolves:
# fish_indent --ansi renders uncoloured, and the indirection measured ~17ms of
# every shell startup on 4.9.3 where these assignments cost nothing measurable.
# fish's own documentation calls `theme save` "not recommended", so declaring
# the values is the supported direction rather than a workaround.
#
# Global, not universal, so this file stays the single source of truth and
# shadows any stale universal variable a host still carries. The cost of that
# is worth knowing before chasing it: `fish_config theme save` writes
# universals, which these globals outrank, so changing the theme through
# fish_config will appear to do nothing until this file changes too. Edit here
# instead.
#
# Only the theme's dark variant is carried. A theme file may hold light, dark
# and unknown variants, and `theme choose` applies the one matching
# fish_terminal_color_theme -- which fish populates from the terminal's
# background-colour reply, and re-applies whenever it changes. Inlining gives
# up that live switch. Every host here runs a dark terminal and the universal
# variables this replaces were dark-only too, so nothing regresses today; a
# light terminal would need the other variant pasted in.
#
# The variables this file leaves alone are not thereby fish's defaults: an
# unset variable resolves to whatever is still in scope, which on a host
# carrying leftover universals is that universal, not the built-in default.
# fish_color_valid_path, fish_color_cwd_root and fish_color_history_current are
# in exactly that state on the Linux host. Their universals happen to equal
# fish's defaults, so nothing looks wrong -- but the set below is the part that
# is actually pinned, and the rest is only as predictable as the host's
# fish_variables. The upstream theme does not set them either.
#
# fish_color_builtin and fish_color_function are a different case, and are
# omitted on purpose: fish falls back to fish_color_command for both, so
# setting them would only restate it.
set -g fish_color_normal cdd6f4
set -g fish_color_command 89b4fa
set -g fish_color_param f2cdcd
set -g fish_color_keyword cba6f7
set -g fish_color_quote a6e3a1
set -g fish_color_redirection f5c2e7
set -g fish_color_end fab387
set -g fish_color_comment 7f849c
set -g fish_color_error f38ba8
set -g fish_color_selection --background=313244
set -g fish_color_search_match --background=313244
set -g fish_color_option a6e3a1
set -g fish_color_operator f5c2e7
set -g fish_color_escape eba0ac
set -g fish_color_autosuggestion 6c7086
set -g fish_color_cancel f38ba8
set -g fish_color_cwd f9e2af
set -g fish_color_user 94e2d5
set -g fish_color_host 89b4fa
set -g fish_color_host_remote a6e3a1
set -g fish_color_status f38ba8
set -g fish_pager_color_progress 6c7086
set -g fish_pager_color_prefix f5c2e7
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description 6c7086
