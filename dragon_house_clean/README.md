# Дом Дракона — самостоятельная реализация v0.4

Godot **4.7.2** / GDScript / Windows 10 primary, macOS 15 Apple Silicon secondary.
This is a new project, **not a patch** of the separate existing House.

The structural interaction target is **Fallout Shelter**: a 2.5D perspective cutaway with connected room modules, visually merged adjacent spaces, zoom to room detail, camera yaw/pan, entity selection, smooth following across levels, and depth-aware placement. It uses original/properly licensed art only — no Bethesda art or code.

## Current vertical slice

- 21 structural room modules over three levels with stable room IDs.
- **True cutaway R1/R2/R3 groups:** same-type connected modules share one continuous floor, wall, roof and label, with stable logical cell IDs; a fourth module is rejected.
- Real perspective camera, wheel zoom, right-mouse pan, bounded Q/E yaw, R3-aware room selection outline, actor follow with deadzone across lift levels; Follow survives zoom changes.
- Build mode (B or button) with public-corridor adjacency, occupied-cell rejection, R3 merge cap, persistent expansion, and color-coded preview.
- Separate simulation planner: needs/daypart/preferences/habits -> purposeful room destinations -> graph pathing -> performing activities. No LLM or external world-event integration.
- 24 documented resident identities + appearance profiles, retained in `data/resident_profiles.json`; 8 QA-only test silhouettes are currently visible and 16 characters remain asset-gated. All 24 names are documented, but the 24 validated production sprite banks have not been imported. Manka is her own roaming actor.
- Private spaces render as a **door only**. Residents may cross their **public frontage corridor** without being allowed to enter the room. Targeting private interiors still fails closed.
- Library, cinema and audio room geometry/stations are present; JSON media manifest import exists. [M] opens a data-backed catalog browser and user-controlled playback for local MP3/OGG/WAV and Ogg/Theora OGV. Physical-book borrowing, unique holder/location, progress and persistent 24-hour abandoned-return rules are implemented. Empty catalog stays empty rather than inventing songs, films or books.
- Persistent JSON world snapshot with verified scratch-file swap and fallback backup. Native Windows x64 and unsigned macOS Universal exports were generated for the previous v0.2 revision; **rebuild export after v0.3 changes**. This remains an early vertical slice, not a production release.

## Run

Open `project.godot` in Godot 4.7.2 Standard and press **F6/F5** (main scene is configured).
From command line:
`godot --path . --editor --headless --quit`
`godot --path . --headless --script res://tests/test_model.gd`

Windows uses the Compatibility renderer by default to reduce GPU requirements; macOS M1 is a separate untested target.

## Controls

Mouse wheel: zoom. Right-mouse drag: pan (cancels Follow). Q/E: bounded camera yaw. Left click: select a character/room. F: follow Manka with a deadzone, crossing floors via the lift. B: build mode. M: media viewer/player. J: action journal. Choose room type in left panel and click a free neighboring cell. Escape or 1: whole-house view. 2: room view. Import catalog button: choose a local JSON file. `data/media_catalog_demo.json` is a **test-only** catalogue with a generated sine WAV and generated Theora clip; it is not Dragon's favourites.

## Media manifest format

```json
{
  "schema": 1,
  "books": [{"id": "book:example", "title": "Verified book title", "author": "..." }],
  "films": [{"id": "film:example", "title": "Verified film title", "file_path": "..." }],
  "tracks": [{"id": "track:example", "title": "Verified track title", "file_path": "..."}]
}
```
Never treat these example IDs as canonical media entries.

## Current limitations (explicit)

This is a structural prototype. It does **not** yet include finalized 24 resident art banks, MP4 in-engine playback, a 3D TV-screen video viewport, complete shelf UI, fine-grained seat reservations, collision-aware furniture navigation, full per-actor inventory, procedural rocks, user-approved private interiors, cross-platform performance evidence or a production-ready export. No external chat/AI bridge is planned for this new project. Follow/zoom/room building and autonomous scheduling are first implementation targets.

## Source-grounded architecture notes

See `docs/DESIGN.md`, `docs/BEHAVIOR.md` and `docs/BUILD_REPORT_2026-11-22.md`. Reference investigation: the project's September 2026 Fallout Shelter 2.6.0 APK/OBB analyses of authored room prefab width/upgrade variants, local XYZ paths, impostor far views and smooth follow controllers. Study architecture principles; never redistribute extracted proprietary assets.



## November asset-agent integration (v0.3)

The local migration agent delivers an **independent verified candidate registry** at \`data/asset_registry_nov2026.json\` and images under \`assets/residents/RES_XX/wardrobes/HOME|CITY|SHORT/STATE/frame.png\`.

\`scripts/asset_bank_resolver.gd\` now consumes that registry **read-only** and binds the \`HOME\` visual bank for an already-active resident **only if**:
- the claimed appearance profile exactly matches \`data/resident_profiles.json\`;
- the registry sets \`visual_bank_ready=true\`;
- \`IDLE_S\`, \`WALK_LEFT\`, \`WALK_RIGHT\` all report \`PASS\`, have valid frame counts and real files;
- all paths remain inside the expected resident + wardrobe root.

Additional available \`READ\`, \`TALK\`, \`REST\`, \`SLEEP\`, \`DRINK\` states are selected according to action, with safe idle fallback if absent. **No dormant residents are activated just because art has arrived**. The 8 current QA silhouettes will convert to verified banks automatically on the next launch when compatible art exists. Assets, approvals, ownership and autonomy remain separate.

The local agent may push new asset/manifests on the same branch; runtime development must **fetch its branch updates and avoid overwriting imported art**. This v0.3 code modifies only \`scripts/\`, \`tests/\`, \`docs/\` and project metadata, not asset directories.

## More tests

\`godot --headless --path . --script res://tests/test_cutaway_groups.gd\`

\`godot --headless --path . --script res://tests/test_camera_construction.gd\`

\`godot --headless --path . --script res://tests/test_asset_binding.gd\`

\`xvfb-run ... godot --path . --script res://tests/benchmark_render.gd\`

See \`docs/V03_CUTAWAY_ASSET_BINDING_QA.md\` for coverage and limitations.

## v0.4 — acceptance and layered interiors

- Read `docs/V04_ASSET_ACCEPTANCE_AND_INTERIORS.md` before importing the local agent's November files. The 2026-11-22 report lists 2,409 locally checked assets but remote binary publication is still blocked.
- Local ZIP intake (dry-run by default): `python3 tools/import_nov_assets.py --source /path/to/normalized.zip --project .`. Add `--apply` after reviewing.
- `data/interior_layers_v1.json` is the strict width-specific approved room skin manifest (currently empty). The room renderer supports 6 authored Z-depth layer roles and private-room refusal.
- Floating resident labels are hidden to avoid overlap; overview displays roof labels. Help is collapsed.
- [V] toggles explicit *QA candidate avatar preview* when the asset agent delivers technically PASS frames but `visual_bank_ready` is still false. These are not approved for final use.
- `tools/make_qa_textures.py` produces original **placeholder-only** stone/floor/wood noise textures; not final artwork.
- Tests: `python3 tests/test_import_nov_assets.py`; Godot `tests/test_interior_layers.gd` and `tests/test_asset_binding.gd`, along with existing movement/privacy/camera tests.
