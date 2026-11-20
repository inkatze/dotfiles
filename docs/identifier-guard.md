# The identifier guard is retired; a review-time check replaces it

`scripts/gitleaks-identifier-rules.sh` generates secret-scanner rules that
would block private project identifiers from entering commits. It is not
wired into any hook or CI job (only `scripts/gitleaks-rules-test.sh` runs it,
by hand), and it should not be: `specs/dev-services` withdrew the
enforcement requirements with no successor and marked their design decisions
superseded. The prohibition itself still binds, but by review rather than by
hook, and enforcement belongs to a successor hygiene bundle that would also
handle the identifiers already published here.

The script reads as live machinery waiting to be connected. It is not. Wiring
it without first amending that spec reverses a recorded decision, and doing
the enforcement half alone leaves the files that already carry the
identifiers permanently exempt: containment, not coverage.

`roles/claude/files/scripts/identifier-check.sh` reads the same identifier
file for a review-time report over the live instruction files, the templates
rendered beside them, these `docs/` notes and the `specs/claude-instructions`
and `specs/review-skills` bundles. It runs by hand at task
review and from the contract checker's fixture suite, prints file and line
but never the matched name, warns when the identifier file is absent (with no
arguments), and never blocks a commit.

Given file arguments (`identifier-check.sh <file>...`) it scans exactly those
files instead of that scope, as text even when they hold a NUL byte or
invalid encoding (the no-argument scan skips binary files), matching names
case-insensitively as whole words, and exits 2 for a named file that is
missing or unreadable or whose path contains a newline.
That is the form to gate publishing a PR body with
(`identifier-check.sh <body file> && gh pr create ...`). With file arguments
an absent or empty identifier file exits 2 too, so a body is never published
unscanned; with no arguments it keeps the fixed scope and only warns. A named
path that itself holds an identifier is reported as `argument <n>` rather
than echoed. Neither form is a commit gate.
