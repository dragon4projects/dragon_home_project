# Canonical architecture traffic hardening — staged follow-up

Base: f7f9b3d42d17cda2b15376843ae7b3f4eccc2245. Isolated branch; current runtime-and-export workflow on the base is not interrupted.

Confirmed by source inspection: TEEA008 traffic _safe_room returned true whenever no candidate furniture layout existed. Canonical private R1, lift and other empty volumes therefore had no detour bounds, and a non-owner could step behind a private frontage during avoidance. This change constrains canonical local movement to the physical X/Z shell, constrains non-owner movement to z>=1.35 on public frontage, and permits monotone depth-only egress if access was revoked behind a door. Horizontal connector crossings still use the existing authored crossing path. Legacy review mode remains unchanged.

New focused Godot test asserts owner access, outsider frontage, egress, room bounds and an opposing pedestrian case. Not run yet. The guard deliberately does not promise head-on passing in a 0.30 m frontage lane. Queue / yielding and shared lift admission are separate unresolved runtime contracts; do not promote this isolated candidate as release until the base runtime evidence and focused test are checked.
