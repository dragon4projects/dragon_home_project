# Dragon House v0.11 — depth pass and TEEA 003 integrator intake

**Date:** 2026-11-23  
**Engine:** Godot 4.7.2  
**Branch:** `dev/dragon-house-v011-depth`

## 1. Integrator-owned depth pass

The accepted TEEA 002 REWORK R1 art remains unchanged. This pass fixes the runtime shell/camera issues listed in the owner art decision.

Implemented:

- reduced the physical floor slab from 0.18 m to 0.10 m;
- reduced the ceiling slab from 0.14 m to 0.09 m and shortened its projection toward the camera;
- reduced the front cutaway lip to 0.07 m height / 0.09 m depth;
- reduced front stone returns, exterior side-wall projection, doorway headers and merged-room seam ribs;
- ROOM camera now targets the room's vertical centre instead of the lower floor band;
- automatic close-view yaw was reduced to a subtle maximum bias of 0.075 rad; Q/E remains the explicit stronger parallax control;
- close-view camera elevation was reduced so the room reads more frontally and less empty foreground floor is visible.

The named nodes `CutawayFloorSlab`, `CutawayCeilingSlab` and `CutawayFrontLip` are now regression-testable.

## 2. Regression evidence

New test: `tests/test_v011_depth_pass.gd`.

It checks:

- floor/ceiling/front-lip maximum thickness;
- the front extent of floor and ceiling geometry;
- ROOM focus height;
- restrained automatic yaw;
- near-frontal close-camera elevation.

Standalone Godot 4.7.2 syntax scan: PASS.  
Standalone `test_v011_depth_pass.gd`: PASS.

The reduced local test environment intentionally did not contain the private LFS image library, so full accepted-art and platform export validation remains the job of repository CI.

## 3. TEEA_INT_20261122_003 intake

Art branch inspected:

`art/teea-interiors-TEEA_INT_20261122_003`

Current delivery contains proposals and an external binary payload for:

- arrival/R1
- corridor/R1
- music/R1
- cinema/R1
- artifact/R1
- workshop/R1

The external ZIP was downloaded independently in the Higgsfield sandbox and its declared SHA-256 was verified:

`2233854a91684acec90ad687961cc1c3b1316f921643a5941e9ed6846778b093`

Payload count: 20 production PNGs plus the contact sheet and QA/provenance documents.

Important status:

- machine image QA: PASS;
- integrator ZIP checksum: PASS;
- artist marks every layer `approved:false`;
- no production branch was modified by the artist;
- Music/Cinema contain physical foreground occlusion layers;
- proposed stations total 7;
- Arrival/Corridor intentionally contain no resident station;
- the binary room art has **not** been promoted into production Git LFS by this intake step.

No owner approval is inferred for TEEA 003. The next required step for that batch is exact live-camera integration with the current v0.11 shell, then owner visual review.

## 4. CI

The repository CI test list now includes:

- `test_v011_accepted_art.gd`
- `test_v011_room_distribution.gd`
- `test_v011_depth_pass.gd`

Private export artifact names are updated to v0.11.


## 5. Production validation trigger

The v0.11 development line was fast-forwarded to `dragon-house-fallout-fresh` on 2026-11-23 after the standalone Godot 4.7.2 depth regression passed. This commit exists to record the promotion and trigger the branch-scoped full LFS/Godot/export workflow. It does not change art approval state.


## 6. Width-safe interaction correction

Full LFS CI exposed a real interaction-contract mismatch after owner acceptance of TEEA 002: the measured Library **R2** chair anchors had been installed as cell overrides for the seeded Library **R1**. That made gameplay advertise furniture which the active R1 procedural room did not draw.

Correction:
- the seeded Library R1 now uses its existing `TABLE_LIBRARY` pair;
- the accepted Library R2 artwork and measurements remain preserved for the future actual R2 merge;
- no R2-only station is installed into an R1 room;
- this is a runtime contract correction, not an art rollback.

Independent Godot 4.7.2 verification with the real accepted 002 PNG payload:
- `FURNITURE_CONTRACT_V10_PASS scene_objects=17`
- `DRAGON_V011_ACCEPTED_ART_PASS layers=15`
- `SOFA_SEATING_V09_PASS`
- `LAZY_ART_V10_PASS`
- `DRAGON_V011_ROOM_DISTRIBUTION_PASS`
- `DRAGON_V011_DEPTH_PASS`
- `ARTIST_ANCHOR_V2_REVIEW_PASS`


## 7. Full CI rerun trigger

The width-safe Library correction and its real-002 targeted regression package are now on the fresh branch. This commit intentionally triggers the full LFS/Godot/Windows/macOS acceptance workflow from the corrected branch head.
