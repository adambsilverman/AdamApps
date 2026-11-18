#!/bin/bash
# Double-click once to turn on automatic GitHub syncing (every 2 minutes, at login too).
# Double-click again any time to re-install. To turn it off:  ./install-sync.command --remove
cd "$(dirname "$0")" || exit 1
ROOT="$(pwd)"
LABEL="com.adamsilverman.adamapps-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/AdamApps-sync.log"

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
if [ "$1" = "--remove" ]; then rm -f "$PLIST"; echo "Auto-sync turned off."; exit 0; fi

chmod +x "$ROOT/sync.sh" "$ROOT/MarkaApps/handoff.sh" 2>/dev/null
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>/bin/bash</string><string>$ROOT/sync.sh</string></array>
  <key>StartInterval</key><integer>120</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST

launchctl bootstrap "gui/$(id -u)" "$PLIST" && echo "✓ Auto-sync is on (every 2 minutes)."
sleep 8
if tail -20 "$LOG" 2>/dev/null | grep -q "Operation not permitted"; then
  echo
  echo "macOS is blocking background access to your Documents folder."
  echo "In the window that opens: click +, press Cmd-Shift-G, type /bin/bash, click Open,"
  echo "and make sure its switch is on. Then double-click this installer again."
  open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
else
  echo "Recent log ($LOG):"; tail -5 "$LOG" 2>/dev/null
fi
