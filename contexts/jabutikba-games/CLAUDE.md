# Jabutikba Games — Unreal Engine / C++ Context

These rules **add to** the global rules. They apply only under
`devbox/source/jabutikba-games/`.

This is a looser, personal context: no task-management integration, no automated
review process, relaxed branch and git workflow beyond the global baseline.

---

## 1. Internationalization (i18n)

- **If the project has i18n:** all user-facing messages go through the project's
  i18n mechanism. Languages: **pt-BR** and **en-US**.
- **If the project has no i18n:** write all messages directly in **pt-BR**.

**Pull requests are always written in pt-BR** — both title and body. The team
reads them; they are not internal notes. Commit messages, code comments and
documentation stay in English unless the project says otherwise.

---

## 2. PIE Session Investigation

When investigating a task, issue, or bug, weigh whether a **Play-In-Editor (PIE)**
session would help understand it better.

If yes, prompt the developer with a short guide on how to replicate the scenario
in PIE, and assist with the investigation where applicable.

---

## 3. Hardware Note — Intel iGPU laptop (13620H / UHD RPL-P)

This laptop CANNOT run Unreal Engine 5.8 projects requiring Vulkan SM6.
Intel Iris Xe / UHD iGPU lacks `VK_EXT_mesh_shader` → SM6 profile fails → editor won't open.
Do NOT retry. Do NOT edit shared project config to force SM5 (adds team-wide cook cost / package bloat).

GPUs that DO support UE5.8 SM6 (need `VK_EXT_mesh_shader`):
- NVIDIA: RTX 20-series (Turing) or newer. GTX 10-series and older: NO.
- AMD dGPU: RX 6000M (RDNA2) or newer. RX 5000M (RDNA1): NO.
- AMD iGPU: 680M / 780M (RDNA2/3, Ryzen 6000+) work iGPU-only. Vega (Ryzen 4000/5000): NO.
- Intel: Arc dGPU yes; Lunar Lake Xe2 iGPU yes; Iris Xe / UHD (this laptop) NO.

Linux: driver must expose the extension — keep Mesa / NVIDIA driver current.

---

## 4. No Live Coding on Linux

Do NOT use C++ Live Coding on a Linux machine — it does not work. Triggering it
(e.g. `Ctrl+Alt+F11`, or the `livecoding_compile` MCP action) tears the editor
down instead of hot-patching the module, risking loss of unsaved in-editor work.

To pick up C++ changes on Linux:
1. Close the editor.
2. Full rebuild of the editor target (`UnrealBuildTool` / `Build.sh`).
3. Reopen the editor.

---

## 5. StateTree Authoring

A **Global Task must NEVER call `FinishTask`**. Global tasks are meant to run for
the entire lifetime of the tree; a global task that finishes (succeeds or fails)
**terminates the whole StateTree** — it stops immediately, enters no state, and
the owning pawn goes brain-dead (frozen). One-shot tasks that call `FinishTask`
(e.g. a "look at actor" that rotates once and finishes) belong as **per-state
tasks**, not in Global Tasks.

Symptom in logs (`LogStateTree` Verbose): `Start Temporary Evaluators & Global
tasks while trying to select linked asset: <ST>` immediately followed by `Stop
Temporary Evaluators & Global tasks` with **no** `Enter state Root...` line — the
tree selected nothing. A correctly-placed fallback state cannot rescue this,
because the failure happens above state selection. Compare against a working tree
that reaches `Enter state {<ST>}Root...`.

Global Tasks that stay `Running` (never call `FinishTask`) are fine as globals
(e.g. a "set refs" task that populates parameters on enter and idles).

**An empty state is lethal under scheduled tick.** A state with no task has
nothing to call `FinishTask`, so `On State Completed` never fires and the
scheduler gets no reason to re-arm component tick — the pawn parks indefinitely
while the tree still reports `RUNNING`. Escapes only if something incidental
re-arms tick (measured dwells: 2.8s, 4.3s, 12s, 66s, never). An empty state is
**not** a no-op state.

**When duplicating a tree, verify each state's exit contract, not just its
structure.** Duplicating a tree copies its states but not the invariants they
relied on: a state whose exit came from a task's same-frame `FinishTask` becomes
a permanent trap the moment that task is stripped. Before deleting a task from a
duplicated tree, establish what completed the state that held it. Prefer
deleting the now-purposeless state over propping it up with a filler task.

**Diagnosing a frozen ST pawn.** `run_status` / `is_running()` / `is_active()`
do **not** discriminate live from dead — a dormant tree reports `RUNNING`. Use a
**time-series** probe instead: sample `is_component_tick_enabled()` (or actor
position) across real wall-time — healthy flips `True`/`False` frame to frame,
dead is stuck `False`. Standard recipe, given ST assets are MCP-blind
(see the `statetree-mcp-blind` memory): `LogStateTree` Verbose for structure and
the transition trail, plus `execute_python` against
`UnrealEditorSubsystem.get_game_world()` for component runtime state (this works
mid-PIE; content assets only load with PIE **stopped**).

**Rank log warnings by onset correlation, not by count.** A frozen-pawn repro
will surface loud pre-existing noise that predates the symptom and is harmless.
Timestamp-align each warning's first occurrence against the moment behaviour
stopped before chasing it.

**Verify each fix by its own log signature.** These failures stack — distinct
causes produce an identical frozen-pawn symptom. Close a fix when *its* specific
signature is gone from a fresh log, never when the symptom disappears, or two
bugs will read as one failed fix.

