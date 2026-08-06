#!/usr/bin/env bash
# Point this machine's Claude Code file-memory directories at the copies tracked in
# the SEPARATE memory repo, so memory survives a reinstall and syncs between machines.
#
#   ./scripts/link-memory.sh            # link (and report anything that needs --adopt)
#   ./scripts/link-memory.sh --adopt    # also MOVE local-only memory into the repo first
#   ./scripts/link-memory.sh --dry-run  # show what would happen, touch nothing
#
# Idempotent: re-running with everything already linked prints "ok" for each row and
# changes nothing.
#
# The memory repo is OPTIONAL and private — memories are personal working notes, not
# shared standards. Without it this script says so and exits 0; Claude Code then keeps
# file memory in ~/.claude/projects/<slug>/memory as it does by default. Override the
# location with CLAUDE_MEMORY_REPO.
#
# Why symlinks rather than checking the repo out into ~/.claude: copies drift silently.
# That is how settings.json once sat four commits behind while both files looked fine
# in isolation. Same reasoning as the CLAUDE.md symlinks in SYNC-README.md.
set -uo pipefail

MEMORY_REPO="${CLAUDE_MEMORY_REPO:-$HOME/devbox/source/dotfiles-claude-memory}"
MANIFEST="$MEMORY_REPO/manifest.tsv"
ADOPT=0
DRY=0

for arg in "$@"; do
	case "$arg" in
		--adopt)   ADOPT=1 ;;
		--dry-run) DRY=1 ;;
		-h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}"; exit 0 ;;
		*) echo "unknown flag: $arg" >&2; exit 2 ;;
	esac
done

if [ ! -d "$MEMORY_REPO" ]; then
	echo "no memory repo at $MEMORY_REPO — skipping (it is optional)."
	echo "Clone it, or set CLAUDE_MEMORY_REPO, to sync file memory across machines."
	exit 0
fi
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 1; }

run() { if [ "$DRY" = 1 ]; then echo "    would: $*"; else "$@"; fi; }

# Claude Code's slug is the absolute project path with "/" swapped for "-".
slug_for() { printf '%s' "$1" | tr '/' '-'; }

rc=0
while IFS=$'\t' read -r label relpath; do
	case "$label" in ''|'#'*) continue ;; esac
	[ -n "${relpath:-}" ] || { echo "!! $label: manifest row has no path"; rc=1; continue; }

	repo_dir="$MEMORY_REPO/$label"
	link="$HOME/.claude/projects/$(slug_for "$HOME/$relpath")/memory"

	if [ -L "$link" ]; then
		current="$(readlink -f "$link")"
		if [ "$current" = "$(readlink -f "$repo_dir")" ]; then
			echo "ok       $label"
		else
			echo "!! $label: linked elsewhere -> $current (leaving alone)"
			rc=1
		fi
		continue
	fi

	# A real directory on the local side is the interesting case: it holds memory this
	# repo has never seen. Never silently delete it.
	if [ -d "$link" ]; then
		if [ -d "$repo_dir" ] && [ -n "$(ls -A "$repo_dir" 2>/dev/null)" ]; then
			echo "!! $label: BOTH sides have files. Merge by hand, then re-run."
			echo "     local: $link"
			echo "     repo:  $repo_dir"
			rc=1
			continue
		fi
		if [ "$ADOPT" != 1 ]; then
			echo "-- $label: local memory not in repo yet; re-run with --adopt to move it"
			rc=1
			continue
		fi
		echo "adopt    $label  ($(ls -1 "$link"/*.md 2>/dev/null | wc -l) files)"
		run mkdir -p "$repo_dir"
		# shellcheck disable=SC2086
		if [ "$DRY" = 1 ]; then
			echo "    would: mv $link/* -> $repo_dir/"
		else
			shopt -s dotglob nullglob
			mv "$link"/* "$repo_dir"/ || { echo "!! $label: move failed"; rc=1; shopt -u dotglob nullglob; continue; }
			shopt -u dotglob nullglob
			rmdir "$link" || { echo "!! $label: local dir not empty after move"; rc=1; continue; }
		fi
	else
		# Nothing local. Fresh machine, or a project whose memory only exists in the repo.
		[ -d "$repo_dir" ] || { echo "-- $label: nothing in repo and nothing local, skipping"; continue; }
		echo "link     $label"
	fi

	run mkdir -p "$(dirname "$link")"
	run ln -sfn "$repo_dir" "$link"
done < "$MANIFEST"

if [ "$DRY" = 1 ]; then echo; echo "(dry run — nothing changed)"; fi
exit $rc
