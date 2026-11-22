# Dragon House v0.7 — Physical Station Reservations

Date: 2026-11-22. New independent Godot 4.7.2 project only. Branch: dragon-house-fallout-fresh.

## Implemented mechanics

- scripts/room_stations.gd reserves unique physical (x,z) stations for active residents inside public room modules. Claims are simple actor-owned JSON fields: station_room_id, station_slot, station_point; no hidden server or external event source.
- Per-module capacities: Common 10; Library 4; Rest 5; Study 4; Workshop 4; Cinema 8; Music 6; Artifact 6; Arrival 4; Corridor 2; Lift 0. A contiguous Common R3 has 30 different **gathering positions**, not 30 physically modeled chairs.
- The life scheduler filters candidate rooms by available stations. It reserves a location before borrowing a real book. When a room is full, it does not assign duplicate positions.
- TALK_PAIR reserves two adjacent positions at the same depth level, checks both actors and routes, and then commits both schedules together. The journal records an arrangement to meet rather than claiming a dialogue already happened.
- room_locomotion.gd accepts an exact station override as the final waypoint of a world route; actual lift and private-frontage route constraints are preserved.
- On snapshot load, room_stations.reconcile() removes invalid, duplicate or stale reservations. The scene HUD reports used/total activity stations for the selected complete R1/R2/R3 room group.
- Dormant residents stay dormant. Manka remains a separate active creature. There is no AI or external event influence.

## Test proof

The local official Godot 4.7.2 test tests/test_room_stations_v07.gd passed: 30 unique Common R3 spots, 31st rejected, released slot reusable, private threshold not used as a public destination, actual social pair spatial adjacency, duplicate snapshot repair, and JSON serialization. 16 Godot script tests and 2 Python QA tests passed in the Higgsfield Linux sandbox.

## Honest boundaries

Station occupancy fixes overlap at activity endpoints, not every collision between moving pedestrians in a narrow corridor. There are currently 30 positions for a gathering, not 30 seats/chairs. Furniture interaction and visible sitting postures require review with the photorealistic interior layers. Physical Dell Latitude 5300 and Apple M1 8GB performance has not been measured. New character art is still QA-only until owner review.
