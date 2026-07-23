# Media Server Cleanup — Tasks

**Status:** Ready
**Last reviewed:** 2026-07-22
**Format-version:** 2
**Execution:** derived — see the status render

## Tasks

### Task 1 — Untrack the media stack from the repo

- **Deliverables:** `roles/services/tasks/main.yml` with the stremio block
  removed and the colima tasks retagged `[services, colima]` (my.cnf and
  the personal-host guard retained); `roles/services/files/stremio/` and
  `roles/services/templates/com.inkatze.stremio-watchdog.plist.j2`
  deleted; `[tasks.stremio]` removed from `mise.toml`; the three Plex
  casks removed from `Brewfile.personal`.
- **Done when:** `yamllint` and `ansible-lint` pass; a repo-wide search
  for stremio/zurg/plex/autoheal/watchdog matches nothing outside `specs/`
  and `resign-ipa.fish`; the colima tasks run under
  `./scripts/playbook.sh -t colima`.
- **Dependencies:** none
- **Citations:** D-2, D-3 · REQ-A1.1, REQ-A1.2, REQ-A1.3, REQ-A1.4,
  REQ-A1.5
- **Estimated effort:** half day

### Task 2 — Author the teardown script

- **Deliverables:** an idempotent `scripts/teardown-media-server.sh`
  implementing the D-1 order (watchdog bootout by label + in-flight
  invocation drain + plist/log removal → `docker stop` + `docker rm` of
  `autoheal` first, then `stremio-server` and `zurg`, and
  `docker volume rm` of
  `stremio-server_stremio-data` and `stremio-server_zurg-data` →
  `~/.config/stremio-server/` removal → Plex helper bootout
  (`tv.plex.player-helper`) and server stop, verified exited → quit
  Stremio if running, then `brew uninstall --zap` of the Plex and Stremio
  casks → sweep of known leftover `~/Library` paths (D-4's manual residual
  sweep remains at Task 3 verification) → keychain entry deletion), every step a
  guarded no-op when its target is already absent, with guards that
  distinguish "target absent" from "cannot determine" (docker steps abort
  when the daemon is unreachable rather than skipping), no dependence on
  repo-tracked files (D-2 consequence), and colima plus non-media
  containers untouched.
- **Done when:** script review is clean; each step's absent-target guard
  is reviewed (the absent path is exercised by Task 3's REQ-D1.2
  double-run); no secret material appears in the script.
- **Dependencies:** none
- **Citations:** D-1, D-2, D-4, D-5 · REQ-B1.1, REQ-B1.2, REQ-B1.3,
  REQ-B1.4, REQ-B1.5, REQ-B1.6, REQ-B1.7, REQ-C1.2, REQ-D1.2
- **Estimated effort:** half day

### Task 3 — Execute the teardown on the personal host and verify

- **Deliverables:** the teardown executed on the personal host, with the
  host checkout synced past Task 1's merge and no concurrent playbook or
  mise run during execution (D-2); the
  verification checklist from `test-spec.md` completed and its results
  recorded in the task PR (no media containers/volumes/launchd
  agents/apps/data/keychain entry; colima and the Firebird dev container
  intact; full playbook run clean; second script run a no-op).
- **Done when:** every REQ-B checklist item passes; `yamllint`,
  `ansible-lint`, and the full playbook complete cleanly; the idempotency
  double-run is recorded.
- **Dependencies:** 1, 2
- **Citations:** D-1, D-2 · REQ-B1.1, REQ-B1.2, REQ-B1.3, REQ-B1.4,
  REQ-B1.5, REQ-B1.6, REQ-B1.7, REQ-D1.1, REQ-D1.2, REQ-D1.3
- **Estimated effort:** half day

### Task 4 — Revoke the 1Password service account (manual)

- **Deliverables:** the 1Password service account whose only consumer was
  the media stack revoked/deleted by the human in the 1Password admin
  surface; the Real-Debrid API token regenerated in the Real-Debrid
  dashboard and the vault item's value updated in place (REQ-C1.3); the
  revocation and rotation noted in the task record.
- **Done when:** the human confirms the service account no longer exists
  and the Real-Debrid token has been regenerated; the Real-Debrid vault
  item itself is retained (value updated, item not deleted).
- **Dependencies:** 3
- **Citations:** REQ-C1.1, REQ-C1.3
- **Estimated effort:** half day

### Task 5 — Remove the teardown script and close out

- **Deliverables:** `scripts/teardown-media-server.sh` deleted per D-5; a
  final repo-wide reference sweep; a dated Changelog entry in
  `requirements.md` recording completion.
- **Done when:** the script is gone from the working tree (present only in
  history); the REQ-A1.5 search is clean; the Changelog entry is
  committed.
- **Dependencies:** 3, 4
- **Citations:** D-5 · REQ-A1.5, REQ-C1.2
- **Estimated effort:** half day

## Awaiting input

(none yet)

## Deferred

(none yet)

## Out of scope

- Transmission, VLC, Infuse, `resign-ipa.fish`, `my.cnf`, and the
  colima/docker runtime: excluded per the Scope section of
  `requirements.md`.
- Deletion of the Real-Debrid vault item: the item stays; only its token
  value is regenerated per REQ-C1.3 (Task 4).
- The future media-server re-add design: a separate spec, which should
  cite this bundle and obs:552c0512's resolution.
