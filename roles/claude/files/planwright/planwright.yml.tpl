# Built by the dotfiles claude role from a 1Password item, so a hand edit is
# lost on the next Ansible run: change the item or the template instead. Mission
# control's own keys (mission_control_*, program_*) are the exception: what it
# writes here is kept in ~/.config/dotfiles/planwright-overlay.supplement.yml and
# carried over the item. Keep this header free of the phrases planwright's
# docs/overlays.md lists as "managed elsewhere", or mission control refuses to
# write the file at all.
flight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}
ready_guard_behind_base: conflict-only

# Fleet concurrency, sized to the workstation's cores and memory now that usage
# is capped weekly only, with no hourly window to pace against. The bound counts
# every in-flight unit, parked ones included, so it sits above the number of
# workers running at once; planwright's weekly usage ladder still throttles near
# the weekly wall.
fleet_max_parallel_units: 10

allocation_model_offload: sonnet
allocation_effort_offload: medium

# The fleet default; a `mc-config.sh knob` write overrides it on one machine,
# kept as the header describes.
mission_control_guidance: standard

# Mission control's program settings, kept whole in one item field because
# their keys name private repositories. A change mission control makes to them
# is kept locally until it is copied into the field.
{{ op://__OP_VAULT__/__OP_ITEM__/mission_control }}
