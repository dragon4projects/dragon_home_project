#!/usr/bin/env python3
"""Verify candidate delivery bytes in a hydrated checkout; no network or mutation."""
import hashlib
import json
from pathlib import Path

project = Path(__file__).resolve().parents[1]
repo = project.parent
manifest = json.loads((project / "data/TEEA008_LFS_DELIVERY_SHA256.json").read_text())["files"]
large = 0
for name, expected in manifest.items():
    path = repo / name
    assert path.is_file(), f"missing {name}"
    assert path.stat().st_size == expected["bytes"], f"size or LFS pointer {name}"
    with path.open("rb") as stream:
        assert hashlib.file_digest(stream, "sha256").hexdigest() == expected["sha256"], name
    if "/assets/teea008_review/decor_bank/" in name:
        large += 1
assert large == 1030 and len(manifest) == 1045
actual = {str(p.relative_to(repo)) for p in (project / "assets/teea008_review/decor_bank").rglob("*") if p.is_file()}
expected_files = {p for p in manifest if "/assets/teea008_review/decor_bank/" in p}
assert actual == expected_files, (len(actual), len(expected_files))
new = json.loads((project / "data/asset_proposals/SKETCHFAB_20261125/dependency_manifest.json").read_text())["items"]
for expected in new:
    name = expected["path"].replace("assets/decor_bank/", "assets/sketchfab_review/decor_bank/", 1)
    path = project / name
    assert path.is_file() and path.stat().st_size == expected["bytes"], name
    with path.open("rb") as stream:
        assert hashlib.file_digest(stream, "sha256").hexdigest() == expected["sha256"], name
assert len(new) == 73
assert len(list((project / "assets/teea008_review/decor_bank").rglob("model.gltf"))) == 243
assert len(list((project / "assets/sketchfab_review/decor_bank").rglob("model.gltf"))) == 6
print("TEEA008_DELIVERY_VERIFY_PASS bank_files=1030 metadata=15 sketchfab_files=73 models=249")
