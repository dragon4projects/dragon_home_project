# Iteration 43 — SQLite projection delta
Date 2026-11-26. Base f07d61eca686cda70ff86ce9a070b81d311cc8d7; code/test head 7668af9e965dd2412a73cca7c1a3f3a9ad4c6ec1. All four changed blobs matched tested sandbox files. No topology, assets, catalogue, private-content, checkpoint cadence, CI or export changes.

## Implementation
SQLite keeps a detached cache of the last committed derived object projection. On normal append, compute exact changed/removed rows by comparing complete supplied projection against cache, not trusting event-advertised object ID. Update only changed rows (INSERT OR REPLACE) and delete only removed IDs within the same canonical event transaction; publish cache only after successful commit. Full sync still used when cache unknown, during explicit rebuild and import. On setup cache primed only after runtime authoritative replay matches persisted derived table, or after successful rebuild. Close invalidates cache. Single-writer assumption unchanged; external concurrent derived-table tampering during live execution is not supported. Failed transaction leaves previously committed in-memory projection/event sequence unchanged, store retains fail-stop write status. WAL FULL, synchronous backup on each accepted transaction, canonical marker and checkpoint rules unchanged. Stage timings stored in transient runtime fields only.

## Matched A/B
Godot 4.7.2 hydrated Higgsfield Linux, same iteration-41 600s QA save cloned to separate XDG roots. 731 initial events including QA object, 24 physical objects, 80 additional changes, 10 checkpoints. Same new store code with full projection forced vs delta enabled; this is not a direct timing comparison to an unmodified prior binary. Both exit 0, exact event prefix, projection, sequence and reload.
Full -> delta:
- writes 1920 -> 80 (one per event).
- projection p50 4739 -> 76 us; p95 4878 -> 85 us.
- plan p95 1 -> 563 us; cache p95 1111 -> 27 us.
- commit p95 3100 -> 616 us.
- complete append p50 37531 -> 31882 us; p95 41121 -> 40108 us; max 51455 -> 56868 us.
- backup p50 23063 -> 23052 us; p95 24176 -> 24860 us. Dominant remaining store stage.
- save p95 83251 -> 82134 us; 10 samples only. Snapshot size equal 1114553 bytes.
No claim of meaningful total tail latency improvement: p95 difference small, max increased, host variance. No target hardware or FPS proof.

## Verification
test_sqlite_projection_delta uses SQL triggers to prohibit unrelated row rewrites and inject target write failure; actual rollback verified for events, rows, cache, revision and world projection, followed by restart and successful new write. Initial fixture exposed missing cache prime on valid replay, corrected and rerun PASS. Expected injected SQL error is not a test failure.
11 regression tests exit 0: projection delta, SQLite, default SQLite, JSON->SQLite, snapshot->SQLite, projection rebuild, backup warning, canonical loss, SQLite recovery, event recovery revision, snapshot digest rotation.
6 real SIGKILL scenarios exit 0: checkpoint, view completion and combined checkpoint recovery, each SQLite intact primary and corrupted primary/backup. Combined group/film/book/partial drink/lift/RNG preserved. Actual power loss untested. Logs /home/user/dragon_qa/iter43_ab_{full,delta}.log, /home/user/.bg/d0e6cdf5.log.
Next investigate whether SQLite backup cost can be reduced with equal recovery guarantees (do not batch/drop backup silently); profile snapshot serialization and validation separately. Then controlled autonomous day/evening media and social coverage, missing pose assets and visual contact, hardware/clean exports. No new visual changes.
