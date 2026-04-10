#!/usr/bin/env bash
# Merges cc-notify hooks into ~/.claude/settings.json non-destructively.
# Existing hooks are preserved; cc-notify hooks are added only if not present.

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
APP="$HOME/Applications/CCNotify.app"

HOOK_CMD='F=$(mktemp /tmp/ccnotify_XXXXXX.json); cat > $F; open -n $HOME/Applications/CCNotify.app --args {{EVENT}} $TERM_PROGRAM $F'

# Ensure settings file exists
if [[ ! -f "$SETTINGS" ]]; then
    echo '{}' > "$SETTINGS"
fi

# Use Python (available on all macOS) to merge hooks into settings.json
python3 - "$SETTINGS" "$APP" <<'PYEOF'
import sys, json, os

settings_path = sys.argv[1]
app_path = sys.argv[2]

with open(settings_path) as f:
    settings = json.load(f)

events = ["UserPromptSubmit", "Notification", "Stop"]
hook_template = (
    "F=$(mktemp /tmp/ccnotify_XXXXXX.json); cat > $F; "
    "open -n $HOME/Applications/CCNotify.app --args {event} $TERM_PROGRAM $F"
)

hooks = settings.setdefault("hooks", {})

for event in events:
    hook_cmd = hook_template.format(event=event)
    event_hooks = hooks.setdefault(event, [])

    # Check if a cc-notify hook already exists for this event
    already_present = any(
        hook_cmd in str(h)
        for entry in event_hooks
        for h in entry.get("hooks", [])
    )

    if not already_present:
        event_hooks.append({"hooks": [{"type": "command", "command": hook_cmd}]})
        print(f"  Added {event} hook")
    else:
        print(f"  {event} hook already present, skipping")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"✓ Hooks configured in {settings_path}")
PYEOF
