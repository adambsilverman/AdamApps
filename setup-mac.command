#!/bin/bash
# Double-click once on each Mac. Sets up pushing to GitHub whenever Claude edits files.
# Nothing runs on a timer:
#  1. Claude Code: a Stop hook runs sync.sh when Claude finishes a reply (.claude/settings.json
#     in AdamApps, SilverApps and MarkaApps; local only, not uploaded).
#  2. Claude in the desktop app (which can't push itself): it commits and touches
#     .git/push-requested; macOS (launchd WatchPaths) runs sync.sh only when that file changes.
# To undo:  ./setup-mac.command --remove
cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"
LABEL="com.adamsilverman.adamapps-push"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/AdamApps-push.log"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
if [ "$1" = "--remove" ]; then
  rm -f "$PLIST" "$ROOT/.claude/settings.json" "$ROOT/SilverApps/.claude/settings.json" "$ROOT/MarkaApps/.claude/settings.json"
  echo "Removed."; exit 0
fi
chmod +x "$ROOT/sync.sh"

# 1. Claude Code Stop hooks
hook() { # hook <dir> <path to sync.sh relative to that project>
  mkdir -p "$1/.claude"
  if [ -f "$1/.claude/settings.json" ] && ! grep -q sync.sh "$1/.claude/settings.json"; then
    echo "⚠ $1/.claude/settings.json already exists; add the Stop hook by hand (see sync.sh)."; return
  fi
  cat > "$1/.claude/settings.json" <<JSON
{
  "hooks": {
    "Stop": [
      { "hooks": [ { "type": "command", "command": "bash \"\$CLAUDE_PROJECT_DIR/$2\"", "timeout": 120 } ] }
    ]
  }
}
JSON
}
hook "$ROOT" "sync.sh"; hook "$ROOT/SilverApps" "../sync.sh"; hook "$ROOT/MarkaApps" "../sync.sh"
for r in SilverApps MarkaApps; do
  grep -qx '.claude/' "$ROOT/$r/.git/info/exclude" 2>/dev/null || echo '.claude/' >> "$ROOT/$r/.git/info/exclude"
done
echo "✓ Claude Code will push after each reply that changed files."

# 2. Push when Claude (desktop app) requests it
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$ROOT/sync.sh</string></array>
  <key>WatchPaths</key><array><string>$ROOT/.git/push-requested</string></array>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$PLIST" && echo "✓ Your Mac will push whenever Claude asks."

# Push anything already waiting, and check macOS lets the background push read Documents
date > "$ROOT/.git/push-requested"; sleep 10
if tail -20 "$LOG" 2>/dev/null | grep -q "Operation not permitted"; then
  echo; echo "macOS blocked the background push from reading Documents."
  echo "In the window that opens: click +, press Cmd-Shift-G, type /bin/bash, click Open,"
  echo "turn its switch on, then double-click this file again."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
else
  echo; tail -6 "$LOG" 2>/dev/null
fi
