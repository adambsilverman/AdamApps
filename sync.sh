#!/bin/bash
# sync.sh — keep AdamApps, SilverApps and MarkaApps in step with GitHub.
#
# Runs every 2 minutes in the background (see install-sync.command). For each repo it:
#   1. skips the repo if something is mid-edit (a file changed in the last minute),
#      a SilverApps build is running, or git is busy;
#   2. MarkaApps only: rebuilds index.html with handoff.sh when an app changed;
#   3. commits every change, pulls anything new from GitHub, and pushes.
# Run it by hand any time:  ./sync.sh        Log: ~/Library/Logs/AdamApps-sync.log

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="$(scutil --get ComputerName 2>/dev/null || hostname -s)"

log()    { echo "$(date '+%Y-%m-%d %H:%M:%S')  $*"; }
notify() { osascript -e "display notification \"$1\" with title \"AdamApps sync\"" >/dev/null 2>&1; }

sync_repo() {
  local repo="$1" name; name="$(basename "$repo")"
  cd "$repo" 2>/dev/null || { log "$name: folder missing"; return; }
  [ -d .git ] || { log "$name: not a git repo"; return; }
  [ -e .git/index.lock ] || [ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] && { log "$name: git busy, skipping"; return; }
  [ -e build/.build.lock ] && { log "$name: build running, skipping"; return; }

  # Wait until edits settle: anything (outside .git) modified in the last minute?
  if [ -n "$(find . -path ./.git -prune -o -type f -mmin -1 -print 2>/dev/null | grep -v '/\.DS_Store$' | head -1)" ]; then
    log "$name: files still changing, will try next round"; return
  fi

  if [ -n "$(git status --porcelain)" ]; then
    # MarkaApps: rebuild the index whenever an app (not just index.html) changed
    if [ -x ./handoff.sh ] && git status --porcelain | grep -v ' index\.html$' | grep -q '\.html'; then
      ./handoff.sh --no-push >/dev/null 2>&1 || log "$name: handoff.sh failed"
    fi
    git add -A
    local files; files="$(git diff --cached --name-only | sed 's#.*/##' | head -5 | paste -sd ',' - | sed 's/,/, /g')"
    local n; n="$(git diff --cached --name-only | wc -l | tr -d ' ')"
    [ "$n" -gt 5 ] && files="$files and $((n-5)) more"
    git commit -q -m "Auto-sync from $HOST: $files" && log "$name: committed $n file(s)"
  fi

  # First push of a brand-new repo: set up tracking with GitHub
  if ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
    if git push -q -u origin HEAD 2>/tmp/adamapps-push.err; then log "$name: first push to GitHub"
    else log "$name: FIRST PUSH FAILED — $(tr '\n' ' ' </tmp/adamapps-push.err)"; fi
    return
  fi

  # Bring in changes made on GitHub or on another computer
  if ! git pull -q --rebase --autostash 2>/tmp/adamapps-pull.err; then
    git rebase --abort >/dev/null 2>&1
    log "$name: PULL CONFLICT — $(tr '\n' ' ' </tmp/adamapps-pull.err)"
    notify "$name has a conflict with GitHub. Open Terminal in that folder and run: git status"
    return
  fi

  if [ -n "$(git log '@{u}..' --oneline 2>/dev/null)" ]; then
    if git push -q 2>/tmp/adamapps-push.err; then
      log "$name: pushed to GitHub"
    else
      log "$name: PUSH FAILED — $(tr '\n' ' ' </tmp/adamapps-push.err)"
      notify "Couldn't push $name to GitHub. See ~/Library/Logs/AdamApps-sync.log"
    fi
  fi
}

for r in "$ROOT" "$ROOT/SilverApps" "$ROOT/MarkaApps"; do sync_repo "$r"; done
