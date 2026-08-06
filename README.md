# dotfiles-claude-rules

Shared Claude Code configuration for **Jabutikba Games** — the rules, hooks, scripts
and skills we all run, so development standards stay the same across machines and
stop drifting apart between developers.

This repo is the source of truth for *how Claude behaves*. It holds no memories, no
credentials and no project data.

## What's in here

| Path | What it is |
|------|-----------|
| `CLAUDE.md` | Global rules — plan-first workflow, verification, branch and git policy, testing, communication style. Loads in every context. |
| `contexts/jabutikba-games/CLAUDE.md` | Unreal Engine / C++ rules. Loads only under that directory tree, stacking on top of global. |
| `RTK.md` | `rtk` (token-saving CLI proxy) reference, included from `CLAUDE.md`. |
| `settings.json` | Model, hooks, plugins, theme. |
| `hooks/` | Session and tool hooks: agentmemory startup, memory sync, a pre-commit guard against bulk permission-only changes. |
| `scripts/` | Symlink wiring and memory index tooling. |
| `skills/` | Shared skills, when we have them. |
| `SYNC-README.md` | The long-form reference for how the symlinking works and why. |

Rules stack: deeper files extend or override shallower ones, and the deepest file
wins for its context.

## Requirements

- **Claude Code**
- **Git Bash on Windows.** The hooks are bash scripts and `settings.json` pins
  `"shell": "bash"`, so Windows runs them through Git Bash. Without it the hooks fail
  (harmlessly, but they do nothing).
- **Python 3** for the memory index generator — only needed if you use the optional
  memory repo.
- `rtk` is optional. The hook checks for it and skips when it is absent.

## Install

```bash
git clone https://github.com/renan-renger/dotfiles-claude-rules.git
cd dotfiles-claude-rules

# Global rules + RTK reference + settings
ln -sf "$(pwd)/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
ln -sf "$(pwd)/RTK.md"    "$HOME/.claude/RTK.md"
cp -n "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.pre-symlink.bak" 2>/dev/null || true
ln -sf "$(pwd)/settings.json" "$HOME/.claude/settings.json"

# Hooks (settings.json refers to them by their ~/.claude/hooks/ path)
./scripts/link-hooks.sh

# Per-context rules
mkdir -p "$HOME/devbox/source/jabutikba-games"
ln -sf "$(pwd)/contexts/jabutikba-games/CLAUDE.md" "$HOME/devbox/source/jabutikba-games/CLAUDE.md"
```

Everything is symlinked rather than copied on purpose: copies drift silently. That is
how `settings.json` once sat four commits behind the repo while both files looked
fine in isolation.

Restart Claude Code afterwards — hook and MCP changes only take effect in a new session.

### MCP servers

MCP config cannot be symlinked from this repo: user-scoped servers live in
`~/.claude.json`, which also holds per-project runtime state and is not shareable.
Run this once per machine instead:

```bash
claude mcp add --scope user agentmemory -- npx -y @agentmemory/mcp
```

Its `AGENTMEMORY_URL` / `AGENTMEMORY_SECRET` / `AGENTMEMORY_TOOLS` come from your
environment, so no secret is ever committed. For a server that should apply to one
project and be shared with everyone working on it, use `--scope project` instead —
that writes a `.mcp.json` in the project repo, which is the mechanism meant for
version control.

### Optional: private memory repo

File memory (what Claude remembers per project) is **personal**, so it is not in this
repo. If you want it version-controlled and synced across your own machines, keep a
private repo of your own and point the tooling at it:

```bash
export CLAUDE_MEMORY_REPO="$HOME/devbox/source/dotfiles-claude-memory"
./scripts/link-memory.sh          # --adopt to move existing local memory in
```

Skip this entirely and nothing breaks: `link-memory.sh` reports that the repo is
absent and exits, the sync hook stays silent, and Claude Code keeps memory where it
normally does, under `~/.claude/projects/<slug>/memory`.

## Update

```bash
git pull
./scripts/link-hooks.sh   # picks up any newly added hook
```

Because the live files are symlinks into this working tree, a `git pull` updates your
active configuration immediately — no copying step. It also means the checked-out
branch *is* your live config: stay on `main` unless you are deliberately testing.

## Contributing / versioning

We follow **GitHub Flow**:

1. Branch off `main` — `<type>/<descriptive-name>`, e.g. `feat/add-review-skill`,
   `fix/hook-path-quoting`. No ticket IDs.
2. Commit focused changes with a message explaining *why*, not just what.
3. Open a pull request against `main` and get a review from another dev.
4. Merge to `main`. `main` is always deployable — everyone's live config follows it.

Since a merge to `main` changes how Claude behaves for all of us, treat rule changes
like production changes: say what problem the rule solves, and prefer the smallest
rule that solves it.
