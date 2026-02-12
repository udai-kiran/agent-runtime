#!/usr/bin/env bash
# SubagentStop hook: runs the full test suite after any agent finishes.
# Exits 2 on failure so the result surfaces in the main conversation.

command -v pytest &>/dev/null || exit 0
[ -d "tests" ] || [ -d "test" ] || exit 0

OUTPUT=$(pytest --tb=short -q 2>&1)
STATUS=$?

if [ $STATUS -ne 0 ]; then
  echo "Test suite failed after agent completed:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

echo "All tests passed."
exit 0
