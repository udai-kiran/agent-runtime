#!/usr/bin/env bash
# PostToolUse hook: runs ruff (import fix) and pyright on written Python files.
# Receives JSON via stdin with tool_input.file_path.
# Exit 2 to surface pyright errors back to Claude for auto-fix.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip if no file path or not a Python file
[ -z "$FILE" ] && exit 0
echo "$FILE" | grep -qE '\.py$' || exit 0
[ -f "$FILE" ] || exit 0

# ruff: fix imports silently (I = isort rules, F401 = unused imports)
if command -v ruff &>/dev/null; then
  ruff check --select I,F401 --fix --quiet "$FILE"
fi

# pyright: report errors back to Claude so it can fix them
if command -v pyright &>/dev/null; then
  PYRIGHT_OUT=$(pyright --outputjson "$FILE" 2>/dev/null)
  ERROR_COUNT=$(echo "$PYRIGHT_OUT" | jq -r '.summary.errorCount // 0')
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "pyright found $ERROR_COUNT error(s) in $FILE:" >&2
    echo "$PYRIGHT_OUT" | jq -r '
      .generalDiagnostics[]
      | select(.severity == "error")
      | "  Line \(.range.start.line + 1): \(.message)"
    ' >&2
    exit 2
  fi
fi

exit 0