---

## 6. Never Write DataTables Through MCP

**`data_table set_rows_from_json` is destructive here. Do not use it.** The
round-trip is not lossless: `get_rows_as_json` exports nested map fields (e.g.
`Attribute Increase Base` / `Attribute Increase Per Level` on
`Struct_SkillCastConfig`) as `{}`, and the importer then rejects them with
`LogCSVImportFactory: Entry 0 on property '<X>' is the incorrect type. Expected
Double, got Object.` The import drops those fields on **every** row, saves the
truncated table anyway, and can take the editor down with it. Measured on
`DT_SkillsNew`: 73750 → 67472 bytes, ~45 rows damaged, editor crash.

Same applies to `export_to_csv` — it feeds from the same lossy path, so a CSV or
JSON "backup" taken through MCP is **not** a valid restore source. **Git is the
only trustworthy backup for a `.uasset`.** Verify a restore by content hash
against `HEAD`, not by file size alone.

To change DataTable values: **edit by hand in the editor UI.** Reading through
MCP (`get_rows_as_json`, `get_row_names`, `get_column_names`) is safe and
useful — only writes are banned.

**After any timed-out MCP write, absence of change is not proof of safety.** The
editor may still be mid-write when the socket times out; the save can land
seconds later. Confirm the editor process has actually exited (beware `pgrep`
matching its own `bash -c` wrapper, and beware more than one editor running),
then re-check `git status` and compare hashes.

---

## 7. A Struct Gaining a Field Is a Data-Migration Event

Adding a field to a struct backing a DataTable is not a schema tweak — every
existing row silently receives the default (`0` / empty), and rows nobody
remembers to re-author keep it. This fails **silently**: no error, no warning,
no compile failure, and often a partially-working feature that masks the gap.

Precedent: PR #1418 added `Cast Amount` / `Delay Between Casts` to
`Struct_SkillCastConfig` and re-imported `DT_SkillsNew` from a backup JSON. Every
skill was re-authored to `Cast Amount 1` except `Skill_Arrow`, whose `0` made
`GA_Base`'s `For Loop  FirstIndex=1  LastIndex=CurrentCastAmount` run zero
iterations — so the player's basic attack spawned projectiles that were never
given velocity. Animation played, nothing fired, for a full day. The same
re-import also silently dropped `Pierce_Base` / `GE_Piercing` from the rows.

When adding or changing a field on a DataTable row struct:

1. Diff row data **before and after**, not just the struct. The offline recipe
   works without the editor:
   `git show <rev>:<path> | git lfs smudge | strings | sort -u`, then `comm`
   against the new version. That is what surfaced both the `Pierce_Base` loss
   and the `SkillConfig_4_` → `SkillConfig_7_` property re-index.
2. State the invariant the new field implies and check every row against it.
   For the case above: *any row with `Projectile Amount > 0` must have
   `Cast Amount >= 1`.*
3. Treat a re-import from exported JSON/CSV as suspect until row survival is
   verified — see §6.

---

## 8. Verify Claims Against Current Assets, Not Stale Artefacts

Two failure modes cost real time on the mage/attack-token work:

**Logs captured before a merge describe the pre-merge tree.** "Cleanup still
needed" was asserted from a log predating the merge that had already fixed it.
Before reporting an outstanding issue, re-check the **current** asset.

**Compact tool output is a rendering, not ground truth.** The MCP graph dump's
`node_title` omits a `K2Node_CreateDelegate`'s bound function, so a correctly
bound `Create Event` reads as unbound; map pins report as their key type, so a
healthy `TMap` pin reads as a bare `byte`/enum. Confirm against the node's own
accessors (`get_create_delegate_function`, `error_msg`) or a compile before
calling a node broken.

Corollary: **saved-asset state and loaded-in-editor state can disagree.** A
serialized error string can persist in a `.uasset` while the in-memory node has
re-resolved on load, and vice versa. Neither alone is authoritative — when they
conflict, say so rather than picking the convenient one.

---

## 9. Closing and Reopening the Editor Is Pre-Approved

You may close and reopen the Unreal Editor, provided you told the developer
beforehand that the work needs it.

Approval of an implementation that requires the editor to be closed (any C++
change on Linux — see §4) **carries approval to close and reopen the editor as
many times as that work needs**. Do not stop to ask again per build cycle.

Say so before the first close, so unsaved in-editor work can be saved. This
covers the editor process only — it does not extend to any other irreversible
action.

---

## 10. Squash on Merge — `unreal-mcp` Only

In the **`unreal-mcp`** repo, always squash when landing work on `main`:
`gh pr merge --squash`, or the Squash button. Never `--merge`, never
`--rebase`.

It is a fork that tracks `upstream/main` (`GenOrca/unreal-mcp`). A linear,
one-commit-per-change `main` stays diffable against upstream; a chain of
intermediate commits per feature makes comparing and re-syncing noisy.

Keep authoring work as several focused commits on the feature branch — they
review well and revert cleanly. The squash happens only at merge time, so the
squashed message must carry the substance of every commit it absorbs, not a
concatenation of subjects.

This does not weaken the global "never rebase feature branches" rule: that one
is about rewriting a branch's own history, this one is about how the branch
lands on `main`.

**Scope: `unreal-mcp` only.** Other repos under this context keep the global
merge workflow unless they say otherwise.
