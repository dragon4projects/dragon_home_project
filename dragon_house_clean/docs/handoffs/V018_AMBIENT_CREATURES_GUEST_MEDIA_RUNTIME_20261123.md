# DRAGON HOUSE v0.18 — INTEGRATOR RUNTIME HANDOFF

Date: 2026-11-23
Owner: Dragon
Integrator branch: `dev/dragon-house-v018-ambient-creatures-media-viewer`
Base production: `dragon-house-fallout-fresh@3bd019771dec104ceec830150a8801b197eb02c5`
Owner approval of art: not implied by this runtime handoff.

## Scope completed

### Ambient creature runtime
- persistent `creatures` world state;
- low-frequency autonomous decisions;
- actual waypoint travel instead of room teleport;
- public-space routing only;
- closed/private room target rejection with causal journal event;
- explicit object-pickup capability per creature;
- explicit object eligibility per object;
- explicit hide capability per creature + per-object hide opt-in;
- protected objects cannot be ambient-picked;
- carried object retains one canonical identity and follows carrier state;
- stashed object remains in world truth but is removed from normal render/hit-test;
- evidence-only pet-owner label via explicit `owner_id`; unknown stays unknown.

### Persistent causal House Journal
- bounded persisted journal;
- object register/pickup/place/stash/lost-found/restore events;
- creature registration/roam/access rejection;
- guest registration/guest-room access changes;
- visible House Journal includes world-causal events in addition to life log.

### Full-screen content viewer plumbing
- full-screen record viewer for books / films / tracks / artifacts;
- safe missing-preview / missing-local-content state;
- playback hook for supported local audio/video;
- media selection opens the shared viewer;
- generic 3D hotspot API: hover label + click full-screen;
- physical objects can bind viewer metadata without changing object identity.

### Physical object visible causality
- one render node per registered object identity;
- placed object appears only at current public room;
- held object follows holder;
- stashed object is not normally visible/clickable;
- object canonical owner remains independent from holder/location.

### Guest runtime contract
- explicit `guest` room type;
- guest actor registration separate from resident-sister identity;
- guest room assigned to one named guest;
- open room: visitable + public cutaway;
- closed room: no public entry, no public cutaway, guest-owner entry retained;
- public frontage remains passable in front of a closed guest door;
- guest open/closed state persists across save/restart;
- REST/SLEEP guest-room selection is reserved to that guest owner.

## Focused Godot 4.7.2 evidence

GitHub Actions run: `#24 / 45177592430`
Conclusion: SUCCESS
Godot: `4.7.2.stable.official.ed1daf0bf`

Pass lines:
- `OBJECT_LIFECYCLE_V017_PASS`
- `AMBIENT_CREATURES_V018_PASS ... waypoint_travel=yes ... rejected_logged=yes ... owner_label=evidence_only ... stash=persistent journal=causal`
- `CONTENT_VIEWER_V018_PASS fullscreen=yes missing_content=safe categories=book_film_track_artifact`
- `GUEST_ROOM_ACCESS_V018_PASS assigned=yes visit_open=yes closed_entry=no owner_entry=yes cutaway_closed=no frontage_transit=yes persisted=yes`
- `DRAGON_HOUSE_MODEL_TEST_PASS`
- `MEDIA_LIFECYCLE_TEST_PASS`

The temporary focused workflow was removed after this pass.

## Production acceptance change

The normal `.github/workflows/dragon-house-lfs.yml` gate now also executes:
- private-door / TEEA003 / authored station v0.16 tests;
- object lifecycle v0.17;
- ambient creatures v0.18;
- content viewer v0.18;
- guest-room access v0.18.

## Deliberately NOT done in this runtime batch

- No Teea 007 guest-room art promoted.
- No Znaechka creature/NPC branch merged wholesale; it diverges from current production and must be integrated as a fresh asset delta.
- No inferred cat ownership.
- No automatic activation of every delivered creature bank.
- No object becomes ambient-stealable by default.
- No new Kitchen.
- No resident private-room exposure.
- No changes to the 423 RES_22–24 frames.
- No claim that media previews already exist; viewer handles real/missing data truthfully.

## Next integration seams

1. Integrate Znaechka current asset delta/manifests over current production without merging her stale base.
2. Bind approved creature banks to `world.creatures` visual states.
3. Ingest Teea 007 guest rooms + measured stations / media surfaces / mug geometry.
4. Materialize media/artifact hotspots from Teea surface metadata + Zna preview manifest.
5. Run full LFS / render / Windows + macOS production acceptance.
