#!/usr/bin/env bash
# Merges cc-notify hooks into ~/.claude/settings.json non-destructively.
# Existing hooks are preserved; cc-notify hooks are added only if not present.

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

# Ensure settings file exists
if [[ ! -f "$SETTINGS" ]]; then
    echo '{}' > "$SETTINGS"
fi

# Back up settings before modifying
cp "$SETTINGS" "${SETTINGS}.bak"

# Use Python (available on all macOS) to merge hooks into settings.json
python3 - "$SETTINGS" <<'PYEOF'
import sys, json

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

events = ["UserPromptSubmit", "Notification", "Stop"]
hook_template = '"$HOME/Applications/CCNotify.app/Contents/Resources/ccnotify-hook.sh" {event}'
marker = "CCNotify.app"  # matches this and every earlier hook command format

hooks = settings.setdefault("hooks", {})

for event in events:
    hook_cmd = hook_template.format(event=event)
    event_hooks = hooks.setdefault(event, [])

    # Replace rather than skip: an earlier install's command differs in text, and an
    # exact-match check would leave it in place and add a second, duplicate notifier.
    current = [h for entry in event_hooks for h in entry.get("hooks", []) if marker in h.get("command", "")]
    if len(current) == 1 and current[0].get("command") == hook_cmd:
        print(f"  {event} hook already current, skipping")
        continue

    kept = []
    for entry in event_hooks:
        inner = [h for h in entry.get("hooks", []) if marker not in h.get("command", "")]
        if inner:
            kept.append({**entry, "hooks": inner})
        elif not entry.get("hooks"):
            kept.append(entry)
    kept.append({"hooks": [{"type": "command", "command": hook_cmd}]})
    hooks[event] = kept
    print(f"  {'Updated' if current else 'Added'} {event} hook")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"✓ Hooks configured in {settings_path}")
PYEOF
