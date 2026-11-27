#!/usr/bin/env bash
# Solnest Coding Agent installer (macOS, Linux, and Windows through Git Bash). No admin
# rights, no PATH edits, nothing to type afterwards. Re-run any time to repair: it keeps
# every file you added.
#
# Run it from Claude Code's Bash tool, or any terminal:
#   bash -o pipefail -c "curl -fsSL https://raw.githubusercontent.com/Solnest-AI/solnest-coding-agent/main/install.sh | bash"
# or, from a copy of the repo:  bash install.sh
#
# What it does: copies the tool into ~/solnest/coding-agent (its permanent home, because
# Claude Code loads the plugin from that folder every time it starts), finds a Python 3.9+
# for the updater (or installs one through uv, no admin needed), writes a launcher
# (bin/py), checks git and jq, and checks the plugin files load. It does not touch Claude
# Code: scripts/install_plugin.sh does that (the next setup step in CLAUDE.md).
set -u

REPO="Solnest-AI/solnest-coding-agent"
BRANCH="${CODING_AGENT_BRANCH:-}"                    # set to test a branch instead of the latest release
ARCHIVE="${CODING_AGENT_ARCHIVE_URL:-}"              # set for offline tests
NAME="coding-agent"
DEST="$HOME/solnest/$NAME"
MANIFEST=".coding-agent-files.txt"
MARK=".claude-plugin/marketplace.json"
HERE=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
fi

OS="$(uname -s)"
WIN=0
case "$OS" in MINGW*|MSYS*|CYGWIN*) WIN=1 ;; esac

echo "Solnest Coding Agent installer ($OS)"

# 0. Never overwrite something that is not ours.
if [ -L "$DEST" ] || [ -e "$DEST/.git" ]; then
  echo "STOP: $DEST is a link or a git checkout (a developer's copy). Nothing was changed."
  exit 3
fi
if [ -f "$DEST/$MARK" ] && ! grep -q '"solnest-coding-agent"' "$DEST/$MARK"; then
  echo "STOP: $DEST holds a different tool. Nothing was changed. Move it away, then run this again."
  exit 3
fi

# 1. The tool files: this copy of the repo if we are running from one, else a download.
SRC=""
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t coding-agent)"
DEST_REAL=""
[ -d "$DEST" ] && DEST_REAL="$(cd "$DEST" && pwd -P)"
if [ -n "$HERE" ] && [ -n "$DEST_REAL" ] && [ "$HERE" = "$DEST_REAL" ]; then
  SRC=""                                   # running from the installed copy: repair in place
  echo "[ok] folder    $DEST (already here, files left as they are)"
elif [ -n "$HERE" ] && [ -f "$HERE/$MARK" ] && [ -f "$HERE/scripts/update.py" ]; then
  SRC="$HERE"
else
  echo "  downloading the tool..."
  if [ -z "$ARCHIVE" ] && [ -z "$BRANCH" ]; then
    # The latest published release (the same thing the updater installs), so work that is
    # only on main never reaches a member. No release yet: main.
    TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest" 2>/dev/null \
           | sed -n 's#.*/releases/tag/\(v[0-9][0-9.]*\)$#\1#p')"
    [ -n "$TAG" ] && ARCHIVE="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
  fi
  [ -z "$ARCHIVE" ] && ARCHIVE="https://github.com/$REPO/archive/refs/heads/${BRANCH:-main}.tar.gz"
  if ! curl -fsSL --retry 3 "$ARCHIVE" -o "$TMP/repo.tar.gz"; then
    echo "ERROR: could not download the tool from GitHub. Check the internet connection and run this again."
    rm -rf "$TMP"; exit 2
  fi
  if ! tar -xzf "$TMP/repo.tar.gz" -C "$TMP"; then
    echo "ERROR: the download could not be unpacked. Run this again."
    rm -rf "$TMP"; exit 2
  fi
  SRC="$(ls -d "$TMP"/*/ 2>/dev/null | head -1)"
  SRC="${SRC%/}"
  if [ -z "$SRC" ] || [ ! -f "$SRC/$MARK" ]; then
    echo "ERROR: the download did not contain the tool."
    rm -rf "$TMP"; exit 2
  fi
fi

if [ -n "$SRC" ]; then
  # Stage a clean copy first: no git link, no keys, no caches, nothing that belongs to
  # one computer. Then copy it over the home folder, where your own files are left alone.
  STAGE="$TMP/stage"
  mkdir -p "$STAGE"
  cp -R "$SRC/." "$STAGE/"
  rm -rf "$STAGE/.git" "$STAGE/.cursor" "$STAGE/.cache" "$STAGE/node_modules" "$STAGE/bin" "$STAGE/.update-backup" \
         "$STAGE/.pytest_cache" "$STAGE/.venv" "$STAGE/$MANIFEST" "$STAGE/stage"
  for f in "$STAGE"/.env "$STAGE"/.env.*; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in .env.example) ;; *) rm -f "$f" ;; esac
  done
  find "$STAGE" -name __pycache__ -type d -prune -exec rm -rf {} + 2>/dev/null
  find "$STAGE" -name .DS_Store -type f -exec rm -f {} + 2>/dev/null
  rm -rf "$STAGE/.claude" "$STAGE/.mcp.json"
  mkdir -p "$DEST"
  cp -R "$STAGE/." "$DEST/"
  echo "[ok] folder    $DEST"
fi

