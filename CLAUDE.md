# Global Development Rules

Universal rules. They apply in **every** context and project.

Context-level `CLAUDE.md` files add stricter or domain-specific rules on top of
these (see `contexts/` in this repo). A deeper file may extend or override a
global rule; when it does, the deeper file wins for that context.

---

## 1. Plan-First Workflow

Before writing any code, present the plan and wait for explicit approval.

Once approved, every change must be:
- Shown before being applied (diff or description).
- Linked to a specific item in the plan.

---

## 2. Never Assume Code Existence — Always Verify

Before referencing, modifying, or planning changes around any method, class,
field, or file, **read the actual source** to confirm it exists and matches
expectations.

- Do not infer structure from naming patterns.
- Do not trust subagent summaries alone — verify with Read or Grep.
- Applies even when the assumed element would be logically consistent or "obvious."

**Failure mode to avoid:** symmetry bias — assuming a complementary method
exists because its counterpart does.

---

## 3. Minimal and Justified Changes

Prefer the smallest change that fulfills the plan.

If a more complex change is unavoidable, explain:
- Why it is necessary.
- What simpler alternatives were considered and why ruled out.

Never introduce changes beyond what the current plan item requires.

---

## 4. Readability Over Line Count

Cognitive complexity takes precedence over line count.

Easier to read > shorter or marginally faster. Favor maintainability unless the
performance difference is significant and justified. Never sacrifice clarity for
cleverness.

---

## 5. Opportunistic Code Smell Fixes

When modifying existing code, resolve behavior-neutral smells in lines you are
already changing. No separate approval, but list them in the diff.

If fixing a smell requires a behavioral change:
- Notify the developer.
- Explain current vs proposed behavior.
- Ask for explicit approval.

---

## 6. Branch Management

Never commit directly to `main` or `master`.

If the current branch is `main` or `master`, create a new branch before starting
work.

**Exception:** `dotfiles-claude-rules` and `dotfiles-claude-memory` (auto-synced
by hook) may be committed straight to `main`.

Branch naming: `<type>/<descriptive-name>`, where the type matches the intent of
the work and the name describes it clearly. No ticket IDs.

- `feat/` — new feature. Examples: `feat/add-user-auth`, `feat/ai-attack-token`.
- `fix/` — bug fix. Examples: `fix/payment-timeout`, `fix/camera-tilt`.

The name must genuinely match the chosen type.

---

## 7. Git Workflow

- Never rebase feature branches — use merge.
- Never force-push to shared branches.
- Never delete and re-clone repos to change branches — use `git checkout`/`git switch`.
- Run `git config core.fileMode false` in any new repo clone.
- Before any commit, run `git diff --stat` and verify only intended files appear.
  If permission-only changes appear in bulk, abort and investigate.

---

## 8. Testing

Run the project's test suite after making changes. Where a project has none
(e.g. Unreal), its own `CLAUDE.md` defines the verification step.

When modifying a constructor signature, grep all test files that instantiate the
class and update them before committing. Do not commit with failing tests.

---

## 9. Test Coverage

New code must include appropriate test coverage where applicable.

For existing code without tests: suggest what would be appropriate, leave the
decision to the developer.

---

## 10. MCP Integration

After adding or modifying an MCP server configuration, remind the developer that
the session must be restarted before changes take effect. Do not attempt to test
MCP connections in the same session they were configured.

---

## 11. Communication Style — Caveman Mode

Default to caveman mode (full intensity) in all responses unless "stop caveman"
or "normal mode". The `caveman` plugin injects the full rules each session; they
are not repeated here.

---

## 12. Memory Persistence — Dual Store

Whenever the developer asks to save something to memory ("remember this", "save
this", "note that", "don't forget", etc.), persist it to **both** stores — never
just one:

1. **File memory** — `~/.claude/projects/<cwd>/memory/*.md`. Write a good
   `description:` in the frontmatter: `MEMORY.md` is generated from it.
2. **agentmemory** — via `mcp__agentmemory__memory_save` (load it first with
   `ToolSearch("select:mcp__agentmemory__memory_save")` if it isn't already
   available). Pass the canonical project identifier, an appropriate `type`
   (pattern / preference / architecture / bug / workflow / fact), `concepts`, and
   relevant `files`.

`project` is **mandatory** on every manual save, never optional. One store serves
all projects, and recall filters and ranks by that tag — an untagged memory is
dead weight nothing will surface. The canonical identifier is the repo's git
toplevel basename (`MadorasRebirth`, `dotfiles-claude-rules`), which is exactly what the
capture hooks tag automatically; use that spelling, not a path or a display name.

Mirror the same curated item into both. This is keyed to the developer's explicit
save request — no separate reminder is needed.

Deleting or correcting a memory applies to both stores. Confirm before deleting
from agentmemory.

---

## 13. Memory Recall — Dual Store

Recall is asymmetric: the file-memory `MEMORY.md` index auto-loads each session,
but agentmemory surfaces nothing on its own. So whenever you draw on a specific
file-memory entry for the current task (open/read a memory file, or act on a
recalled-memory note), **also run an agentmemory recall for that same topic** —
`mcp__agentmemory__memory_recall` or `memory_smart_search` (load first with
`ToolSearch("select:mcp__agentmemory__memory_recall")` if needed) — so both stores
contribute to the answer.

The developer runs the session-start recall themselves (`/recall`, `/handoff`);
this rule covers the topic-triggered recalls that come up mid-session.

@RTK.md
