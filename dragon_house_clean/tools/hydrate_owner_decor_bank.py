#!/usr/bin/env python3
"""Restore selected CC0 1K source models from the already harvested asset IDs.

The source library stays outside the public repo. No private archive URL is
published; official Poly Haven file metadata supplies each dependency and hash.
"""
import hashlib
import json
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import quote, unquote

ROOT = Path(__file__).resolve().parents[1]
ASSETS = (
    "gothic_coffee_table", "sofa_02", "chinese_armchair",
    "wooden_display_shelves_01", "chinese_commode",
    "wooden_table_02", "metal_stool_02", "worn_metal_rack",
)

def get(url):
    if not url.startswith("https://"):
        raise ValueError("Non-HTTPS source")
    for attempt in range(4):
        try:
            with urlopen(Request(url, headers={"User-Agent": "DragonHouse-PersonalProject/1.0"}), timeout=60) as response:
                return response.read()
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)

def checked(entry):
    data = get(entry["url"])
    expected = entry.get("md5")
    if expected and hashlib.md5(data).hexdigest().lower() != expected.lower():
        raise ValueError("MD5 mismatch: " + entry["url"])
    if entry.get("size") and len(data) != int(entry["size"]):
        raise ValueError("Size mismatch: " + entry["url"])
    return data

def hydrate(asset):
    files = json.loads(get("https://api.polyhaven.com/files/" + quote(asset, safe="")))
    source = files["gltf"]["1k"]["gltf"]
    doc = json.loads(checked(source))
    includes = source.get("include", {})
    out = ROOT / "assets" / "decor_bank" / asset
    out.mkdir(parents=True, exist_ok=True)
    deps = out / "deps"
    deps.mkdir(exist_ok=True)
    used = {}
    for obj in doc.get("buffers", []) + doc.get("images", []):
        uri = obj.get("uri")
        if not uri or uri.startswith("data:"):
            continue
        if uri not in used:
            candidates = [uri, unquote(uri)]
            entry = next((includes[k] for k in candidates if k in includes), None)
            if entry is None:
                matches = [v for k,v in includes.items() if unquote(k).lstrip("./") == unquote(uri).lstrip("./")]
                if len(matches) != 1:
                    raise ValueError(f"{asset}: unresolved dependency {uri}")
                entry = matches[0]
            name = f"{len(used):02d}_" + Path(unquote(uri)).name
            data = checked(entry)
            (deps / name).write_bytes(data)
            used[uri] = "deps/" + name
        obj["uri"] = used[uri]
    (out / "model.gltf").write_text(json.dumps(doc), encoding="utf-8")
    (out / "SOURCE.txt").write_text(
        f"Poly Haven CC0: https://polyhaven.com/a/{asset}\n1K glTF source: {source['url']}\n"
        f"Original MD5: {source.get('md5', 'unavailable')}\n", encoding="utf-8")
    print("OWNER_DECOR_MODEL_READY", asset, len(used), flush=True)

if __name__ == "__main__":
    for asset in ASSETS:
        hydrate(asset)
    print("OWNER_DECOR_BANK_PASS", len(ASSETS), flush=True)
