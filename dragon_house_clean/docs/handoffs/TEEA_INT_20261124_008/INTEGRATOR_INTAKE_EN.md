# TEEA008 integrator intake — 2026-11-24

Status: STAGING_VERIFIED / BINARY_LFS_TRANSFER_PENDING. Candidate only.
Source: 3e534fc84003878c80628519a3e7389ad922a56b. Integration baseline: ce429f0b9c907526ec31e50a8af6b3c3f30997df.
Independent verification: original ZIP SHA-256 matched; 209/209 dependencies verified; 45 model.gltf records; 4 material sets. Local materializer tested: dry run, apply, idempotent rerun, conflict rejection.

The source archive is private; its URL is deliberately not committed here. This repository is public and the connector does not expose a Git LFS object upload operation. Do not bypass .gitattributes, publish a private download link, or commit pointers without actual LFS objects. Use an authenticated git-lfs checkout of this integration branch to stage the authorized files with tools/stage_teea008.py. Check conflicts against any existing hydrated decor bank. A clean LFS checkout and runtime proof remain required.

Candidate placement review:
- Artifact/R1: measured shelf at (-1.4, .025, -1.68), commode at (1.35, .025, -1.62); explicitly bind artifact_cabinet and legacy artifact_pedestal station IDs to actual shelf/commode approaches. Preserve display-object IDs and home anchors; do not place a second baked pedestal.
- Workshop/R1: rack (-1.6, .025, -1.58), table (.68, .025, -1.33), stool (.68, .025, .07). The candidate station records include rack view and stool seating, not the existing pair of work stations. Rebind before replacing working geometry; preserve existing capacity.
- Common/R3: seven independently normalized furniture instances, two candidate mugs. Remove duplicate baked pieces only after actual station bindings, hearth clearance, support slots and camera proof. Preserve canonical mugs, no implicit ownership changes.
- Cinema/R1: screen at (0, .025, -1.7), sofa at (0, .025, .2), yaw 180 degrees. Rebind existing media surface and view seats; maintain separate TV/game use when applicable. Speakers optional; no invented columns or curtains.
- All 80 stations are candidates, not automatically promoted; small-artifact candidates remain theft_enabled=false. Miu remains a guest. No room topology modifications.

Existing successful Mac review build at run 45462819889, artifact 14954781353, precedes this intake. It is not a TEEA008 build.
