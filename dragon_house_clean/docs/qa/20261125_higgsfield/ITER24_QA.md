# Iteration 4.24 — measured social floor clusters

Baseline 3c1320e1c2c62ea60fe060175be9e0a2f8dcbccd. Executed in hydrated Higgsfield Linux Godot 4.7.2/Xvfb/llvmpipe QA workspace, same temporary import exclusions as ITER22/23. No GitHub Actions.

## Findings and changes
The previous greedy row-first sampling used up the station capacity before finding standing circles. On the actual canonical furniture layout, pair claims succeeded in both lounges, hearth and kitchen, but only the kitchen supported groups 3–6. The kitchen was already eligible through the canonical planner extension; the new planner gate checks actual compatible free geometry rather than free-slot count.

Preserve authored furniture approaches, then prioritize a compact mutually clear cluster selected from a bounded grid of up to 48 points. Retain capacity, spacing and collision rules. Remaining ordinary standing spots follow. The group claim search is reused for planning feasibility. In measured layouts group members must stand at z<=0.75, keeping the z=1.50 connector aisle clear of group stations. No room, furniture, access, physical station capacity or asset changes. New grid ordering may invalidate old standing anchors; stable IDs and existing reconciliation handle cancellation/replanning, not teleportation. Search is bounded greedy, not proof of maximum possible capacity. Hearth still has no accepted group configuration; do not claim group availability there.

Actual final empty-station QA: ROOM_0020 rest 3–4; ROOM_0026 rest 3–5; ROOM_0027 common pairs only; ROOM_0036 kitchen 3–6. Occupied stations excluded. 37 selected group claims independently sampled from both connector entries.

## Executed tests
All seven final-source tests exit 0 with PASS: test_canonical_group_geometry, test_group_session_recovery, test_group_departure_recovery, test_group_late_join, test_pair_session_recovery, test_social_facing_fatigue, test_teea008_nav. Navigation 33 variants, 292 stations, 584 route segments, 57400 live samples, 836 path calls, 0 failures. Guest mobility test passes. This is not a full regression sweep.

## Real visual evidence
iter24_group.jpg, SHA256 c7e0222179e4aadbc3752154ceb45bb98accf5d727d9be376c6a9a83cb259f35. Real engine capture 1280x720, compressed to 1100px wide for Git. Active session deliberately staged at six real claimed stations with actual character sprites and directional idle selection. No natural autonomous assembly claim. Visual inspection: six figures separated on floor, inward-facing directions plausible, furniture preserved. Flat idle poses and some spacing/lighting remain provisional. Visual log SHA256 d8c281b92c816768d260f5647598f1147f053cddd8418f465f72cfc44db1e66f. Full image and logs in ephemeral sandbox. No seated pose, cup hand or moving FOLLOW acceptance in this iteration.

## Next
Run real seated/contact QA captures with existing calibrated poses, then moving FOLLOW/LOD transitions and cup/book hand contact. Check autonomous gathering and old standing-station save migrations. Hearth group geometry may require later approved furniture layout work. Full production import/export, target hardware performance and owner approval remain pending.
