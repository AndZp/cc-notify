#!/usr/bin/env bash
# Hermetic tests for Scripts/install.sh against a throwaway $HOME.
#
# Usage: bash Tests/test-install.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
SETTINGS="$WORK/.claude/settings.json"
mkdir -p "$WORK/.claude"

failures=0
pass() { echo "  ✓ $1"; }
fail() { echo "  ✗ $1"; failures=$((failures + 1)); }

install() { HOME="$WORK" bash "$ROOT/Scripts/install.sh" >/dev/null; }

# summary — one line per event: "<event> <ccnotify hook count> <other hook count> <ccnotify command>"
summary() {
    python3 - "$SETTINGS" <<'PYEOF'
import json, sys
hooks = json.load(open(sys.argv[1])).get("hooks", {})
for event in ["UserPromptSubmit", "Notification", "Stop"]:
    cmds = [h["command"] for e in hooks.get(event, []) for h in e.get("hooks", [])]
    mine = [c for c in cmds if "CCNotify.app" in c]
    print(event, len(mine), len(cmds) - len(mine), mine[0] if mine else "-")
PYEOF
}

expected() {
    local event
    for event in UserPromptSubmit Notification Stop; do
        echo "$event 1 $1 \"\$HOME/Applications/CCNotify.app/Contents/Resources/ccnotify-hook.sh\" $event"
    done
}

echo "▶ install.sh"

rm -f "$SETTINGS"
install
[[ "$(summary)" == "$(expected 0)" ]] && pass "fresh install adds one hook per event" || fail "fresh install: $(summary)"

cat >"$SETTINGS" <<'EOF'
{
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "F=$(mktemp /tmp/ccnotify_XXXXXX.json); cat > $F; open -n $HOME/Applications/CCNotify.app --args Stop $TERM_PROGRAM $F"}]},
      {"hooks": [{"type": "command", "command": "other-stop-hook"}], "_source": "someone-else"}
    ],
    "Notification": [
      {"hooks": [{"type": "command", "command": "F=$(mktemp /tmp/ccnotify_XXXXXX.json); cat > $F; open -n $HOME/Applications/CCNotify.app --args Notification $TERM_PROGRAM $F"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "F=$(mktemp /tmp/ccnotify_XXXXXX.json); cat > $F; open -n $HOME/Applications/CCNotify.app --args UserPromptSubmit $TERM_PROGRAM $F"}]}
    ]
  },
  "theme": "dark"
}
EOF
install
got="$(summary)"
want="$(expected 0 | sed 's/^Stop 1 0 /Stop 1 1 /')"
[[ "$got" == "$want" ]] && pass "upgrade replaces an older hook instead of adding a second one" || fail "upgrade: $got"

install
[[ "$(summary)" == "$want" ]] && pass "re-running is a no-op" || fail "re-run: $(summary)"

python3 -c "
import json, sys
s = json.load(open('$SETTINGS'))
stop = s['hooks']['Stop']
assert s['theme'] == 'dark'
assert any(e.get('_source') == 'someone-else' and e['hooks'][0]['command'] == 'other-stop-hook' for e in stop)
" && pass "other settings and hooks are preserved" || fail "other settings or hooks were changed"

if [[ "$failures" -gt 0 ]]; then
    echo "✗ $failures failing"
    exit 1
fi
echo "✓ all install tests passed"
