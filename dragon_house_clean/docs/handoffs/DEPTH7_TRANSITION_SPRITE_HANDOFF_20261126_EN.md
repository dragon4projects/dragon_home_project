# Transition sprite delivery — pending authored art
Use `data/asset_proposals/DH_SPRITE_TRANSITION_REQUIREMENTS_20261126.json` as the
first-pass worklist, not as evidence that images already exist. Each row specifies
the approved/reviewed wardrobe, standing image and measured destination pose.
Do not use a single idle/seat image as a transition or duplicate frames.
Generate 4 intermediate poses between standing and seated, and 4 on standing up;
include matched endpoints in the review sheet but do not overwrite the original
endpoints. Use the actor's original canvas, transparent background and identity.
Store candidate frames under the corresponding actor/wardrobe/new state with
four-digit sequence names, plus provenance, SHA-256, alpha bbox, timing, per-frame
pelvis and both foot contact coordinates and scene-facing direction. Record
whether an actual foot is raised in a frame. Do not infer contact from alpha bounds
alone. The runtime must blend placement between the measured approach and seat
contact, not physically move the actor to a second station. Reserve the existing
seat throughout sitting down and until standing up completes. On reload use the
actual saved activity/claim; do not restart a completed transition or consume
media time twice. If the seat disappears or access is revoked, cancel safely.
Require a graphical test of both directions for each new calibrated bank before
activation. Side-occlusion crops are not valid full-body endpoint art.
No authored transition sequences were present in the verified registry.
Also deliver Manka CHASE_LEFT (real opposite direction), CATCH/RELEASE poses
with mouse-contact anchors, and a compatible mouse pose if the art supports it.
The current hunt holds the mouse's actual location without inventing a bite or
mouth attachment. Do not silently mirror asymmetric character art.