# 2. A Python that works here (3.9 or newer), for the updater only. On a Mac without the
#    Xcode command line tools, /usr/bin/python3 is a stub that pops up a dialog, so it is
#    skipped. On Windows the Microsoft Store alias (WindowsApps) is tried last: on a fresh
#    machine it is a stub.
python_ok() { "$@" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; }
real_path() { "$@" -c 'import sys; print(sys.executable)' 2>/dev/null | tr -d '\r' | tr '\\' '/'; }
PY=""
LATER=""
for c in python3 python; do
  p="$(command -v "$c" 2>/dev/null)" || continue
  if [ "$OS" = "Darwin" ] && { [ "$p" = "/usr/bin/python3" ] || [ "$p" = "/usr/bin/python" ]; }; then
    xcode-select -p >/dev/null 2>&1 || continue
  fi
  case "$p" in *WindowsApps*) LATER="$LATER $c"; continue ;; esac
  python_ok "$p" && { PY="$(real_path "$p")"; break; }
done
if [ -z "$PY" ] && command -v py >/dev/null 2>&1 && python_ok py -3; then
  PY="$(real_path py -3)"
fi
find_uv_python() {
  for u in uv "$HOME/.local/bin/uv" "$HOME/.local/bin/uv.exe"; do
    command -v "$u" >/dev/null 2>&1 || continue
    p="$("$u" python find 3.13 2>/dev/null | tr -d '\r' | tr '\\' '/')"
    [ -n "$p" ] && python_ok "$p" && { PY="$p"; return 0; }
    "$u" python install 3.13 >/dev/null 2>&1
    p="$("$u" python find 3.13 2>/dev/null | tr -d '\r' | tr '\\' '/')"
    [ -n "$p" ] && python_ok "$p" && { PY="$p"; return 0; }
  done
  return 1
}
if [ "$WIN" = 1 ] && [ -z "${UV_PYTHON_INSTALL_DIR:-}" ]; then
  # The Claude desktop app on Windows redirects AppData writes; keep uv's Python under the profile.
  export UV_PYTHON_INSTALL_DIR="$(cygpath -w "$HOME/.uv/python" 2>/dev/null || echo "$HOME/.uv/python")"
fi
[ -z "$PY" ] && find_uv_python
if [ -z "$PY" ]; then
  for c in $LATER; do
    p="$(command -v "$c" 2>/dev/null)" || continue
    python_ok "$p" && { PY="$(echo "$p" | tr '\\' '/')"; break; }
  done
fi
if [ -z "$PY" ]; then
  echo "  installing Python (through uv, no admin needed)..."
  if [ "$WIN" = 1 ]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex" >/dev/null 2>&1
  else
    curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1
  fi
  find_uv_python
fi
if [ -z "$PY" ]; then
  echo "ERROR: no working Python 3.9+ was found and the automatic install failed."
  echo "       Install Python from https://www.python.org/downloads/ (Windows: tick 'Add python.exe to PATH'), then run this again."
  rm -rf "$TMP"
  exit 2
fi
echo "[ok] Python    $PY"

# 3. The launcher: the updater always runs through bin/py, so it never depends on PATH.
mkdir -p "$DEST/bin"
cat > "$DEST/bin/py" <<EOF
#!/bin/sh
# Python launcher for the Solnest Coding Agent, written by install.sh.
# Runs the Python found at install time; falls back to whatever works if it moved.
P="$PY"
if [ -x "\$P" ]; then exec "\$P" "\$@"; fi
for c in python3 python; do
  q="\$(command -v "\$c" 2>/dev/null)" || continue
  case "\$q" in
    *WindowsApps*) continue ;;
    /usr/bin/python3) xcode-select -p >/dev/null 2>&1 || continue ;;
  esac
  "\$q" -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1 && exec "\$q" "\$@"
done
if command -v py >/dev/null 2>&1; then exec py -3 "\$@"; fi
echo "ERROR: no Python found. Run the Solnest Coding Agent installer again." >&2
exit 1
EOF
chmod +x "$DEST/bin/py"
if [ "$WIN" = 1 ]; then
  WPY="$(cygpath -w "$PY" 2>/dev/null || echo "$PY")"
  printf '@echo off\r\nrem Python launcher for the Solnest Coding Agent (PowerShell / cmd), written by install.sh.\r\n"%s" %%*\r\nexit /b %%errorlevel%%\r\n' "$WPY" > "$DEST/bin/py.cmd"
fi
echo "[ok] launcher  $DEST/bin/py"

# 4. git and jq: the two quality gates (secret scan, auto-test) are shell scripts that
#    read their input with jq. Without jq they stay quiet instead of checking anything.
rc=0
if command -v git >/dev/null 2>&1; then
  echo "[ok] git       $(git --version 2>/dev/null | tr -d '\r')"
else
  echo "[!!] git       not found. Install it, reopen Claude Code, run this again."
  rc=4
fi
if command -v jq >/dev/null 2>&1; then
  echo "[ok] jq        $(jq --version 2>/dev/null | tr -d '\r')"
else
  echo "[!!] jq        not found. Install it, reopen Claude Code, run this again."
  rc=4
fi

# 5. Prove the plugin files load (read-only: nothing is registered with Claude Code here).
if OUT="$("$DEST/bin/py" "$DEST/scripts/update.py" --after 2>&1)"; then
  OUT="${OUT#\[update\] OK: }"; echo "[ok] files     ${OUT%.}"
else
  echo "[!!] files     the plugin files did not load ($OUT). Run this installer again."
  rc=1
fi
echo "[ok] version   $(tr -d '[:space:]' < "$DEST/VERSION" 2>/dev/null || echo unknown)"

rm -rf "$TMP"
exit $rc
