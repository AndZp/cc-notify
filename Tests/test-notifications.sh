#!/usr/bin/env bash
# Sends mock hook payloads to cc-notify to verify each notification type.
# Requires cc-notify to be installed at ~/Applications/CCNotify.app
#
# Usage:
#   bash Tests/test-notifications.sh           # run all tests
#   bash Tests/test-notifications.sh stop-only # only send a Stop notification

set -euo pipefail

APP="$HOME/Applications/CCNotify.app"
MODE="${1:-all}"

if [[ ! -d "$APP" ]]; then
    echo "Error: CCNotify.app not found at $APP"
    echo "Run 'make install' first."
    exit 1
fi

send() {
    local event="$1"
    local payload="$2"
    local f
    f=$(mktemp /tmp/ccnotify_test_XXXXXX.json)
    echo "$payload" > "$f"
    open -n "$APP" --args "$event" "" "$f"
    sleep 0.5
}

if [[ "$MODE" == "stop-only" ]]; then
    echo "▶ Sending Stop notification..."
    send "Stop" '{"session_id":"test-123","cwd":"/Users/test/cc-notify","hook_event_name":"Stop"}'
    echo "✓ Sent Stop"
    exit 0
fi

echo "▶ Sending test notifications..."
echo ""

echo "1/4 — Permission prompt"
send "Notification" '{
  "session_id": "test-abc",
  "cwd": "/Users/test/my-project",
  "hook_event_name": "Notification",
  "notification_type": "permission_prompt",
  "message": "Run: npm run build"
}'

sleep 1
echo "2/4 — Input needed (idle prompt)"
send "Notification" '{
  "session_id": "test-abc",
  "cwd": "/Users/test/my-project",
  "hook_event_name": "Notification",
  "notification_type": "idle_prompt",
  "message": "Should I continue with the refactor?"
}'

sleep 1
echo "3/4 — UserPromptSubmit (saves timestamp, no notification)"
send "UserPromptSubmit" '{
  "session_id": "test-abc",
  "cwd": "/Users/test/my-project",
  "hook_event_name": "UserPromptSubmit"
}'

sleep 2
echo "4/4 — Stop (with duration from step 3)"
send "Stop" '{
  "session_id": "test-abc",
  "cwd": "/Users/test/my-project",
  "hook_event_name": "Stop"
}'

echo ""
echo "✓ All test notifications sent."
echo "  Check your notification center — you should see 3 notifications."
echo "  The Stop notification should show a duration (e.g. \"Finished in 3s\")."
