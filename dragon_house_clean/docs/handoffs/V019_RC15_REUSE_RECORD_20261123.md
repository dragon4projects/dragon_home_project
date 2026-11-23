# Dragon House v0.19 — Mora/RC1.5 reuse record

Date: 2026-11-23
Integrator branch: `dev/dragon-house-v019-rc15-reuse-scheduler-level`
Current production base: `dragon-house-fallout-fresh@c280f62778bcc4a4ac0093db48a852f0469b6bf2`
Historical engineering source: `dragon4projects/dragon_cave_godot@a55ee0ec8c8cc2ff39c1015e672464b99ec1eba2`

This is a provenance/architecture record, not owner approval.

## Reused nearly as code — life scheduler

Historical source:
- `autonomy/life_scheduler_v2.gd`
- usage pattern verified in `autonomy/resident_autonomy.gd`

Preserved concepts/behavior:
- per-actor `due_at`;
- wake reason;
- stable stagger;
- elapsed-time consumption;
- explicit `schedule_at` / `schedule_in` / `wake`;
- deterministic ordering by due time then actor ID;
- bounded `pop_due()`;
- movement remains frame-driven while high-level planning is due-driven.

Current adaptations:
- scheduler state persists under current `WorldModel.runtime_state`;
- recovery accepts current JSON compatibility snapshots;
- current action vocabulary, station claims, routes, media and social logic are retained;
- current planner metrics are recorded;
- camera/LOD/LEVEL operations do not wake planner jobs;
- current Godot 4.7.2 strict typing rules applied.

No old resident identities, rooms, geometry or content were imported.

## Reused as architecture/state contract — semantic views

Historical sources:
- `production_v02/semantic_stream_v2.gd`
- `production_v02/runtime_camera.gd`

Preserved contract:
- semantic states `HOUSE / LEVEL / ROOM / FOLLOW`;
- selected-level visibility;
- connector context across adjacent levels;
- HOUSE/LEVEL are cheap semantic representations;
- ROOM/FOLLOW may materialize rich detail;
- Follow changes active level when tracked actor crosses a connector;
- view state never owns simulation truth or wakes life planning.

Not copied:
- old orthographic camera assumptions;
- old `UPPER/CORE/LOWER_01/LOWER_02` coordinates;
- old cave geometry, floor centers, room IDs and private-room implementation;
- old visibility controller nodes.

Current implementation derives levels from actual `world.rooms[*].level` and keeps the present perspective Shelter-style camera.

## Reuse candidate for next strangler — event/provenance core

Historical sources inspected:
- `core_client.gd`
- `qa/core_outbox_replay_qa.gd`
- `content_system/content_store.gd`

Useful verified guarantees to preserve:
- stable event IDs;
- explicit source / authority / truth class;
- durable pending events;
- restart-preserved event identity;
- rejection retained rather than silently discarded;
- duplicate event ID is idempotent;
- temp-write -> atomic replace discipline;
- revision / expected-revision check;
- invariant validation before persistent commit.

Will NOT be copied wholesale:
- HTTP localhost Core dependency;
- token/config transport;
- old repository-specific content schema;
- old renderer-to-service topology.

Planned migration remains a strangler:
1. define current canonical event envelope;
2. route one mutation family first (physical objects);
3. reducer projection + equivalence tests against current WorldModel;
4. durable local event backend;
5. SQLite only after reducer/event semantics are proven and migration is non-destructive;
6. expand mutation families gradually.

## Explicit non-reuse

No old game art, private-room contents, resident canon, coordinates, or stale production branch is promoted by this work.
The historical repository is an engineering evidence bank, not the current source of product truth.
