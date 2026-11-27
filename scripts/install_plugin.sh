#!/usr/bin/env bash
# Install (or reinstall) the plugin in Claude Code from this folder.
#
#   bash scripts/install_plugin.sh            setup: fails when Claude Code's command is missing
#   bash scripts/install_plugin.sh --after    what the automatic updater runs after a new release
#
# Finds the `claude` command (on the PATH, in ~/.local/bin, or inside the desktop app on
# Windows and Mac), points the "solnest" plugin source at this folder (replacing an older
# source that pointed at GitHub), installs the plugin from it and records the new version.
# Claude Code loads the plugin straight from this folder, so the new version is live the
# next time Claude Code starts. Running it twice is fine.
#
# Exits 0 only when the plugin files load and the installed plugin's version is this
# folder's VERSION. With --after, a missing `claude` command is not a failure: the files
# are already in place and load at the next start, and a good release must not be undone
# because a background check could not see the command.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
HERE="$(pwd -P)"
AFTER=0; [ "${1:-}" = "--after" ] && AFTER=1
PLUGIN="solnest-coding-agent@solnest"
MARKET="solnest"

# 1. The files themselves (read-only check; a broken release stops here and gets undone).
PY="bin/py"
if [ ! -x "$PY" ]; then
  PY=""
  for c in python3 python; do
    command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' 2>/dev/null && { PY="$c"; break; }
  done
fi
if [ -z "$PY" ]; then
  echo "files: no Python found. Run install.sh again."
  exit 1
fi
if ! "$PY" scripts/update.py --after; then
  exit 1
fi
WANT="$(tr -d '[:space:]' < VERSION)"

# 2. The `claude` command.
CLAUDE_BIN="$(command -v claude 2>/dev/null)"; for c in "$HOME/.local/bin/claude" "$HOME/.local/bin/claude.exe"; do [ -z "$CLAUDE_BIN" ] && [ -x "$c" ] && CLAUDE_BIN="$c"; done; [ -z "$CLAUDE_BIN" ] && [ -n "${APPDATA:-}" ] && CLAUDE_BIN="$(ls -t "$(cygpath -u "$APPDATA" 2>/dev/null || printf '%s' "$APPDATA")"/Claude/claude-code/*/claude.exe 2>/dev/null | head -1)"; [ -z "$CLAUDE_BIN" ] && CLAUDE_BIN="$(ls -t "$HOME/Library/Application Support/Claude/claude-code/"*/claude.app/Contents/MacOS/claude 2>/dev/null | head -1)"
if [ -z "$CLAUDE_BIN" ]; then
  echo "claude: NOT FOUND"
  [ "$AFTER" = 1 ] && { echo "plugin: files are at version $WANT and load the next time Claude Code starts"; exit 0; }
  exit 1
fi

# 3. Point the plugin source at this folder. An older install added the source straight
#    from GitHub under the same name; that one is removed first (Claude Code removes its
#    copy of the plugin with it, and the next line installs it again from this folder).
#    A source that already is this folder is left alone.
SRC="$("$CLAUDE_BIN" plugin marketplace list --json 2>/dev/null | "$PY" -c '
import json, os, sys
try:
    found = [m for m in json.load(sys.stdin) if m.get("name") == sys.argv[1]]
except Exception:
    found = []
here = os.path.realpath(os.getcwd())
same = bool(found) and bool(found[0].get("path")) and os.path.realpath(found[0]["path"]) == here
print("same" if same else "other" if found else "none")
' "$MARKET" 2>/dev/null)"
if [ "$SRC" != "same" ]; then
  "$CLAUDE_BIN" plugin marketplace remove "$MARKET" >/dev/null 2>&1
fi
"$CLAUDE_BIN" plugin marketplace add "$HERE" && "$CLAUDE_BIN" plugin install "$PLUGIN" && "$CLAUDE_BIN" plugin update "$PLUGIN" >/dev/null 2>&1
GOT="$("$CLAUDE_BIN" plugin list --json 2>/dev/null | "$PY" -c '
import json, sys
try:
    print(next(p.get("version", "") for p in json.load(sys.stdin) if p.get("id") == sys.argv[1]))
except Exception:
    pass
' "$PLUGIN" 2>/dev/null)"
[ -z "$GOT" ] && GOT="$("$CLAUDE_BIN" plugin list 2>/dev/null | grep -A1 "$PLUGIN" | sed -n 's/.*Version:[[:space:]]*//p' | head -1)"
echo "plugin: Version: ${GOT:-not installed}"
[ "$GOT" = "$WANT" ]
