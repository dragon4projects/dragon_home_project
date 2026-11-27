# I91 — local authoring and measured library capacity
Base public branch: integration/sprite-complete-20261126, commit 9c748e7353f5d1c8c753f4e3a4ed6bc6104479c6.
Scope: code/data only. No LFS assets, topology, public/main or owner save changes. The existing dense service QA flag enables the SHA-bound book overlay when present.
## Baseline observed on real I90 scene
- 76 catalog books, 40 physical/assigned; two libraries 20 shelf positions each.
- 187 film/series records; 698 track records (not a claim that all are autonomous eligible).
- 12/10 seat candidates in the two libraries; three cinema stations remain withheld.
- Old JSON import registered three test media records but failed to retain sibling previews.
- Frame assignment encoded a new PNG, with no original/type/title persistence.
- Existing artifact image assignment already preserved original bytes in measured S/M/L grid.
## Implemented
- LocalMediaCatalogImport: owner-selected JSON; books/films/tracks or audio alias. Strict title/stable ID and metadata validation, optional explicit source-backed durations/series tables, no real AV playback. Relative named sibling PNG/JPEG/WebP and optional TXT/MD (book), content-addressed exact masters and separate max512 thumbnails. Reject ID conflicts, unsafe paths, unavailable slots; duplicate same metadata no-op. New books catalog-only unless explicit measured room + slot supplied. Mutable holder/progress fields never accepted from manifest. Media and object imports use separate manifests. Batch limits 2000 rows, 4 MiB manifest, 128 MiB attachments.
- Content viewer opens verified full original and text. Existing cinema surface manual assignment accepts verified local preview. Actual dense-layout device aperture mounting/active previews still pending.
- Dense wall holder: explicit painting/poster type and owner title (filename fallback), immutable master, thumb, atomic per-slot JSON, legacy assignment remains as fallback when no record. Existing image original not reconstructed. Full original verified on click. Aspect conserved and hover title cached on mounted frame. Explicit re-home/removal/version UI and bulk import still pending.
- Book geometry measured on 4 existing wooden_bookshelf_worn meshes, actual vertical triangle intersection across scaled book footprint with clearance and other AABB obstacles; both entry approaches checked. Old slot IDs preserved; measured Y may be refined. Manifest binds source + 3 compiled partitions + service overlay SHA; no partition changes. 60 + 65 slots, 125 total, old 40 all qualified. Canonical 76 books balanced 38/38, free positions remain. Existing assignments retained before promoting previously catalog-only books.
## Evidence (Godot 4.7.2 Linux headless, isolated XDG)
- iter91_baseline.log exit0 (audit of original I90)
- iter91_media_unit1.log and iter91_media_unit2.log exit0: four fixtures (book, film, series, track), original JPEG + TXT/MD after source removal, exact bytes/512 derivative, duplicate no-op, whole-manifest invalid preflight, identity conflict, bad shelf rejection, durations, separate process restart.
- iter91_dense_content1.log and iter91_dense_content2.log exit0: six categories through actual scene entry points; source JPEG/PNG/WebP removed, physical frame aspect, title/type, exact full master and cube viewer after restart.
- iter91_book_supports.log exit0: 25+35 and 30+35 supports; all 40 legacy supports qualified.
- iter91_books_migrate1.log and iter91_books_migrate2.log exit0 on isolated copy of the pre-overlay world: 76 actual canonical volumes, 38+38, preserve all 40 prior assignments. New explicit book import into free measured support; actual path/move to shelf, pickup-before-arrival rejected, reading seat arrival, 40 seconds reading, return, persisted progress after restart.
- iter91_chair_planes.log exit0: read-only ray grid of 4 missing chair models plus unrepaired blendkit_sofa. This is evidence of geometry, not seating approval. Unrepaired sofa has discontinuous ray hits; evaluate repaired mesh or substitute within same footprint. No new seats enabled by this iteration.
## Residual blockers
- Complete 16 seats per library with measured pelvis/feet/route + actor/wardrobe compatible pose; I90 64 candidate contacts only, 175 delivered pose estimates not equivalent to full seating approval.
- Real dense media device mounting and interaction, read/write-friendly authoring UI for JSON catalog + physical book home selection; no EPUB/PDF parser or AV playback. Existing legacy generic object JSON path has legacy wall anchors; direct cube/frame authoring is the supported verified dense path. Bulk artwork, explicit re-home, clear, version UI still pending. No old owner-save migration certification.
- Remaining decor/hearth/cinema, artifact re-pack/migration, autonomous drink choice/contact, target platform performance, long soak/clean export. No production release or new platform export in I91.
- Repo write forbidden (403) on the public connector, so this is a verified local patch, not a remote commit.
