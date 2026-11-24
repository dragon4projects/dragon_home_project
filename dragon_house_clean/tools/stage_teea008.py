#!/usr/bin/env python3
"""Materialize the immutable TEEA008 partial drop locally; never download, push or activate it.

Usage: python3 tools/stage_teea008.py /path/to/drop.zip [--root PATH] [--apply]
Default is verification and conflict report only. Use a real git-lfs checkout for --apply.
"""
import argparse
import hashlib
import json
import shutil
import stat
import tempfile
from pathlib import Path, PurePosixPath
from zipfile import ZipFile

DROP_SHA = "3bd99227af50afee13f1cde7ff7577854bdbeb95f254cb4ec6349cda1e05237f"
DROP_BYTES = 43337704
TASK = "TEEA_INT_20261124_008"
PREFIX = "dragon_house_clean/"
META = "data/asset_proposals/" + TASK + "/"
META_FILES = (
    "asset_aliases.json", "asset_geometry.json", "asset_index.json",
    "asset_interactions.json", "dependency_manifest.json", "gap_inventory.json",
    "material_shells.json", "media_surface_delta.json", "portable_candidates.json",
    "qa_import.json", "room_layouts_xz.json",
)

def sha(path):
    with path.open("rb") as src:
        return hashlib.file_digest(src, "sha256").hexdigest()

def safe_name(name):
    p = PurePosixPath(name)
    if p.is_absolute() or ".." in p.parts or "\\" in name or not name:
        raise ValueError("unsafe member: " + name)
    return p

def destination(root, name):
    p = root.joinpath(*safe_name(name).parts)
    for parent in [p, *p.parents]:
        if parent == root:
            break
        if parent.is_symlink():
            raise ValueError("symlink in destination: " + str(parent))
    if not p.resolve().is_relative_to(root):
        raise ValueError("destination escapes project root")
    return p

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("archive", type=Path)
    ap.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    root = args.root.resolve()
    if not root.is_dir() or not (root / "project.godot").is_file():
        raise SystemExit("root must be the existing dragon_house_clean project")
    if args.archive.stat().st_size != DROP_BYTES or sha(args.archive) != DROP_SHA:
        raise SystemExit("TEEA008 archive size or SHA256 mismatch")
    with tempfile.TemporaryDirectory(prefix="teea008-") as temp, ZipFile(args.archive) as z:
        staging = Path(temp)
        names = set()
        for info in z.infolist():
            safe_name(info.filename)
            if info.filename in names:
                raise ValueError("duplicate ZIP member")
            names.add(info.filename)
            if stat.S_ISLNK(info.external_attr >> 16):
                raise ValueError("symlink in ZIP")
        def extract(name):
            target = staging / safe_name(name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(PREFIX + name) as src, target.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            return target
        manifest = json.loads(extract(META + "dependency_manifest.json").read_text())
        items = manifest["items"]
        if manifest["task_id"] != TASK or manifest["owner_approved"] is not False or len(items) != 209:
            raise ValueError("unexpected manifest")
        paths = set()
        payload = []
        for item in items:
            name = item["path"]
            if name in paths or not name.startswith("assets/decor_bank/"):
                raise ValueError("duplicate or out-of-scope path: " + name)
            paths.add(name)
            file = extract(name)
            if file.stat().st_size != item["bytes"] or sha(file) != item["sha256"]:
                raise ValueError("dependency mismatch: " + name)
            payload.append((name, file))
        if sum(p.endswith("/model.gltf") for p in paths) != 45:
            raise ValueError("unexpected model count")
        for name in META_FILES:
            rel = META + name
            file = extract(rel)
            doc = json.loads(file.read_text())
            if doc.get("task_id") != TASK or doc.get("owner_approved") is not False:
                raise ValueError("unexpected candidate metadata: " + rel)
            payload.append((rel, file))
        conflicts, missing, identical = [], [], []
        for name, file in payload:
            target = destination(root, name)
            if target.exists():
                if not target.is_file() or sha(target) != sha(file):
                    conflicts.append(name)
                else:
                    identical.append(name)
            else:
                missing.append((name, file))
        print(f"TEEA008_VERIFIED dependencies={len(items)} models=45 metadata={len(META_FILES)} new={len(missing)} identical={len(identical)} conflicts={len(conflicts)}")
        for name in conflicts:
            print("CONFLICT", name)
        if conflicts:
            raise SystemExit("Refusing to overwrite existing bytes. Reconcile collisions first.")
        if not args.apply:
            print("DRY_RUN: no files written")
            return
        # No Git mutation here; let real git-lfs filters handle subsequent git add.
        for name, file in missing:
            target = destination(root, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            with file.open("rb") as src, target.open("xb") as dst:
                shutil.copyfileobj(src, dst)
            if sha(target) != sha(file):
                raise IOError("post-copy hash mismatch: " + name)
        print("TEEA008_STAGED_LOCALLY: candidate files only, no approval, no runtime activation")

if __name__ == "__main__":
    main()
