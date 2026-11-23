# Dragon House v0.13 — corridor passing

**Status:** CI candidate  
**Branch:** `dev/dragon-house-v013-corridor-passing`  
**Base:** owner/CI accepted v0.12  
**Engine:** Godot 4.7.2 Compatibility

## Problem

Residents previously followed exact room/door/aisle waypoints but had no local
avoidance while travelling. Two residents walking toward each other could occupy
nearly the same world point and visually pass through one another. Residents
moving in the same direction could also step through the person immediately in
front.

A full physics crowd solver is unnecessary for the small Shelter-style cutaway
and would be undesirable on the 8 GB Dell target.

## Implementation

The authored route remains unchanged. Local avoidance only modifies the
**transient movement target** while the actor is on public walking waypoints:

- `leave_station`
- `room_center`
- `approach_public_frontage`
- `door_out`
- `door_in`

It never modifies:
- station coordinates,
- furniture anchors,
- save data,
- lift targets,
- private-room access rules.

### Opposing traffic

When two active travelling residents on the same level approach each other:

- avoidance begins within 1.85 m;
- each gets a shallow temporary Z lane (±0.34 m);
- near the crossing point, stable resident-ID order gives deterministic
  right-of-way;
- the yielding resident pauses briefly instead of intersecting the other body;
- both converge back to the exact authored aisle afterwards.

### Same-direction traffic

If a resident is less than 0.58 m behind another traveller moving in the same
direction, the rear resident yields for the current movement tick. Movement
resumes automatically when the gap reopens.

This produces no persistent lane state and no new save-schema fields.

## Regression

`tests/test_corridor_passing_v013.gd`

The test explicitly drives two residents through the same aisle in opposite
directions and then in the same direction.

Current local Godot 4.7.2 result:

`CORRIDOR_PASSING_V013_PASS min_distance=0.501 lane_sep=0.512 following=yield_resume`

Locked acceptance thresholds:
- minimum centre-to-centre distance >= 0.42 m;
- visible passing-lane separation >= 0.45 m;
- both residents return to authored Z after the pass;
- rear same-direction resident yields and resumes.

Regression pack also passes:
- `LOCOMOTION_TEST_PASS path=11 waypoints=31 lift=1`
- `SOCIAL_PAIR_TEST_PASS`
- `SOFA_SEATING_V09_PASS`
- `DRAGON_V011_ROOM_DISTRIBUTION_PASS`
- `DRAGON_HOUSE_MODEL_TEST_PASS`

## Performance intent

This is an O(active travelling residents²) local check over the small active
resident set, with early rejection by phase, level, X distance and Z distance.
No NavigationServer, RigidBody or continuous collision world is introduced.

The final acceptance remains the full repository LFS/Godot/Windows/macOS CI.
