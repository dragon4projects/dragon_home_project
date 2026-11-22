# Dragon House v0.4 — November Asset Acceptance and Modular Interiors

Date: 2026-11-22. Independent project only.
Repository: `dragon4projects/songs_panels`, branch `dragon-house-fallout-fresh`.
Target: Godot 4.7.2 Compatibility, Windows 10 x64 (primary), macOS 15 M1 (secondary).

## Phase 0 — Evidence received (DONE, source-limited)

The uploaded `NOV2026_ASSET_MIGRATION_REPORT.md` reports `PARTIAL_VERIFIED`, **not** completed publication.
Reported on the agent's local machine: 2,409 normalized files / 189,781,935 bytes; 2,408 images tested as Texture2D; 24 canonical identities; image-bank coverage for 21/24 residents; 17 technically playable HOME banks in a temporary isolated check; 8 historical master props recovered. Three residents (RES_22 Veya, RES_23 Khitrushka, RES_24 Yazvochka) still lack verified production image banks.

**None of those binary assets or the normalized runtime registry was delivered to this repository as of inspection**. The GitHub branch contained two report documents, but no `data/asset_registry_nov2026.json`. The agent reported `BLOCKED_GIT_CREDENTIALS`: private Git CLI and Git LFS authentication failed. Source report paths describe candidate rooms, not accepted layered interior art.

Do not confuse local copy, data QA, artistic approval, and runtime binding. The old Dragon House runtime and source trees are out of scope and must not be modified.

## Phase 1 — Physical asset intake (IMPLEMENTED SCRIPT; DELIVERY BLOCKED)

Run the standalone tool on a checkout of the independent project:

```bash
python3 tools/import_nov_assets.py --source /path/to/NOV2026_NORMALIZED.zip --project .
python3 tools/import_nov_assets.py --source /path/to/NOV2026_NORMALIZED.zip --project . --apply --report NOV2026_INTAKE_LOCAL.json
```

- Accept a source directory or ZIP with or without the `dragon_house_clean/` prefix.
- Require canonical registry for all 24 IDs, asset index, bank coverage and SHA256SUMS before copying.
- Check ZIP path traversal, symlinks, case-insensitive collisions, allowed asset paths/extensions, source hashes, unexpected replacement of existing files.
- Dry-run is the default. Application is per-file atomic, idempotent for byte-identical entries and rejects modification of existing different bytes.
- Archive and quarantine sources are **excluded by default**; `--include-archive` is an explicit optional local storage choice. Do not publish private owner-controlled art by default.
- Never run `git push` or mark `visual_bank_ready=true` automatically. This script is a *local acceptance gate*, not proof of publication or artist approval.
- No auth token belongs in manifests, logs or chat. LFS upload must be performed only after the local operator restores secure GitHub CLI credentials; alternatively supply the normalized ZIP through a connected accessible file location.

**Current gate:** the user's report alone cannot supply image bytes. Do not claim 2,409 imported assets yet.

## Phase 2 — Modular room visuals (IMPLEMENTED ARCHITECTURE)

Godot code now has a controlled layered shell per R1/R2/R3 group and an original-art manifest:

`data/interior_layers_v1.json` → `scripts/interior_skin.gd`.

Rendering order/depth contract, camera at positive Z:

| Role | Relative Z | Purpose |
|---|---:|---|
| backdrop | -1.79 | stone rear art |
| back_decor | -1.63 | library shelves, mounted objects |
| furniture_back | -1.37 | furniture behind residents |
| resident gait/traffic | actual waypoint Z | persons, pet, props |
| foreground | +1.63 | near-side furniture/occluders |
| front_trim | +1.91 | front floor lip/arch |
| light_overlay | +1.96 | sparse transparent light |

Layer paths must be `assets/rooms/<room_type>/R<width>/*.(png|webp|jpg|jpeg)`, resolve to existing files, have role/width validation and `approved=true`. Duplicate roles, path traversal, missing images and private interiors are rejected. On absence of approved art the game shows temporary geometry rather than a fake "finished interior."

Each R1/R2/R3 room merges its shell without destroying logical room IDs. Private rooms display only facade/door; owner interior is not instantiated. The public hallway can pass in front of their doors.

**Still needed:** approved R1/R2/R3 backgrounds, proper depth mask anchors, per-room art direction review, and documented owner permissions. The source report explicitly recorded zero fully verified layered interiors.

## Phase 3 — Camera/readability (IMPLEMENTED, QA visual)

- Removed overlapping floating resident name labels: names and intent are available via selected/follow HUD.
- Room labels are limited to overview, positioned above roof. Selection outline spans merged group.
- Contextual controls help is collapsed by default to reduce obstruction.
- Generated original low-cost basalt, floor and wood QA textures to replace repetitive diagonal black streaks. Their source recipe is `tools/make_qa_textures.py`. They are **not** approved final interiors.
- Added tiny front-edge rock occluders and separate named background/structural/foreground/approved-art nodes.

## Phase 4 — Resident preview (IMPLEMENTED, not approved)

`asset_bank_resolver.gd` now distinguishes:
- **verified_bank:** exact profile + required PASS frames + real files + explicit `visual_bank_ready=true`.
- **candidate_bank:** exact profile + required PASS frames + real files, without claiming final approval.
- **preferred_wardrobe:** HOME → CITY → SHORT, using only fully verified by default.
- **QA preview:** press `V` to temporarily display candidate PASS banks with a visible `QA-ПРОСМОТР` label. Press again to restore approved-only display.
- Dormant residents remain dormant; no missing human identity is fabricated or silently promoted.

In final migration status, even confirmed 17 HOME candidate banks remain QA preview until a runtime+human identity check authorizes final bindings.

## Phase 5 — Tests (PASS)

- `tests/test_import_nov_assets.py`: ZIP dry-run/apply/repeat + conflict + traversal.
- `tests/test_interior_layers.gd`: depth, R3 art path, private fail closed, duplicate/invalid layer excluded.
- `tests/test_asset_binding.gd`: profile identity check, path safety, candidate vs approved separation.
- Previously working: model, cutaway R3, camera construction, XYZ lift locomotion, social pairing, books, AV, backup persistence.

Testing uses official Godot 4.7.2 headless + Xvfb/llvmpipe for rendering. **Not** real Dell Latitude 5300 or M1 measurements.

## Phase 6 — Follow-up gates (PENDING)

1. Receive ZIP bytes / secure LFS push from the agent.
2. Verify archive and manifests in a new checkout; run Godot resource import (target 2,408 images) without touching old runtime.
3. Run `V` QA preview and visually inspect all 21 known-profile banks, attention to 3 missing names and EVM clothing states.
4. Integrate real verified room R1/R2/R3 art into the room manifest, separate back/mid/front; confirm authored alpha, perspective and owner permissions.
5. Build, play-test and benchmark **on physical Win10 Dell / macOS M1** before claiming hardware suitability.
6. Release bundles only when current commit's source and binary asset hashes match.

No Bethesda/Fallout Shelter copyrighted imagery/code may enter the project; the game is a perspective/camera/room-building reference only.
