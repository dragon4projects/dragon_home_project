# Hearth room — interior iteration 1

Owner accepted architecture visually and asked to proceed to furnishing. Parent 57cf858e7d572b18002cc8cb102f6de9e1318eb4; lift/pass-through CI separate and still pending at the time of branching.

Common/R3 only: 14.4 m wide × 3.6 m playable depth, fixed connectors and shell. Three distinct furnishing islands: left coffee/conversation (service table and machine, two-seat sofa, chair in middle depth, low mug table); central hearth/rest (animated fire, fur, added measured chair); right dragon nook (two-seat sofa, chair moved toward middle depth, round chess table, woven rug, fur beside dragon). Existing sleeping dragon increased from 1.05 m to 1.575 m long provisionally, no animation/AI/pickup. No new outside assets. Cup and chess support positions and IDs untouched. Additional warm near-detail lights; duplicate procedural Common sconces suppressed. The existing scenery lightwell remains.

Independent JS numeric inspection before commit: 10 authored station approaches clear with 0.325 m radius; all fixed AABBs inside room and pairwise non-overlapping; entire front line z=1.5 clear on 0.1 m samples. Runtime revision changed to trigger existing save replan mechanism for affected routes and physical positions, not a topology migration. Exact visual pose quality, light, contact and performance need actual Godot render review. No target OS build yet. Owner screenshots show sprite-head clipping and a nearly invisible actor in workshop; logged separately, no unsupported claim of fix.

Dedicated Godot test checks all 10 measured approaches from both connectors, no overlapping fixed furniture, real model mounts near/far, cup position stability and actual registered stations. 
