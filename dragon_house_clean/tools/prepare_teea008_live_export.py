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
(data/"TEEA008_POSE_EXPORT_PROOF.json").write_text(json.dumps({"owner_approved":False,"frames":frames},indent=2)+"\n")
(data/"TEEA008_LIVE_REVIEW.enabled").write_text("OWNER_REVIEW_ONLY\n")
print("TEEA008_EXPORT_STAGE_PASS original_pose_frames=",len(frames))
