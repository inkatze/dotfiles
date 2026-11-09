# Built by the dotfiles claude role from a 1Password item, so a hand edit is
# lost on the next Ansible run: change the item or the template instead. Mission
# control's own keys (mission_control_*, program_*) are the exception: what it
# writes here is kept in ~/.config/dotfiles/planwright-overlay.supplement.yml and
# carried over the item. Keep this header free of the phrases planwright's
# docs/overlays.md lists as "managed elsewhere", or mission control refuses to
# write the file at all.
flight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}
ready_guard_behind_base: conflict-only

# Mission control's program settings, kept whole in one item field because
# their keys name private repositories. A change mission control makes to them
# is kept locally until it is copied into the field.
{{ op://__OP_VAULT__/__OP_ITEM__/mission_control }}
