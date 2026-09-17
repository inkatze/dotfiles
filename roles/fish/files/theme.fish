# Catppuccin Mocha. The colours are not copied into this repo: they live in the
# theme file the catppuccin/fish plugin installs, and `fish_config theme save`
# copies them into fish_variables as literal values.
#
# Universals are the right store, because literal values are what
# `set_color $fish_color_*` needs and fish's own `theme demo` and
# fish_breakpoint_prompt read them that way. The defect worth fixing was that
# fish_variables is gitignored and per-machine, so losing it was silent: fish
# fell back to its default theme, where fish_color_command is `--reset`, and the
# command word alone went uncoloured, which reads as a font quirk.
#
# The test is for an empty store, not for this theme specifically, so a host
# that has deliberately saved some other theme keeps it without being nagged.
status is-interactive || exit 0
test -r $__fish_config_dir/themes/catppuccin-mocha.theme || exit 0
set -qU fish_color_command && exit 0

# Usable now; persisting needs a terminal, so it stays a hint. On stderr because
# `fish -i -c` is interactive and callers capture its stdout. Only when the
# theme applied: a failure prints its own error, and saying "not persisted"
# over it would describe the wrong problem.
if fish_config theme choose catppuccin-mocha
    echo "fish: theme not persisted on this host. Run: fish_config theme save catppuccin-mocha" >&2
end
