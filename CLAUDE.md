# AdamApps

Home folder for all of Adam Silverman's web apps. Lives at `~/Documents/AdamApps` (no longer in OneDrive).
Three separate GitHub repositories, each published with GitHub Pages:

| Folder | Repository | Site |
|---|---|---|
| `AdamApps/` (this folder) | github.com/adambsilverman/AdamApps | https://adambsilverman.github.io/AdamApps/ |
| `AdamApps/SilverApps/` | github.com/adambsilverman/SilverApps | https://adambsilverman.github.io/SilverApps/ |
| `AdamApps/MarkaApps/` | github.com/adambsilverman/MarkaApps | https://adambsilverman.github.io/MarkaApps/ |

`SilverApps/` and `MarkaApps/` are their own git repos, ignored by this one (`.gitignore`).
Each has its own instructions: `SilverApps/HANDOFF.md`, `MarkaApps/CLAUDE.md`.

## Rules
- `index.html` here is the hub page linking to the other sites. Adam's own apps go in this
  folder as `*.html` files; add a card for each to the "My apps" section of `index.html`.
- **When you have finished editing files in any of the three repos, run `sync.sh` (in this
  folder) once, before your final reply.** It commits and pushes every repo that changed (and
  rebuilds the MarkaApps index when an app there changed); unchanged repos are skipped. There is
  no background sync. In Claude Code the Stop hook in `.claude/settings.json` runs it for you.
  Working through the desktop app's Linux shell (`bash $HOME/mnt/AdamApps/sync.sh`), pushing to
  GitHub is blocked, so the script commits and sets `.git/push-requested`; Adam's Mac then pushes
  (launchd watch installed by `setup-mac.command`). Don't try to push any other way.
  Report what it committed/pushed (or any CONFLICT) in your reply.
- `_archive/` holds old material moved out of OneDrive. It is never committed.
- Never put passwords or recovery codes anywhere in this folder: everything outside `_archive/` is public.
