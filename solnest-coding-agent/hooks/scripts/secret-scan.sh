#!/bin/bash
set -euo pipefail

# Pre-commit secret scan — blocks git commits that contain hardcoded secrets.
# Reads tool input from stdin (JSON), checks if command is a git commit,
# then scans staged files for secret patterns.

input=$(cat)
command=$(echo "$input" | jq -r '.tool_input.command // empty')

# Only check git commit commands
if ! echo "$command" | grep -qE '^\s*git\s+commit'; then
  exit 0
fi

# Get list of staged files
staged_files=$(git diff --cached --name-only 2>/dev/null || true)

if [ -z "$staged_files" ]; then
  exit 0
fi

# Secret patterns to scan for
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
  'PRIVATE KEY-----'          # Private keys
  'password\s*=\s*["\x27][^"\x27]{8,}' # Hardcoded passwords
)

found_secrets=""

for file in $staged_files; do
  # Skip binary files, .env.example, lock files, and this script
  if [[ "$file" == *.lock ]] || [[ "$file" == *".env.example" ]] || [[ "$file" == *.sh ]]; then
    continue
  fi

  # Skip files that don't exist (deleted)
  if [ ! -f "$file" ]; then
    continue
  fi

  for pattern in "${patterns[@]}"; do
    matches=$(git diff --cached -- "$file" | grep -E "^\+" | grep -oE "$pattern" 2>/dev/null || true)
    if [ -n "$matches" ]; then
      found_secrets="${found_secrets}\n  - ${file}: matches pattern '${pattern}'"
    fi
  done
done

if [ -n "$found_secrets" ]; then
  echo "{\"hookSpecificOutput\":{\"permissionDecision\":\"deny\"},\"systemMessage\":\"SECRET SCAN BLOCKED COMMIT: Hardcoded secrets detected in staged files:${found_secrets}\nRemove these secrets and use environment variables instead. Never commit API keys, tokens, or passwords.\"}" >&2
  exit 2
fi

exit 0
