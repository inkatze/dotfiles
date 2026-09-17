# Catppuccin Mocha, declared here rather than saved with `fish_config theme
# save`. That writes universal variables into fish_variables, which is
# gitignored and per-machine, so a host can silently lose the theme and fall
# back to fish's default -- where fish_color_command is `--reset`, leaving the
# command word uncoloured while everything around it stays coloured. It reads
# as a font quirk, not as missing config.
#
# Inlined rather than calling `fish_config theme choose`: the theme files
# fisher installs are gitignored too, so tracked config cannot point at them.
#
# These are global, so they outrank any universal a host still carries. The
# flip side is that `fish_config theme save` will appear to do nothing; change
# the theme here instead. Only the dark variant is carried, so a light
# terminal would need the other one pasted in. fish_color_builtin and
# fish_color_function are omitted because fish falls back to
# fish_color_command for both.
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
