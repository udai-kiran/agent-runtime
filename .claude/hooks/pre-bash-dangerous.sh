#!/usr/bin/env bash
# PreToolUse hook: blocks destructive Bash commands and feeds a warning back to Claude.
# Exit 2 blocks execution and surfaces the message so Claude reconsiders.

INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

[ -z "$CMD" ] && exit 0

# Patterns considered destructive
PATTERNS=(
  'rm\s+-[a-zA-Z]*r[a-zA-Z]*f'   # rm -rf / rm -fr etc.
  'rm\s+-[a-zA-Z]*f[a-zA-Z]*r'
  '>\s*/dev/sd'                    # overwrite block devices
  'mkfs\.'                         # format filesystem
  'dd\s+.*of=/dev/'                # dd to raw device
  ':(){:|:&};:'                    # fork bomb
  'git\s+reset\s+--hard'
  'git\s+clean\s+-[a-zA-Z]*f'
  'git\s+push\s+.*--force(?!-with-lease)' # --force but not --force-with-lease
  'DROP\s+TABLE'
  'DROP\s+DATABASE'
  'TRUNCATE\s+TABLE'
  'DELETE\s+FROM\s+\w+\s*;'        # DELETE without WHERE
)

for pattern in "${PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiP "$pattern" 2>/dev/null || echo "$CMD" | grep -qiE "$pattern" 2>/dev/null; then
    echo "Blocked: destructive command detected — '$(echo "$CMD" | head -1)'" >&2
    echo "If this is intentional, ask the user to confirm before proceeding." >&2
    exit 2
  fi
done

exit 0
