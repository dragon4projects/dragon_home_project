# Dragon House v0.20 — Object Event / Permission / Provenance Strangler

Date: 2026-11-23
Integrator branch: `dev/dragon-house-v020-object-event-strangler`
Accepted production base: `dragon-house-fallout-fresh@917d2d02cbc5ac6b0d8b69539a6ec266a37ebbdc`
Base full acceptance: workflow run #42 / `45195748147` — SUCCESS

This document records an architecture migration slice. It is not Dragon owner approval.

## 1. Why this slice exists

v0.19 removed frame-scanned high-level life planning and added the explicit semantic LEVEL mode. The next P0 debt is the persistent truth path:

```
input
 -> truth/permission gate
 -> append-oriented canonical event
 -> reducer
 -> current-state projection
 -> renderer / scheduler / journal
```

Before v0.20, physical-object methods validated locally, mutated `WorldModel.objects` directly and only then appended explanatory history/journal rows. Ambient helper code performed some important eligibility checks before calling the generic WorldModel API, so caller discipline remained part of the safety boundary.

v0.20 moves the first mutation family — physical objects — behind one central event boundary while preserving the current public WorldModel object API.

## 2. Historical implementation reused

Historical code was inspected from the old Mora/RC line and from the archived Runtime Rebase World Core packages.

### Mora/RC1.5

Repository: `dragon4projects/dragon_cave_godot@a55ee0ec8c8cc2ff39c1015e672464b99ec1eba2`

Useful files:
- `core_client.gd`
- `qa/core_outbox_replay_qa.gd`
- `content_system/content_store.gd`

Reused guarantees:
- stable event identity;
- durable pending/canonical event semantics;
- duplicate event ID does not reduce twice;
- rejected mutation is not silently treated as accepted;
- temp-write / verify / atomic replacement discipline;
- explicit revision;
- invariant validation before persistent commit.

### Runtime Rebase Iteration 2 / Iteration 4

Archived packages were materialized from the project Library and their recorded SHA256 values matched.

Iteration 2:
- `DRAGON_HOUSE_RUNTIME_REBASE_V2_ITER2_2026-11-20.zip`
- SHA256 `5da406da073ac40f5710899ef272802b85fcef56a15cb37ef79cc66d44f55147`
- contained SQLite schema, `core.py`, `reducer.py`, `permission_gate.py`, migrations and tests;
- archived unit suite was rerun: 6/6 PASS.

Iteration 4:
- `DRAGON_HOUSE_RUNTIME_REBASE_V2_ITER4_2026-11-20.zip`
- SHA256 `e58753513d6edd52416dce78a4768dd8325f3d2f2ca13710d7eb0451d40e9b34`
- adds localhost server/setup/Godot adapter contract;
- archived suite was rerun: 9/9 PASS.

RC0:
- `DRAGON_HOUSE_RUNTIME_REBASE_V2_RC0_2026-11-20.zip`
- SHA256 `a7cedebbffc7ea4305edf344467e72a0b08f5fa0a2d1376ad4069cbfb6dde177`

The old SQLite schema remains the compatibility target for a future backend:
- append-only `events` with unique `event_id` and monotonic `seq`;
- derived `objects` table;
- reducer replay;
- WAL/FULL durability;
- event insert and reducer mutation in one transaction.

## 3. What is deliberately NOT reused yet

The old local service launcher requires `py -3` / Python when run from source.

Fresh Dragon House must not silently acquire a separately installed Python requirement on Windows or macOS.

Therefore v0.20 reuses:
- event grammar;
- truth/authority gate semantics;
- append/revision/replay behavior;
- reducer model;
- crash/recovery discipline;

but does NOT yet require:
- Python runtime;
- localhost HTTP service;
- separate Core process;
- SQLite plugin/GDExtension.

The first goal is to prove the event/reducer boundary and migration equivalence inside the existing Godot product. SQLite remains the target backend after this truth path is proven.

## 4. Canonical truth grammar

The envelope follows `13_WORLD_TRUTH_AND_CONSENT_MODEL.md`.

Persistent object events carry:
- `event_id`
- `created_at` (plus timestamp compatibility field)
- `source_type`
- `source_id`
- `authority`
- `truth_class`
- `visibility`
- `event_type`
- `subject_id`
- `object_id`
- `room_id`
- `from`
- `to`
- `expires_at`
- `reversibility`
- `provenance`
- `notes`
- `payload`
- store-assigned monotonic `seq`

Truth classes:
- `EXPLICIT_WORLD_FACT`
- `AMBIENT_SIMULATION`
- `PRESENTATION_ONLY`

Source/authority combinations are centrally checked. In particular:
- renderer cannot claim Dragon/owner/system authority;
- ambient simulation cannot elevate itself to explicit truth;
- migration remains `HISTORICAL_IMPORT`;
- system mutations require `SYSTEM_RULE`;
- presentation cannot mutate object truth.

## 5. New runtime modules

### `scripts/world_event_store.gd`

Temporary local append-oriented compatibility backend.

Properties:
- separate from the JSON current-state snapshot;
- schema version 1;
- unique event ID;
- monotonic sequence;
- no API for event deletion/reordering;
- atomic temp write;
- read-back structural verification before commit;
- backup rotation;
- corrupt primary quarantine;
- backup replay;
- fail-closed when both canonical copies are unreadable;
- object-specific event-history query.

