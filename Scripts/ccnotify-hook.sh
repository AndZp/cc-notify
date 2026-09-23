#!/bin/sh
# Claude Code hook entry point, installed inside CCNotify.app.
# Usage (from settings.json): ccnotify-hook.sh <Event>   — the hook payload JSON arrives on stdin.
# Living in the bundle means hook behavior ships with the app: `make install` updates it
# without rewriting settings.json.

event="$1"
app="$(cd "$(dirname "$0")/../.." && pwd)"

# Conductor already notifies for its own agents (completion sound, dock badge, click opens the
# workspace), so CCNotify stands down there unless CCNOTIFY_CONDUCTOR is set. Its agents run
# through the Agent SDK; a `claude` typed into Conductor's built-in terminal has
# CONDUCTOR_WORKSPACE_ID but no CLAUDE_AGENT_SDK_VERSION, gets no Conductor notification,
# and keeps CCNotify's.
if [ -n "$CONDUCTOR_WORKSPACE_ID" ] && [ -n "$CLAUDE_AGENT_SDK_VERSION" ]; then
    if [ -z "$CCNOTIFY_CONDUCTOR" ]; then
        cat >/dev/null
        exit 0
    fi
    host="Conductor"
else
    host="$TERM_PROGRAM"
fi

# No suffix after the Xs: BSD mktemp only randomizes trailing Xs, so `…_XXXXXX.json` is one
# fixed filename and two sessions stopping at once collide.
payload=$(mktemp /tmp/ccnotify_XXXXXXXX)
cat >"$payload"
open -n "$app" --args "$event" "$host" "$payload"
