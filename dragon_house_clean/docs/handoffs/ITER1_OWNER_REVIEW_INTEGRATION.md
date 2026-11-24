# Dragon House Iteration 1 owner-review integration

Status: **IMPLEMENTATION BRANCH / NOT OWNER APPROVED**

Branch: `integration/dragon-house-iter1-owner-review`

Pinned sources:
- production base: `1216e2f1a737008e3d9fea0f5d240d54a78a6ea2`
- staged v0.22 intake: `488ed009adab7b0a27989534c8fad7a55e3ead94`
- TEEA006 canonical source: `887e5f1c874c7fb0deb600c58c06ad4e5dafb90f`
- TEEA007 closure: `996950493cc1e703abefc3659a13177160caa8d0`

Review rules:
- candidate art remains `approved=false / owner_approved=false`;
- accepted production room art is not overwritten;
- review uses `user://dragon_house_iter1_owner_review.json`;
- TEEA006 runtime assets are hydrated from immutable ZIP SHA-256 `5ae489046eefb6dc3718f2334945bb6fc7786dc59fc0758060e7f7e1d010e275`;
- TEEA007 base runtime assets are hydrated from immutable ZIP SHA-256 `05f734b2af745a062a4942653834e38149b10301c9bb035b4682ae7004a78cbb`;
- TEEA007 closure addendum SHA-256 `abc63bc791fb5bd90e08dcc57bf9447df68385373675fec2ecd4a928f562292b` is verified as closure evidence;
- the TEEA007 base payload contains runtime room art for Vampire Girl and Miu, but no `guest_centaur` room art. Centaur therefore retains procedural room fallback for this review; no replacement interior is invented;
- three guests are frozen candidates with autonomy disabled;
- media surfaces remain unbound unless an explicit binding exists;
- Shurshun uses delivered `npc_cat_black_hero` and owner `RES_03` per owner decision;
- unknown pet ownership remains unknown.

The original TEEA007 runtime contract is retained rather than rewritten. Its embedded TEEA006 payload digest reflects the later TEEA006 packaging lineage; this integration explicitly pins live review geometry to the owner/current-project canonical TEEA006 commit and immutable ZIP above. The seam is recorded, not silently normalized.

## TEEA006 station-source seam

The Git-tracked TEEA006 furniture-anchor candidate at the pinned commit is not valid JSON: the blob itself contains a literal truncation marker inside `non_station_furniture`. The same historical corruption is present in related 004/005 anchor exports. The integrator must not infer or reconstruct missing station coordinates from prose.

Owner-review hydration therefore searches the immutable TEEA006 ZIP for a valid machine source that is simultaneously `schema=3`, `approved=false`, `owner_approved=false`, and contains exactly 31 measured stations. If such a source is present, its 31 stations are applied. If no such source exists, the build keeps the existing production station registry unchanged and records `station_source_gap=true` / `stations_applied=0`. The build may still be used for visual owner review, but station integration is not considered closed in that fallback case.

