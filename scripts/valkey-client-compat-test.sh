#!/usr/bin/env bash
# Valkey verification for the declared dev-services layer (specs/dev-services
# Task 4, D-2). Makes Task 4's Done-when checkable rather than asserted:
#
#   Loopback      -- the server is listening at the declared address and port,
#                    and at no non-loopback address. Both directions are
#                    checked: the listening sockets are enumerated, and a real
#                    connection is attempted against every non-loopback address
#                    the host actually has (REQ-A1.3).
#   Client        -- the consuming stack's Redis client, the Elixir library
#                    `redix`, connects on loopback with no credentials and gets
#                    a successful ping (REQ-A1.5, REQ-A1.2).
#   Compatibility -- that same client is then exercised across the command
#                    surface a cache/session consumer actually depends on:
#                    string and counter commands, expiry, pipelining, a
#                    MULTI/EXEC transaction, server-error propagation, and
#                    pub/sub.
#
# The third group is the point of this script and the reason it is a script at
# all. D-2 chose Valkey over Redis on a maintenance-stream argument, and
# accepted a client-compatibility risk it recorded as *researched rather than
# executed*. Task 4's Done-when closes that gap by requiring the real client be
# run against a real server, and states that a failure there reopens D-2 rather
# than being worked around. A `valkey-cli` ping would not close it: it proves
# the two halves of one vendor's own tooling agree, which was never in doubt.
# So the client here is the library the consuming stack actually uses, and the
# commands are ones a consumer issues rather than a handshake.
#
# Two modes, chosen automatically and named in the output:
#
#   live    -- the declared unit is active, so the assertions run against the
#              provisioned service. This is the strong form, and what the
#              target host gives once the role has run.
#   staged  -- the unit is not active, so the archive package is fetched and
#              unpacked into a scratch directory and started from *its own*
#              shipped valkey.conf. Only the state paths and the port are
#              rewritten; `bind`, `protected-mode` and `requirepass` are
#              carried through untouched and asserted to be, since those three
#              are the whole of what the loopback assertions are about. This
#              mode needs no root, which is what lets the compatibility clause
#              be answered from a worktree on a host where the role has not
#              yet provisioned anything.
#
# The client's dependencies are fetched from hex.pm at pinned versions and
# verified by SHA-256, then compiled directly -- no `mix deps.get`, no
# `Mix.install`. Two reasons. A compatibility result is only meaningful if it
# names the version it holds for, and pinning is what makes the recorded result
# reproducible rather than "whatever resolved that day". And the mise-managed
# Erlang on the target host is currently built without OpenSSL, so it has no
# `crypto` application and hex cannot be reached over TLS at all; the pinned
# path is the one that works on both a healthy toolchain and that one. (The
# broken Erlang build is recorded as an observation; it is not this bundle's to
# fix, and this script does not depend on it being fixed.)
#
# Not wired into CI or lefthook: it needs an Elixir toolchain and network, and
# the macOS matrix has neither reason nor ability to run it. Task 6's Linux job
# owns the in-CI form of the loopback assertions. Run manually, from a
# mise-activated shell so the Elixir and Erlang compilers are on PATH:
#
#   fish -c "scripts/valkey-client-compat-test.sh"
#
# Exit 0 = all assertions pass.
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
defaults="$repo_root/roles/services/defaults/main.yml"

# Pinned client and its transitive dependencies. `redix` is the consuming
# stack's client; `nimble_options` and `telemetry` are what it requires. Bump a
# version here and the SHA-256 beside it, then re-run: the recorded result then
# holds for the new pair rather than silently for the old one.
deps=(
    "redix 1.6.0 b2eccb05e02f21c0c3ca57513e6bacb4dd48e6406dadbd7ff9fbe07bd6745999"
    "nimble_options 1.1.1 821b2470ca9442c4b6984882fe9bb0389371b8ddec4d45a9504f00a66f650b44"
    "telemetry 1.3.0 7015fc8919dbe63764f4b4b87a95b7c0996bd539e0d499be6ec9d7f3875b79e6"
)

