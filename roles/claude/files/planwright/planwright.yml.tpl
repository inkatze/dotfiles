# Built by the dotfiles claude role from a 1Password item, so a hand edit is
# lost on the next Ansible run: change the item or the template instead. Mission
# control's own keys (mission_control_*, program_*) are the exception: what it
# writes here is kept in ~/.config/dotfiles/planwright-overlay.supplement.yml and
# carried over the item. Keep this header free of the phrases planwright's
# docs/overlays.md lists as "managed elsewhere", or mission control refuses to
# write the file at all.
flight_pr_hosts: {{ op://__OP_VAULT__/__OP_ITEM__/flight_pr_hosts }}
ready_guard_behind_base: conflict-only

# Workers may also write inside their own unit branch and worktree without a
# prompt, beyond the scratch-only default.
worker_self_approval: scratch own-branch

# Slow or ansible-driven hooks CI runs anyway, skipped on a worker's plain
# `git commit`. Never list a security hook.
worker_hook_exclude: skill-contracts-suite claude-skills-link copilot-retirement claude-steps-catalog syntax-check git-unattended-auth cubic-instructions credential-path-guard planwright-marketplace

# Gate test and lint runs go to the Mac; planwright falls back to this host
# when it is busy, in use or unreachable.
fleet_compute_host: mac

# Host-wide, so it lives in this user-level layer.
fleet_host_max_live_workers: 10

allocation_model_offload: sonnet
allocation_effort_offload: medium

# The fleet default; a `mc-config.sh knob` write overrides it on one machine,
# kept as the header describes.
mission_control_guidance: standard

# Mission control's program settings, kept whole in one item field because
# their keys name private repositories. A change mission control makes to them
# is kept locally until it is copied into the field.
{{ op://__OP_VAULT__/__OP_ITEM__/mission_control }}
