# Dragon House v0.12 — width-aware furniture contracts

**Status:** development branch only  
**Branch:** `dev/dragon-house-v012-width-anchors`  
**Engine:** Godot 4.7.2

## Why this exists

The v0.11 full-LFS acceptance run exposed a real contract bug: owner-accepted Library **R2** measured chair anchors had been installed as cell-coordinate overrides while the seeded house still contained Library **R1**. The renderer correctly drew the R1 procedural table, while gameplay advertised an R2 chair that did not exist in that room.

The immediate v0.11 fix kept R2 measurements out of the active R1 contract. v0.12 removes the entire class of error.

## Contract

Furniture interaction data now supports `variant_cell_overrides` keyed as:

`<room_type>:R<width>:<module_index>`

Examples:
- `common:R3:0`
- `common:R3:1`
- `common:R3:2`
- `library:R2:0`
- `library:R2:1`

A width-specific contract activates only when the logical cell is actually part of that exact merged R1/R2/R3 room.

Fallback order:
1. exact variant-cell override,
2. legacy exact world-cell override,
3. generic room profile.

Private rooms and lifts still return no public furniture stations.

## Accepted 002 migration

The owner-accepted measured Common R3 stations were moved from world-X overrides into:
- `common:R3:0`: two left-sofa seats,
- `common:R3:1`: intentionally no furniture station,
- `common:R3:2`: right bench + right chair.

The owner-accepted Library R2 measurements are now preserved as:
- `library:R2:0`: `library_chair_left_seat_a`,
- `library:R2:1`: `library_chair_right_seat_a`.

The seeded Library R1 continues to use the procedural `TABLE_LIBRARY` pair until an actual R2 exists.

## Runtime

`RoomStations.layout_for_world(world, room)` resolves merged width and module index before selecting physical anchors.

Reservation, pair placement and save reconciliation use this world-aware layout.

When accepted art replaces procedural furniture, `main.gd` also creates invisible runtime furniture anchor nodes from the same exact width-specific contract. Rendering and simulation therefore resolve the same furniture identities.

## Regression proof

Local Godot 4.7.2 with the real accepted TEEA 002 PNG payload:

- `WIDTH_ANCHORS_V012_PASS library_R1=table library_R2=chairs common_R3=scoped`
- `FURNITURE_CONTRACT_V10_PASS scene_objects=17`
- `SOFA_SEATING_V09_PASS`
- `LAZY_ART_V10_PASS`
- `DRAGON_V011_ACCEPTED_ART_PASS`
- `ROOM_LOD_V06_PASS`
- `DRAGON_V011_ROOM_DISTRIBUTION_PASS`
- `DRAGON_V011_DEPTH_PASS`
- `ARTIST_ANCHOR_V2_REVIEW_PASS`

v0.12 is not promoted to `dragon-house-fallout-fresh` until v0.11 acceptance is closed and the full LFS CI is run with `test_width_anchors_v012.gd`.
