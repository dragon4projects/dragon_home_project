# I94 — stabilization checkpoint (2026-11-27)
Status: tested candidate, not final release. Cumulative I91-I94; base 9c748e7353f5d1c8c753f4e3a4ed6bc6104479c6.
Godot 4.7.2 Linux headless. Existing owner-review data and initial topology retained.
## Implemented
- Explicit private door protocol: default closed, separate open/quiet/standing invitation/knock/answer/revoke/leave state, owner-controlled adapter only, public frontage at actual door, private journal, no generic furniture/item/view access. Safe physical exit on revoke/close, backup recovery invalidates old permissions. Snapshot validation of visit identity and geometry. Synthetic tests do not grant actual owner permissions. UI/authority adapter not yet wired.
- Beverage pacing: 900 simulation seconds between autonomous visits after successful sip; ongoing sipping and resuming after pause preserve choice and contents. Failed autonomous route retry 60 seconds. Tuning, not owner-approved numeric law.
- Exact horizontal candidate waypoints instead of prematurely advancing within 25 mm; continuous swept geometry outside exempt passage bands.
- Transactional add-room operation with rollback on save failure, strict R1/R2/R3 size and noncolliding room ID. Separate generic common-room layout, no duplication of unique sleeping dragon or canonical cup IDs. Generic added-room bank still needs seven-depth qualification and full editing/placement UI.
## Evidence
- Initial regression 22/22 passed.
- Final fresh isolated regression 26/26 passed; test_i94_private_door, test_i94_beverage_pacing, test_i94_room_add_transaction, test_xz_topology_iter2 plus prior 22.
- Three 900s complete runs: original 6609 path calls/0 failures/0 stalled replans, drink intents 133928/201600; paced before final movement fix 1709 calls/190 failures/68 replans, drink intents 14250/201600; final 1396 calls/0 failures/60 replans, drink intents 7464/201600; 195977 checked positions, 328 boardings, lift peak 5/6, 45 checkpoints, tick p95 7578us. Different autonomous activity mixes; no target hardware FPS claim. Remaining traffic replans unresolved. Trace also identified 3 withheld cinema approaches; they remain withheld.
## Remaining release blockers
- 16/16 physical reader seats per library, distinct compatible rest poses; directional reading remains 10/16 distinct actor coverage. Additional authored sprites and actual seat fit, no substitution.
- Remaining legacy artifact reconciliation, editing/rehome, wardrobe stations and calibrated alternate outfits, compatible simultaneous activities, private invitation UI/authorized adapter, all new room variants seven-depth layout and editor validation.
- Re-run full integration after new assets; target Windows and macOS native export/runtime/performance. No new build or remote publish verified in I94. Use existing authenticated local publisher/intake and current remote base; do not reuse stale artifacts as final.
