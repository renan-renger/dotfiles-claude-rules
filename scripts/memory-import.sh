#!/usr/bin/env bash
# Load a memory-export.sh dump into this machine's central agentmemory store.
#
#   ./scripts/memory-import.sh dump.json            # merge (default): add/overwrite by id
#   ./scripts/memory-import.sh dump.json replace    # wipe local store first, then load
#   ./scripts/memory-import.sh dump.json skip       # only add records whose id is new
#
# merge overwrites same-id records with the incoming version — there is no 3-way
# merge, so if both machines edited the same memory the imported side wins. Two
# machines drifting for a long time is not a merge, it is a choice.
#
# The server accepts an export only if its `version` is in the release's supported
# list, so keep agentmemory on comparable versions across machines.
set -euo pipefail

REST_URL="${AGENTMEMORY_URL:-http://localhost:3111}"
FILE="${1:?usage: memory-import.sh <export.json> [merge|replace|skip]}"
STRATEGY="${2:-merge}"

case "$STRATEGY" in
  merge|replace|skip) ;;
  *) echo "strategy must be merge, replace, or skip" >&2; exit 2 ;;
esac

if ! curl -fsS --max-time 2 "$REST_URL/agentmemory/livez" >/dev/null; then
  echo "agentmemory not reachable at $REST_URL — start it with: ~/.claude/hooks/agentmemory-start.sh" >&2
  exit 1
fi

if [ "$STRATEGY" = "replace" ]; then
  BACKUP="$HOME/.agentmemory/backups/pre-import-$(date +%Y%m%dT%H%M%S).json"
  mkdir -p "$(dirname "$BACKUP")"
  curl -fsS "$REST_URL/agentmemory/export" -o "$BACKUP"
  echo "replace: current store backed up to $BACKUP"
fi

PAYLOAD="$(mktemp)"
trap 'rm -f "$PAYLOAD"' EXIT
FILE="$FILE" STRATEGY="$STRATEGY" PAYLOAD="$PAYLOAD" python3 - <<'PY'
import json, os
data = json.load(open(os.environ["FILE"]))
json.dump({"exportData": data, "strategy": os.environ["STRATEGY"]},
          open(os.environ["PAYLOAD"], "w"))
print(f"importing version={data['version']} memories={len(data['memories'])} "
      f"sessions={len(data['sessions'])} strategy={os.environ['STRATEGY']}")
PY

curl -fsS -X POST "$REST_URL/agentmemory/import" \
  -H 'Content-Type: application/json' \
  --data-binary "@$PAYLOAD"
echo
