#!/usr/bin/env bash
# Blocks commits when >10 permission-only file changes are staged.
# Triggered by Claude Code's PreToolUse hook on Bash git commit calls.

PERM_ONLY=$(git diff --cached --numstat 2>/dev/null \
  | awk '$1 == 0 && $2 == 0 {count++} END {print count+0}')

if [ "$PERM_ONLY" -gt 10 ]; then
  echo "⚠️  BLOCKED: $PERM_ONLY permission-only changes staged."
  echo "These are likely file mode (chmod) changes, not content changes."
  echo ""
  echo "To inspect:  git diff --cached --stat | grep 'mode change'"
  echo "To fix:      git config core.fileMode false && git checkout -- ."
  exit 1
fi
