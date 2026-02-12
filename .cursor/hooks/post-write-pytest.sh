#!/usr/bin/env bash
# PostToolUse hook: runs pytest on the related test file after a Python file is written.
# Exits 2 on test failure so Claude sees the output and self-corrects.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE" ] && exit 0
echo "$FILE" | grep -qE '\.py$' || exit 0
[ -f "$FILE" ] || exit 0

# Skip if the written file is itself a test file (avoid double-running)
BASENAME=$(basename "$FILE")

find_test_file() {
  local src_file="$1"
  local name="${BASENAME%.py}"

  # Already a test file — run it directly
  if echo "$name" | grep -qE '^test_|_test$'; then
    echo "$src_file"
    return
  fi

  # Common test locations to probe, in priority order
  local candidates=(
    "tests/test_${name}.py"
    "tests/${name}/test_${name}.py"
    "test/test_${name}.py"
    "test_${name}.py"
  )

  # Also try mirroring the source path under tests/
  local rel="${src_file#*/}"   # strip leading dir component
  local mirrored="tests/test_${rel##*/}"
  candidates+=("$mirrored")

  for candidate in "${candidates[@]}"; do
    [ -f "$candidate" ] && echo "$candidate" && return
  done
}

TEST_FILE=$(find_test_file "$FILE")

if [ -z "$TEST_FILE" ]; then
  # No matching test file found — skip silently
  exit 0
fi

command -v pytest &>/dev/null || exit 0

OUTPUT=$(pytest "$TEST_FILE" --tb=short -q 2>&1)
STATUS=$?

if [ $STATUS -ne 0 ]; then
  echo "pytest failed for $TEST_FILE after writing $FILE:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
