# Media Server Cleanup — Test Spec

**Status:** Done
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: the repo-health REQs (A1.1, D1.1) verify through the repo's
CI linters plus manual checks (`[test + manual]`); the remaining repo-side
REQs are `[manual]`; the machine-side REQs verify
through the Task 3 checklist run on the personal host (`[manual]` — no CI
runner has access to the machine's launchd, Docker, or keychain state);
the secrets-hygiene REQ is `[design-level]`, backed by review at Tasks 2,
3, and 5 (the pre-commit hooks contribute lint only). CI is the repo's
GitHub Actions workflow, which runs the Ansible lint suite.

### REQ-A1.1 — stremio block removed, my.cnf retained [test + manual]

`ansible-lint` and `yamllint` pass over the edited role in CI. Manual:
read `roles/services/tasks/main.yml` and confirm only my.cnf and colima
tasks remain; `git log` shows the stremio files deleted, not moved; the
Task 1 PR diff shows no change to the my.cnf task or
`roles/services/files/my.cnf` (the "retained unchanged" clause).

### REQ-A1.2 — no stremio mise task [manual]

`mise tasks` output contains no `stremio` entry.

### REQ-A1.3 — no Plex casks tracked [manual]

`grep -i plex Brewfile.personal` returns nothing.

### REQ-A1.4 — colima tasks retained under new tag [manual]

`./scripts/playbook.sh -t colima` runs the colima start, readiness wait,
and mountInotify tasks on the personal host; `grep -n stremio
roles/services/tasks/main.yml` returns nothing; every retained colima task
still carries `when: inventory_hostname == 'personal'` and tags exactly
`[services, colima]` (grep the role file for `when:` and `tags:`).

### REQ-A1.5 — repo-wide reference sweep [manual]

`git grep -iwE 'stremio|zurg|plex|autoheal|watchdog'` (word-bounded: the
substring form false-matches "multiplexer"/"complex" in unrelated files;
autoheal/watchdog cover the REQ-A1.1 terms the shorter pattern missed,
verified to have no unrelated word-matches at kickoff) over the working
tree matches only `specs/` and `resign-ipa.fish`. Run at Task 1 and again
at Task 5 close-out.

### REQ-B1.1 — containers and volumes removed [manual]

`docker ps -a` shows none of stremio-server/zurg/autoheal; `docker volume
ls` shows neither `stremio-server_stremio-data` nor
`stremio-server_zurg-data` (the compose-project-prefixed names verified on
the host).

### REQ-B1.2 — watchdog agent removed [manual]

`launchctl list` contains no `com.inkatze.stremio-watchdog`; the plist is
absent from `~/Library/LaunchAgents/`; no `stremio-watchdog` logs remain
in `/tmp/`.

### REQ-B1.3 — config directory removed [manual]

`~/.config/stremio-server/` does not exist (verifies the rendered token
file is gone with it).

### REQ-B1.4 — Plex stopped and zapped [manual]

`launchctl list` contains no plexapp entries and no `tv.plex.player-helper`
(and its plist is absent from `~/Library/LaunchAgents/`); the three Plex apps are
absent from `/Applications`; `brew list --cask` lists no plex casks;
`~/Library/Application Support/Plex Media Server` does not exist (the
~589 MB library measured at drafting is deleted).

### REQ-B1.5 — Stremio cask zapped [manual]

`brew list --cask` does not list stremio; Stremio.app is absent from
`/Applications`; no Stremio residue remains under `~/Library`
(Application Support, Caches, Preferences — the "data zapped" clause).

### REQ-B1.6 — keychain entry deleted [manual]

`security find-generic-password -a op-service-account -s
OP_SERVICE_ACCOUNT_TOKEN` exits non-zero.

### REQ-B1.7 — colima and dev containers intact [manual]

`colima status` reports running; `docker ps -a` still lists
the Firebird dev container; `brew list` still includes colima, docker, and
docker-compose.

### REQ-C1.1 — service account revoked [manual]

Human confirmation in the Task 4 record that the service account was
deleted in the 1Password admin surface, with the Real-Debrid vault item
untouched.

### REQ-C1.2 — no secrets in committed artifacts [design-level]

The bundle, teardown script, and PR bodies name credentials without
reproducing values. Verification is human/agent review at Task 2 (script
review), Task 3 (the PR body that records checklist command outputs), and
Task 5 (close-out); lefthook's pre-commit hooks contribute
lint only — the repo has no general secret scanner (verified against
`lefthook.yml` at kickoff, 2026-07-22).

### REQ-C1.3 — Real-Debrid token regenerated [manual]

Human confirmation in the Task 4 record that the Real-Debrid API token was
regenerated in the Real-Debrid dashboard and the vault item's value
updated in place (item retained). Invalidates the copy that existed in
plaintext in the rendered zurg config.

### REQ-D1.1 — lint and playbook clean after untracking [test + manual]

CI runs `yamllint`/`ansible-lint` on the Task 1 PR. Manual: a full
playbook run on the personal host completes cleanly (reference absence is
established by the REQ-A1.5 sweep, not by the run; the run proves the
playbook still converges without the stack).

### REQ-D1.2 — teardown idempotent [manual]

The teardown script is run a second time immediately after the first
completes; the second run exits zero having changed nothing (each step
reports its no-op guard). Recorded in the Task 3 PR.

### REQ-D1.3 — completion checklist [manual]

The union of the REQ-B1.1–B1.7 checks above, executed in one pass after
teardown and recorded in the Task 3 PR.
