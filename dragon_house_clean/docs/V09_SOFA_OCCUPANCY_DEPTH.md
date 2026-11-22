# Dragon House v0.9 — Real Sofa Occupancy, Legacy Save Repair and Cutaway Depth

Date: 2026-11-22 • Source branch `dragon-house-fallout-fresh` • Godot 4.7.2.

## Trigger and scope

The owner ran v0.6 on Windows and reported that residents still overlapped when visually sitting on one furniture place, and that room perspective lacked depth. This release addresses **mechanics and physical geometry**, while Teea and Znaechka author the independently commissioned **photorealistic** interior and sprite art.

No changes to the legacy Dragon House repository, no AI integrations, and no external events controlling life.

## 1. Furniture-backed stations (not arbitrary room spots)

- `room_stations.layout(room)` is now semantically typed. Each place has: stable index, local (x,z) offset, `kind` (`seat`, `floor_rest`, `work`, `standing`) and `furniture_id` when it belongs to an existing, physically rendered object.
- The actual existing sofas in Common module x=−1 (`SOFA_COMMON_MIDDLE`) and x=0 (`SOFA_COMMON_RIGHT`) have **two** exclusive seats each. Rest lounge sofa, cinema sofa, workbenches and library desk points have individually modeled coordinates. At the hearth (x=−2) the two floor-rest points are **skins**, not fictitious sofas.
- An R3 Common still offers 30 unique physical gathering positions across three modules. **Only four sofa seats exist** in its current procedural geometry; 30 gathering positions do not mean 30 chairs.
- `single(world, actor, room, intent)` prioritizes an appropriate seat/work position where present. When the seats are occupied, a third REST actor gets a different standing position rather than playing a seated animation on the same furniture.
- `pair(...)` prefers two adjacent available seats of the same depth, then safe same-row standing positions if all seats are in use; no same-slot pair assignments. Fallback positions are explicitly labeled as non-seats.
- All kinds and furniture links are stored as primitive actor fields in the world snapshot. Private room fronts are traversable but **not** valid public seating destinations, even if someone is the named room owner (private interiors remain unrendered).

## 2. Migration from a v0.6 save

Older snapshots may already contain two or three active residents at precisely the same sofa coordinates and no reservation fields.

- On loading a saved world, `room_stations.reconcile()` repairs stale claims and reconstructs per-place identity. **It also rebases the actual resident body XYZ location (if already performing) or the final station waypoint (if traveling) for v0.7–v0.8 snapshots whose numeric slot IDs survived but old generic coordinates did not match the newly modeled sofa.**
- `room_stations.migrate_legacy_positions()` migrates currently **performing** residents to a unique valid position in their existing public room before the first world render. A resident whose old room is full does not get assigned an occupied seat.
- For old **traveling** residents, the last station waypoint is rebased to an available real point and future movement follows that route. The actor remains traveling; no teleportation is required.
- This is a targeted render-position/state migration, not an assertion that a user-approved character or private identity is present in the home.

## 3. Sofa approach and visual posture

- `room_locomotion.build_waypoints()` now routes to each specific sofa seat via an approach along the public aisle; the final movement to the seat does not cut diagonally through adjacent sofas.
- `main.gd.desired_actor_animation()` requests `RELAXED_SIT` or `SLEEP` only when the activity is actually happening at a reserved `seat`. Otherwise it requests `IDLE_S`; a standing resident does not visually claim to be seated.
- Missing or unapproved photographic sit frames are **not fabricated**: the existing asset resolver falls back to permitted idle imagery. Seat geometry and canonical actor sprite approval remain independent.

## 4. Physical room depth (still interim geometry)

- Added `Stage_CutawayDepth` to public rooms: underlit depth lines in the floor, a true front floor lip/returns and additional physically recessed rear wall trim.
- At close zoom, camera gets a gentle extra ~6.6-degree oblique angle, smoothly fading to elevation/side-cutaway view on the whole-house overview. Manual Q/E rotation still works.
- Physically real Z-positioned geometry is added without changing the already-commissioned layer role/depth contract in `interior_skin.gd`.
- **This is not a finished photorealistic interior**. Teea's real room layer assets are still needed. Likewise no caricature/cartoon sprite is promoted to final art.

## 5. Test evidence

- `tests/test_sofa_seating_v09.gd`: two REST actors take different ends of the same physical sofa, third does not sit on it, paths approach from the aisle, stage depth exists only in public rooms, private door is still denied, **v0.6 triple-overlap and v0.7 preserved-slot/obsolete-coordinate snapshots both repaired immediately**, legacy travel endpoint corrected, closer camera yaw adds depth.
- `tests/test_room_stations_v07.gd`: reverified all 30 gathering spots and updated expected depth corridor bounds to include new physical front/back lane positions.
- Every previous Godot test retained (camera, room merge, build, locomotion, social pair, media, JSON snapshot, actual LFS sprite anchor, privacy, UI and 49-cell LOD).
- Local Godot 4.7.2 sandbox: **19 Godot tests and 2 Python QA tests PASS**. Virtual OpenGL cutaway screenshot rendered without script errors. Full-LFS GitHub CI must pass separately before binaries can be called accepted.

## 6. What remains

- **Visible sitting** requires authentic photorealistic sitting sprite frames in the wardrobe banks; technical seat assignment does not invent them.
- Natural pedestrian separation during transit through narrow corridors is not fully collision-solved; this iteration fixes end positions and avoids diagonal shortcuts to a sofa.
- Seating coordinates are derived from *current procedural* furniture. When a new Teea room image has different physical furniture, its seat anchor metadata must be mapped and checked before final activation.
- Dell Latitude 5300 Windows 10 and Apple M1 8 GB actual FPS/memory remain unbenchmarked.
