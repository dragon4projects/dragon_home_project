# Higgsfield sandbox Godot QA — 2026-11-25

Status: PARTIAL_RUNTIME_QA; not owner approval, not a release candidate acceptance.

## Environment / reproducibility

- Source main at test start: 31607b48c7cfdd4c840fd63a0f7934df2f1dadeb.
- Linux x86_64, official Godot 4.7.2.stable.official.ed1daf0bf; 1 CPU, 8 GiB RAM, Mesa llvmpipe compatibility renderer via Xvfb.
- Real sparse checkout of dragon_house_clean; all 5330 LFS paths hydrated (zero remaining pointers); TEEA005/006/007 and closure ZIPs validated by the repository hydration script, which generated the review overlay.
- Initial --editor --quit scan was not a successful resource import; it produced no imported resources and complained about Blender. Full --import was started and interrupted for time. For actual visual run, moved nine .blend authoring sources outside the disposable project copy; left corresponding runtime GLB files. Added local-only .gdignore to residents and creatures to avoid bulk image conversion; the asset resolver reads raw PNG/WebP bytes. Ran Godot --headless --path . --import: exit 0, 5361 cached files (includes earlier partial import), no ERROR/SCRIPT ERROR/Parse Error in the final import log. No export claim.
- Fresh isolated XDG_DATA_HOME for tests/visuals. No real user save or private door text exported. No GitHub Actions.
- Six stale assertions/fixtures corrected and rerun: float comparison after JSON roundtrip, two SQLite crash fixtures (mandatory initial snapshot retained, subsequent changes only in event journal), pair session journal vs removed debug string, actual 1.50 m connector vs obsolete generic aisle, content viewer only Close control (no source/play buttons). All runtime code in tested checkout is the baseline; these six edits are tests only.

## Final successful test runs (41 distinct test scripts)

First batch (13): test_book_possession_recovery, test_group_late_join, test_group_departure_recovery, test_group_session_recovery, test_pair_session_recovery, test_carrier_reconciliation, test_private_cinema_merge, test_event_recovery_revision, test_world_recovery_guard, test_canonical_lift_capacity, test_reading_lifecycle, test_shared_media_attendance, test_rolling_housekeeping.
Corrected and rerun: test_social_facing_fatigue.
Second batch (8): test_filmix_bundle, test_cinema_timed_sessions, test_music_timed_sessions, test_canonical_house_architecture, test_canonical_route_index, test_teea008_nav, test_life_scheduler_v019, test_life_due_wake_integration_v019.
SQLite and gate (9): test_object_event_default_sqlite_v021, test_object_event_sqlite_v021 (corrected fixture), test_object_event_sqlite_recovery_v021, test_object_event_sqlite_canonical_loss_v021, test_object_event_sqlite_backup_warning_v021 (corrected fixture), test_object_event_json_to_sqlite_v021, test_object_event_projection_rebuild_v021, test_object_event_snapshot_to_sqlite_v021, test_object_event_gate_v020.
Legacy/model (6): test_model, test_snapshot, test_social (corrected), test_room_stations_v07, test_locomotion (corrected), test_xz_topology_iter2.
Canonical actual imported scene (4): test_canonical_social_interiors, test_canonical_house_scene, test_canonical_hearth_interior, test_canonical_public_interiors (corrected).

Measured output: 6 floors, 90 cells, 47 nonlift rooms, 18 lift cells, 3 shafts, 24 homes; actual scene 65 room records, 24 residents, all camera modes visible, sleeping dragon present. 148 directed edges and 1430 route parity cases. TEEA nav 33 variants, 292 slots, 584 entry routes, 57400 sampled positions, 888 path calls, 0 failures. Six lift slots and seventh waits, reload and legacy drain. Filmix 187 cards/187 verified cached posters. Public interiors 12 rooms, 126 approach checks, 5 physical media carriers, 156 supported projections. Social interiors 4 rooms, 10 registered cups. Hearth 3 islands, 10 measured approaches, 20 entry paths, 2 cups, 12 blockers.

## Open regressions (not passed)

- test_room_capacity_v06: fails at line 21, old synthetic 49-cell expectation; executed with canonical architecture marker and therefore not a valid legacy-mode fixture. Separate explicit legacy-mode rerun and canonical bounded-LOD test needed. Do not change fixed topology to satisfy old count.
- test_canonical_render_contract: fails at line 106 expecting first conditional library decoration to be visible. The populated book catalogue may already reserve that support; investigate actual reservation and test both occupied/free slots before changing the renderer. Not established as fixture-only or product defect.
- All tests not listed remain unexecuted for this turn. No Windows/macOS export or hardware FPS measurements.

## Real rendering

capture_canonical_house.gd exit 0, CANONICAL_RENDER_CAPTURE_PASS, 16 1280x720 PNG screenshots generated in the actual TEEA008 LIVE scene (logs show navigation, roster, life, scene, ready; no SCRIPT ERROR/ERROR).
Draw calls per capture: HOUSE 1680, kitchen 624, lounge upper 426, lounge lower 391, hearth 491, centaur 108, vampire 85, Miu 93, cinema 518, cinema upper 358, music 352, study 1331, workshop 857, gallery 585, library upper 966, library 1069. These are screenshot-time counts, NOT hardware FPS or load-time proof.

Visually inspected actual HOUSE + hearth/kitchen/lounge upper/library contact sheet. All floors visible, room labels, doors and many furnishings present; no fallback-only scene. Interior visual quality NOT approved: sparse furniture in several spaces, dark and uniform illumination/weak material separation, sleeping dragon looks relatively small beside the bright oversized portal, some silhouettes appear to overlap furniture or stand at suspicious heights. Need close-up contact verification before declaring actual floating. HOUSE has high draw-call count: budget/LOD optimization required on target hardware, keeping visible all floors. Remaining 11 captures generated, not individually visually inspected.

Evidence stored here: house.jpg (SHA256 91d38bbc9bd55f9da55ee90873b2f001aba2aa1d2fdaf23b660b55361963ef0d), room_contact_sheet.jpg (SHA256 c57f4c278e5cf2707379bc5f579b48b09c56434df62e384dc482051973e1448c). Compressed from actual engine frames; no generative images. Import log SHA256 828126afb4245acd7f5fa2000a5e55495e3d49e4fad7dbb913e2b0c3f0ec503e. Visual run log SHA256 c215f8944f76126c35cbae756bd68ef6d31baf3bd69b22e9cd3991ea05a03e00. Logs and all 16 full PNG captures remain in the current Higgsfield QA workspace /home/user/dragon_qa (ephemeral); only these two reviewed image derivatives and this report are persisted in Git here.

Next: resolve conditional dressing and canonical LOD regressions, measure social station feasibility in actual layout, inspect remaining 11 images, validate directional social art and seating/contact at close zoom, perform full production import/export with real assets on target platforms. Repeat full tests with no temporary visual import optimizations before release.
