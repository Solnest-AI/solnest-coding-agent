#!/bin/bash
set -uo pipefail

# Auto-test loop — runs after every source code Edit/Write.
# Detects the project's test runner, executes tests, and if they fail,
# feeds the error output back to Claude via exit code 2 + stderr.
#
# Flow: Edit source code → this hook runs → tests pass? → continue
#                                          → tests fail? → error fed back to Claude → Claude fixes → re-edit triggers this hook again → loop
#
# Not failures (never block):
#   - no tests collected (pytest exit 5, jest/vitest "No test(s) found")
#   - test runner not installed (exit 127, "No module named pytest")
#   - failures right after editing a TEST file: that is the TDD red step, so
#     Claude gets the output as context instead of a "fix this" block

# Opt-out / opt-down. Set SOLNEST_AUTOTEST in your shell or Claude Code env:
#   off  = skip this hook entirely
#   warn = run the tests and report failures, but never block the edit
#   (unset or anything else) = block the edit when tests fail (default)
AUTOTEST_MODE="${SOLNEST_AUTOTEST:-block}"
if [ "$AUTOTEST_MODE" = "off" ]; then
  exit 0
fi

# Resolve a Python interpreter. Stock macOS 12.3+ ships no `python`, only `python3`,
# so hardcoding `python` here made the hook report "tests failed" when they never ran.
PY_BIN="$(command -v python3 || command -v python || true)"

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
    if [ -n "$PY_BIN" ]; then
      test_cmd="$PY_BIN -m pytest -q --tb=line --no-header"
    fi
    break
  elif [ -f "$dir/requirements.txt" ]; then
    # Check if pytest is available
    project_root="$dir"
    if { [ -d "$dir/tests" ] || [ -d "$dir/test" ]; } && [ -n "$PY_BIN" ]; then
      test_cmd="$PY_BIN -m pytest -q --tb=line --no-header"
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

# Is the edited file a test? Checked relative to the project root so a
# project that merely lives under a folder named "test" isn't misread.
is_test_file() {
  local rel="${file_path#"$project_root"/}"
  case "$(basename "$file_path")" in
    test_*.py|*_test.py|conftest.py|*.test.*|*.spec.*|*_test.go|*_spec.rb|*_test.rb|*Test.java|*Tests.java|*Test.kt|*Tests.kt|*Tests.swift|*Test.php)
      return 0 ;;
  esac
  case "$rel" in
    tests/*|test/*|__tests__/*|spec/*|*/tests/*|*/test/*|*/__tests__/*|*/spec/*)
      return 0 ;;
  esac
  return 1
}

skip() {
  jq -n --arg m "AUTO-TEST SKIPPED after editing $file_path: $1" '{systemMessage: $m}'
  exit 0
}

# Run the tests
cd "$project_root"
test_output=$(eval "$test_cmd" 2>&1)
test_exit=$?

if [ $test_exit -eq 0 ]; then
  # Tests passed — report success as a system message.
  jq -n --arg msg "AUTO-TEST PASSED: All tests passing after editing $file_path" \
    '{systemMessage: $msg}'
  exit 0
else
  # Nothing was tested — not a failure
  if [[ $test_cmd == *pytest* ]] && [ $test_exit -eq 5 ]; then
    skip "no tests collected"
  fi
  if [[ $test_cmd == npm* ]] && echo "$test_output" | grep -qiE 'no test files found|no tests found'; then
    skip "no tests collected"
  fi

  # The runner itself is missing — an environment problem, not a test failure
  if [ $test_exit -eq 127 ] || echo "$test_output" | grep -q 'No module named pytest'; then
    skip "test runner not available ($test_cmd)"
  fi

  # Truncate output to 1500 chars to avoid overwhelming context.
  truncated_output=$(echo "$test_output" | tail -40 | head -c 1500)

  if is_test_file; then
    # TDD red step: a failing test right after writing it is expected. Tell
    # Claude what failed (non-blocking) so it can confirm it fails for the
    # intended reason, then write the implementation.
    jq -n --arg f "$file_path" --arg c "$test_cmd" --arg o "$truncated_output" '{
      systemMessage: ("AUTO-TEST RED after editing test file " + $f + " (expected during TDD)"),
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ("AUTO-TEST: tests are failing after you edited the test file " + $f + ". If this is the TDD red step, confirm each failure is the one you intended (not a typo, import error, or broken fixture), then write the implementation. Test command: " + $c + "\n\nTest output:\n" + $o)
      }
    }'
    exit 0
  fi

  if [ "$AUTOTEST_MODE" = "warn" ]; then
    # Report only. Useful mid-refactor, or on a repo whose suite was already red.
    # jq builds the JSON so the test output is escaped correctly. The old code
    # shelled out to `python`, which does not exist on stock macOS 12.3+, and then
    # spliced an already-quoted string inside quotes, producing invalid JSON.
    jq -n --arg msg "AUTO-TEST FAILED after editing $file_path (SOLNEST_AUTOTEST=warn, not blocking). Test command: $test_cmd." \
          --arg out "$truncated_output" \
      '{systemMessage: ($msg + "\n\nTest output:\n" + $out)}'
    exit 0
  fi

  # Blocking mode: exit code 2 feeds stderr back to Claude as the reason.
  {
    echo "AUTO-TEST FAILED after editing $file_path."
    echo "Test command: $test_cmd"
    echo "Fix the failing tests before continuing, or set SOLNEST_AUTOTEST=warn"
    echo "(report but do not block) or SOLNEST_AUTOTEST=off to disable this hook."
    echo
    echo "Test output:"
    echo "$truncated_output"
  } >&2
  exit 2
fi
