# Design contract — clean-room Dragon House

## Baseline
Primary: Windows 10, Dell Latitude 5300, 8 GB RAM. Secondary: macOS 15, M1, 8 GB RAM. Godot 4.7.2 Standard GDScript, Compatibility renderer. No AI/cloud events. All ordinary life arises from documented local simulation rules.

## Reference mechanics, not copied assets
The September 2026 Fallout Shelter 2.6.0 APK/OBB documentation established that:
- Close rooms were implemented with optimized meshes/room prefabs and authored occupancy positions.
- Room width variants R1/R2/R3 and visual upgrade levels L1/L2/L3 were distinct; a merged room appeared coherent at close range.
- Workers had authored XYZ waypoints, including movement into depth and elevation.
- Far view could use optimized impostors; camera had a dedicated Follow controller with smoothing/dead-zone.
- A single persistent map underlies room view and house view.

We reproduce the **observed look, motion grammar, spatial continuity and interaction patterns** using Godot. Our authored room data and artwork are independent.

## Scene/logic separation

`world_model.gd`: stable room IDs, cell adjacency, routing, media catalog, save/load, privacy.
`life.gd`: local autonomous decisions on needs + preferences + daypart, movement and commitments.
`main.gd`: 3D cutaway presentation, sprites, click interactions, camera, construction UI.
Any camera mode change must not trigger a behavioral decision or create a canonical social fact.

## Room building
1. Grid cells are hidden structural modules, not the visible art style.
2. A construction click is valid only at an adjacent empty cell, or vertically beside an existing lift.
3. Connected same-type cells remove full-width interior side partitions and share a visual shell rhythm; furniture can remain asymmetric.
4. The room has a stable ID even when merged/expanded.
5. Different-type neighbors connect with framed thresholds; two heights joined through lifts.
6. Privacy: nonpublic interiors are not instantiated and inaccessible to general actor pathing.

## Camera
HOUSE/ROOM/FOLLOW are views of one scene, not independent pictures. Mouse zoom is continuous. Follow keeps a smooth world-space target as the actor moves on its own graph; turning the camera never triggers activity changes. The camera cannot look into owner-controlled private rooms.

## Asset pipeline
Original authored artwork:
`res://assets/rooms/<room_type>/*.png` room shell/background/foreground
`res://assets/residents/<resident_id>/<state>/<direction>.png` identity-preserving sprite banks
`res://assets/props/*.png` stage props
`res://assets/previews/film|music|book/*.png` thumbnails.
A missing canon visual is an explicit missing asset — not a fabricated person.

At close range: geometric depth, foreground occluders, furniture anchors and resident directional banks. At far range: LOD/impostors and inexpensive actor silhouettes. Current prototype uses **geometric authoring stand-ins**; not final art.

## Next acceptance gates
- [x] Room adjacency and cross-level route unit test.
- [x] Private-room route fails closed in model test.
- [x] Independent autonomy produces decisions.
- [ ] Actual Windows Intel/GT620M camera, FPS and memory.
- [ ] Room-level furniture depth and ray-cutaway visual QA.
- [ ] Approved 24 visual bank ingest, missing identities tracked.
- [ ] Media playback, books, trailers, audio and posters from verified inventory.
- [ ] Action commitment/reservations for social conversations and furniture.
- [ ] Win64 portable export + macOS smoke test.


Book lifecycle proof: `tests/test_media.gd` covers double-borrow rejection, progress, legal return and 24-hour abandoned cleanup.
