#!/bin/bash
set -uo pipefail

# Auto-test loop — runs after every source code Edit/Write.
# Detects the project's test runner, executes tests, and if they fail,
# feeds the error output back to Claude via exit code 2 + stderr.
#
# Flow: Edit source code → this hook runs → tests pass? → continue
#                                          → tests fail? → error fed back to Claude → Claude fixes → re-edit triggers this hook again → loop

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // empty')
file_path=""

# Extract the file path based on tool type
if [ "$tool_name" = "Edit" ]; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
elif [ "$tool_name" = "Write" ]; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
fi

# No file path? Skip.
if [ -z "$file_path" ]; then
  exit 0
fi

# Check if this is a source code file (not config, docs, etc.)
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.java|*.vue|*.svelte|*.rb|*.php|*.swift|*.kt)
    # Source code — proceed with testing
    ;;
  *)
    # Not source code — skip
    exit 0
    ;;
esac

# Find the project root by walking up from the file path looking for package.json or pyproject.toml
dir=$(dirname "$file_path")
project_root=""
test_cmd=""

while [ "$dir" != "/" ] && [ "$dir" != "." ]; do
  if [ -f "$dir/package.json" ]; then
    project_root="$dir"
    # Check if there's a test script defined
    has_test=$(cat "$dir/package.json" | jq -r '.scripts.test // empty' 2>/dev/null)
    if [ -n "$has_test" ] && [ "$has_test" != "echo \"Error: no test specified\" && exit 1" ]; then
      test_cmd="npm test --silent"
    fi
    break
  elif [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.py" ] || [ -f "$dir/pytest.ini" ] || [ -f "$dir/setup.cfg" ]; then
    project_root="$dir"
    test_cmd="python -m pytest -q --tb=line --no-header"
    break
  elif [ -f "$dir/requirements.txt" ]; then
    # Check if pytest is available
    project_root="$dir"
    if [ -d "$dir/tests" ] || [ -d "$dir/test" ]; then
      test_cmd="python -m pytest -q --tb=line --no-header"
    fi
    break
  elif [ -f "$dir/Cargo.toml" ]; then
    project_root="$dir"
    test_cmd="cargo test --quiet"
    break
  elif [ -f "$dir/go.mod" ]; then
    project_root="$dir"
    test_cmd="go test ./..."
    break
  fi
  dir=$(dirname "$dir")
done

# No project root or no test command found? Just remind, don't block.
if [ -z "$project_root" ] || [ -z "$test_cmd" ]; then
  exit 0
fi

# Run the tests
cd "$project_root"
test_output=$(eval "$test_cmd" 2>&1)
test_exit=$?

if [ $test_exit -eq 0 ]; then
  # Tests passed — report success as system message
  echo "{\"systemMessage\":\"AUTO-TEST PASSED: All tests passing after editing $file_path\"}"
  exit 0
else
  # Tests failed — feed errors back to Claude via exit code 2
  # Truncate output to 1500 chars to avoid overwhelming context
  truncated_output=$(echo "$test_output" | tail -40 | head -c 1500)

  # Escape JSON special characters
  escaped_output=$(echo "$truncated_output" | python -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || echo "\"(could not capture test output)\"")

  echo "{\"systemMessage\":\"AUTO-TEST FAILED after editing $file_path. Test command: $test_cmd. Fix the failing tests before continuing.\n\nTest output:\n$escaped_output\"}" >&2
  exit 2
fi
