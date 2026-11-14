# Rendered from 1Password by the dotfiles osx role on the offload host; a hand
# edit is overwritten on the next run. The key is trusted only from the
# dispatching host's address, with no forwarding of any kind.
from="{{ op://__OP_VAULT__/__OP_ITEM__/server_ip }}",restrict,pty {{ op://__OP_VAULT__/__OP_ITEM__/offload_client_pubkey }}
