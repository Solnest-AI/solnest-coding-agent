#!/usr/bin/env bash
# Refuse to publish if anything private is tracked: a .env, a secret-shaped string, a real
# home-folder path, a personal email, a private name, or an em-dash in member-facing text.
# Run from anywhere:  bash scripts/prepublish.sh
set -u; cd "$(dirname "$0")/.."
bad=0
PROSE="README.md CLAUDE.md UPDATE.md CHANGELOG.md solnest-coding-agent/README.md solnest-coding-agent/CLAUDE.md $(ls solnest-coding-agent/agents/*.md)"

git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.env\.example$' && { echo "FAIL: a .env is tracked"; bad=1; }
git ls-files | grep -E '(^|/)\.cursor(/|$)' && { echo "FAIL: .cursor (private editor rules) is tracked"; bad=1; }
git ls-files | grep -E 'node_modules/|\.venv/|__pycache__/|\.update-backup/|(^|/)bin/|token.*\.json$|credentials.*\.json$' && { echo "FAIL: build products, tokens or updater state tracked"; bad=1; }
git grep -nIE '(fc-[A-Za-z0-9]{20,}|pt_[A-Za-z0-9]{20,}|bpat_[A-Za-z0-9]{20,}|rb_mcp_[A-Za-z0-9]{10,}|eyJ[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{10,}|ghp_[A-Za-z0-9]{20,}|xox[bap]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}|sbp_[a-f0-9]{30,}|AKIA[0-9A-Z]{16})' -- . && { echo "FAIL: secret-shaped string tracked"; bad=1; }
# A real person's home folder (a placeholder like /Users/you or <name> is fine).
git grep -nIE '(/Users/|/home/|[A-Za-z]:\\Users\\)[A-Za-z0-9][A-Za-z0-9._-]*[/\\]' -- . | grep -vE '(/Users/|/home/)(you|me|name|user|username|example)/' && { echo "FAIL: a real home-folder path is tracked"; bad=1; }
# Any email that is not the support address.
git grep -nIoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' -- . | grep -viE ':(hello@solnestai\.com|[^:]*@example\.(com|org))$' && { echo "FAIL: an email other than the support address is tracked"; bad=1; }
# Em-dash (U+2014) in member-facing text. Code comments may keep theirs.
for f in $PROSE; do
  [ -f "$f" ] && grep -n $'\xe2\x80\x94' "$f" /dev/null && { echo "FAIL: em-dash in member-facing text ($f)"; bad=1; }
done
git grep -nIiE 'drag (this|the|it) |drag-and-drop|\.zip' -- . ':!scripts/prepublish.sh' ':!.gitignore' && { echo "FAIL: the old folder or zip install is mentioned"; bad=1; }

# Private names (clients, a former employer). They are kept here as hashes, never in plain
# text, so this public file does not list them. Every word and word pair in every tracked
# text file is hashed and compared.
PY=""
for c in python3 python; do
  command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; raise SystemExit(sys.version_info < (3, 9))' 2>/dev/null && { PY="$c"; break; }
done
if [ -z "$PY" ]; then
  echo "FAIL: no Python 3.9+ to run the private-name check"; bad=1
else
  git ls-files -z | "$PY" -c '
import hashlib, re, sys
private = set(sys.argv[1].split())
hit = 0
for path in sys.stdin.buffer.read().decode().split("\0"):
    if not path:
        continue
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        continue
    for n, line in enumerate(text.splitlines(), 1):
        words = re.findall(r"[a-z0-9]+", line.lower())
        for cand in words + [a + " " + b for a, b in zip(words, words[1:])]:
            if hashlib.sha256(("solnest-prepublish:" + cand).encode()).hexdigest()[:20] in private:
                print("%s:%d: private name" % (path, n)); hit = 1
sys.exit(hit)
' "0d330f50ad3210be0476 18383ac2ece9bae58c4e 367c093ef2e9a76f81b7 40c526a4613434674a12 6742a7293d4d89d67926 8082838e2bd80fbf7947 80db8872c9fc68a95c5e ab605bd4c49617c75be9 c170966acac05c3e8cb6 cc7ce928f0bccdc705ff d12d21d6a7281c8a2dcd d42fc32481eb6b4c6b35 e06ac0ad8af5061b9035 ee3ef92a4bf8d1de5976 fa6c9f364fba361ea509" || { echo "FAIL: a private name is tracked"; bad=1; }
fi

# The plugin's own version must be the release version (Claude Code reads plugin.json).
v="$(tr -d '[:space:]' < VERSION)"
grep -q "\"version\": \"$v\"" solnest-coding-agent/.claude-plugin/plugin.json || { echo "FAIL: plugin.json version is not VERSION ($v)"; bad=1; }
git grep -nI 'Ryan Le' -- . ':!scripts/prepublish.sh' && { echo "FAIL: a personal name is tracked"; bad=1; }

[ $bad -eq 0 ] && echo "OK: prepublish clean"
exit $bad
