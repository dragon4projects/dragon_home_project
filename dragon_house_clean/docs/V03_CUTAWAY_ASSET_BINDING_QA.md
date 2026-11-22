# Dragon House v0.3 — Runtime / Cutaway / Asset binding QA

Date: 2026-11-22. Branch: \`dragon-house-fallout-fresh\`. Engine: 4.7.2 Standard.
Scope of this update: gameplay/visual code ONLY. **No imported November art is modified**.

## New renderer/camera constraints

- \`world_model.gd:visual_groups()\` returns R1/R2/R3 contiguous same-type segments.
- Each segment is one geometry shell with one shared floor/back/roof, one group label and furniture modules inside.
- A fourth identical adjacent module is rejected. Logical cell IDs are stable.
- \`main.gd:set_mode("ROOM")\` focuses the **merged group** center and scales zoom with R1/R2/R3 width. Selection outline spans the whole group.
- \`can_build\` requires a public accessible frontage or lift-shaft adjacency; isolated room cells cannot appear.
- Residents can **walk past** a private door via explicit \`public_frontage=true\`; the \`room_id\` is a corridor waypoint only. Destinations and interactions inside private rooms still require owner access.
- RoomLocomotion maintains frontend Z for such private-door corridors. It never uses a private interior anchor for normal traffic.
- HOUSE view target ~30 FPS cap, detail modes 60 cap. Detailed tiny QA meshes are hidden in far view. Resident gait banks use idle at far zoom; only detailed modes show animated frames.

## November asset-bank contract

\`scripts/asset_bank_resolver.gd\` expects \`data/asset_registry_nov2026.json\` with the v1 manifest described in the separate migration agent task.

Default visual binding requires exact resident appearance_profile, visual_bank_ready=true, verified \`IDLE_S\`, \`WALK_LEFT\` and \`WALK_RIGHT\` frame arrays with \`status=PASS\`. Each frame path must be inside \`assets/residents/RES_XX/wardrobes/HOME/\`. Paths containing \`..\`, backslashes, absolute external paths or another resident's ID are rejected.

Cache is bounded at 36 texture objects (not a full VRAM budget guarantee). Stage-specific READ/TALK/RELAXED_SIT/SLEEP/DRINK/VIEW are used only if explicitly marked PASS with real frames. No undocumented left/right mirroring, no permission elevation, no dormant resident activation.

No manifest yet => safely show existing QA placeholders. A manifest that passes a filename test does not by itself establish artistic identity quality. This is a technical gate, not a human visual review.

## Test ledger — independent Higgsfield Godot 4.7.2

- PASS \`test_model.gd\` — 24 profiles, privacy denied as destination, 3 levels, autonomous jobs.
- PASS \`test_cutaway_groups.gd\` — 21 logical modules -> 19 visual shells; R3 expansion and R4 rejection; private-frontage public passage only; no duplicate or dropped cells.
- PASS \`test_camera_construction.gd\` — scene-level real node count, selected group-centered focus, zoom preserves Follow, bounded yaw, manual pan cancels Follow.
- PASS \`test_locomotion.gd\` — physical XYZ waypoints and vertical lift.
- PASS \`test_asset_binding.gd\` — synthetic temporary PNG and JSON; verified state binds, cross-ID and path traversal rejected, visual readiness required; fixtures removed.
- PASS \`test_social.gd\` — reciprocal pair.
- PASS \`test_media.gd\` — books, 24h returns, persistence.
- PASS \`test_av.gd\` — WAV/OGV accepted, unsupported MP4 not advertised as native.
- PASS \`test_snapshot.gd\` — corrupted primary recovers from backup.
- PASS virtual-display scene render and room screenshot (Mesa llvmpipe, not real target GPU).

## Renderer comparative evidence — software Mesa llvmpipe / 1280×720

All FPS results are virtualized CPU software renderer and should **NOT** be presented as Dell Latitude 5300 or Mac M1 performance.

Before micro-detail far LOD + mesh reuse:
- HOUSE ~26.6 FPS, peak 374 draws, 697 visible objects.
- ROOM ~20.4 FPS, peak 165 draws, 506 objects.

After micro-detail far LOD + mesh reuse:
- HOUSE ~25.0 FPS, peak **309 draws**, **632** objects.
- ROOM ~20.6 FPS, peak 165 draws, 506 objects.

Draw calls and visible objects improved at HOUSE scale; timing change is within virtual benchmark noise, **no measured FPS improvement claim**. The close-up remains too heavy in llvmpipe and must be checked on actual Intel/GT620M and M1 devices. This benchmark used temporary QA geometric interiors without actual 24 approved high-res banks.

## Remaining blockers

1. Asset agent real November bank manifests and image bytes, plus visual/identity QA.
2. Original room R1/R2/R3 art, depth masks, room-based occlusion with true fidelity to the reference.
3. 24 fully approved active residents, furniture occupancy reservations, 30-seater Common.
4. Camera robustness under actual perspective UI usage, real input hardware and real target performance.
5. Windows and macOS exports from current commit after the v0.3 code update (previous v0.2 binaries do not contain these features).
