#!/bin/bash
set -uo pipefail

# Pre-commit secret scan — blocks git commits that contain hardcoded secrets.
# Reads tool input from stdin (JSON), checks if the command runs a git commit
# anywhere (including after `&&`, `;`, `cd dir &&`, or with `git -C dir`),
# then scans what that commit will contain for secret patterns.
#
# PreToolUse runs BEFORE the command, so in `git add . && git commit` nothing
# is staged yet. When the command also stages files (`git add`, `commit -a`),
# unstaged and untracked changes are scanned too.

command -v jq >/dev/null 2>&1 || exit 0

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')
base_dir=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$base_dir" ] && [ -d "$base_dir" ] || base_dir=$PWD

# One path argument: "double quoted", 'single quoted', or a bare word
path_re="(\"([^\"]*)\"|'([^']*)'|([^[:space:];&|()]+))"
sep_re="(^|[;&|(\`[:space:]])"

# `git`, then only global options (-C dir, -c k=v, --flags), then the subcommand
git_re="${sep_re}git(([[:space:]]+(-C|-c|--git-dir|--work-tree)[[:space:]]+${path_re})|([[:space:]]+-[^[:space:];&|]+))*[[:space:]]+"
end_re="([[:space:];&|)]|\$)"

# Only check commands that run git commit
commit_re="${git_re}commit${end_re}"
if ! [[ $command =~ $commit_re ]]; then
  exit 0
fi

# Scan unstaged + untracked too when the same command stages files
broad=0
add_re="${git_re}add${end_re}"
all_re="commit[^;&|]*[[:space:]](-[a-zA-Z]*a[a-zA-Z]*|--all)${end_re}"
if [[ $command =~ $add_re ]] || [[ $command =~ $all_re ]]; then
  broad=1
fi

# Candidate repos: the session cwd, every `cd <dir>`, every `-C <dir>`
dirs=("$base_dir")
for kw in cd -C; do
  rest=$command
  kw_re="${sep_re}${kw}[[:space:]]+${path_re}"
  while [[ $rest =~ $kw_re ]]; do
    p="${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}"
    rest=${rest#*"${BASH_REMATCH[0]}"}
    p=${p/#\~/$HOME}
    case "$p" in
      /*) dirs+=("$p") ;;
      *) dirs+=("$base_dir/$p") ;;
    esac
  done
done

# Secret patterns to scan for (POSIX ERE so BSD and GNU grep agree)
patterns=(
  'sk-ant-api[0-9]'          # Anthropic API keys
  'sk-[a-zA-Z0-9]{20,}'      # OpenAI API keys
  'AKIA[0-9A-Z]{16}'         # AWS access key IDs
  'ghp_[a-zA-Z0-9]{36}'      # GitHub personal access tokens
  'gho_[a-zA-Z0-9]{36}'      # GitHub OAuth tokens
  'xoxb-[0-9]'               # Slack bot tokens
  'xoxp-[0-9]'               # Slack user tokens
  'apify_api_[a-zA-Z0-9]'    # Apify tokens
  'pit-[a-f0-9]{8}'          # GHL API keys
  'eyJ[a-zA-Z0-9_-]{20,}\.'  # JWT tokens
  '-----BEGIN [A-Z ]*PRIVATE KEY'  # Private keys
  "password[[:space:]]*=[[:space:]]*[\"'][^\"']{8,}"  # Hardcoded passwords
)
grep_args=()
for pattern in "${patterns[@]}"; do grep_args+=(-e "$pattern"); done

found_secrets=""

# $1 = repo root, $2 = file, stdin = text to check (not piped: must run in this shell)
check_text() {
  local text
  text=$(cat)
  [ -n "$text" ] || return 0
  printf '%s\n' "$text" | grep -Eq "${grep_args[@]}" || return 0
  for pattern in "${patterns[@]}"; do
    if printf '%s\n' "$text" | grep -Eq -e "$pattern"; then
      found_secrets="${found_secrets}\n  - $1/$2: matches pattern '${pattern}'"
    fi
  done
}

skip_file() {
  [[ "$1" == *.lock ]] || [[ "$1" == *".env.example" ]]
}

seen=""
for d in "${dirs[@]}"; do
  [ -d "$d" ] || continue
  top=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || continue
  case "$seen" in *"|$top|"*) continue ;; esac
  seen="$seen|$top|"

  # Staged changes: added lines only
  while IFS= read -r file; do
    [ -n "$file" ] && ! skip_file "$file" || continue
    check_text "$top" "$file" < <(git -C "$top" diff --cached -- "$file" 2>/dev/null | grep -E '^\+' | grep -Ev '^\+\+\+ ')
  done < <(git -C "$top" diff --cached --name-only 2>/dev/null)

  [ "$broad" -eq 1 ] || continue

  # Tracked but unstaged changes (git add / commit -a will pick these up)
  while IFS= read -r file; do
    [ -n "$file" ] && ! skip_file "$file" || continue
    check_text "$top" "$file" < <(git -C "$top" diff -- "$file" 2>/dev/null | grep -E '^\+' | grep -Ev '^\+\+\+ ')
  done < <(git -C "$top" diff --name-only 2>/dev/null)

  # Untracked, not ignored files (git add . will pick these up)
  while IFS= read -r file; do
    [ -n "$file" ] && [ -f "$top/$file" ] && ! skip_file "$file" || continue
    check_text "$top" "$file" < <(grep -I '' "$top/$file" 2>/dev/null)
  done < <(git -C "$top" ls-files --others --exclude-standard 2>/dev/null)
done

if [ -n "$found_secrets" ]; then
  printf 'SECRET SCAN BLOCKED COMMIT: Hardcoded secrets detected in files this commit would include:%b\nRemove these secrets and use environment variables instead. Never commit API keys, tokens, or passwords.\n' "$found_secrets" >&2
  exit 2
fi

exit 0
