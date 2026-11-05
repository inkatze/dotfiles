# Rendered from 1Password by the dotfiles claude role; a hand edit here is
# overwritten on the next Ansible run. Change the item or the template instead.
flight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}
ready_guard_behind_base: conflict-only

# Fleet concurrency, sized to the workstation's cores and memory now that usage
# is capped weekly only, with no hourly window to pace against. The bound counts
# every in-flight unit, parked ones included, so it sits above the number of
# workers running at once; planwright's weekly usage ladder still throttles near
# the weekly wall.
fleet_max_parallel_units: 10

# Mission control's program settings, kept whole in one item field because
# their keys name private repositories. Mission control writes them to this
# file, so copy any change it makes into the field before the next Ansible run.
{{ op://__OP_VAULT__/__OP_ITEM__/mission_control }}
