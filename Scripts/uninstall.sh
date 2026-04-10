#!/usr/bin/env bash
# Removes cc-notify hooks from ~/.claude/settings.json.
# Other hooks are preserved.

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"

if [[ ! -f "$SETTINGS" ]]; then
    echo "No settings.json found, nothing to remove"
    exit 0
fi

python3 - "$SETTINGS" <<'PYEOF'
import sys, json

settings_path = sys.argv[1]

with open(settings_path) as f:
    settings = json.load(f)

marker = "CCNotify.app"
hooks = settings.get("hooks", {})
removed = 0

for event, entries in list(hooks.items()):
    filtered = []
    for entry in entries:
        inner = [h for h in entry.get("hooks", []) if marker not in h.get("command", "")]
        if inner:
            filtered.append({**entry, "hooks": inner})
        else:
            removed += 1
    if filtered:
        hooks[event] = filtered
    else:
        del hooks[event]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")

print(f"✓ Removed {removed} cc-notify hook(s) from {settings_path}")
PYEOF
