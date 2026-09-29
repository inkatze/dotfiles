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
one JSON object):

```bash
f=~/.config/dotfiles/slack-users.json
[ -s "$f" ] || { umask 077; echo '{}' > "$f"; }
tmp=$(mktemp "$f.XXXXXX") && jq --arg l "<github-login>" --arg id "<slack-user-id>" \
  '.[$l] = $id' "$f" > "$tmp" && mv "$tmp" "$f"
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
