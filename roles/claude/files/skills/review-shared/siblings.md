# Sibling repositories

A repository often consumes a shape another one defines: a type, schema,
endpoint or message its producer owns. A review that validates the consumer
against its own code alone cannot tell whether it matches what the producer
actually sends, so the producer's definition is read as validation context.

## The map

`~/.config/dotfiles/sibling-repos.json` (mode 0600), rendered by the claude
role's Ansible run from the 1Password item `dotfiles-sibling-repos` through
[sibling-repos.json.tpl](sibling-repos.json.tpl); change the item, never the
file. Its `version` must be `1`: on another version, or none, stop, naming the
file and the version it carries. `repos` maps a consuming repository
(`<owner>/<repo>`, compared lower-cased) to its producers, each mapped to the
path of a local clone (absolute, or `~/` for the home directory). No file, or
no entry for this repository, means no producer context: say so once and
continue.

## Attaching a producer

**A mapped producer's code is validation pass 2's context**: when the diff
consumes a shape a mapped producer defines (it imports, calls or parses a
type, schema, endpoint or message the producer owns), read that definition
from the producer's clone and attach it to that finding's pass 2, naming the
producer file and the clone's `HEAD` in the validation record.

- Read it with `git -C '<clone>' show HEAD:<path>`, never by running anything
  in the clone, and only paths the definition lives in.
- A clone that is missing, is not a git repository, or does not hold the
  definition gives no context: say which and validate without it.
- A clone behind its upstream (`git -C '<clone>' rev-list --count
  HEAD..@{upstream}` above zero, as last fetched; this run never fetches it)
  is named as behind in the validation record, since its definition may
  predate the producer's current one.
- The producer's code stays local: it is never sent to a backend, since the
  egress consent covers the reviewed repository, not its producers.
