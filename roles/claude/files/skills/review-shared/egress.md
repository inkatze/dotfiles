# Egress consent

Sending a repository's code to an external service is asked once per repo,
before anything is sent, and remembered machine-locally in
`~/.config/dotfiles/code-review-egress.json` (mode 0600, never tracked: it
enumerates repos this machine has approved for upload).

## Keys and values

- `/code-review`'s backend pass and `/panel-review`'s `codex` and `gemini`
  backends: key `<owner>/<repo>`, value the backend (`codex` or `gemini`).
  One approval serves both skills; a different backend for an approved repo
  asks again.
- `/panel-review`'s `reviewer:<name>` backend: key
  `reviewer:<name>:<owner>/<repo>`, value the real path of the file that will
  run. A bare `<owner>/<repo>` lookup never matches it, so the two kinds of
  approval cannot overwrite each other.

Resolve the repo with `gh repo view --json nameWithOwner -q .nameWithOwner`.
If it does not resolve (no GitHub remote, `gh` offline), ask for this run and
record nothing. A file holding no JSON at all (empty or whitespace) counts as
absent; one that is a symlink, unreadable, not a regular file, or anything
other than a single JSON object stops the run and names the path. Anything
other than a yes stops the run. Revoking is deleting the key while no review
is running (a writer holding the lock would put it back).

## Recording a yes

Run this as its own `Bash` call, so no later trap or long step holds the lock.
The wait is bounded because a writer killed mid-write leaves the lock
directory behind, and failing to lock or write never undoes the yes: the run
goes on, approved for this run only. Exit 2 means stop the run. The value is
pasted into single quotes, so refuse one containing `'`, a newline or a
control character before substituting it.

```bash
f=~/.config/dotfiles/code-review-egress.json
key='<key>'; val='<value>'
command -v jq > /dev/null || { echo "jq not found; nothing recorded, and this run cannot continue without it" >&2; exit 2; }
dir="${f%/*}"; tries=50; n=0; locked=""; rc=0; why="$dir is missing or not writable"
[ -d "$dir" ] || (umask 077; mkdir -p "$dir") 2>/dev/null
if [ -d "$dir" ] && [ -w "$dir" ]; then
  why="$f.lock is still held after 10s (another run, or a killed one: rmdir it if no review is running)"
  if [ -L "$f.lock" ] || { [ -e "$f.lock" ] && [ ! -d "$f.lock" ]; }; then
    why="$f.lock exists and is not a lock directory"; n=$tries
  fi
  while [ "$n" -lt "$tries" ]; do
    mkdir "$f.lock" 2>/dev/null && { locked=1; break; }
    n=$((n + 1)); sleep 0.2
  done
fi
if [ -z "$locked" ]; then
  echo "could not lock $f: $why; approved for this run only" >&2
else
  seed=""
  if [ ! -L "$f" ] && { [ ! -e "$f" ] || { [ -f "$f" ] && [ -r "$f" ] && ! LC_ALL=C grep -q '[^[:space:]]' "$f"; }; }; then seed=1; fi
  tmp=""
  if [ -z "$seed" ] && { [ -L "$f" ] || [ ! -f "$f" ] || ! jq -e -s 'length == 1 and (.[0] | type == "object")' "$f" > /dev/null 2>&1; }; then
    echo "$f is a symlink, unreadable, not a regular file, or not a single JSON object; nothing recorded or overwritten" >&2; rc=2
  elif ! { tmp=$(mktemp "$f.XXXXXX") && if [ -n "$seed" ]; then jq -n --arg k "$key" --arg v "$val" '{($k): $v}'
      else jq --arg k "$key" --arg v "$val" '.[$k] = $v' "$f"; fi > "$tmp" && [ -s "$tmp" ] && chmod 600 "$tmp" && mv "$tmp" "$f"; }; then
    rm -f "$tmp"; echo "could not record consent in $f; approved for this run only" >&2
  fi
  rmdir "$f.lock"
fi
exit "$rc"
```

The lock is released after the write whether or not the write succeeded, so
`rmdir` sits after the failure branch, not inside it.
