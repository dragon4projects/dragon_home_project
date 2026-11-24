# Iteration 2 pre-decor integration checkpoint — 2026-11-24

Status: PARTIAL_CODE_READY / QA_NOT_RUN. Not a release or owner acceptance.

Base: 611a83d53a650ea16f50a624d6484d857aff71d8 (owner decor branch).
Selected object-event logic from 41b37351cd9250ceb0f6b73efdab568d24513a47.
Integration commits: ecbdda15921440657d859281c37ea60f2a7b4116, 3232704a5e069e178c2791ea63347e4f364678cb, ec23509dbafa2ff16da086f91061afd0a6b6f1b5 and this commit.

Implemented in source: X/Z object homes, wall-display separate XYZ metadata, owner reassignment, small-artifact ambient restriction, simulation-day returns, additive catalog import, explicit runtime object import, viewer categories and visible concrete-media/owned-creature inspection; station claims are invalidated on layout changes without moving actor coordinates.

No topology edits, production merge, new art, or TEEA008 binaries. No Godot execution in this environment: engine unavailable, GitHub clone DNS failure. Existing object-branch CI is not proof for this integrated branch. Expanded workflow tests are queued as source, not executed evidence.

Still open: integrated runtime regression and Mac export; verified furnishing of new R1/R2/R3 rooms using existing assets; geometric footprint/approach/collision, guest behavior and camera checks; final TEEA008 model/placement/media-holder intake; real shelf/book/container placement and full final visual QA. Media inspection uses actual activity record on visible actor until final media surfaces are integrated. Book return uses room-level home rather than final measured shelf anchor.

Do not mark iteration 2 complete before these gates are verified. Do not use previous CI green to certify new changes.
