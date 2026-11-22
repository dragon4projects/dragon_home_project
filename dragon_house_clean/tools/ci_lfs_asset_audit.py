#!/usr/bin/env python3
"""Validate an already checked-out independent Dragon House LFS migration.

Hard failures: missing referenced frames, Git LFS pointer instead of image bytes,
profile changes, malformed path/status, wrong SHA, missing canon masters.
No artist approval, resident activation, or private-room permissions are granted.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import sys

REQUIRED = {"IDLE_S", "WALK_LEFT", "WALK_RIGHT"}
KNOWN_MASTERS = {
    "CUBE_LETTERS": "d82d626db0e7d108feaf026b16c5c0ac6d4918e49513ad3d8ee7f003f46b91cd",
    "POSTER_SHURSHUN": "c9de29faabb8ac071dac50f1b99c393a96d4b2faa4bd7366d98ef47d24a47609",
    "PHOTO_MOON": "9a700858492f90e19c2c2fd070c4186b0663dec939ce9707829718c8768fcb4b",
    "PORTRAIT_SHURS": "5d160c598db3a431354fb53419648571e19f4de9d82b7fe945af38421cd2dc65",
    "MUG_BLUE_A": "26c0560be9b4fd295f1eb5ee3ea78319d13011a72f71504f486daf82354d1a92",
    "MUG_BLUE_B": "d341de2ab28ef48976945627fdec5c995c06796fda22c13e15d4619760c5927b",
    "MUG_RED_A": "f5ac722e768b9c3fa5ebdccf7fb36daca43331ac5c094430ca7641c7c5c0ab3c",
    "MUG_RED_B": "c655dfb1c8dbefb092cbc6ae7ac9e65d927d53b084e32a8910a5e5c06efeab62",
}

def fail(message: str) -> None:
    raise ValueError(message)

def verified_path(project: Path, name: str, prefix: str) -> Path:
    if not isinstance(name,str):
        fail(f"path is not string: {name}")
    name=name.removeprefix("res://")
    if name.startswith("/") or "\\" in name or ".." in PurePosixPath(name).parts:
        fail(f"unsafe path: {name}")
    if not name.startswith(prefix):
        fail(f"wrong canonical namespace: {name} (expected {prefix})")
    p=project / name
    if not p.is_file() or p.is_symlink():
        fail(f"missing normalized file: {name}")
    with p.open("rb") as f:
        header=f.read(130)
    if header.startswith(b"version https://git-lfs.github.com/spec/v1"):
        fail(f"LFS pointer not checked out: {name}")
    ext=p.suffix.lower()
    if ext==".png" and not header.startswith(b"\x89PNG\r\n\x1a\n"):
        fail(f"invalid PNG header: {name}")
    if ext==".jpg" or ext==".jpeg":
        if not header.startswith(b"\xff\xd8"):
            fail(f"invalid JPEG header: {name}")
    if ext==".webp" and not (header.startswith(b"RIFF") and header[8:12]==b"WEBP"):
        fail(f"invalid WebP header: {name}")
    return p

def sha256(path: Path) -> str:
    digest=hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024*1024), b""):
            digest.update(block)
    return digest.hexdigest()

def check(root: Path) -> dict:
    registry=json.loads((root/"data/asset_registry_nov2026.json").read_text(encoding="utf-8"))
    profiles=json.loads((root/"data/resident_profiles.json").read_text(encoding="utf-8"))
    if registry.get("schema")!=1 or len(profiles.get("residents",[]))!=24:
        fail("schema or profile count invalid")
    expected={r["id"]:r["appearance_profile"] for r in profiles["residents"]}
    if set(registry.get("residents",{}))!=set(expected):
        fail("registry IDs do not exactly match canonical profiles")
    ready=[]
    frame_links=0
    checked_files=set()
    for id, resident in registry["residents"].items():
        if resident.get("appearance_profile")!=expected[id]:
            fail(f"appearance-profile mismatch: {id}")
        complete=False
        for outfit, bank in resident.get("wardrobes",{}).items():
            # EXTRA branches for EVM must remain distinct; no merging with HOME.
            if outfit not in {"HOME","CITY","SHORT"} and not outfit.startswith("EXTRA/"):
                fail(f"unknown outfit key: {id}/{outfit}")
            states=bank.get("states",{})
            if not isinstance(states,dict):
                fail(f"invalid states object: {id}/{outfit}")
            ok_states=set()
            for state, item in states.items():
                if item.get("status")!="PASS":
                    continue
                frames=item.get("frames",[])
                if not isinstance(frames,list) or not frames:
                    fail(f"PASS without frames: {id}/{outfit}/{state}")
                if len(frames)>24:
                    fail(f"too many frames in state: {id}/{outfit}/{state}")
                pref=f"assets/residents/{id}/wardrobes/{outfit}/{state}/"
                for path in frames:
                    if not isinstance(path,str):
                        fail(f"bad frame entry: {id}/{state}")
                    normalized=path.removeprefix("res://")
                    verified_path(root,normalized,pref)
                    checked_files.add(normalized)
                    frame_links+=1
                ok_states.add(state)
                fps=item.get("fps")
                if isinstance(fps,(int,float)) and (fps<0.1 or fps>30):
                    fail(f"invalid fps: {id}/{outfit}/{state}")
            if outfit in {"HOME","CITY","SHORT"} and REQUIRED.issubset(ok_states):
                complete=True
        if complete:
            ready.append(id)
    # No fake art should be marked as fully approved by mere presence.
    if any(r.get("visual_bank_ready",False) for r in registry["residents"].values()):
        fail("asset registry unexpectedly authorizes resident visual banks")
    if len(ready)<21:
        fail(f"only {len(ready)} / 21 expected complete resident candidates")
    # Props are historically SHA-verified masters.
    prop={r["id"]:r for r in registry.get("props",{}).get("display_previews",[])}
    for prop_id,digest in KNOWN_MASTERS.items():
        if prop_id not in prop:
            fail(f"missing historically accepted prop: {prop_id}")
        path=verified_path(root,prop[prop_id]["master_path"],"assets/props/")
        if sha256(path)!=digest:
            fail(f"historical master hash mismatch: {prop_id}")
        checked_files.add(str(path.relative_to(root)))
    manka=registry.get("creatures",{}).get("manjka",{})
    manka_ok=0
    for state, info in manka.get("states",{}).items():
        if info.get("status")!="PASS":
            continue
        for frame in info.get("frames",[]):
            checked_files.add(str(verified_path(root,frame,"assets/creatures/manjka/").relative_to(root)))
        manka_ok+=1
    if manka_ok<7:
        fail(f"Manka is missing PASS states: {manka_ok}")
    # Verify all normalized SHA256SUMS entries, including materials and previews.
    sha_file=root/"assets/manifests/SHA256SUMS.txt"
    pairs=[]
    for line in sha_file.read_text(encoding="utf-8").splitlines():
        m=re.fullmatch(r"([0-9a-f]{64})\s+\*?(.+)",line)
        if not m:
            fail("malformed SHA256SUMS entry")
        pairs.append((m.group(1),m.group(2)))
    bad=[]
    for expected_hash,name in pairs:
        path=verified_path(root,name,"assets/")
        if sha256(path)!=expected_hash:
            bad.append(name)
    if bad:
        fail(f"SHA256 mismatch on {len(bad)} files; example: {bad[0]}")
    metadata=registry.get("media_previews",{}).get("books",[])
    if len(metadata)!=76 or any(b.get("status")!="METADATA_ONLY" for b in metadata):
        fail("76 cloud books must remain metadata-only")
    return {
        "status": "LFS_BYTES_VERIFIED_QA_ONLY",
        "canonical_residents":24,
        "complete_candidate_banks":len(ready),
        "candidate_ids":ready,
        "approved_resident_banks":0,
        "manka_pass_states":manka_ok,
        "historical_master_sha256_pass":len(KNOWN_MASTERS),
        "media_books_metadata_only":len(metadata),
        "sha256_files_verified":len(pairs),
        "frame_references_verified":frame_links,
        "unique_frame_paths":len(checked_files),
        "old_project_edited":False,
        "human_visual_approval":False
    }

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--project",type=Path,default=Path("."))
    ap.add_argument("--report",type=Path,default=Path("LFS_ACCEPTANCE_QA.json"))
    args=ap.parse_args()
    try:
        result=check(args.project.resolve())
        args.report.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
        print(json.dumps(result,ensure_ascii=False))
    except Exception as error:
        print(f"LFS_ASSET_AUDIT_FAILED: {error}",file=sys.stderr)
        raise SystemExit(2)
if __name__=="__main__":
    main()

