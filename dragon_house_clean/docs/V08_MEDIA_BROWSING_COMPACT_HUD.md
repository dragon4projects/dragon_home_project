# Dragon House v0.8 — Truthful Media Browsing and Compact Observation HUD

Date: 2026-11-22. Fresh independent Godot 4.7.2 project.
Source branch: dragon4projects/songs_panels / dragon-house-fallout-fresh.

## Implemented

- Residents can now **browse** a documented book catalog in the Library, inspect a film listing in the Cinema, or select a music listing in the Music room, without the simulation pretending that the physical book or a locally playable media file exists.
- New distinct autonomous activities: BROWSE_BOOK_CATALOG, BROWSE_FILMS, BROWSE_AUDIO. Each is available only when that catalog category has actual imported entries. Actual READ_BOOK, WATCH_FILM and LISTEN_MUSIC remain gated to verified physical books or supported on-disk playable media bytes.
- A browsing resident selects one real catalog entry ID, occupies a reserved physical station from v0.7 and saves reference-only browsing_item_id/browsing_category. No imaginary book ownership, playback, watching or reading-progress credits.
- Artist sprite states use VIEW/idle for catalog browsing rather than a falsely depicted active media file.
- Fixed media UI bug: the message 'physical book not confirmed' was appended before the selected title and immediately overwritten. It is now retained. Nullable author does not display as the string Null.
- Left debug HUD is compact by default to protect the room view. '☰ Меню' or Tab expands full controls and status; both camera modes and the media dialog remain usable when collapsed. A short overview label remains visible. No need to permanently cover one third of the screen.

## Tests

- tests/test_catalog_browsing_v08.gd: 1 metadata-only book, 1 unplayable film, 1 absent audio file produce browsing actions but NOT READ/WATCH/LISTEN, do not borrow or credit a physical book; catalog UI explicitly identifies missing files.
- tests/test_compact_hud_v08.gd: startup compact, Tab toggles, camera modes keep HUD state, media panel works independently.
- v0.7 station reservation tests and all earlier room, sprite, privacy, persistence, camera and media tests retained.
- Local independent Higgsfield Godot v4.7.2: 18 Godot scripts + 2 Python tests PASS (20 total). Virtual Mesa screenshot inspected: left side is visibly less obstructed.
- GitHub Actions should separately import the real November private Git LFS corpus, rerun tests and package Windows/macOS. No performance claim on actual 8 GB target machines.

## Asset agents

No room art or character production files are modified. Teea and Znaechka may work on their photorealistic private branches. Their candidate files require separate visual review and exact manifest approvals, not automatic promotion.

## Honest limitations

- Browsing a listing is not equivalent to physically reading, watching or listening; the UI and journals maintain that distinction.
- The preview/cover slicing and media-art registry from future art batches are not yet imported. No covers are fabricated.
- Photography-grade layered public-room art is still pending Teea's review; three resident identity banks are pending Znaechka.