Important: this JSON document is a backend compatibility layer, not the final SQLite claim.

### `scripts/world_event_gate.gd`

Central object truth/permission gate.

Enforces:
- required typed envelope;
- truth/source/authority pairing;
- no presentation mutation;
- no ambient ownership change;
- holder/location/state invariants;
- current-state preconditions;
- actor co-location/access;
- object movable flag;
- ambient pickup opt-in;
- ambient hide opt-in;
- protected-object denial;
- creature pickup/hide capabilities;
- public-only House Spirit recovery;
- House Spirit cannot take from a holder;
- explicit restore only to canonical home.

This closes the previous safety seam where direct `WorldModel.pickup_physical_object()` could bypass the ambient helper's eligibility checks.

### `scripts/object_event_reducer.gd`

Pure object projection reducer.

The reducer, not caller code, now changes:
- holder;
- room;
- state;
- canonical owner when a future accepted owner-change event is used;
- ambient policy;
- movement reason/authority;
- last explicit location;
- updated event identity;
- bounded object history.

Ambient motion does not overwrite canonical ownership or the last explicit placement.

### `scripts/object_event_runtime.gd`

Strangler facade between current WorldModel APIs and the new event path.

Responsibilities:
- lazy setup from the current `save_path`;
- migration from legacy JSON object projection;
- gate -> reducer candidate -> durable event append -> projection publish;
- crash-gap replay;
- compatibility snapshot revision metadata;
- accepted-event House Journal projection;
- journal reconciliation by canonical event ID;
- provenance/explanation query.

Existing public WorldModel APIs remain stable:
- `register_physical_object`
- `set_object_ambient_protection`
- `pickup_physical_object`
- `place_physical_object`
- `recover_physical_object_to_lost_found`
- `restore_physical_object_home`

## 6. Legacy JSON migration

If a readable JSON world snapshot contains objects but no canonical object event stream:

1. existing object rows are read as migration input;
2. one `OBJECT_REGISTERED` event is generated per identity;
3. source type is `migration_import`;
4. authority is `HISTORICAL_IMPORT`;
5. provenance is `MIGRATION_FROM_JSON_SNAPSHOT_V1`;
6. legacy per-object history is retained;
7. events are atomically committed;
8. reducer projection replaces the compatibility object dictionary;
9. no source object data is deleted.

When a canonical stream already exists, replayed events own the object projection. The JSON snapshot is then only a checkpoint/compatibility copy.

## 7. Crash / recovery semantics

Event append happens before publishing the in-memory projection.

Therefore a crash after event commit but before `save_world()` is recoverable:
- startup seeds/loads non-object world state;
- canonical events replay;
- object projection is rebuilt;
- compatibility snapshot may then be written.

If primary event storage is corrupt and backup is valid:
- corrupt primary is quarantined as `.corrupt`;
- backup events are replayed;
- object projection follows the backup, not a newer stale JSON checkpoint;
- v0.20 House Journal object rows whose event IDs are no longer canonical are pruned;
- missing canonical object journal rows are reconstructed.

If both canonical event copies are corrupt:
- compatibility JSON remains inspectable;
- object event runtime enters `CORRUPT_NO_RECOVERY`;
- future object mutations fail closed;
- no new canonical event stream is silently invented from that state.

## 8. Provenance query

WorldModel exposes:
- `object_event_history(object_id, limit)`
- `explain_physical_object(object_id)`

The explanation includes:
- canonical owner;
- current holder/location/state;
- last explicit location;
- movement reason and authority;
- canonical event count;
- latest accepted event including truth/authority/provenance.

This is the first concrete answer path for the project requirement:
> why is this object here?

## 9. Focused evidence to date

Focused runs before the final journal-recovery tightening:
- run #3 — SUCCESS
- run #4 — SUCCESS
- run #5 — SUCCESS
- run #6 — SUCCESS
- run #7 — SUCCESS
- run #8 — SUCCESS
- run #9 / `45199415163` — SUCCESS

Run #9 proves:
- central bypass denial;
- protected object denial;
- creature pickup/hide capability enforcement;
- presentation mutation denial;
- renderer authority elevation denial;
- ownership stability;
- duplicate event idempotency;
- typed envelope;
- crash-gap replay;
- provenance query;
- journal replay;
- JSON migration;
- backup recovery;
- double-corrupt fail-closed behavior;
- old snapshot recovery;
- v0.17 object lifecycle;
- v0.18 ambient creatures;
- content viewer;
- guest-room access;
- base model.

Later focused run(s) are used to prove the additional journal pruning rule for backup rollback before merge.

## 10. Remaining architecture boundary

v0.20 is NOT the claim that the entire Dragon House is event sourced.

Only the physical-object mutation family crosses the new canonical gate/reducer/event path.

Still direct/snapshot based:
- room construction/configuration;
- resident/guest current state;
- creature current state;
- media lifecycle;
- permissions outside object movement;
- door state;
- scheduler state.

Next architecture steps after v0.20 acceptance:
1. keep object event grammar stable;
2. replace JSON event backend with SQLite compatible with the proven old schema, preferably without external Python;
3. prove state equivalence again;
4. expand one mutation family at a time;
5. never make renderer/presentation the truth authority.
