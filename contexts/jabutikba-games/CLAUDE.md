# Jabutikba Games — Unreal Engine / C++ Context

These rules **add to** the global rules. They apply only under
`devbox/source/jabutikba-games/`.

This is a looser, personal context: no task-management integration and no
automated review process. Repo-level `CLAUDE.md` files are stricter and win.

---

## 1. Internationalization (i18n)

- **If the project has i18n:** all user-facing messages go through the project's
  i18n mechanism, in the languages the project ships.
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

- **A Global Task must NEVER call `FinishTask`.** It terminates the whole tree:
  no state is entered and the pawn freezes. One-shot tasks that finish belong
  as per-state tasks. Global Tasks that stay `Running` are fine.
- **An empty state is lethal under scheduled tick.** With no task nothing calls
  `FinishTask`, so component tick is never re-armed and the pawn parks while
  the tree still reports `RUNNING`. An empty state is not a no-op state.
- **When duplicating a tree, verify each state's exit contract.** A state that
  exited through a task's same-frame `FinishTask` becomes a permanent trap once
  that task is stripped. Delete the purposeless state; do not prop it up with
  a filler task.
- **`run_status` / `is_running()` do not tell live from dead** — a dormant tree
  reports `RUNNING`. Probe `is_component_tick_enabled()` over real wall-time
  instead: healthy flips, dead is stuck `False`.
- **Rank log warnings by onset correlation, not count, and verify each fix by
  its own log signature** — distinct causes stack into the same symptom.

Log signatures, full recipe, measured dwells: memory
`statetree-global-task-finishtask`, `statetree-frozen-pawn-playbook`.

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
MCP (`get_row_names`, `get_column_names`) is safe. `get_rows_as_json` is
read-only but lossy: nested maps come back as `{}`. For a faithful read use
`export_data_table_to_json_string` via `execute_python`.

**After any timed-out MCP write, absence of change is not proof of safety.** The
editor may still be mid-write when the socket times out; the save can land
seconds later. Confirm the editor process has actually exited (beware `pgrep`
matching its own `bash -c` wrapper, and beware more than one editor running),
then re-check `git status` and compare hashes.

---

## 7. A Struct Gaining a Field Is a Data-Migration Event

Adding a field to a struct backing a DataTable gives every existing row the
default (`0` / empty), silently: no error, no warning, no compile failure, often
a partially-working feature that hides the gap (PR #1418: `Skill_Arrow` got
`Cast Amount 0`, so the basic attack fired nothing).

When adding or changing a field on a DataTable row struct:

1. Diff row data **before and after**, not just the struct. Offline recipe:
   `git show <rev>:<path> | git lfs smudge | strings | sort -u`, then `comm`
   against the new version.
2. State the invariant the new field implies and check every row against it
   (e.g. *any row with `Projectile Amount > 0` must have `Cast Amount >= 1`*).
3. Treat a re-import from exported JSON/CSV as suspect until row survival is
   verified — see §6.

Full case study: memory `skill-arrow-cast-amount-migration`.

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
