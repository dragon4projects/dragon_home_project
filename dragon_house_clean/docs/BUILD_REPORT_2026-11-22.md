# Independent Dragon House — Build / QA report
Date: 2026-11-22. All states relate exclusively to the **new** repository branch.

## Verified source
- Branch: `dragon4projects/songs_panels:dragon-house-fallout-fresh`
- Project subdirectory: `dragon_house_clean/`
- Godot: **4.7.2.stable.official.ed1daf0bf**; Standard GDScript, Compatibility renderer.
- Old Dragon House runtime/repository was **not modified**.
- Fallout Shelter: studied September APK/OBB reference analyses; no protected art or source code copied.

## Source and visual truth
- 21 connected structural room modules, 3 level bands; real lift path, build mode, same-type side-wall merging.
- 24 canonical identity/profile records, 8 QA silhouettes + Manka displayed. No new identity invented.
- Manka art prototype generated separately; validated in-engine sprite bank still needed.
- House shell/furniture in current build are **QA blockout**; not visually production accepted. Room/occupant art still materially below the Fallout Shelter matching target.
- Books/films/tracks only appear as real catalog records after explicit import. The included demonstrator is synthetic and visibly marked QA.
- Native Theora video was observed playing in a Godot video widget in xvfb/llvmpipe, and WAV load passed. Physical device sound hardware is untested.

## Automated test evidence (Higgsfield Linux x86_64)
- `tests/test_model.gd`: adjacency, privacy fail-closed, cross-level graph route, autonomous decisions.
- `tests/test_locomotion.gd`: door/aisle/station waypoints, lift-only vertical path, physical XYZ motion to upper floor.
- `tests/test_social.gd`: actual reciprocal two-person social pairing.
- `tests/test_media.gd`: physical book uniqueness, progress, 24h forgotten-item lifecycle and disk persistence.
- `tests/test_av.gd`: WAV + OGV paths decode/load, unsupported MP4 rejected.
- `tests/test_snapshot.gd`: recovery from corrupted main snapshot via prior backup.
- `tests/screenshot_room.gd` and `tests/screenshot_media.gd`: actual rendered screenshots (virtual X11, Mesa llvmpipe).

## Export evidence
- Windows Desktop x86_64: release `.exe + .pck` emitted using Godot 4.7.2 official release templates.
- macOS: universal Apple Silicon/Intel zip emitted using Godot 4.7.2 templates, **unsigned/not notarized**.
- Neither artifact has been executed on the user's Dell Latitude 5300 Windows 10 or M1/macOS 15.
- Therefore real FPS, RAM, input response and Gatekeeper behavior on target devices are **NOT TESTED**.

## Next high-impact gaps
1. Import real approved avatar frame banks rather than showing QA silhouettes.
2. Replace primitive rooms with original cutaway art and perspective-layer compositing.
3. Full room width variant art/upgrade variants, animated camera occlusion, lift animations.
4. Bedroom/private-room owner data only with verified permissions.
5. Media previews from accepted real source lists; direct TV in-room video; source-controlled library inventory.
6. 30-person Common seating/reservation, real furniture collision and performance soak.
