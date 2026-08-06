#!/usr/bin/env bash
# SessionStart hook: ensure the agentmemory server is running on port 3111 so the
# MCP shim exposes the full tool set instead of the ~7-tool local fallback.
#
# Idempotent and non-blocking: exits immediately if the server is already up,
# otherwise launches it detached so session startup never waits on the first-run
# engine download.
#
# The engine's state adapter uses a cwd-relative path (./data/state_store.db), so
# whichever directory the first session of the day starts from owns the store —
# giving every project its own isolated, unsearchable memory. Pinning cwd to
# ~/.agentmemory forces a single central store. Per-project scoping is preserved:
# the capture hooks tag each observation with the project resolved from the
# session's own cwd (git toplevel basename), independent of the server's cwd.
set -euo pipefail

if curl -fsS --max-time 1 http://localhost:3111/agentmemory/livez >/dev/null 2>&1; then
  exit 0
fi

cd "$HOME/.agentmemory"
nohup npx -y @agentmemory/agentmemory@latest >/dev/null 2>&1 &
disown 2>/dev/null || true
exit 0
