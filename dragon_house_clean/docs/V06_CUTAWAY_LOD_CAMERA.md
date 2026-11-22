# Dragon House v0.6: camera-anchored zoom, recessed backwalls, lazy room details
Date: 2026-11-22. Independent Godot 4.7.2 project only.
Repo: dragon4projects/songs_panels; branch dragon-house-fallout-fresh.

## What is implemented

- Real sprite feet: the renderer formerly calculated an anchor from documented imported source frames but then overwrote the Y position with a generic temporary silhouette position. v0.6 preserves the per-bank feet anchor. LFS-backed test is separate.
- Three scene-detail levels: stable R1/R2/R3 shell and corridor pathways; lightweight always-visible overview cues by public room type; lazy-instantiated detailed furniture only in rooms near the camera, evicted when camera moves away. This changes rendering only, never World Core life or ownership state.
- Backwall architecture: recessed panels, upper arch returns, side posts, low plinth and subtle emissive sconces for public rooms. No heavyweight dynamic lights or unapproved imported room imagery. Private rooms retain owner-gated doors only, with zero private interiors.
- Camera: wheel zoom keeps the projected world point beneath the cursor instead of always zooming the center; FOLLOW tracking remains actor-anchored. Camera state does not drive autonomous life.
- Existing 21/24 LFS candidate avatar banks, 7 Manka technical states, 8 historical artifact masters and 76 metadata-only library titles remain valid and QA-only.

## Test ledger

- test_room_lod_v06.gd: HOUSE details zero, overview silhouette, room focus materialization, no duplicate furniture, far eviction, no private room backwall or furnishings, one bay per public module.
- test_cursor_zoom_v06.gd: mouse point preserved, FOLLOW retained during wheel zoom.
- test_room_capacity_v06.gd: 49 synthetic room cells / 47 cutaway groups; 4 detailed groups near camera, 0 far. This is a scaling/invariant test, not an FPS claim.
- test_lfs_sprite_anchor_v06.gd: uses actual imported Git LFS bytes to test RES_01 sprite foot height, Manka and QA-only opt-in; requires the private GitHub Actions checkout.
- Every v0.5 regression test for camera, building, Manka, social life, books, AV formats, privacy, registry and 2,409 SHA records stays in the workflow.

## Gaps and next work

- No approved complete layered interior banks yet. The November report explicitly recorded zero; do not blindly claim the procedural geometry is finished artwork. Real public R1/R2/R3 room images still require authoring/review and explicit manifest approval.
- 3 characters lack confirmed animation banks. Tech-pass artwork is not a canonical identity; no unapproved resident gets activated.
- Windows 10 Dell Latitude 5300 and macOS 15 M1 8GB performance must be checked physically. The CI environment is not a hardware benchmark.
- No Bethesda copyrighted art, scripts or textures are used.

## Build process

The private GitHub Actions workflow validates actual Git LFS objects, prepares an owner-only 24-character contact sheet, runs Godot 4.7.2 import, the full suite and exports Windows/macOS QA packages with the actual assets. Its run result must be checked: publishing a workflow file does not imply successful builds.