fails=0
pass() { echo "ok[$1]: $2"; }
fail() {
    echo "FAIL[$1]: $2" >&2
    fails=$((fails + 1))
}

# Elixir malfunctions under a non-UTF-8 locale -- it warns that the VM's native
# name encoding is latin1 and then misbehaves on any non-ASCII byte. Agent
# sessions on this host export LC_ALL=C, so this is a live case rather than a
# hypothetical one. Set it here rather than asking the caller to.
case "${LC_ALL:-${LANG:-}}" in
*UTF-8* | *utf-8* | *utf8* | *UTF8*) ;;
*) export LANG=C.UTF-8 LC_ALL=C.UTF-8 ;;
esac

# `ip` and `timeout` are here for a sharper reason than the rest. Both are used
# by the non-loopback assertion, and neither failure is loud: without `ip` the
# address list comes back empty and the assertion downgrades to a skip line
# claiming the host has no non-loopback interface, and without `timeout` every
# connection probe fails and reads as a refusal. Either way a missing tool
# would be reported as a passing security property. A guard that quietly checks
# less than it claims is worse than one that refuses to run, which is the same
# posture scripts/gitleaks-identifier-rules.sh takes toward its own input.
#
# The staged-mode-only tools are checked inside stage_server instead, so a live
# run on a host without them still works.
for tool in python3 curl sha256sum tar ss ip timeout elixir elixirc erlc; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "FAIL: $tool not on PATH; run from a mise-activated shell" >&2
        exit 1
    fi
done
if ! python3 -c 'import yaml' 2>/dev/null; then
    echo "FAIL: python3 has no yaml module; the declaration below is read with it" >&2
    exit 1
fi

