# Baseline Snapshots

Encrypted usage-metrics snapshots live here as
`baseline-YYYY-MM.md.age`. Schema and methodology are defined in
[`SCHEMA.md`](SCHEMA.md); authorized recipients are listed in
[`recipients.txt`](recipients.txt).

**Plaintext `baseline-*.md` files must never be committed.** A lefthook
pre-commit guard rejects them loudly. See the guard in `lefthook.yml`.

## Encrypt a new snapshot

Produce the plaintext outside this directory (e.g. in `/tmp`), encrypt
directly into the snapshots directory, then delete the plaintext.

```fish
# 1. generate the plaintext somewhere OUTSIDE snapshots/
set plaintext (mktemp -t baseline-2026-04.XXXXXX.md)
# ... run the producer script, writing metrics into $plaintext ...

# 2. encrypt to the tracked location
age -R specs/metrics-baseline/snapshots/recipients.txt \
    -o specs/metrics-baseline/snapshots/baseline-2026-04.md.age \
    $plaintext

# 3. wipe plaintext
shred -u $plaintext 2>/dev/null; or rm -P $plaintext
```

Anyone with the repo can encrypt. Only holders of a private key matching a
pubkey in `recipients.txt` can decrypt.

## Decrypt a snapshot

`age` needs the private key as a file on disk. The recipient key lives in
1Password (`op://Private/id_personal`), so export it to a temp file for
the duration of the decrypt:

```fish
set key (mktemp -t age-key.XXXXXX)
op read "op://Private/id_personal/private key?ssh-format=openssh" > $key
chmod 600 $key

age -i $key -d specs/metrics-baseline/snapshots/baseline-2026-04.md.age \
  | less   # or redirect to a path OUTSIDE snapshots/

shred -u $key 2>/dev/null; or rm -P $key
```

Never write the decrypted plaintext back under
`specs/metrics-baseline/snapshots/` — the pre-commit guard will reject it
and, more importantly, it shouldn't exist there in the first place.

## Adding a recipient

Append the new `ssh-rsa …` / `ssh-ed25519 …` line to `recipients.txt`,
commit, and re-encrypt existing snapshots so the new recipient can read
them. Removing a recipient requires the same re-encrypt.
