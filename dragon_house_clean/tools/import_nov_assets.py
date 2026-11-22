#!/usr/bin/env python3
"""Safe offline intake of the NOV2026 asset bundle into a NEW Dragon House checkout.

This tool does not create Git commits, approve assets, or modify the legacy project.
Run with --dry-run before --apply. Requires Python 3.10+ standard library only.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import tempfile
import zipfile

PREFIX = "dragon_house_clean/"
RUNROOTS = (
    "assets/residents/", "assets/creatures/", "assets/rooms/", "assets/props/",
    "assets/materials/", "assets/previews/", "assets/fx/", "assets/ui/",
    "assets/manifests/",
)
ARCHIVE_ROOTS = ("assets/_nov2026_archive/", "assets/_nov2026_quarantine/")
DATA_FILES = {"data/asset_registry_nov2026.json",
              "data/media_import_candidates_nov2026.json"}
DOC_FILES = {"docs/NOV2026_ASSET_MIGRATION_REPORT.md",
             "docs/NOV2026_ASSET_MIGRATION_NEXT_STEPS.md"}
MEDIA_EXT = {".png", ".webp", ".jpg", ".jpeg", ".tres", ".svg"}
DOC_EXT = {".json", ".jsonl", ".csv", ".txt", ".md"}
MAX_SINGLE = 160 * 1024 * 1024
REQUIRED = {"data/asset_registry_nov2026.json",
            "assets/manifests/asset_index.jsonl",
            "assets/manifests/bank_coverage.json",
            "assets/manifests/SHA256SUMS.txt"}


def normalized(name: str) -> str:
    if "\\" in name or name.startswith("/"):
        raise ValueError(f"unsafe path: {name!r}")
    if name.startswith(PREFIX):
        name = name[len(PREFIX):]
    p = PurePosixPath(name)
    if any(part in {".", "..", ""} for part in p.parts) or p.is_absolute():
        raise ValueError(f"traversal: {name!r}")
    result = str(p)
    if not result or result.startswith("."):
        raise ValueError(f"hidden/invalid path: {result!r}")
    return result


def category(rel: str, include_archive: bool) -> str:
    if rel in DATA_FILES or rel in DOC_FILES:
        return "manifest"
    if rel.startswith(ARCHIVE_ROOTS):
        return "original" if include_archive else "skipped_archive"
    if rel.startswith(RUNROOTS):
        if rel.endswith((".godot", ".import")):
            return "forbidden"
        ext = Path(rel).suffix.lower()
        if rel.startswith("assets/manifests/"):
            return "manifest" if ext in DOC_EXT else "forbidden"
        return "image" if ext in MEDIA_EXT else "forbidden"
    return "forbidden"


def digest_stream(source, expected_length: int):
    h = hashlib.sha256()
    count = 0
    while True:
        chunk = source.read(1024 * 1024)
        if not chunk:
            break
        count += len(chunk)
        if count > MAX_SINGLE:
            raise ValueError("single file too large")
        h.update(chunk)
    if count != expected_length:
        raise ValueError(f"length mismatch {count} != {expected_length}")
    return h.hexdigest()


def read_hashes(raw: bytes) -> dict:
    out = {}
    for line in raw.decode("utf-8-sig").splitlines():
        match = re.match(r"^([a-fA-F0-9]{64})\s+\*?(.+)$", line.strip())
        if not match:
            continue
        rel = normalized(match.group(2).lstrip("./"))
        out[rel] = match.group(1).lower()
    return out


@contextmanager
def _open_zip_file(path: Path, filename: str):
    with zipfile.ZipFile(path) as archive:
        with archive.open(filename) as file:
            yield file


def list_entries(source: Path):
    if source.is_dir():
        for file in sorted(source.rglob("*")):
            if file.is_symlink():
                raise ValueError(f"symlink refused: {file}")
            if not file.is_file():
                continue
            yield str(file.relative_to(source)).replace(os.sep, "/"), file.stat().st_size, lambda p=file: p.open("rb")
    elif zipfile.is_zipfile(source):
        with zipfile.ZipFile(source) as z:
            for info in z.infolist():
                if info.is_dir():
                    continue
                mode = (info.external_attr >> 16) & 0xFFFF
                if stat.S_ISLNK(mode):
                    raise ValueError(f"symlink ZIP entry refused: {info.filename}")
                yield info.filename, info.file_size, lambda p=source, name=info.filename: _open_zip_file(p,name)
    else:
        raise ValueError("source must be a directory or ZIP")


def intake(source: Path, project: Path, apply: bool, include_archive: bool, report: Path) -> dict:
    if not (project / "project.godot").is_file():
        raise ValueError("destination must be an existing independent Godot project root")
    plan = []
    duplicate_path_set = set()
    duplicate_case_set = {}
    declared_hashes = {}
    total_bytes = 0
    with tempfile.TemporaryDirectory(prefix="dragon-nov-intake-") as temp:
        staging = Path(temp)
        # First pass: preserve the SHA256SUMS manifest, then verify every entry.
        entries = list(list_entries(source))
        by_name = {}
        for raw, size, opener in entries:
            rel = normalized(raw)
            if rel in by_name:
                raise ValueError(f"duplicate path in bundle: {rel}")
            k = rel.casefold()
            if k in duplicate_case_set and duplicate_case_set[k] != rel:
                raise ValueError(f"Windows filename collision: {rel}, {duplicate_case_set[k]}")
            duplicate_case_set[k] = rel
            if size > MAX_SINGLE:
                raise ValueError(f"single file >160MiB: {rel}")
            by_name[rel] = (size, opener)
        missing = REQUIRED - set(by_name)
        if missing:
            raise ValueError(f"bundle is missing required manifests: {sorted(missing)}")
        with by_name["assets/manifests/SHA256SUMS.txt"][1]() as f:
            declared_hashes = read_hashes(f.read())
        for rel, (size, opener) in by_name.items():
            what = category(rel, include_archive)
            if what == "forbidden":
                raise ValueError(f"unexpected path or extension: {rel}")
            if what == "skipped_archive":
                continue
            h = hashlib.sha256()
            new = staging / rel
            new.parent.mkdir(parents=True, exist_ok=True)
            with opener() as fin, new.open("wb") as fout:
                copied = 0
                while True:
                    block = fin.read(1024 * 1024)
                    if not block:
                        break
                    copied += len(block)
                    if copied > MAX_SINGLE:
                        raise ValueError(f"size limit: {rel}")
                    h.update(block)
                    fout.write(block)
            if copied != size:
                raise ValueError(f"short read: {rel}")
            sha = h.hexdigest()
            if rel in declared_hashes and declared_hashes[rel] != sha:
                raise ValueError(f"SHA256 mismatch for {rel}")
            target = project / rel
            # A pre-existing symlink in *any parent directory* could redirect
            # an otherwise well-formed normalized path outside the new project.
            ancestor = project
            for component in PurePosixPath(rel).parts[:-1]:
                ancestor = ancestor / component
                if ancestor.is_symlink():
                    raise ValueError(f"destination parent symlink refused: {rel}")
            if target.is_symlink():
                raise ValueError(f"existing target symlink refused: {rel}")
            if target.exists():
                existing_sha = hashlib.sha256(target.read_bytes()).hexdigest()
                action = "identical" if existing_sha == sha else "CONFLICT"
            else:
                action = "copy"
            if action == "CONFLICT":
                raise ValueError(f"existing file would be overwritten: {rel}")
            total_bytes += copied
            plan.append({"path": rel, "kind": what, "size": copied, "sha256": sha, "action": action})
        # Check the two required indexes are actually parseable, not just named.
        with (staging / "assets/manifests/asset_index.jsonl").open("r", encoding="utf-8-sig") as idx:
            for line_number, line in enumerate(idx,1):
                if line.strip():
                    try:
                        if not isinstance(json.loads(line), dict):
                            raise ValueError("not an object")
                    except (ValueError, json.JSONDecodeError) as err:
                        raise ValueError(f"invalid asset_index.jsonl line {line_number}: {err}") from err
        coverage = json.loads((staging / "assets/manifests/bank_coverage.json").read_text(encoding="utf-8-sig"))
        if not isinstance(coverage,(list,dict)):
            raise ValueError("bank_coverage must be a JSON list or dictionary")
        # Registry is untrusted metadata. Check basic shape and all declared profile IDs.
        reg = json.loads((staging / "data/asset_registry_nov2026.json").read_text(encoding="utf-8-sig"))
        residents = reg.get("residents", {}) if isinstance(reg, dict) else {}
        if reg.get("schema") != 1 or not isinstance(residents, dict):
            raise ValueError("resident registry schema is not 1 or residents is not a map")
        ids = {f"RES_{i:02d}" for i in range(1, 25)}
        if not ids.issubset(residents):
            raise ValueError(f"resident registry missing canonical IDs: {sorted(ids - set(residents))}")
        # Confirm checksummed objects that were included: do not claim missing quarantine is shipped.
        paths = {row["path"] for row in plan}
        for name in declared_hashes:
            if category(name, include_archive) != "skipped_archive" and name not in paths:
                raise ValueError(f"SHA256SUMS declares missing binary: {name}")
        if apply:
            for row in plan:
                if row["action"] == "identical":
                    continue
                src = staging / row["path"]
                dest = project / row["path"]
                dest.parent.mkdir(parents=True, exist_ok=True)
                if dest.exists() or dest.is_symlink():
                    raise ValueError(f"destination changed during intake: {dest}")
                with tempfile.NamedTemporaryFile(dir=dest.parent, prefix=".nov_stage_", delete=False) as tmp:
                    temp_name = tmp.name
                    with src.open("rb") as source_stream:
                        shutil.copyfileobj(source_stream, tmp)
                os.replace(temp_name, dest)
        output = {"status": "LOCAL_COPIED" if apply else "DRY_RUN_VALIDATED",
                  "source": str(source), "files": len(plan),
                  "bytes": total_bytes, "copied": sum(1 for row in plan if row["action"]=="copy"),
                  "identical": sum(1 for row in plan if row["action"]=="identical"),
                  "archived_skipped": len(entries)-len(plan),
                  "remote_published": False, "runtime_bound": False,
                  "file_index": plan}
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(output, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        return {k:v for k,v in output.items() if k!="file_index"}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--source", type=Path, required=True)
    ap.add_argument("--project", type=Path, required=True)
    ap.add_argument("--apply", action="store_true", help="Copy validated files (default is dry-run)")
    ap.add_argument("--include-archive", action="store_true",
                    help="Also copy archive/quarantine files; access-restricted by default")
    ap.add_argument("--report", type=Path, default=Path("NOV2026_INTAKE_LOCAL.json"))
    args=ap.parse_args()
    try:
        result=intake(args.source,args.project,args.apply,args.include_archive,args.report)
        print(json.dumps(result,ensure_ascii=False))
    except Exception as e:
        print(f"INTAKE_REJECTED: {e}",file=sys.stderr)
        raise SystemExit(2)
if __name__=="__main__":
    main()

