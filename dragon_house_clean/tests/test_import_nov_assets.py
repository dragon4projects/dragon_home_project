#!/usr/bin/env python3
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools/import_nov_assets.py"

def run(*args):
    return subprocess.run(["python3", str(TOOL), *map(str,args)], capture_output=True, text=True)

with tempfile.TemporaryDirectory() as td:
    work = Path(td)
    root = work / "new_project"
    root.mkdir()
    (root/"project.godot").write_text("config_version=5")
    target = "assets/residents/RES_01/wardrobes/HOME/IDLE_S/0001.png"
    # Valid PNG byte sequence with transparent pixel.
    sample=bytes.fromhex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c4890000000b49444154789c636000020000050001a5f645400000000049454e44ae426082")
    content = {
       target: sample,
       "data/asset_registry_nov2026.json":json.dumps({"schema":1,"residents":{f"RES_{i:02d}":{"appearance_profile":"QA"} for i in range(1,25)}}).encode(),
       "assets/manifests/asset_index.jsonl":b'{"kind":"QA"}\n',
       "assets/manifests/bank_coverage.json":b'{}',
    }
    content["assets/manifests/SHA256SUMS.txt"] = (hashlib.sha256(sample).hexdigest()+"  "+target+"\n").encode()
    archive=work/"migration.zip"
    with zipfile.ZipFile(archive,"w") as z:
        for key, body in content.items():
            z.writestr("dragon_house_clean/"+key,body)
    report=work/"dry-run.json"
    result=run("--source",archive,"--project",root,"--report",report)
    assert result.returncode==0, result.stderr
    assert not (root/target).exists()
    data=json.loads(report.read_text())
    assert data["files"]==5 and data["status"]=="DRY_RUN_VALIDATED"
    result=run("--source",archive,"--project",root,"--report",report,"--apply")
    assert result.returncode==0, result.stderr
    assert (root/target).read_bytes()==sample
    result=run("--source",archive,"--project",root,"--report",report,"--apply")
    assert result.returncode==0 and json.loads(report.read_text())["identical"]==5
    (root/target).write_bytes(b"DO NOT OVERWRITE EXISTING ART")
    result=run("--source",archive,"--project",root,"--report",report,"--apply")
    assert result.returncode==2 and "would be overwritten" in result.stderr
    assert (root/target).read_bytes()==b"DO NOT OVERWRITE EXISTING ART"
    attack=work/"attack.zip"
    with zipfile.ZipFile(attack,"w") as z:
        for key,body in content.items():
            z.writestr(key,body)
        z.writestr("../outside.txt",b"FORBIDDEN")
    result=run("--source",attack,"--project",root,"--report",report,"--apply")
    assert result.returncode==2 and "traversal" in result.stderr
    assert not (work/"outside.txt").exists()
    print("NOV_ASSET_INTAKE_TEST_PASS dry-run=5 applied=5 repeat=idempotent conflict=blocked traversal=blocked")

