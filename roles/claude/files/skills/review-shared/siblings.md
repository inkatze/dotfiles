# Sibling repositories

A repository often consumes a shape another one defines: a type, schema,
endpoint or message its producer owns. A review that validates the consumer
against its own code alone cannot tell whether it matches what the producer
actually sends, so the producer's definition is read as validation context.

## The map

`~/.config/dotfiles/sibling-repos.json` (mode 0600), rendered by the claude
role's Ansible run from the 1Password item `dotfiles-sibling-repos` through
[sibling-repos.json.tpl](sibling-repos.json.tpl); change the item, never the
file. Read it at pre-flight, before anything is uploaded or anyone is told a
review started. Its `version` must be `1`: on another version, or none, stop,
naming the file and the version it carries. `repos` maps a consuming
repository (`<owner>/<repo>`, compared lower-cased) to its producers, each
mapped to the path of a local clone, absolute or under `~/`; a leading `~/` is
replaced by the home directory's absolute path before the path is quoted into
any command, since a quoted tilde never expands. A file that is not one JSON
object, whose `repos` is not an object of objects of strings, or that names a
clone path neither absolute nor under `~/`, or one containing `'`, a newline
or a control character (it is pasted into single quotes), stops the run the
same way, naming the file. No file, or no entry for this repository, means no producer context:
say so once and continue.

## Attaching a producer

**A mapped producer's code is validation pass 2's context**: when the diff
consumes a shape a mapped producer defines (it imports, calls or parses a
type, schema, endpoint or message the producer owns), read that definition
from the producer's clone and attach it to pass 2 of each finding that touches
the consumed shape, naming the producer file and the clone's `HEAD` in that
finding's validation-passes entry.

- Read it with `git -C '<clone>' show 'HEAD:<path>'`, never by running
  anything in the clone, and only the file the definition lives in, never a
  secrets file (`.env*`, credentials, keys). The path is inferred from the
  diff, so it goes in as one single-quoted literal, and one containing `'`, a
  newline or a control character is refused.
- A clone that is missing, is not a git repository, or does not hold the
  definition gives no context: say which and validate without it.
- A clone behind its upstream (`git -C '<clone>' rev-list --count
  HEAD..@{upstream}` above zero, as last fetched; this run never fetches it)
  is named as behind in that entry, since its definition may predate the
  producer's current one; a clone with no upstream, or a detached `HEAD`, is
  named as of unknown freshness.
- The producer's code stays local: it is never sent to a backend, since the
  egress consent covers the reviewed repository, not its producers, and never
  named in anything posted: its repository, file and `HEAD` appear only in
  the finding's validation-passes entry, which stays in the run's record.
