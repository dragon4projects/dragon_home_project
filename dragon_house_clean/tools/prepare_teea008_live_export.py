#!/usr/bin/env python3
"""Local owner-review export staging; never commit generated review marker."""
import hashlib,json,pathlib,sys
root=pathlib.Path(sys.argv[1]).resolve()
data=root/"data/integration_candidates"
if not (data/"ITER1_OWNER_REVIEW.enabled").is_file():
    raise SystemExit("hydrate existing review first")
manifest=json.loads((root/"data/teea008_pose_contacts_review.json").read_text())
frames={}
for profile in manifest["profiles"].values():
    for state in profile["states"].values():
        path=root/state["path"]
        digest=hashlib.file_digest(path.open("rb"),"sha256").hexdigest()
        if digest!=state["sha256"]:raise SystemExit(f"frame hash mismatch {path}")
        frames["res://"+state["path"]]=digest
if len(frames)!=127:raise SystemExit(f"expected 127 original frames, got {len(frames)}")
intake=root/"data/asset_proposals/DH_SPRITE_20261126_INTAKE"
intake_path=intake/"frames.json"
if intake_path.is_file():
    records=json.loads(intake_path.read_text())
    if len(records)!=42:raise SystemExit("unexpected intake66 frame count")
    for rec in records:
        path=root/rec["path"]
        digest=hashlib.file_digest(path.open("rb"),"sha256").hexdigest()
        if digest!=rec["sha256"] or path.stat().st_size!=rec["size"]:
            raise SystemExit(f"intake frame mismatch {path}")
        frames["res://"+rec["path"]]=digest
    pose=intake/"pose_contacts.json"
    if pose.is_file():
        for profile in json.loads(pose.read_text())["profiles"].values():
            for state in profile["states"].values():
                if frames.get("res://"+state["path"])!=state["sha256"]:
                    raise SystemExit("new contact hash mismatch")
(data/"TEEA008_POSE_EXPORT_PROOF.json").write_text(json.dumps({"owner_approved":False,"frames":frames},indent=2)+"\n")
(data/"TEEA008_LIVE_REVIEW.enabled").write_text("OWNER_REVIEW_ONLY\n")
print("TEEA008_EXPORT_STAGE_PASS verified_source_frames=",len(frames))
