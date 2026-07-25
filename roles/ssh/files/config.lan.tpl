# LAN host aliases — TEMPLATE. Rendered to ~/.ssh/config.local by
# scripts/ssh-lan-config-sync.sh, which pipes this file through `op inject`.
#
# This file is COMMITTED and contains NO secrets: every machine-identifying
# value is an `op://` secret reference resolved at playbook time from
# 1Password. That satisfies specs/linux-migration REQ-F1.1 (no LAN IPs or
# internal hostnames in committed artifacts) while still letting Ansible sync
# the config to every host — a gitignored file would not sync.
#
# __OP_VAULT__ and __OP_ITEM__ are substituted by the sync script from
# DOTFILES_OP_VAULT / DOTFILES_OP_ITEM before injection. Keep the structure
# here under review; keep only the values in 1Password.
#
# Required fields on the 1Password item (see roles/ssh/README.md):
#   server_alias, server_host, server_ip, server_user

Host {{ op://__OP_VAULT__/__OP_ITEM__/server_alias }} {{ op://__OP_VAULT__/__OP_ITEM__/server_ip }}
    User {{ op://__OP_VAULT__/__OP_ITEM__/server_user }}
    ForwardAgent yes
    SendEnv ANTHROPIC_API_KEY

Host {{ op://__OP_VAULT__/__OP_ITEM__/server_alias }}
    Hostname {{ op://__OP_VAULT__/__OP_ITEM__/server_host }}
