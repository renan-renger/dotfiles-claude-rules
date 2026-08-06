# dotfiles-claude-rules — shared Claude Code config sync

Portable `~/.claude` config, shared across the team and synced across your machines.
**Secrets and machine-local data are NOT tracked** (see `.gitignore` — ignore-all +
allowlist). See `README.md` for the short install; this file is the long-form
reference for how the wiring works and why.

**Two repos.** This one holds the shared rules and tooling and is public. Per-project
**file memory is personal** and lives in a separate *private* repo, resolved at run
time from `CLAUDE_MEMORY_REPO` (default `~/devbox/source/dotfiles-claude-memory`).
That repo is **optional**: without it `link-memory.sh` reports its absence and exits,
the sync hook stays silent, and Claude Code keeps memory in its default location.

## What IS synced
- `CLAUDE.md` — **global** instructions (universal rules only; loads in every context)
- `contexts/` — per-context rule files that stack on top of the global ones
- `settings.json` — model, theme, permissions, enabled plugins
- MCP servers are NOT tracked here — see the agentmemory section
- `commands/` — custom slash commands
- `skills/` — user skills
- `hooks/` — hook scripts
- `scripts/` — maintenance scripts (agentmemory export/import, memory linking)

Per-project file memory is **not** here — see the separate private memory repo below.

## What is NOT synced (stays local, private)
`.credentials.json`, `remote-settings.json`, `policy-limits.json`, `history.jsonl`,
`projects/` (**except** the `memory/` subdirectories — see below; the 110MB of JSONL
session transcripts beside them stays local), `sessions/`, `session-env/`, `shell-snapshots/`, `plugins/`, `backups/`,
caches, `*.bak`, transient dotfiles.

Plugins reinstall automatically from marketplaces listed in `settings.json`
(`enabledPlugins` + `extraKnownMarketplaces`) — no need to sync `plugins/`.

## Apply on a NEW machine (e.g. desktop)

`~/.claude` already exists (Claude Code created it). Do NOT delete it — layer the
repo on top so local secrets stay untouched.

```bash
cd ~/.claude
git init
git remote add origin git@github.com:renan-renger/dotfiles-claude-rules.git   # or https URL
git fetch origin

# Preview what will change BEFORE touching anything:
git checkout origin/main -- .            # dry-run alternative: git diff origin/main -- CLAUDE.md settings.json

# If CLAUDE.md / settings.json already exist locally and differ, git will overwrite
# the tracked ones with the repo version. Back up first if unsure:
#   cp CLAUDE.md CLAUDE.md.local.bak
```

Safer full setup on a fresh machine:

```bash
cd ~/.claude
git init && git remote add origin git@github.com:renan-renger/dotfiles-claude-rules.git
git fetch origin
git reset --soft origin/main     # adopt repo history, keep working files
git checkout origin/main -- .    # write tracked config into place
git status                       # verify only allowlisted files changed
```

Wire up file memory — **optional**, and only if you keep a private memory repo (see
the next section for what this does):

```bash
cd ~/devbox/source/dotfiles-claude-rules   # wherever you cloned it
export CLAUDE_MEMORY_REPO="$HOME/devbox/source/dotfiles-claude-memory"
./scripts/link-memory.sh --dry-run   # confirm the slugs it resolves look right
./scripts/link-memory.sh             # symlink memory repo into ~/.claude/projects/*/
./scripts/link-hooks.sh              # symlink repo hooks into ~/.claude/hooks/
```

Re-run `link-hooks.sh` after pulling a commit that adds a hook: `settings.json`
calls hooks by their `~/.claude/hooks/` path, and an unlinked one fails silently.

Restart Claude Code after applying so new settings/plugins load.

## Multi-context rule files

`CLAUDE.md` (repo root) holds the **global** rules — they load in every context.
Per-context rules live in `contexts/<name>/CLAUDE.md` and load only when the
working directory is inside that context's tree, stacking on top of global.

| Repo file | Symlinked to | Context |
|-----------|--------------|---------|
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | global (all contexts) |
| `RTK.md` | `~/.claude/RTK.md` | global (`@RTK.md` include) |
| `settings.json` | `~/.claude/settings.json` | global |
| `hooks/*.sh` | `~/.claude/hooks/*.sh` | global, via `scripts/link-hooks.sh` |
| `<memory repo>/<label>/` | `~/.claude/projects/<slug>/memory` | per project, via `scripts/link-memory.sh` (optional) |
| `contexts/jabutikba-games/CLAUDE.md` | `~/devbox/source/jabutikba-games/CLAUDE.md` | Unreal Engine / C++ |

