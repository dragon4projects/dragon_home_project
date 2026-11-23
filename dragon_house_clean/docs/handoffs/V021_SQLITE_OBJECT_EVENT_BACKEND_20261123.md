# Dragon House v0.21 — SQLite Object-Event Backend / Default Cutover Handoff

Date: 2026-11-23  
Role: Integrator  
Production base: `dragon-house-fallout-fresh@1216e2f1a737008e3d9fea0f5d240d54a78a6ea2`  
Base full acceptance: run #44 / `45203091451` — SUCCESS  
Final v0.21 feature acceptance: PENDING on the commit containing this document.

This handoff records implementation and reproducible evidence. It is not Dragon owner approval and does not activate any unfinished Teea/Znaechka content.

## 1. Scope

v0.21 replaces the temporary JSON compatibility backend for the already-accepted v0.20 **physical-object event family** with an embedded SQLite backend when the vendored SQLite GDExtension is available.

The stable public WorldModel APIs remain unchanged:
- register_physical_object
- set_object_ambient_protection
- pickup_physical_object
- place_physical_object
- recover_physical_object_to_lost_found
- restore_physical_object_home
- object_event_history
- explain_physical_object

The truth path remains:

`caller -> world_event_gate -> object_event_reducer candidate -> canonical store commit -> current projection -> journal/renderer`

Only physical-object truth is event-sourced in this slice. Rooms, residents/guests, creatures, media lifecycle, doors and the rest of WorldModel remain on their existing persistence paths. v0.21 does not claim a fully event-sourced House.

## 2. Historical implementation reused

The archived Runtime Rebase implementation was reopened from the project Library, not reconstructed from memory.

Iteration 2:
- `DRAGON_HOUSE_RUNTIME_REBASE_V2_ITER2_2026-11-20.zip`
- recorded SHA256: `5da406da073ac40f5710899ef272802b85fcef56a15cb37ef79cc66d44f55147`
- relevant code: `core.py`, `reducer.py`, `permission_gate.py`, `schema.sql`
- archived test suite rerun: 6/6 PASS

Iteration 4:
- `DRAGON_HOUSE_RUNTIME_REBASE_V2_ITER4_2026-11-20.zip`
- recorded SHA256: `e58753513d6edd52416dce78a4768dd8325f3d2f2ca13710d7eb0451d40e9b34`
- archived test suite rerun: 9/9 PASS

Reused architectural guarantees:
- SQLite WAL journal mode;
- synchronous=FULL;
- unique stable event_id and monotonic seq;
- event append and derived-state reducer mutation in one transaction;
- canonical events are immutable/replayable;
- derived state is disposable and rebuildable;
- rejected truth mutation is not appended;
- no renderer authority elevation;
- no ambient canonical-owner rewrite.

Not reused:
- Python runtime requirement;
- localhost Python service;
- separate Core process.

The embedded Godot backend keeps the proven transaction/reducer semantics without adding Python to Windows/macOS runtime requirements.

## 3. Embedded SQLite backend

New runtime module:
- `scripts/world_event_store_sqlite.gd`

SQLite tables in this slice:
- `schema_meta`
- `events` — canonical append-only object events
- `objects` — derived object projection

This deliberately does not create decorative empty tables for mutation families that have not yet crossed the strangler boundary.

Canonical append behavior:
1. gate validates event against current projection;
2. reducer computes candidate projection;
3. SQLite `BEGIN IMMEDIATE`;
4. event row inserted;
5. derived `objects` projection synchronized;
6. `COMMIT`;
7. in-memory projection published.

Recovery backup is not a second commit phase. If the canonical transaction committed but the recovery-copy refresh fails, the mutation remains accepted and runtime reports `READY_BACKUP_STALE` plus `object_event_backup_warning`.

## 4. Default backend and cutover

With the vendored SQLite class available and no environment override:
- clean worlds use SQLite by default;
- existing v0.20 JSON canonical event streams migrate automatically to SQLite;
- pre-v0.20 object snapshots migrate automatically through typed historical-import events.

Explicit `DRAGON_OBJECT_EVENT_BACKEND=json` remains a pre-cutover development/compatibility override only.

After SQLite becomes canonical, it is sticky:
- a later `json` override cannot downgrade the world;
- stale JSON remains migration evidence only;
- a missing/corrupt SQLite canonical store never promotes stale JSON back to truth.

