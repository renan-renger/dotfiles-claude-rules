#!/usr/bin/env bash
# Symlink every hook script tracked in this repo into ~/.claude/hooks/, where the
# hook commands in settings.json expect to find them.
#
#   ./scripts/link-hooks.sh            # link anything missing, report the rest
#   ./scripts/link-hooks.sh --dry-run  # show what would happen, touch nothing
#
# Idempotent: re-running with everything already linked prints "ok" for each row and
# changes nothing.
#
# Exists because settings.json refers to hooks by their ~/.claude/hooks/ path. A hook
# added to this repo but never linked fails with exit 127 at session start, and the
# hook runner swallows it — memory-sync.sh sat unlinked and silently dead that way.
set -uo pipefail

REPO="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
HOOKS="$REPO/hooks"
DEST="$HOME/.claude/hooks"
DRY=0

for arg in "$@"; do
	case "$arg" in
		--dry-run) DRY=1 ;;
		-h|--help) sed -n '2,9p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "unknown flag: $arg" >&2; exit 2 ;;
	esac
done

[ -d "$HOOKS" ] || { echo "no hooks directory at $HOOKS" >&2; exit 1; }

run() { if [ "$DRY" = 1 ]; then echo "    would: $*"; else "$@"; fi; }

rc=0
run mkdir -p "$DEST"

shopt -s nullglob
for src in "$HOOKS"/*.sh; do
	name="$(basename "$src")"
	link="$DEST/$name"

	if [ -L "$link" ]; then
		current="$(readlink -f "$link")"
		if [ "$current" = "$(readlink -f "$src")" ]; then
			echo "ok       $name"
		else
			echo "!! $name: linked elsewhere -> $current (leaving alone)"
			rc=1
		fi
		continue
	fi

	# A real file here is a hand-written hook this repo has never seen. Never clobber it.
	if [ -e "$link" ]; then
		echo "!! $name: real file at $link, not a link (leaving alone)"
		rc=1
		continue
	fi

	echo "link     $name"
	run ln -sfn "$src" "$link"
done
shopt -u nullglob

if [ "$DRY" = 1 ]; then echo; echo "(dry run — nothing changed)"; fi
exit $rc
