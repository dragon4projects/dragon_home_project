# Дом Дракона — чистая независимая реализация

Godot **4.7.2** / GDScript / Windows 10 primary, macOS 15 Apple Silicon secondary.
This is a new project, **not a patch** of the separate existing House.

The structural interaction target is **Fallout Shelter**: a 2.5D perspective cutaway with connected room modules, visually merged adjacent spaces, zoom to room detail, camera yaw/pan, entity selection, smooth following across levels, and depth-aware placement. It uses original/properly licensed art only — no Bethesda art or code.

## Current vertical slice

- 21 structural room modules over three levels with stable room IDs.
- 3-wide contiguous Common reads as one open space, rather than three fully separated boxes.
- Real perspective camera, wheel zoom, right-mouse pan, Q/E yaw, click-select and F-to-follow Manka; Follow survives zoom changes.
- Build mode (B or button) with adjacency constraints, occupied-cell rejection, persistent expansion, and color-coded preview.
- Separate simulation planner: needs/daypart/preferences/habits -> purposeful room destinations -> graph pathing -> performing activities. No LLM or external world-event integration.
- 24 canonical resident **slots**; 8 known names represented by temporary visual test silhouettes and 16 intentionally hidden until identities/approved visual banks are imported. Manka is her own roaming actor.
- Private spaces render as a door only; unauthorized camera/actor route stops at threshold.
- Library, cinema and audio room geometry/stations are present; JSON media manifest import exists. Physical-book borrowing, unique holder/location, progress and persistent 24-hour abandoned-return rules are implemented. Empty catalog stays empty rather than inventing songs, films or books.
- Persistent JSON world snapshot. Current phase is a proof slice, not a release.

## Run

Open `project.godot` in Godot 4.7.2 Standard and press **F6/F5** (main scene is configured).
From command line:
`godot --path . --editor --headless --quit`
`godot --path . --headless --script res://tests/test_model.gd`

Windows uses the Compatibility renderer by default to reduce GPU requirements; macOS M1 is a separate untested target.

## Controls

Mouse wheel: zoom. Right-mouse drag: pan. Q/E: camera yaw. Left click: select a character/room. F: follow Manka. B: build mode. Choose type in left panel and click a free neighboring cell. Escape or 1: whole-house view. 2: room view. Import catalog button: choose a local JSON file.

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

This is a structural prototype. It does **not** yet include finalized 24 resident art banks, movie/music playback, complete shelf UI, fine-grained seat reservations, collision-aware furniture navigation, full per-actor inventory, procedural rocks, user-approved private interiors, cross-platform performance evidence or a finished export. No external chat/AI bridge is planned for this new project. Follow/zoom/room building and autonomous scheduling are first implementation targets.

## Source-grounded architecture notes

See `docs/DESIGN.md` and `docs/BEHAVIOR.md`. Reference investigation: the project's September 2026 Fallout Shelter 2.6.0 APK/OBB analyses of authored room prefab width/upgrade variants, local XYZ paths, impostor far views and smooth follow controllers. Study architecture principles; never redistribute extracted proprietary assets.

