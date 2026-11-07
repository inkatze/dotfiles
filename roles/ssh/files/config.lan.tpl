# LAN host aliases — TEMPLATE. Rendered to ~/.ssh/config.local by
# scripts/ssh-lan-config-sync.sh, which pipes this file through `op inject`.
#
# This file is COMMITTED and contains NO secrets: every machine-identifying
# value is a 1Password secret reference resolved at playbook time. That
# satisfies specs/linux-migration REQ-F1.1 (no LAN IPs or internal hostnames in
# committed artifacts) while still letting Ansible sync the config to every
# host — a gitignored file would not sync.
#
# Do NOT write a bare secret-reference scheme prefix anywhere in this file, not
# even in a comment. `op inject` scans the whole template for references and
# does not skip comment lines, so a prose mention with no vault/item/field after
# it aborts the entire render with "invalid secret reference: too few '/'".
# That is not hypothetical: this comment used to carry one, and it meant the
# sync had never once succeeded on any host.
#
# __OP_VAULT__ and __OP_ITEM__ are substituted by the sync script from
# DOTFILES_OP_VAULT / DOTFILES_OP_ITEM before injection. Keep the structure
# here under review; keep only the values in 1Password.
#
# Required fields on the 1Password item (see roles/ssh/README.md):
#   server_alias, server_host, server_ip, server_user,
#   offload_alias, offload_host, offload_user

Host {{ op://__OP_VAULT__/__OP_ITEM__/server_alias }} {{ op://__OP_VAULT__/__OP_ITEM__/server_ip }}
    User {{ op://__OP_VAULT__/__OP_ITEM__/server_user }}
    ForwardAgent yes
    SendEnv ANTHROPIC_API_KEY

Host {{ op://__OP_VAULT__/__OP_ITEM__/server_alias }}
    Hostname {{ op://__OP_VAULT__/__OP_ITEM__/server_host }}

# The offload host (docs/offload-host.md). It trusts the offload key only from
# this host's IPv4 address, so the connection must not go out over IPv6, which
# an mDNS name often resolves to first. IdentityAgent none keeps a locked
# 1Password agent out of an unattended connection.
Host {{ op://__OP_VAULT__/__OP_ITEM__/offload_alias }}
    Hostname {{ op://__OP_VAULT__/__OP_ITEM__/offload_host }}
    User {{ op://__OP_VAULT__/__OP_ITEM__/offload_user }}
    AddressFamily inet
    IdentityFile ~/.ssh/id_offload
    IdentitiesOnly yes
    IdentityAgent none
    ForwardAgent no
