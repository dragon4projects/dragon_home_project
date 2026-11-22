# Dragon House v0.5 — November LFS acceptance and integration

Date: 2026-11-22. Independent Godot 4.7.2 project only.
Repository: dragon4projects/songs_panels, branch dragon-house-fallout-fresh.

## Source verification

The revised uploaded migration report states that the local agent successfully published 2,408 Git LFS objects and verified 2,409 SHA-256 records in a fresh clone at commit 786003bacfe5fa4e33fa16f3c350d32f5d39765f.

I independently checked the GitHub branch HEAD, the full 1.4 MB asset_registry_nov2026.json and sample real LFS pointers in the Git tree. Registry coverage: 24 canonical IDs, technical IDLE_S/WALK_LEFT/WALK_RIGHT frames in at least one wardrobe for 21/24 residents, seven PASS Manka states, eight historically restored master artifacts, nine Poly Haven CC0 texture albedos and exactly 76 METADATA_ONLY book records. No accepted layered room interiors. All resident visual_bank_ready flags remain false as intended.

The connected GitHub adapter can read the large JSON manifest but exposes PNGs only as LFS pointers. The independent Higgsfield sandbox is not authorized to download private LFS bytes. Therefore remote LFS existence and the worker's hash verification are supported; my own complete-byte acceptance awaits the CI checkout with lfs:true.

## Plan and implementation ledger

A. Verify current branch, registry, canonical names, LFS pointers: DONE.
B. Bind original resident frames without changing identities: IMPLEMENTED. Match exact appearance_profile, frame state and path. Choose registry default_wardrobe first, then HOME, CITY, SHORT.
C. Review all resident banks: IMPLEMENTED. [K] opens an all-24 gallery with wardrobes/states and preview animation, including dormant residents without activating their life.
D. Respect artistic consent: IMPLEMENTED. [V] is explicit QA preview in the living House, while visual_bank_ready remains false. No silent final approval.
E. Manka: IMPLEMENTED. Her idle, walk left/right and rest technical frames are read from the new registry in [V] QA mode.
F. Historic artifacts and drinks: IMPLEMENTED. Original master references stay intact. Smaller catalog previews are instanced in public Artifact Gallery and Common, never inside unauthorized private rooms.
G. CC0 materials: IMPLEMENTED. Real source-licensed rock/wood albedos are preferred over placeholder textures if LFS bytes exist; reused shared materials.
H. Catalog: IMPLEMENTED. Exactly 76 confirmed cloud book titles enter the media catalog as metadata, not physically owned books; reading/borrowing without an actual copy remains prohibited.
I. Prove actual LFS bytes: PASSED. Private GitHub Actions run 45042303230 audited 2,409 SHA-256 entries, 2,347 resident-frame references, 68 EVM-extra frames, 21 full candidate banks, 7 Manka states, 8 historical masters and 76 cloud titles. Stage cannot be marked DONE until a remote job passes.
J. Godot 4.7.2 engine test after checkout with full LFS: PASSED in run 45042303230. Godot import and full scene/world/media tests all green.
K. True R1/R2/R3 layered rooms: BLOCKED. The migration agent reports ZERO approved full layered interiors; user/owner approval or new art is necessary.
L. Windows Dell 5300 / M1 8 GB performance: NOT TESTED ON ACTUAL HARDWARE.
M. Owner-only contact sheet of reference vs current sprites and LFS-backed Win/Mac QA binaries: WORKFLOW IMPLEMENTED; awaiting artifact-producing run.

## Implementation contracts

Source of truth for identities and approved/technical status is data/asset_registry_nov2026.json. No source automatically turns a dormant resident into an autonomous resident. Veya, Khitrushka and Yazvochka remain without verified production banks.

Books imported via world_model.merge_reference_book_metadata have physical=false and catalog_only=true. media_runtime.available_books() and borrow() do not treat them as real items. No cover art or film/audio previews are fabricated.

Art gallery displays historical master-derived previews when present. Room shell continues using the separate cutaway layers and stable room IDs. Private room interiors remain owner-gated and do not appear in the world renderer.

tools/ci_lfs_asset_audit.py checks decoded image magic headers (not Git pointers), exact resident IDs, allowed paths, state frame existence, original-master SHA-256 and SHA256SUMS. The repository root .github/workflows/dragon-house-lfs.yml checks out LFS, runs the audit, imports Godot 4.7.2 textures and runs the test suite. This workflow is a verification mechanism; publishing it does not itself prove a green run.

## Follow-up after green CI

1. Review every imported actor face, clothing branch and feet anchor at room zoom; approve art per identity.
2. Review Manka visually, including body proportions and walk animation; do not confuse technical PASS with canonical approval.
3. Build real public cutaway R1/R2/R3 room images with back/mid/front compositing from approved originals and new art; preserve private doors.
4. Export complete binaries from the proven LFS checkout and smoke-test Windows 10 Dell Latitude 5300 and macOS 15 M1 8 GB.

Do not edit the old Dragon House repository or use Bethesda copyright art assets. Fallout Shelter is a mechanics, camera and topology reference, not a source of distributable graphics.


## Green acceptance evidence (private repository)

Completed workflow run: https://github.com/dragon4projects/songs_panels/actions/runs/45042303230

Godot 4.7.2 resource import succeeded using actual Git LFS bytes from the private branch. All 13 Godot runtime/script tests in the workflow passed, plus the Python intake regression test. The QA audit reports LFS_BYTES_VERIFIED_QA_ONLY, complete_candidate_banks=21, approved_resident_banks=0, historical_master_sha256_pass=8, sha256_files_verified=2409, frame_references_verified=2347, evm_legacy_extra_frames_verified=68 and media_books_metadata_only=76. This is technical acceptance only; not user approval of faces, outfits or room art.

The reviewed current workflow also prepares a *private-only* contact sheet and full-LFS Windows/Mac export archives. These are not treated as completed until the next run actually emits artifacts. No actor or owner privacy permission is changed.
