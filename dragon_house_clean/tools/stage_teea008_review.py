#!/usr/bin/env python3
"""Stage verified TEEA008 candidate data without overwriting accepted paths."""
import hashlib, json, pathlib, shutil, sys, zipfile, tempfile
EXPECTED="170fef032089fb82bc25176c0bd61a3368eedda8508962405ea039c3edf428ba"
if len(sys.argv)!=3:
    raise SystemExit("usage: stage_teea008_review.py ARCHIVE PROJECT_ROOT")
archive=pathlib.Path(sys.argv[1]).resolve()
root=pathlib.Path(sys.argv[2]).resolve()
if hashlib.file_digest(archive.open("rb"),"sha256").hexdigest()!=EXPECTED:
    raise SystemExit("archive SHA mismatch")
with tempfile.TemporaryDirectory() as tmp:
    p=pathlib.Path(tmp)
    with zipfile.ZipFile(archive) as z:
        for item in z.infolist():
            target=(p/item.filename).resolve()
            if not target.is_relative_to(p) or (item.external_attr>>16)&0o170000==0o120000:
                raise SystemExit("unsafe ZIP member")
        z.extractall(p)
    src=p/"dragon_house_clean"
    data=src/"data/asset_proposals/TEEA_INT_20261124_008"
    import subprocess
    subprocess.run([sys.executable,str(src/"docs/handoffs/TEEA_INT_20261124_008/verify_payload.py"),str(src)],check=True)
    for source,target in [(src/"assets/decor_bank",root/"assets/teea008_review/decor_bank"),(data,root/"data/teea008_review")]:
        if target.exists():
            raise SystemExit("review target exists; use a clean staging checkout")
        shutil.copytree(source,target)
print("TEEA008_STAGE_PASS separate_candidate_paths=true")
