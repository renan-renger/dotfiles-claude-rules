#!/usr/bin/env bash
# Sync tracked file memory with the remote. Called by the SessionStart / Stop hooks,
# and safe to run by hand.
#
#   ./hooks/memory-sync.sh pull    # fetch + merge remote memory changes
#   ./hooks/memory-sync.sh push    # regenerate indexes, commit, push
#
# Operates on the PRIVATE memory repo (CLAUDE_MEMORY_REPO, default
# ~/devbox/source/dotfiles-claude-memory), never on the shared rules repo. That
# separation is why a blanket `git add` is safe here: this repo holds nothing but
# memory, whereas the rules repo's settings.json is rewritten by Claude Code at
# runtime and must never be swept into an unreviewed automatic commit.
#
# The memory repo is optional. Without it this exits 0 in silence — teammates who
# only want the shared rules must not see hook noise every session.
#
# Always exits 0. This runs from hooks, and a network blip or a dirty tree must never
# take a session down with it — failures are printed and swallowed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
MEMORY_REPO="${CLAUDE_MEMORY_REPO:-$HOME/devbox/source/dotfiles-claude-memory}"

[ -d "$MEMORY_REPO/.git" ] || exit 0
cd "$MEMORY_REPO" || exit 0

MODE="${1:-}"
BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"

note() { echo "[memory-sync] $*"; }

case "$MODE" in
pull)
	git fetch --quiet origin "$BRANCH" 2>/dev/null || { note "fetch failed (offline?), skipping"; exit 0; }
	if ! git diff --quiet 2>/dev/null; then
		note "local memory has uncommitted changes; not merging over them"
		exit 0
	fi
	# Merge, never rebase: this branch is shared between machines and rebasing it
	# would rewrite commits the other machine already has.
	if git merge --quiet --no-edit "origin/$BRANCH" 2>/dev/null; then
		note "up to date with origin/$BRANCH"
	else
		git merge --abort 2>/dev/null
		note "merge conflicted and was aborted — resolve by hand in $MEMORY_REPO"
	fi
	;;

push)
	python3 "$SCRIPT_DIR/scripts/gen-memory-index.py" "$MEMORY_REPO" >/dev/null 2>&1 \
		|| note "index generator failed"
	git add -A 2>/dev/null
	if git diff --cached --quiet 2>/dev/null; then
		exit 0                                   # nothing changed this session
	fi
	files=$(git diff --cached --name-only | wc -l)
	git commit --quiet -m "memory: sync $(date +%Y-%m-%dT%H:%M) ($files files)" \
		|| { note "commit failed"; exit 0; }
	git push --quiet origin "$BRANCH" 2>/dev/null \
		&& note "pushed $files memory file(s)" \
		|| note "commit made but push failed (offline?) — will go out next session"
	;;

*)
	echo "usage: $(basename "$0") {pull|push}" >&2
	;;
esac

exit 0