Wire the symlinks (run from the repo root):

```bash
REPO="$(pwd)"
ln -sf "$REPO/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$REPO/RTK.md"    "$HOME/.claude/RTK.md"
cp -n "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-symlink.bak" 2>/dev/null || true
ln -sf "$REPO/settings.json" "$HOME/.claude/settings.json"
./scripts/link-hooks.sh

mkdir -p "$HOME/devbox/source/jabutikba-games"
ln -sf "$REPO/contexts/jabutikba-games/CLAUDE.md" "$HOME/devbox/source/jabutikba-games/CLAUDE.md"
```

Symlink everything rather than checking the repo out into `~/.claude`: copies drift
silently — that is how `settings.json` sat four commits behind the repo (missing the
rtk hook and the `LC_ALL` fix) while both files looked fine in isolation.

Trade-off worth knowing: Claude Code rewrites `settings.json` at runtime (`/config`
toggles, key reordering), so with the symlink in place those writes land in the repo
and show up as unstaged diffs. That is the intended direction — commit or discard
them — but never `git checkout` the file while a session is running, or you fight
the editor.

`epic-fab/` and `UnrealEngine-5.8.1-src/` intentionally have **no** context file —
they run under global rules only.

To add a context: create `contexts/<name>/CLAUDE.md`, then symlink it into the
target project dir.

**Note on deploy method:** the symlink above makes the repo the single source of
truth for all three `CLAUDE.md` files, superseding the copy/checkout method below
*for those files*. If you instead check the whole repo out directly into
`~/.claude` (see next section), `CLAUDE.md` becomes a real file there — skip the
global symlink in that case, but still symlink the two `contexts/` files into
their project dirs.

## Push changes FROM any machine

```bash
cd ~/.claude
git add -A          # .gitignore keeps secrets out automatically
git status          # ALWAYS eyeball: confirm zero secrets staged
git commit -m "update claude config"
git push
```

## File memory (per-project `MEMORY.md`)

Claude Code keeps durable per-project facts as markdown at
`~/.claude/projects/<slug>/memory/` — an index (`MEMORY.md`) that loads into context
every session, plus one file per fact. It is ~500KB of plain text across all projects.

**It is tracked in a separate private repo**, not in this one — memories are personal
working notes rather than shared standards, and keeping them out of a public repo is
the point. The tooling here resolves that repo from `CLAUDE_MEMORY_REPO`, defaulting
to `~/devbox/source/dotfiles-claude-memory`, and no-ops when it is not cloned.

**The slug is machine-specific**, so the directories are not tracked by name: the slug
is the project's absolute path with every `/` replaced by `-`
(`/home/you/devbox/source/X` → `-home-you-devbox-source-X`). `manifest.tsv` in the
memory repo stores the `$HOME`-relative path instead, and `scripts/link-memory.sh`
recomputes the slug on each machine. A different `$HOME` needs no edit.

```bash
./scripts/link-memory.sh --dry-run   # show what it would link
./scripts/link-memory.sh             # symlink repo -> ~/.claude/projects/<slug>/memory
./scripts/link-memory.sh --adopt     # ALSO move local-only memory into the repo first
```

`--adopt` is for a machine whose memory the repo has never seen. If both sides have
files it refuses and says so rather than picking a winner — merge by hand, then re-run.

**`MEMORY.md` is generated, not hand-written.** `scripts/gen-memory-index.py` rebuilds
it from each memory file's frontmatter (`name` + `description`), sorted alphabetically
so both machines produce byte-identical output.

```bash
./scripts/gen-memory-index.py           # rewrite the indexes
./scripts/gen-memory-index.py --check   # exit 1 if any is stale
```

Two reasons it is generated. It used to drift — nothing checked that a line existed for
every file, or that a line did not outlive its file. And it is the **only** part of file
memory that two machines reliably conflict on: the memory files are separate and small
so git merges them cleanly, while the index is one list both sides append to. Derived
files get regenerated instead of merged.

**Sync is automatic**, via `hooks/memory-sync.sh` wired into `settings.json`:

| hook | action |
|---|---|
| `SessionStart` | `memory-sync.sh pull` — fetch + **merge** `origin/main` |
| `Stop` | `memory-sync.sh push` — regenerate indexes, commit, push |

Both always exit 0: a hook must never take a session down over a network blip, and
both exit immediately when no memory repo is cloned.

