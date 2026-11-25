# RC visual follow-up: support projection audit

Status: implementation, independent data audit; engine test execution pending.

Source baseline: fb68f85f1d066cd37177c2243465746976e25a6d. Scope: TEEA008 base room layout manifest, social variant replacements, Sketchfab common additions, library/gallery additions, media/work additions, guest display additions, conditional shelf dressing. This is a manifest-level audit (37 variant keys including derived centaur R2, 390 instance rows before imperative hearth overrides). It is not an assertion that every asset or rendered scene has passed visual QA.

146 references to furniture hosts (including conditional decor slots); all 146 host IDs resolved within their variants. Using the measured AABBs and slot heights, all 146 were within a 25 mm tolerance on the host footprint and support plane. Existing independent visual depth transformation, however, left 143 of 146 item origins displaced by more than 10 mm compared to their host's projection, 121 by more than 50 mm, worst 226.5 mm (library/R3 upper shelf volumes).

Fix: transform a supported object's room-space origin by the host's depth factor and pivot; use its own uniform model scale times the same host depth factor. Do not apply host model scale or rotation a second time. Identical function for detail and overview model mounts. Free-standing items and wall mounts retain their original projection. This matches the existing live book, cup and artifact support formulas. No canonical topology, owner-assigned homes, privacy, or source model data is modified.

Regression: canonical public interiors test checks every resolved support reference across runtime layout keys, comparing position and scale with the host formula. Actual imported meshes, shelf openings, transparency, camera/LOD and screenshots still require engine QA. Source shelf clearance is a proposed measured envelope, not a visual approval.

No GitHub Actions dispatch in this pass.