If native SQLite bytes are absent in an uncut source checkout, a clean world may still use the JSON compatibility backend. If SQLite was already canonical, missing native support/store fails closed.

## 5. Migration semantics

v0.20 JSON event-stream migration:
- source JSON remains byte-identical;
- event_id preserved;
- seq preserved;
- reducer projection must equal SQLite derived projection;
- subsequent events advance SQLite only.

Pre-v0.20 snapshot migration:
- source snapshot remains non-destructively inspectable;
- generated registration events use:
  - source_type = migration_import
  - authority = HISTORICAL_IMPORT
  - truth_class = EXPLICIT_WORLD_FACT
- legacy object history is retained.

## 6. Recovery / rollback protection

SQLite primary corrupt:
- primary quarantined;
- readable backup restored and fully validated;
- replay continues from backup.

Primary missing but backup present:
- backup is restored **before** SQLite open can create an empty database.

Both primary and backup unreadable:
- compatibility snapshot remains inspectable;
- mutation path fails closed.

Canonical marker:
- `<save>.world_events_v1.sqlite.canonical.json`
- records last known canonical sequence.

The marker prevents two silent rollback classes:
- primary + backup both missing after SQLite cutover -> `SQLITE_CANONICAL_MISSING`;
- readable backup sequence behind marker -> `SQLITE_ROLLBACK_DETECTED`.

In both cases stale JSON is not eligible to become truth, and the last-known canonical revision remains visible for diagnosis.

Derived `objects` table mismatch:
- canonical events replay through reducer;
- derived table rebuilt transactionally;
- event identity/order unchanged.

## 7. Vendored dependency / supply chain

Pinned dependency:
- `2shady4u/godot-sqlite` release `v4.9`
- upstream release asset `addons.zip`
- release asset SHA256: `95e91b72fe32984a84edaf6357a78753661f37a170cb362f5b948e0ede7c2cb0`
- descriptor compatibility minimum: Godot 4.7
- Dragon House engine: Godot 4.7.2

Vendored under:
- `dragon_house_clean/addons/godot-sqlite/`

Included native targets only:
- Linux x86_64 debug + release (CI/editor)
- Windows x86_64 debug + release
- macOS universal debug + release

Native binaries are Git LFS objects. Android/iOS/Web binaries are intentionally excluded.

Licenses included beside the addon:
- godot-sqlite wrapper: MIT
- bundled SQLite: public domain

`SHA256SUMS.txt` and `SUPPLY_CHAIN.md` record the selected files and provenance.

## 8. Focused evidence before final merge

Backup/canonical-loss focused gate:
- run `45210488908` — SUCCESS
- proves committed event remains canonical when recovery backup refresh fails;
- proves missing primary restores backup;
- proves stale backup behind canonical marker is rejected;
- proves total canonical SQLite loss fails closed without stale-JSON rollback.

Default-cutover focused gate:
- run `45212626662` — SUCCESS
- proves no-env clean world selects SQLite;
- proves explicit JSON remains a pre-cutover compatibility lane;
- proves v0.20 JSON automatically migrates on normal launch;
- proves v0.20 JSON gate/replay/migration regressions still pass;
- proves v0.17 object lifecycle and v0.18 ambient object use remain compatible.

Vendoring workflow:
- run `45210972492` — SUCCESS
- six selected native binaries pushed as Git LFS objects;
- LFS OID SHA256 values match the vendored checksum manifest.

## 9. Production acceptance changes

`.github/workflows/dragon-house-lfs.yml` is extended to:
- fetch the additional vendored LFS binaries;
- verify the SQLite checksum manifest;
- run all v0.21 object-event regressions;
- export Windows/macOS with vendored SQLite;
- require SQLite DLL/framework presence;
- include the Windows SQLite DLL in the private Windows QA ZIP.

The feature branch final gate independently tests Linux semantics, native Windows, native macOS and full-LFS export/package behavior.

## 10. Remaining architecture boundary

After v0.21 is accepted in production:
1. do not expand event sourcing by bulk rewrite;
2. move one mutation family at a time behind the same gate/event/reducer contract;
3. keep renderer/presentation outside truth authority;
4. keep private-room/consent rules independent of technical reachability;
5. integrate Teea/Znaechka content only after their exact handoff heads are verified;
6. Zoo/creature animation may consume the object contract, but may not bypass it.

The next event-family candidate should be chosen from the Supervisor backlog after production evidence is green; do not invent a second parallel World Core.
