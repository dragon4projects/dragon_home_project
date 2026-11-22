# Dragon House v0.10 — Data-driven furniture interactions and streamed interior art

**Date:** 2026-11-22  
**Repository / branch:** \`dragon4projects/songs_panels\` / \`dragon-house-fallout-fresh\`  
**Engine:** Godot 4.7.2 Compatibility, Windows 10 Dell Latitude 5300 8GB primary; macOS 15 Apple M1 8GB secondary.  
**Scope:** Mechanics and renderer only. No changes to the legacy Dragon House and no automatic artist approval.

## 1. Why the change was necessary

Version 0.9 prevented two people from receiving the same sofa seat, but the sofa stations were coded directly in \`room_stations.gd\`. When Teea's new photorealistic interiors arrive, their furniture may not be in exactly the same positions. If the art and gameplay coordinates are not reviewed as one contract, an actor will sit on empty air or walk through an upholstered object. Rendering both the old procedural sofa and a new \`furniture_back\` image produces a doubled sofa.

## 2. Implemented

- \`data/furniture_interactions_v1.json\` defines the original **physical** furniture positions, independent of any sprite or room art file. This is *not* a human identity approval document.
- \`scripts/interaction_anchor_registry.gd\` validates the JSON strictly before using it: allowed public room types only; valid IDs/roles/pose hints, numeric ranges and bounds, non-duplicate station IDs and physical spacing. \`private\` remains excluded, including private rooms owned by an active resident.
- Each authoring anchor has \`id\` (stable across saves), \`kind\` (\`seat\`/\`floor_rest\`/\`work\`/\`standing\`), \`x\`, \`z\`, \`furniture_id\`, \`pose_hint\`, \`approach_z\`. Coordinates are local **to a 4.8-unit room cell**, x positive right, z negative behind the actors. The logical room identity remains a separate stable ID.
- Named scene nodes are now created for existing physical props: \`SOFA_COMMON_MIDDLE\`, \`SOFA_COMMON_GENERIC\`, \`SOFA_REST\`, \`SOFA_CINEMA\`, \`TABLE_LIBRARY\`, \`DESK_STUDY\`, \`DESK_MUSIC\`, \`BENCH_WORKSHOP\`, \`FIREPLACE_SKINS\`. The 17 authored station references in the seeded world have a corresponding scene node when detail is materialized near the camera.
- World snapshots now carry \`station_anchor_id\`, \`station_pose_hint\`, \`station_approach_z\` in addition to existing slot and furniture IDs. When approved furniture moves/reorders within the same room profile, \`reconcile()\` remaps the persisted actor to the same stable anchor ID instead of a now-incorrect numeric index. Existing v0.6–v0.9 saves without anchor IDs remain supported by index and legacy migration.
- Route waypoints use the per-anchor \`approach_z\` (rather than an assumed global seat approach depth). Resident pose for REST is chosen from the physical anchor's \`pose_hint\` **only when an actual seat is held**. Unapproved/missing sitting sprite frames continue to fall back to permitted idle art.
- \`main.gd\` now **streams approved room artwork near the camera**: it mounts the author-approved back/mid/foreground Sprite3D layers when the public room is close, then releases sprites when the camera leaves. The \`interior_skin.gd\` texture cache is bounded to 6 entries rather than 32 to reduce memory pressure.
- If an approved \`furniture_back\` role is present for the full public room, the near-camera procedural furniture mesh is not drawn again. The interaction contract still spawns **invisible named anchors** for resident placement. The \`Layer_OverviewCues\` lightweight geometry remains on the distant HOUSE view, and private rooms have no interior art or stations.

## 3. Tests

- \`test_furniture_contract_v10.gd\`: valid baseline data, named real scene props for every seeded physical anchor, stable-ID remapping after future reorder, bad private/oversized/duplicate proposals rejected, candidate inspection does not change live physics.
- \`test_lazy_room_art_v10.gd\`: synthetic **QA-only** furniture image loaded via the existing approved art loader in an isolated test scene; validates on-demand room art, **no duplicated mesh sofa**, remote eviction and re-entry without duplicate sprites, private door remains closed. The synthetic image is deleted after the test.
- All previous room topology, build, social, catalog, privacy, animation, sofa, save migration, large-house memory scaling and LFS integration tests are retained.
- Synthetic local Godot test and independent GitHub LFS/Windows/macOS build evidence must be reported separately. This is not a benchmark on the owner's actual laptop/Mac.

## 4. Authoring handoff to Teea and Znaechka (machine-readable addendum)

**Teea / interiors:** Do not modify or replace \`data/furniture_interactions_v1.json\` or \`data/interior_layers_v1.json\` on your own. Instead supply \`data/asset_proposals/<BATCH_ID>_furniture_anchors.json\` as a candidate containing \`schema:1\`, \`room_profiles\` dictionary and \`cell_overrides\` dictionary with only public-room types and the same anchor fields. Use the baseline JSON to understand coordinates and reuse stable \`id\` values for the same seat/work position. Provide a separate, **private** before/after contact sheet showing the actual physical furniture center, actor pelvis/feet and approach aisle. For an added/removal/reposition, document old and new anchor IDs, whether existing residents must relocate, and an explicit owner sign-off request. A candidate is never installed simply because it passes JSON validation.

**Znaechka / character poses:** Never infer that a \`seat\` implies a \`RELAXED_SIT\` animation is artist-approved. Add photorealistic wardrobe-specific motion frames following the *existing* \`RES_XX/wardrobes/HOME|CITY|SHORT/<STATE>/0001.png\` pattern, plus measured feet anchor and identity QA. Test the motion against the known \`SOFA_*\` coordinates at ROOM zoom. If the animation is missing, stand-in/idle remains; do not create cartoon, chibi, folk-art, or puppet-looking interim art.

**Approved art completeness:** For any R1/R2/R3 variant, \`furniture_back\` must be a coherent complete replacement for the procedural furnishing of that whole room before ChatGPT marks it \`approved:true\`. A partial furniture image may be QA-reviewed, but must not be promoted yet: otherwise the runtime deliberately hides all procedural room furniture to prevent double objects. Supply \`backdrop\`, \`back_decor\`, \`furniture_back\`, \`foreground\`, \`front_trim\`, \`light_overlay\` in the exact role/path structure documented in \`interior_skin.gd\`. All new artwork must be **photorealistic**. No copied Fallout Shelter or Bethesda images.

**Candidate format example:**

\`\`\`json
{
  "schema": 1,
  "room_profiles": {
    "rest": [
      {
        "id": "rest_left",
        "x": -0.85,
        "z": -0.39,
        "kind": "seat",
        "furniture_id": "SOFA_REST",
        "pose_hint": "RELAXED_SIT",
        "approach_z": 0.95
      }
    ]
  },
  "cell_overrides": {}
}
\`\`\`

The example is **not** a complete replacement for the live manifest; it is a proposed change to be reviewed and merged. Real production must include all active seats, plus correct per-cell mappings. Valid candidate JSON is **not** approval for gameplay or art. \`check_candidate_patch()\` returns \`approved:false\` and \`integrated:false\` even when validation succeeds.

## 5. Remaining limitations

- The current runtime still uses procedural, non-photorealistic interim geometry. Teea's photorealistic room images are not yet delivered/approved. 
- Correct walking around one another in crowded corridors requires a separate, higher-level local avoidance mechanism. This release does **not** claim to solve it.
- Native seated movement needs Znaechka's identity-matched, photorealistic sitting animation states. A correct seat position is not an animated sitting person.
- Final QA on Windows 10 Dell Latitude 5300 and macOS M1 8GB remains to be performed by the owner; cloud Linux tests cannot prove hardware FPS or VRAM use.

