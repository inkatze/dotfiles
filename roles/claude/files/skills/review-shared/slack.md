# Slack notifications

Some review skills message the person on the other end of a PR. Each skill
decides when to send and what to say; the mechanics are these.

**Optional, and never blocking.** If no Slack MCP server is available, or a
recipient cannot be resolved, say so once in the terminal and carry on. A
notification failure never aborts, retry-loops or delays the review: the
review is the deliverable, the message is a courtesy. Default to a DM.

## Resolve the GitHub login to a Slack user

1. **Remembered first.** Consult `~/.config/dotfiles/slack-users.json`
   (`{"<github-login>": "<slack-user-id>"}`, mode 0600, never tracked: it holds
   other people's identities).
2. **By email.** The profile email (`gh api users/<login> --jq .email`), else
   the author email on their commits in the PR (`gh pr view <n> --json
   commits`), looked up through the Slack MCP's user-by-email call. Emails
   resolve a person and are never stored.
3. **Otherwise, ask after the review, never mid-run.** Say in the terminal
   that this person gets no message, finish the review, then ask for the
   handle. The first run for a new person sends nothing; later runs do.

Record what you learn with a read-modify-write, never an append (the file is
one JSON object), as its own `Bash` call. This is the locked write
[egress.md](egress.md) uses, except that every failure is one terminal line
and the review goes on: a mapping that is not recorded only means asking
again next time. Both values are pasted into single quotes, and a GitHub login
and a Slack user id are letters, digits and `-` only, so refuse anything else
before substituting.

```bash
f=~/.config/dotfiles/slack-users.json
login='<github-login>'; id='<slack-user-id>'
command -v jq > /dev/null || { echo "jq not found; $login's Slack id not recorded" >&2; exit 0; }
dir="${f%/*}"; tries=50; n=0; locked=""; why="$dir is missing or not writable"
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
  echo "could not lock $f: $why; $login's Slack id not recorded" >&2
else
  seed=""
  if [ ! -L "$f" ] && { [ ! -e "$f" ] || { [ -f "$f" ] && [ -r "$f" ] && ! LC_ALL=C grep -q '[^[:space:]]' "$f"; }; }; then seed=1; fi
  tmp=""
  if [ -z "$seed" ] && { [ -L "$f" ] || [ ! -f "$f" ] || ! jq -e -s 'length == 1 and (.[0] | type == "object")' "$f" > /dev/null 2>&1; }; then
    echo "$f is a symlink, unreadable, not a regular file, or not a single JSON object; $login's Slack id not recorded" >&2
  elif ! { tmp=$(mktemp "$f.XXXXXX") && if [ -n "$seed" ]; then jq -n --arg k "$login" --arg v "$id" '{($k): $v}'
      else jq --arg k "$login" --arg v "$id" '.[$k] = $v' "$f"; fi > "$tmp" && [ -s "$tmp" ] && chmod 600 "$tmp" && mv "$tmp" "$f"; }; then
    rm -f "$tmp"; echo "could not record $login's Slack id in $f" >&2
  fi
  rmdir "$f.lock"
fi
```

A recipient is never guessed.

## Confirm before sending

Show the resolved recipient and the exact text, and wait for a yes:

```
notify <name> (@<handle>)? [y/N]
<the message, exactly as it will be sent>
```

When the resolution came through a commit email rather than the profile email
or the remembered file, say so in the prompt (`@<handle>, via commit email`):
commit emails are author-controlled. Anything other than a yes sends nothing
and the review carries on. With no operator present, draft the message and
its recipient into the handoff instead of sending it.

## Signing

Every message ends with the sign-off on its own line, exactly:

```
– clanky
```

The leading character is an EN DASH (U+2013), and nothing follows the name.