workdir=$(mktemp -d)
server_pid=""
cleanup() {
    if [[ -n "$server_pid" ]] && kill -0 "$server_pid" 2>/dev/null; then
        kill "$server_pid" 2>/dev/null || true
        wait "$server_pid" 2>/dev/null || true
    fi
    rm -rf "$workdir"
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# The declaration is the source of truth for what to test against
# ---------------------------------------------------------------------------
#
# Read rather than hard-coded, so a declaration edit moves this script's target
# with it. That is the same property REQ-B1.1 asks of the lifecycle tasks, and
# a verification script that names its own address and port would quietly stop
# testing the declared service the moment the two diverged.
if ! decl=$(python3 - "$defaults" <<'PY'
import sys, yaml

doc = yaml.safe_load(open(sys.argv[1])) or {}
for entry in doc.get("services_dev_services") or []:
    if entry.get("package") == "valkey-server":
        print(entry["unit"])
        print(entry["listen_address"])
        print(entry["listen_port"])
        break
else:
    sys.exit("no services_dev_services entry declares package valkey-server")
PY
); then
    echo "FAIL: could not read the Valkey declaration from $defaults" >&2
    exit 1
fi
declared_unit=$(sed -n 1p <<<"$decl")
declared_address=$(sed -n 2p <<<"$decl")
declared_port=$(sed -n 3p <<<"$decl")
echo "declaration: unit=$declared_unit address=$declared_address port=$declared_port"

# ---------------------------------------------------------------------------
# Mode: the provisioned service if there is one, otherwise a staged instance
# ---------------------------------------------------------------------------
stage_server() {
    local pkgdir="$workdir/pkg" rundir="$workdir/run" conf="$workdir/run/valkey.conf"
    mkdir -p "$pkgdir" "$rundir"

    for tool in apt-get dpkg-deb; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "FAIL: $tool not on PATH; staged mode unpacks the archive package with it" >&2
            exit 1
        fi
    done

    # Refuse to stage onto an occupied port. Without this the assertions below
    # would run against whatever process already holds it, and every one of
    # them would pass: the bind checks would describe the foreign socket, and
    # the client checks would succeed outright if that process happened to be
    # a `redis-server` -- reporting a Valkey compatibility result derived from
    # the very engine D-2 rejected. The service being active is the one case
    # where another listener is expected, and it is handled as live mode.
    if ss -Hltn "sport = :$declared_port" | grep -q .; then
        echo "FAIL: something is already listening on port $declared_port, so a staged" >&2
        echo "      run would assert against it rather than against the packaged server." >&2
        echo "      Stop it, or start $declared_unit so this runs in live mode." >&2
        exit 1
    fi

    # valkey-tools carries the actual server binary; in valkey-server,
    # /usr/bin/valkey-server is a symlink into it. Fetching only the declared
    # package would unpack a dangling link.
    if ! (cd "$pkgdir" && apt-get download valkey-server valkey-tools >/dev/null 2>&1); then
        echo "FAIL: could not fetch the valkey-server package from the archive" >&2
        exit 1
    fi
    for deb in "$pkgdir"/*.deb; do
        dpkg-deb -x "$deb" "$pkgdir/root"
    done

    local shipped="$pkgdir/root/etc/valkey/valkey.conf"
    local binary="$pkgdir/root/usr/bin/valkey-server"
    if [[ ! -f "$shipped" || ! -x "$binary" ]]; then
        echo "FAIL: unpacked package has no valkey.conf or no server binary" >&2
        exit 1
    fi

    # State paths and the port move; nothing else does. The server refuses to
    # start if `dir` names a directory it cannot reach, and the packaged value
    # is a root-owned /var path, so this rewrite is what makes a rootless run
    # possible at all.
    sed -E \
        -e "s#^dir .*#dir $rundir#" \
        -e "s#^logfile .*#logfile $rundir/valkey.log#" \
        -e "s#^pidfile .*#pidfile $rundir/valkey.pid#" \
        -e "s#^port .*#port $declared_port#" \
        "$shipped" >"$conf"

    # Assert the rewrite left the security-relevant directives alone. Without
    # this, a sed that over-matched would turn the loopback assertions below
    # into assertions about this script's own edit.
    local shipped_sec staged_sec
    shipped_sec=$(grep -E '^(bind|protected-mode|requirepass) ' "$shipped" || true)
    staged_sec=$(grep -E '^(bind|protected-mode|requirepass) ' "$conf" || true)
    if [[ "$shipped_sec" != "$staged_sec" ]]; then
        fail "staged-config-faithful" \
            "the staged config's bind/protected-mode/requirepass differ from the packaged ones"
    else
        pass "staged-config-faithful" \
            "packaged bind/protected-mode/requirepass carried through unmodified"
    fi

    "$binary" "$conf" --daemonize no >"$rundir/stdout.log" 2>&1 &
    server_pid=$!

    # Liveness is checked *before* the socket is accepted as ours, so that a
    # server which lost a race for the port cannot have someone else's listener
    # mistaken for a successful start. The check above makes that race narrow;
    # this makes it closed.
    local waited=0
    while true; do
        if ! kill -0 "$server_pid" 2>/dev/null; then
            echo "FAIL: staged valkey-server exited during startup:" >&2
            cat "$rundir/stdout.log" >&2
            exit 1
        fi
        if ss -Hltn "sport = :$declared_port" | grep -q .; then
            break
        fi
        sleep 0.2
        waited=$((waited + 1))
        if [[ "$waited" -gt 100 ]]; then
            echo "FAIL: staged valkey-server did not listen on port $declared_port within 20s" >&2
            exit 1
        fi
    done
}

mode=staged
if command -v systemctl >/dev/null 2>&1 &&
    [[ "$(systemctl is-active "$declared_unit" 2>/dev/null || true)" == "active" ]]; then
    mode=live
fi

if [[ "$mode" == live ]]; then
    echo "mode: live -- asserting against the provisioned $declared_unit"
else
    echo "mode: staged -- $declared_unit is not active, so the archive package is" \
        "unpacked and started from its own shipped config"
    stage_server
fi

# ---------------------------------------------------------------------------
# Loopback, both directions
# ---------------------------------------------------------------------------
#
# The lifecycle's wait_for step already asserts the declared address and port
# are listening. It cannot assert the negative, because a service bound to a
# wildcard satisfies a loopback connection perfectly well -- which is exactly
# the regression REQ-A1.3 is about, since both engines' upstream defaults
# differ from the distribution's and a packaging change could widen the bind
# without anything else changing.
listening=$(ss -Hltn "sport = :$declared_port" | awk '{print $4}')
if [[ -z "$listening" ]]; then
    fail "listening" "nothing is listening on port $declared_port"
else
    # Both questions -- are all the binds loopback, and is the declared one
    # among them -- are answered where the addresses are already parsed. Doing
    # the second with a regex over the raw `ss` output was the weaker half: it
    # escaped dots and anchored on them, so it only ever understood dotted
    # IPv4, and a declaration naming `::1` would have been reported as missing
    # from a socket list that contained it, since `ss` writes IPv6 bracketed.
    # `ipaddress` compares addresses as addresses, so the two forms of the same
    # address agree and no escaping is involved.
    bind_report=$(python3 - "$declared_address" <<PY
import ipaddress, sys

declared = ipaddress.ip_address(sys.argv[1])
wildcards = {"*", "0.0.0.0", "::"}
non_loopback = []
declared_found = False

for entry in """$listening""".split():
    host = entry.rsplit(":", 1)[0].strip("[]")
    if host in wildcards:
        non_loopback.append(entry)
        continue
    try:
        address = ipaddress.ip_address(host)
    except ValueError:
        non_loopback.append(entry)
        continue
    if not address.is_loopback:
        non_loopback.append(entry)
    if address == declared:
        declared_found = True

print("yes" if declared_found else "no")
print(" ".join(non_loopback))
PY
    )
    declared_found=$(sed -n 1p <<<"$bind_report")
    non_loopback_binds=$(sed -n 2p <<<"$bind_report")

    if [[ -n "$non_loopback_binds" ]]; then
        fail "bind-loopback-only" \
            "port $declared_port is bound at non-loopback address(es): $non_loopback_binds"
    else
        pass "bind-loopback-only" \
            "every socket on port $declared_port is bound to a loopback address"
    fi

    if [[ "$declared_found" == yes ]]; then
        pass "bind-declared" "listening at the declared $declared_address:$declared_port"
    else
        fail "bind-declared" \
            "nothing is listening at the declared $declared_address:$declared_port (found: $listening)"
    fi
fi

# Enumerating sockets proves what the kernel was asked for. Attempting a
# connection proves what a client on the LAN would actually get, which is the
# form Task 4's Done-when is written in. Addresses are discovered rather than
# named: this repo is public, and the host's own addresses are not something to
# commit (REQ-D1.1's posture, and the repo guide's machine-local rule).
mapfile -t host_addresses < <(ip -o addr show scope global 2>/dev/null |
    awk '{split($4, a, "/"); print a[1]}')
if [[ "${#host_addresses[@]}" -eq 0 ]]; then
    echo "skip[no-non-loopback-connection]: the host has no global-scope address," \
        "so there is no non-loopback interface to refuse a connection on"
else
    reachable=()
    for address in "${host_addresses[@]}"; do
        if timeout 5 bash -c "exec 3<>/dev/tcp/$address/$declared_port" 2>/dev/null; then
            reachable+=("$address")
        fi
    done
    if [[ "${#reachable[@]}" -gt 0 ]]; then
        fail "no-non-loopback-connection" \
            "port $declared_port accepted a connection on ${#reachable[@]} non-loopback address(es)"
    else
        pass "no-non-loopback-connection" \
            "all ${#host_addresses[@]} non-loopback address(es) refused a connection on port $declared_port"
    fi
fi

# ---------------------------------------------------------------------------
# The consuming stack's client
# ---------------------------------------------------------------------------
ebin="$workdir/ebin"
mkdir -p "$ebin" "$workdir/src"
for dep in "${deps[@]}"; do
    read -r name version checksum <<<"$dep"
    tarball="$workdir/src/$name-$version.tar"
    if ! curl -sSfL -o "$tarball" "https://repo.hex.pm/tarballs/$name-$version.tar"; then
        echo "FAIL: could not fetch $name $version from hex.pm" >&2
        exit 1
    fi
    if ! echo "$checksum  $tarball" | sha256sum --check --status; then
        echo "FAIL: $name $version does not match its pinned SHA-256" >&2
        exit 1
    fi
    mkdir -p "$workdir/src/$name"
    tar -xf "$tarball" -C "$workdir/src/$name"
    tar -xzf "$workdir/src/$name/contents.tar.gz" -C "$workdir/src/$name"
done
# Name the versions, not just the libraries. The result this script reports is
# a statement about a specific pair of versions, and a record that omits half
# of the pair is not one a later reader can act on.
pinned=$(for dep in "${deps[@]}"; do
    read -r name version _ <<<"$dep"
    printf '%s %s, ' "$name" "$version"
done)
pass "client-pinned" "${pinned%, } fetched and SHA-256 verified"

# telemetry is Erlang and ships an app resource file; redix requires it to be
# a *started* application, not merely loadable, or every command it issues logs
# a handler-lookup warning.
if ! erlc -o "$ebin" "$workdir"/src/telemetry/src/*.erl >"$workdir/telemetry-compile.log" 2>&1; then
    echo "FAIL: telemetry did not compile; the compatibility clause cannot be answered" >&2
    cat "$workdir/telemetry-compile.log" >&2
    exit 1
fi
cp "$workdir/src/telemetry/src/telemetry.app.src" "$ebin/telemetry.app"
# `mix` is unusable here (it needs :crypto for its build lock), so the two
# Elixir libraries are compiled straight to BEAM. redix references :ssl, which
# this Erlang lacks; that is a warning at compile time and irrelevant at run
# time, because a loopback connection with no credentials uses no TLS -- so the
# compiler's output is kept out of the way rather than shown, but it is kept,
# and printed if the compile fails. A silent abort here would be the worst
# outcome: the compatibility clause would go unanswered with nothing said.
compile() {
    local library="$1" log="$workdir/$1-compile.log"
    local sources=()
    mapfile -t sources < <(find "$workdir/src/$library/lib" -name '*.ex')
    if ! elixirc -o "$ebin" -pa "$ebin" --ignore-module-conflict \
        "${sources[@]}" >"$log" 2>&1; then
        echo "FAIL: $library did not compile; the compatibility clause cannot be answered" >&2
        cat "$log" >&2
        exit 1
    fi
}
compile nimble_options
compile redix
if [[ ! -f "$ebin/Elixir.Redix.beam" ]]; then
    echo "FAIL: redix compiled without producing Elixir.Redix; refusing to report a result" >&2
    exit 1
fi

# Every assertion below runs through redix. Deliberately: substituting
# `valkey-cli` for the ping would prove the vendor's own tooling talks to the
# vendor's own server, which is not the claim D-2 needs checked.
cat >"$workdir/exercise.exs" <<'EOF'
Application.ensure_all_started(:telemetry)

address = System.fetch_env!("VALKEY_ADDRESS")
port = System.fetch_env!("VALKEY_PORT")
uri = "valkey://#{address}:#{port}"

defmodule Check do
  def run(label, expected, fun) do
    actual = fun.()

    if actual == expected do
      IO.puts("ok[client-#{label}]: #{inspect(actual)}")
    else
      IO.puts(:stderr, "FAIL[client-#{label}]: expected #{inspect(expected)}, got #{inspect(actual)}")
      Process.put(:failed, true)
    end
  end
end

# The `valkey://` scheme rather than `redis://`: redix has understood it since
# v1.5.0, and using it means the connection path being exercised is the one a
# consumer configured for Valkey would take.
{:ok, conn} = Redix.start_link(uri)

# Clause one of the Done-when: a local client, no credentials, a good ping.
Check.run("ping", {:ok, "PONG"}, fn -> Redix.command(conn, ["PING"]) end)

key = "planwright:dev-services:task4:" <> Integer.to_string(System.unique_integer([:positive]))

Check.run("set-get", {:ok, "cached"}, fn ->
  {:ok, "OK"} = Redix.command(conn, ["SET", key, "cached"])
  Redix.command(conn, ["GET", key])
end)

Check.run("expiry", true, fn ->
  {:ok, 1} = Redix.command(conn, ["EXPIRE", key, "60"])
  {:ok, ttl} = Redix.command(conn, ["TTL", key])
  ttl > 0 and ttl <= 60
end)

Check.run("counter", {:ok, 7}, fn -> Redix.command(conn, ["INCRBY", key <> ":n", "7"]) end)

Check.run("pipeline", {:ok, ["OK", "OK", ["1", "2"]]}, fn ->
  Redix.pipeline(conn, [
    ["SET", key <> ":a", "1"],
    ["SET", key <> ":b", "2"],
    ["MGET", key <> ":a", key <> ":b"]
  ])
end)

Check.run("transaction", {:ok, ["OK", "x"]}, fn ->
  Redix.transaction_pipeline(conn, [["SET", key <> ":t", "x"], ["GET", key <> ":t"]])
end)

# A server-side error must arrive as %Redix.Error{}, not as a crash or a
# mangled reply. This is where a protocol divergence between the two engines
# would surface first, so it is asserted rather than assumed.
Check.run("server-error", true, fn ->
  case Redix.command(conn, ["INCR", key]) do
    {:error, %Redix.Error{message: message}} -> is_binary(message) and message != ""
    other -> other
  end
end)

Check.run("delete", {:ok, 5}, fn ->
  Redix.command(conn, ["DEL", key, key <> ":n", key <> ":a", key <> ":b", key <> ":t"])
end)

# Pub/sub runs over a second connection type with its own protocol mode, so it
# is a genuinely separate compatibility surface from the command connection.
Check.run("pubsub", {:ok, "payload"}, fn ->
  {:ok, pubsub} = Redix.PubSub.start_link(uri)
  {:ok, ref} = Redix.PubSub.subscribe(pubsub, "planwright:dev-services:task4", self())

  receive do
    {:redix_pubsub, ^pubsub, ^ref, :subscribed, _} -> :ok
  after
    5_000 -> throw(:subscribe_timeout)
  end

  {:ok, 1} = Redix.command(conn, ["PUBLISH", "planwright:dev-services:task4", "payload"])

  receive do
    {:redix_pubsub, ^pubsub, ^ref, :message, %{payload: payload}} -> {:ok, payload}
  after
    5_000 -> {:error, :message_timeout}
  end
end)

{:ok, info} = Redix.command(conn, ["INFO", "server"])

info
|> String.split("\r\n")
|> Enum.filter(&String.starts_with?(&1, ["server_name:", "valkey_version:", "redis_version:"]))
|> Enum.sort()
|> Enum.each(&IO.puts("server: #{&1}"))

if Process.get(:failed), do: System.halt(1)
EOF

read -r _ redix_version _ <<<"${deps[0]}"
if VALKEY_ADDRESS="$declared_address" VALKEY_PORT="$declared_port" \
    elixir -pa "$ebin" "$workdir/exercise.exs"; then
    pass "client-compatibility" \
        "redix $redix_version exercised against the running server across the command surface above"
else
    fail "client-compatibility" \
        "redix could not be exercised against the running server; per Task 4 this reopens D-2"
fi

if [[ "$fails" -ne 0 ]]; then
    echo "valkey-client-compat-test: $fails assertion(s) failed" >&2
    exit 1
fi
echo "valkey-client-compat-test: all assertions passed ($mode mode)"
