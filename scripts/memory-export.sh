#!/usr/bin/env bash
# Dump the central agentmemory store to a JSON file for transfer to another machine.
#
#   ./scripts/memory-export.sh                      # everything -> ~/agentmemory-export-<ts>.json
#   ./scripts/memory-export.sh out.json             # everything -> out.json
#   ./scripts/memory-export.sh out.json --only MadorasRebirth,dotfiles-claude
#   ./scripts/memory-export.sh out.json --exclude some-employer-repo
#
# --only / --exclude filter memories and sessions by their `project` tag. Untagged
# records (project missing) are dropped by --only and kept by --exclude.
#
# The output is raw session material — treat it like source code, not like config.
# Nothing here writes into the repo on purpose: no snapshot is tracked by git.
set -euo pipefail

REST_URL="${AGENTMEMORY_URL:-http://localhost:3111}"
OUT="${1:-$HOME/agentmemory-export-$(date +%Y%m%dT%H%M%S).json}"
shift || true

MODE=""
PROJECTS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only|--exclude) MODE="${1#--}"; PROJECTS="${2:-}"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if ! curl -fsS --max-time 2 "$REST_URL/agentmemory/livez" >/dev/null; then
  echo "agentmemory not reachable at $REST_URL — start it with: ~/.claude/hooks/agentmemory-start.sh" >&2
  exit 1
fi

curl -fsS "$REST_URL/agentmemory/export" -o "$OUT"

if [ -n "$MODE" ]; then
  MODE="$MODE" PROJECTS="$PROJECTS" OUT="$OUT" python3 - <<'PY'
import json, os

mode = os.environ["MODE"]
wanted = {p.strip() for p in os.environ["PROJECTS"].split(",") if p.strip()}
path = os.environ["OUT"]
data = json.load(open(path))

def keep(record):
    project = record.get("project")
    if mode == "only":
        return project in wanted
    return project not in wanted

data["memories"] = [m for m in data["memories"] if keep(m)]
kept_sessions = [s for s in data["sessions"] if keep(s)]
kept_ids = {s["id"] for s in kept_sessions}
data["sessions"] = kept_sessions
data["observations"] = {k: v for k, v in data["observations"].items() if k in kept_ids}
data["summaries"] = [s for s in data["summaries"] if s.get("sessionId") in kept_ids]

json.dump(data, open(path, "w"))
print(f"filtered ({mode} {','.join(sorted(wanted))}): "
      f"{len(data['memories'])} memories, {len(data['sessions'])} sessions")
PY
fi

python3 - "$OUT" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
print(f"wrote {sys.argv[1]}  version={data['version']}  "
      f"memories={len(data['memories'])}  sessions={len(data['sessions'])}")
PY
