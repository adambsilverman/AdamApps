#!/bin/bash
# sync.sh — commit and push whatever changed in AdamApps, SilverApps and MarkaApps.
#
# Not a background job: Claude runs this once when it has finished editing files
# (automatically in Claude Code via the Stop hook in .claude/settings.json; in other
# sessions because CLAUDE.md tells it to). You can also run it yourself:  ./sync.sh
# Repos with no changes are skipped without touching the network.
#
# Pushing uses your Mac's saved GitHub login. Where that isn't available (Claude working
# through the desktop app's Linux shell), it uses a token saved in .git/github-token
# inside this folder — that file is never uploaded.

ROOT="$(cd "$(dirname "$0")" && pwd)"
TOKEN_FILE="$ROOT/.git/github-token"
if [ -s "$TOKEN_FILE" ]; then
  export GIT_CONFIG_COUNT=2
  export GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=""
  export GIT_CONFIG_KEY_1=credential.helper
  export GIT_CONFIG_VALUE_1="!f() { echo username=x-access-token; echo password=\$(cat '$TOKEN_FILE'); }; f"
fi
HOST="$( (scutil --get ComputerName || hostname -s || hostname) 2>/dev/null | head -1)"

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

  if ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then   # brand-new repo, first push
    git push -q -u origin HEAD && echo "$name: first push to GitHub" || echo "$name: PUSH FAILED"
    return 0
  fi
  [ -z "$(git log '@{u}..' --oneline 2>/dev/null)" ] && return 0  # nothing to send

  if ! git pull -q --rebase --autostash; then
    git rebase --abort >/dev/null 2>&1
    echo "$name: CONFLICT with GitHub — not pushed. Resolve in $repo (git status)."
    return 1
  fi
  git push -q && echo "$name: pushed to GitHub" || echo "$name: PUSH FAILED"
}

for r in "$ROOT" "$ROOT/SilverApps" "$ROOT/MarkaApps"; do sync_repo "$r"; done