**The hook only ever touches the memory repo.** Claude Code rewrites `settings.json`
at runtime, and with the symlink in place those writes land in *this* repo — an
automatic `git add -A` here would sweep them into an unreviewed commit. Splitting the
two repos removes that hazard at the root: the Stop hook commits in a repo that
contains nothing but memory. Your own config changes still need a manual commit,
reviewed through a pull request.

Pull refuses to merge over uncommitted local memory changes, and aborts a conflicted
merge rather than leaving the tree half-resolved. If a conflict happens, resolve it in
the repo by hand — the files are small markdown.

**When swapping machines:** nothing to do beyond the `link-memory.sh` step in the
new-machine section above. Memory arrives with the next `git pull`, and the SessionStart
hook does that for you.

**Privacy note.** This repo is private, and the tracked memory includes notes about
employer projects (`partner-ops`, `employee-integration-*`, `work-schedule-*`,
`data-analysis`). Dropping a row from `memory/manifest.tsv` stops syncing that project
without touching its files. Re-read that list if this repo's visibility ever changes.

## agentmemory (persistent memory MCP)

[agentmemory](https://github.com/rohitg00/agentmemory) gives the agent persistent,
semantically-searchable memory via a local server (REST on `:3111`, MCP shim).
Tracked in this repo as the plugin entry in `settings.json`, a SessionStart hook, and
the sync scripts; skills and secrets stay per-machine.

**The MCP server itself is not tracked here.** User-scoped servers live in
`~/.claude.json`, which also holds per-project runtime state, so it cannot be
symlinked into a shared repo. Add it per machine instead (idempotent).

**Wire it on a new machine:**

```bash
# 1. Add the MCP server to this machine's live config (~/.claude.json).
npx -y @agentmemory/agentmemory@latest connect claude-code
#    or: claude mcp add --scope user agentmemory -- npx -y @agentmemory/mcp

# 2. Install the skills that teach the agent WHEN to call the memory tools
#    (bootstrap-only — intentionally gitignored, not vendored).
npx skills add rohitg00/agentmemory -y

# 3. Restart Claude Code (or /mcp) so the tools load.
```

**Server:** the `hooks/agentmemory-start.sh` SessionStart hook boots the server on
first session if it isn't already up (non-blocking). Without a running server the
MCP shim falls back to ~7 local tools instead of the full set.

**One central store.** The engine's state adapter path is *cwd-relative*
(`./data/state_store.db` in the bundled `iii-config.yaml`), so an unpinned server
gives whichever project launched today's first session its own private store —
memories saved in one repo are simply invisible from every other one. The boot
hook therefore `cd`s to `~/.agentmemory` first, making
`~/.agentmemory/data/state_store.db` the single store on the machine. Never launch
the server by hand from a project directory; if you do, you get a fresh empty
store and the real one goes quiet. Check with:

```bash
ls -l /proc/$(cat ~/.agentmemory/iii.pid)/cwd   # expect ~/.agentmemory
```

**Project scoping survives centralization.** Each memory and session carries a
`project` tag; recall filters on it and boosts same-project hits 1.5×. The tag is
resolved by the capture hooks from *their own* cwd —
`AGENTMEMORY_PROJECT_NAME`, else `basename(git rev-parse --show-toplevel)`, else
the directory name — so the server's cwd never leaks into it.

**Capture hooks** ship with the upstream plugin (`agentmemory@agentmemory` in
`settings.json` → `enabledPlugins` + `extraKnownMarketplaces`). They record
sessions, prompts, tool use, failures and compactions automatically, all
project-tagged. Without the plugin the store only ever holds what the agent saved
by hand through the MCP tools — and those saves are **not** auto-tagged: the
`project` argument is optional, so an untagged save is invisible to
project-scoped recall. Hence global rule 12: manual saves always pass the
canonical project identifier.

**Backfill from transcripts** (optional): `npx -y @agentmemory/agentmemory@latest
import-jsonl <dir>` replays `~/.claude/projects` JSONL history into the store. Pass
one project directory at a time so employer transcripts stay out of a personal
store; add `--max-files 1000` for repos with long histories (default caps at 200).
Sessions and observations come out correctly project-tagged, but the tag is derived
from the **transcript directory name**, not from git — a session run inside a
subdirectory (`.../MadorasRebirth/Docs`) imports as project `Docs` and needs
retagging via `scripts/memory-export.sh` → edit → `memory-import.sh ... merge`.

**Wipe the lessons namespace after any import-jsonl run.** The importer also runs a
"lesson" extractor that regex-grabs sentences around never/don't/always and stores
them truncated: a 56-session backfill produced 252 lessons, every one at confidence
0.4 tagged `auto-import`, 103 of them mid-sentence fragments (`"never write the
tag."`, `"don't trust it here."`). They surface in recall ahead of nothing useful.
There is no lesson-delete API — only a decay sweep that soft-deletes at confidence
≤ 0.1 after weeks — and the KV file carries a trailer that makes hand-editing
unsafe, so drop the whole namespace with the server stopped:

```bash
cd ~/.agentmemory && npx -y @agentmemory/agentmemory@latest stop
cp ~/.agentmemory/data/state_store.db/'mem%3Alessons.bin' \
   ~/.agentmemory/backups/lessons-wipe-$(date +%Y%m%dT%H%M%S).bin
rm ~/.agentmemory/data/state_store.db/'mem%3Alessons.bin'
~/.claude/hooks/agentmemory-start.sh
curl -s localhost:3111/agentmemory/lessons | head -c 60   # expect {"lessons":[]
```

Memories, sessions and observations live in other namespaces and are untouched.
Restore by copying the backup back with the server stopped.

**Moving memory between machines** — manual on purpose; no snapshot is tracked by
git (raw session content in a config repo ages badly, and it would churn every
session):

```bash
./scripts/memory-export.sh dump.json --only MadorasRebirth,dotfiles-claude-rules
# copy dump.json to the other machine, then there:
./scripts/memory-import.sh dump.json merge
```

`merge` (default) overwrites same-id records with the incoming version, `replace`
wipes the local store first (auto-backed-up to `~/.agentmemory/backups/`), `skip`
only adds ids that are new. There is no 3-way merge, so sync one direction at a
time. The importing server rejects exports whose `version` is outside its
supported list — keep both machines on comparable agentmemory versions.

**Secrets / optional features:** none are tracked. If you want an auth secret or an
LLM provider key, put them in `~/.agentmemory/.env` (outside this repo). Context
auto-injection (`AGENTMEMORY_INJECT_CONTEXT`) is left **off** on purpose — it feeds
stored memory into every prompt, which is a prompt-injection surface. Enable
deliberately, not by default.

## RTK — Rust Token Killer

[rtk](https://github.com/rtk-ai/rtk) is a CLI proxy that filters command output before it
reaches the model (60–90% fewer tokens on dev operations). A `PreToolUse` hook
rewrites Bash commands transparently: `git status` → `rtk git status`.

Tracked here: `RTK.md` (the slim command reference), the `@RTK.md` include at the
bottom of `CLAUDE.md`, and the hook entry in `settings.json`. The **binary is not**
tracked — install it per machine.

**Wire it on a new machine:**

```bash
# 1. Install the rtk binary (lands in ~/.local/bin/rtk). The installer verifies
#    the release sha256 against checksums.txt and needs no sudo.
#    Beware the name collision: reachingforthejack/rtk is a different tool.
curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
rtk --version   # expect: rtk 0.43.0 or newer

# 2. Symlink the tracked reference (repo stays source of truth).
ln -sf "$(pwd)/RTK.md" "$HOME/.claude/RTK.md"

# 3. Verify — do NOT run `rtk init -g --auto-patch`; it would rewrite the
#    symlinked settings.json / CLAUDE.md. The repo already carries both edits.
rtk init -g --show          # all four rows should read [ok]
rtk hook check "git status" # expect: rtk git status
```

Restart Claude Code so the hook loads.

**Locale gotcha (fixed upstream, kept for history):** rtk 0.37.2 returned nothing
from `rtk ls` under `LANG=pt_BR.UTF-8` — every `ls` came back `(empty)` because the
listing parser assumed English output. Only the `ls` filter was affected. The
workaround was `"env": { "LC_ALL": "C.UTF-8" }` in `settings.json`, at the cost of
English shell messages inside Claude Code sessions. Verified fixed in 0.43.0
(`LC_ALL=pt_BR.UTF-8 rtk ls` lists normally), so the `env` block is gone. If `ls`
ever returns `(empty)` again on a machine, check its locale first.

## Safety invariant
`.gitignore` ignores `*` first, then allowlists. Any new file — including a future
secret Claude Code drops in `~/.claude` — is ignored unless you explicitly add a
`!` allow rule. Never add `!.credentials.json` or similar.
