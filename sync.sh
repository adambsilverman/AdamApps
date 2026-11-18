#!/bin/bash
# sync.sh — commit and push whatever changed in AdamApps, SilverApps and MarkaApps.
#
# Nothing runs on a schedule. Claude runs this once when it has finished editing files:
#  • On the Mac (Claude Code, or you in Terminal): commits and pushes straight away.
#    Claude Code runs it automatically through the Stop hook that setup-mac.command installs.
#  • In Claude's Linux shell (desktop app sessions), where pushing to GitHub is blocked:
#    commits, then sets the flag .git/push-requested. The Mac notices that one file change
#    (launchd WatchPaths, installed by setup-mac.command) and runs this script to push.
# Repos with nothing to commit or push are skipped without touching the network.

ROOT="$(cd "$(dirname "$0")" && pwd)"
FLAG="$ROOT/.git/push-requested"
ON_MAC=0; [ "$(uname)" = Darwin ] && ON_MAC=1
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if [ "$ON_MAC" = 1 ]; then HOST="$(scutil --get ComputerName 2>/dev/null || hostname -s)"; else HOST="Claude"; fi
NEED_PUSH=0

sync_repo() {
  local repo="$1" name; name="$(basename "$repo")"
  cd "$repo" 2>/dev/null && [ -d .git ] || return 0
  if [ -e build/.build.lock ]; then echo "$name: a build is running — run sync.sh again when it finishes"; return 0; fi

  if [ -n "$(git status --porcelain)" ]; then
    # MarkaApps: rebuild the index whenever an app (not just index.html) changed
    if [ -f ./handoff.sh ] && git status --porcelain | grep -v ' index\.html$' | grep -q '\.html'; then
      bash ./handoff.sh --no-push >/dev/null || echo "$name: handoff.sh failed"
    fi
    git add -A
    local n files
    n="$(git diff --cached --name-only | wc -l | tr -d ' ')"
    files="$(git diff --cached --name-only | sed 's#.*/##' | head -5 | paste -sd ',' - | sed 's/,/, /g')"
    [ "$n" -gt 5 ] && files="$files and $((n-5)) more"
    git commit -q -m "Update from $HOST: $files" && echo "$name: committed $n file(s)"
  fi

  local upstream=1; git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 || upstream=0
  if [ "$upstream" = 1 ] && [ -z "$(git log '@{u}..' --oneline 2>/dev/null)" ]; then return 0; fi  # nothing to send

  if [ "$ON_MAC" = 0 ]; then NEED_PUSH=1; echo "$name: ready — your Mac will push it"; return 0; fi

  if [ "$upstream" = 0 ]; then   # brand-new repo, first push
    git push -q -u origin HEAD && echo "$name: first push to GitHub" || { echo "$name: PUSH FAILED"; NEED_PUSH=1; }
    return 0
  fi
  if ! git pull -q --rebase --autostash; then
    git rebase --abort >/dev/null 2>&1
    echo "$name: CONFLICT with GitHub — not pushed. Resolve in $repo (git status)."
    osascript -e "display notification \"$name conflicts with GitHub — open Terminal there and run git status\" with title \"AdamApps\"" 2>/dev/null
    return 0
  fi
  git push -q && echo "$name: pushed to GitHub" || { echo "$name: PUSH FAILED"; NEED_PUSH=1; }
}

for r in "$ROOT" "$ROOT/SilverApps" "$ROOT/MarkaApps"; do sync_repo "$r"; done

if [ "$ON_MAC" = 0 ]; then
  [ "$NEED_PUSH" = 1 ] && date > "$FLAG"          # wake the Mac's watcher
else
  [ "$NEED_PUSH" = 0 ] && rm -f "$FLAG"           # all pushed: clear any request
fi
exit 0
