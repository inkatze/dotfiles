#!/bin/sh
# Keeps a runner's work directory out of Spotlight: macOS never indexes a folder
# whose name ends in .noindex. Usage: runner-workdir.sh <runner-dir>
#
# A runner registered with `--work _work.noindex` already does. For one
# registered with the default `_work`, config.sh's --work cannot be applied
# again, so the directory moves to `_work.noindex` and `_work` becomes a
# symlink to it, which the runner follows. Nothing is touched while a job runs
# (its files are in use); the next play run catches up. Prints "moved" on a
# change, otherwise nothing.
set -eu

dir="${1:?usage: runner-workdir.sh <runner-dir>}"
cd "$dir"

if [ -f .runner ] && grep -q '"workFolder"[[:space:]]*:[[:space:]]*"_work.noindex"' .runner; then exit 0; fi
[ -L _work ] && exit 0
if pgrep -f "$dir/bin/Runner.Worker" >/dev/null 2>&1; then exit 0; fi

if [ -d _work ]; then
    [ -e _work.noindex ] && exit 0
    mv _work _work.noindex
else
    [ -e _work ] && exit 0
    mkdir -p _work.noindex
fi
ln -s _work.noindex _work
echo moved
