#!/usr/bin/env bash
# Hermetic tests for Scripts/ccnotify-hook.sh: the hook runs from a fake CCNotify.app, and a fake
# `open` on PATH records what it would launch, so nothing is built and no notification is sent.
#
# Usage: bash Tests/test-hook.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APP="$WORK/CCNotify.app"
HOOK="$APP/Contents/Resources/ccnotify-hook.sh"
mkdir -p "$APP/Contents/Resources" "$WORK/bin"
cp "$ROOT/Scripts/ccnotify-hook.sh" "$HOOK"

cat >"$WORK/bin/open" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$OPEN_LOG"
EOF
chmod +x "$WORK/bin/open"

failures=0
args=()

# run_hook <event> <payload> [VAR=value ...] — runs the hook with a clean env plus the given vars,
# then loads what `open` received into $args and removes the payload file it was handed.
run_hook() {
    local event="$1" payload="$2" line
    shift 2
    rm -f "$WORK/open.log"
    args=()
    printf '%s' "$payload" | env -i PATH="$WORK/bin:/usr/bin:/bin" OPEN_LOG="$WORK/open.log" "$@" \
        /bin/sh "$HOOK" "$event"
    [[ -f "$WORK/open.log" ]] || return 0
    while IFS= read -r line; do args+=("$line"); done <"$WORK/open.log"
    received_payload="$(cat "${args[5]}" 2>/dev/null || true)"
    rm -f "${args[5]}"
}

pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; failures=$((failures + 1)); }

# expect_launch <name> <host> <payload> — the app was opened for Stop with <host> and the payload.
expect_launch() {
    local name="$1" host="$2" payload="$3"
    if [[ ${#args[@]} -eq 0 ]]; then
        fail "$name: expected the app to be opened, it was not"
    elif [[ "${args[0]}" == "-n" && "${args[1]}" == "$APP" && "${args[2]}" == "--args" \
            && "${args[3]}" == "Stop" && "${args[4]}" == "$host" \
            && "${args[5]}" == /tmp/ccnotify_* && "$received_payload" == "$payload" ]]; then
        pass "$name"
    else
        fail "$name: unexpected open args: ${args[*]}"
    fi
}

expect_no_launch() {
    local name="$1"
    if [[ ${#args[@]} -eq 0 ]]; then
        pass "$name"
    else
        fail "$name: expected no launch, got: ${args[*]}"
    fi
}

PAYLOAD='{"session_id":"test-123","hook_event_name":"Stop"}'

echo "▶ ccnotify-hook.sh"

run_hook Stop "$PAYLOAD" TERM_PROGRAM=WarpTerminal
expect_launch "terminal: passes TERM_PROGRAM through" "WarpTerminal" "$PAYLOAD"

run_hook Stop "$PAYLOAD" CONDUCTOR_WORKSPACE_ID=ws-1 CLAUDE_AGENT_SDK_VERSION=0.3.0
expect_no_launch "Conductor agent: stands down"

run_hook Stop "$PAYLOAD" CONDUCTOR_WORKSPACE_ID=ws-1 CLAUDE_AGENT_SDK_VERSION=0.3.0 CCNOTIFY_CONDUCTOR=1
expect_launch "Conductor agent + CCNOTIFY_CONDUCTOR: notifies as Conductor" "Conductor" "$PAYLOAD"

run_hook Stop "$PAYLOAD" CONDUCTOR_WORKSPACE_ID=ws-1
expect_launch "claude in Conductor's terminal: still notifies" "" "$PAYLOAD"

# A second session stopping before the app has consumed the first payload needs its own file.
held="$(printf '%s' "$PAYLOAD" | env -i PATH="$WORK/bin:/usr/bin:/bin" OPEN_LOG="$WORK/held.log" \
    TERM_PROGRAM=WarpTerminal /bin/sh "$HOOK" Stop; sed -n 6p "$WORK/held.log")"
run_hook Stop "$PAYLOAD" TERM_PROGRAM=WarpTerminal
rm -f "$held"
expect_launch "two stops before the app reads either get separate payload files" "WarpTerminal" "$PAYLOAD"

if [[ "$failures" -gt 0 ]]; then
    echo "✗ $failures failing"
    exit 1
fi
echo "✓ all hook tests passed"
