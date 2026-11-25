# Iteration 4.22 — canonical rendering, shelf claims, bounded detail

Source baseline: 1356b29fa9150db80e308bcd6fa91f32ab039a57. Godot 4.7.2.stable.official.ed1daf0bf, Higgsfield Linux x86_64/Xvfb/Mesa llvmpipe, hydrated working tree from iteration 4.21 with all real LFS assets, same local-only optimized import (raw character/creature PNGs, source Blender files outside project). No hardware export, no GitHub Actions.

## Runtime changes
- Conditional dressing honors the existing physical book return reservation map as well as book shelf assignments and object supports. A held physical book remains drawable even if its shelf assignment is temporarily absent.
- Canonical renderer admits at most two detailed furniture groups (including procedural fallbacks); nearest physical focus ranked by room bounds, floor distance and small existing-detail retention. All room shells and existing real-model overview cues remain visible. HOUSE/LEVEL never load proximity detail. Manual wheel zoom below 44 in canonical HOUSE/LEVEL switches to FREE, preserving cursor zoom and follow behavior.
- No change to world topology, route geometry, character scheduling, privacy policy, or media content. Two-room budget is a provisional low-end rendering choice, not an owner-approved visual limit.

## Executed tests
All commands use isolated XDG_DATA_HOME. Five canonical/follow tests passed on final modified source: test_canonical_lod_budget, test_canonical_render_contract, test_canonical_house_scene, test_canonical_public_interiors, test_cursor_zoom_v06. No SCRIPT ERROR in these five final runs. Canonical 65 sections visible (47 nonlift rooms +18 lift cells), 24 residents, detailed groups max 2, manual wheel FREE, no materialization on unchanged view, resident dictionaries unchanged by camera.
Shelf diagnostic: first library has 24 conditional decorations, 10 hidden because the real measured supports are assigned to books, 14 visible; measured book slots 10, total world book assignments 20. Updated render regression validates real occupied/free nodes, claim and cancellation, held book without assignment, then restores fixture. It also preserves earlier seat projection, missing-pose fallback, stale room fallback, depth test and guest facade roundtrip checks.
Legacy test_room_capacity_v06 passed with both review markers temporarily disabled and an explicitly procedural decor fixture (native owner-decor intentionally omitted only inside this old synthetic test). 49 module cells = 47 physical rooms, including one R3; HOUSE/LEVEL detailed count 0, ROOM count 3. Test skips canonical mode with an explicit message pointing at test_canonical_lod_budget. Both review markers restored afterward. Earlier failed attempts were due to counting cells as rooms and legacy always-mounted decor. This is not a claim of full legacy native-decor LOD coverage.

## Actual scene capture
4 frames, 1280x720, same capture harness and renderer as prior iteration, exit 0, CANONICAL_RENDER_CAPTURE_PASS.
| View | Previous | Current |
|---|---:|---:|
| HOUSE | 1680 | 1680 |
| Hearth | 491 | 406 |
| Study | 1331 | 522 |
| Library | 1069 | 1014 |
Draw calls are snapshot counts, not FPS. HOUSE PNG hashes identical (06df3e47c680e7a0389f9c3a45ddd21bc16b3375cdb002f6d37c3191230f7f19). Visually inspected study/hearth before/after: selected detailed room retains furnishings; adjacent rooms lose small decoration in favor of their overview models. Some sparse interiors, uniform lighting and relative dragon size remain unchanged; owner approval not claimed. Library capture generated but not visually reviewed separately in this iteration.
Evidence: iter22_before_after.jpg (left before/right after; study above/hearth below), SHA256 8a3f9a4e9af600270fc57b998e47724e30efe19755a5bfc8bf9c634de044e425. Capture log SHA256 56e43b4ea59821b93bbe3e6854a1538fc8120032a43ee2bcb71b24dbb0d38d1e. Full PNGs/logs in ephemeral Higgsfield workspace only; contact sheet persisted in Git.

## Open
HOUSE overview still 1680 draw calls; investigate static overview batching/material costs without replacing real silhouettes, reducing visibility or exposing private rooms. Library still relatively expensive. Verify moving/FOLLOW camera transitions for visible popping and seat contacts in neighbors, not just fixed captures. Actual social group feasibility and larger full-runtime regression sweep, full clean production import/export, Windows/macOS QA and hardware performance remain pending. Prior runtime tests were not all rerun here. No release acceptance.
