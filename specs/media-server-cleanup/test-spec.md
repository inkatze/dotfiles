# Media Server Cleanup — Test Spec

**Status:** Draft
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

Coverage mix: the repo-side REQs verify through the repo's CI linters plus
a manual reference sweep (`[test + manual]`); the machine-side REQs verify
through the Task 3 checklist run on the personal host (`[manual]` — no CI
runner has access to the machine's launchd, Docker, or keychain state);
the secrets-hygiene REQ is `[design-level]` backed by the repo's existing
pre-commit hooks. CI is the repo's GitHub Actions workflow, which runs the
Ansible lint suite.

### REQ-A1.1 — stremio block removed, my.cnf retained [test + manual]

`ansible-lint` and `yamllint` pass over the edited role in CI. Manual:
read `roles/services/tasks/main.yml` and confirm only my.cnf and colima
tasks remain; `git log` shows the stremio files deleted, not moved.

### REQ-A1.2 — no stremio mise task [manual]

`mise tasks` output contains no `stremio` entry.

### REQ-A1.3 — no Plex casks tracked [manual]

`grep -i plex Brewfile.personal` returns nothing.

### REQ-A1.4 — colima tasks retained under new tag [manual]

`./scripts/playbook.sh -t colima` runs the colima start, readiness wait,
and mountInotify tasks on the personal host; `grep -n stremio
roles/services/tasks/main.yml` returns nothing.

### REQ-A1.5 — repo-wide reference sweep [manual]

`git grep -iE 'stremio|zurg|plex'` over the working tree matches only
`specs/` and `resign-ipa.fish`. Run at Task 1 and again at Task 5
close-out.

### REQ-B1.1 — containers and volumes removed [manual]

`docker ps -a` shows none of stremio-server/zurg/autoheal; `docker volume
ls` shows neither stremio-data nor zurg-data.

### REQ-B1.2 — watchdog agent removed [manual]

`launchctl list` contains no `com.inkatze.stremio-watchdog`; the plist is
absent from `~/Library/LaunchAgents/`; no `stremio-watchdog` logs remain
in `/tmp/`.

### REQ-B1.3 — config directory removed [manual]

`~/.config/stremio-server/` does not exist (verifies the rendered token
file is gone with it).

### REQ-B1.4 — Plex stopped and zapped [manual]

`launchctl list` contains no plexapp/plex entries; the three Plex apps are
absent from `/Applications`; `brew list --cask` lists no plex casks;
`~/Library/Application Support/Plex Media Server` does not exist (the
~589 MB library measured at drafting is deleted).

### REQ-B1.5 — Stremio cask zapped [manual]

`brew list --cask` does not list stremio; Stremio.app is absent from
`/Applications`.

### REQ-B1.6 — keychain entry deleted [manual]

`security find-generic-password -a op-service-account -s
OP_SERVICE_ACCOUNT_TOKEN` exits non-zero.

### REQ-B1.7 — colima and dev containers intact [manual]

`colima status` reports running (or startable); `docker ps -a` still lists
the Firebird dev container; `brew list` still includes colima, docker, and
docker-compose.

### REQ-C1.1 — service account revoked [manual]

Human confirmation in the Task 4 record that the service account was
deleted in the 1Password admin surface, with the Real-Debrid vault item
untouched.

### REQ-C1.2 — no secrets in committed artifacts [design-level]

The bundle, teardown script, and PR bodies name credentials without
reproducing values; the repo's pre-commit hooks (lefthook) run on every
commit of this spec's branches. Reviewed at Task 2 (script review) and
Task 5 (close-out).

### REQ-D1.1 — lint and playbook clean after untracking [test + manual]

CI runs `yamllint`/`ansible-lint` on the Task 1 PR. Manual: a full
playbook run on the personal host completes with no stremio-referencing
task.

### REQ-D1.2 — teardown idempotent [manual]

The teardown script is run a second time immediately after the first
completes; the second run exits zero having changed nothing (each step
reports its no-op guard). Recorded in the Task 3 PR.

### REQ-D1.3 — completion checklist [manual]

The union of the REQ-B1.1–B1.7 checks above, executed in one pass after
teardown and recorded in the Task 3 PR.
