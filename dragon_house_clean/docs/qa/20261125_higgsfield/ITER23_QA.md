# Iteration 4.23 — room-local static overview batching

Baseline main 47a5d0aff41999ade34ec22fa80a797bd8f50b2f. Executed in the existing hydrated Higgsfield Linux Godot 4.7.2/Xvfb/llvmpipe test workspace. Actual runtime assets retained; same temporary import exclusions as ITER22_QA.md. No CI, no hardware exports.

## Implementation
scripts/static_overview_batch.gd operates only on actual canonical overview furniture roots, never across rooms. Exact compatible mesh/material resources are instanced with MultiMesh; compatible small single-surface opaque ArrayMeshes without imported LOD chains are merged with SurfaceTool under a 24,000-vertex chunk limit (4,000 per source). It excludes transparent materials, animated wrappers, conditional dressing, micro-detail, skinned/blend-shape meshes, overlays, triplanar/billboard materials, custom attributes for merges, and nonpositive/nonuniform transforms. Original nodes and meshes remain named but hidden; detailed furniture, measured stations, routes and room visibility are unchanged. The runtime environment switch DRAGON_QA_DISABLE_OVERVIEW_BATCH=1 allows comparison/rollback without editing assets. No private room overview root is created. Guest facade rebuild discards that room's batches. Retaining source nodes trades memory for traceability and reversibility; actual memory/triangle and frame-time effects not yet measured. MultiMesh may select LOD/culling collectively, so not a claim of identical draw behavior across all camera positions.

## Executed tests
Final source hashes checked against repository blobs. All four real Godot tests exited 0: test_static_overview_batch (169 sources, 74 batches, 95 saved, visibility and privacy roundtrip), test_canonical_lod_budget (65 visible sections, max two detailed interiors), test_canonical_render_contract (seat projection, depth, guest privacy, conditional book claims), test_canonical_house_scene (24 residents, sleeping dragon and six visible levels). Real 4-frame capture exited 0 with CANONICAL_RENDER_CAPTURE_PASS, no script errors. Early experiment used nonexistent ArrayMesh.surface_get_lods; corrected to RenderingServer.mesh_get_surface and verified real run; erroneous experiment not committed.

## Capture comparison
Same 1280x720 capture and renderer as ITER22.
| View | Previous draw calls | Current draw calls | Fraction of pixels changed |
|---|---:|---:|---:|
| HOUSE |1680|1585|0.03103%|
| Hearth |406|402|0.09494%|
| Study |522|445|0.00586%|
| Library |1014|1012|0.07813%|

HOUSE mean absolute RGB channel error 0.00302/255; 0.01302% of pixels have any channel delta >8. Not pixel-identical. Visually inspected HOUSE before/after comparison, no evident geometry loss at that scale. Other three compared numerically but not individually inspected in this iteration. Draw-call counts are not FPS or hardware performance.
Evidence: iter23_house_comparison.jpg (top before, bottom after), SHA256 3b7bc557b63e02acd8247d1f5860df463094ecd01786b096670375185541900a. Visual log SHA256 9dd3832810398c38958a3bae25baf52ba1954759803f0f66885ab11a92257189. Full PNGs/logs remain in ephemeral workspace.

## Next
Further HOUSE optimization should profile actual static shell and material costs; avoid sacrificing visible furnishings or access boundaries. Library remains expensive. Prioritize visual contact and group feasibility in actual authored geometry, including moving FOLLOW/seat transitions; then full regression/export and target hardware profiling. No owner approval/release acceptance.
