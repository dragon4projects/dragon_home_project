#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAND = ROOT / "data" / "integration_candidates"
T6 = ROOT / "data" / "asset_proposals" / "TEEA_INT_20261123_006_interiors.json"
T6_ANCHORS = ROOT / "data" / "asset_proposals" / "TEEA_INT_20261123_006_furniture_anchors_candidate.json"
BASE_FURN = ROOT / "data" / "furniture_interactions_v1.json"
ROOM_OUT = CAND / "ITER1_ROOM_ART_REVIEW.json"
FURN_OUT = CAND / "furniture_interactions_iter1_review.json"
REPORT_OUT = CAND / "ITER1_INTAKE_REPORT.json"

T6_PREFIX = "assets/room_candidates/TEEA_INT_20261123_006"
T7_PREFIX = "assets/room_candidates/TEEA_INT_20261123_007"

REQUIRED_CREATURE_BANKS = [
    "npc_ai_magic_sphere",
    "npc_cat_black_hero", "npc_cat_calico", "npc_cat_ginger",
    "npc_cat_sphynx", "npc_cat_tabby", "npc_cat_white",
    "npc_hedgehog_01", "npc_hedgehog_02", "npc_hedgehog_03",
    "npc_mouse_brown", "npc_mouse_gray", "npc_mouse_pale",
    "npc_rat_agouti", "npc_rat_hero", "npc_rat_hooded",
    "npc_rat_juvenile_gray", "npc_rat_white",
]
POSE_MAP = {
    "IDLE_S":"IDLE_S", "RELAXED_SIT":"RELAXED_SIT", "SLEEP":"SLEEP",
    "READ":"READ", "USE":"USE", "VIEW":"VIEW", "TALK":"TALK", "DRINK":"DRINK",
    "LISTEN":"RELAXED_SIT", "WATCH":"RELAXED_SIT", "INSPECT":"VIEW",
}
KIND_MAP = {"seat":"seat", "floor_rest":"floor_rest", "work":"work",
            "standing":"standing", "view":"standing"}

def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def write(path: Path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                    encoding="utf-8")

def main():
    t6 = load(T6)
    if t6.get("schema") != 2 or t6.get("approved") is not False or t6.get("owner_approved") is not False:
        raise SystemExit("TEEA006 candidate approval/schema contract mismatch")

    room_types = {}
    t6_layers = 0
    t6_variants = 0
    for room_type, variants in t6["room_types"].items():
        room_types[room_type] = {}
        for variant, entry in variants.items():
            t6_variants += 1
            out_layers = []
            for item in entry.get("layers", []):
                src = str(item["path"])
                if not src.startswith("assets/rooms/"):
                    raise SystemExit(f"unsafe TEEA006 path: {src}")
                rel_after = src[len("assets/rooms/"):]
                candidate_rel = f"{T6_PREFIX}/{rel_after}"
                candidate_abs = ROOT / candidate_rel
                if not candidate_abs.is_file():
                    raise SystemExit(f"missing TEEA006 candidate file: {candidate_rel}")
                expected = str(item.get("sha256",""))
                actual = sha(candidate_abs)
                if expected and actual != expected:
                    raise SystemExit(f"TEEA006 SHA mismatch: {candidate_rel}")
                copied = dict(item)
                copied["path"] = candidate_rel
                copied["approved"] = False
                copied["owner_approved"] = False
                copied["candidate_review"] = True
                copied["source_batch"] = "TEEA_INT_20261123_006"
                out_layers.append(copied)
                t6_layers += 1
            room_types[room_type][variant] = {
                "layers": out_layers,
                "source_batch": "TEEA_INT_20261123_006",
                "approved": False,
                "owner_approved": False,
            }

    if t6_variants != 12 or t6_layers != 40:
        raise SystemExit(f"TEEA006 expected 12 variants/40 layers, got {t6_variants}/{t6_layers}")

    guest_art = {}
    for guest in ("guest_centaur", "guest_vampire", "guest_miu"):
        layers = []
        base = ROOT / T7_PREFIX / guest / "R1"
        for role in ("backdrop", "back_decor", "furniture_back", "foreground"):
            p = base / f"{role}.png"
            if p.is_file():
                rel = p.relative_to(ROOT).as_posix()
                layers.append({
                    "role": role,
                    "path": rel,
                    "sha256": sha(p),
                    "approved": False,
                    "owner_approved": False,
                    "candidate_review": True,
                    "source_batch": "TEEA_INT_20261123_007",
                })
        if layers:
            room_types[guest] = {
                "R1": {
                    "layers": layers,
                    "source_batch": "TEEA_INT_20261123_007",
                    "approved": False,
                    "owner_approved": False,
                }
            }
        guest_art[guest] = len(layers)

    write(ROOM_OUT, {
        "schema": 2,
        "batch_id": "ITER1_OWNER_REVIEW",
        "approved": False,
        "owner_approved": False,
        "review_only": True,
        "sources": {
            "teea006_commit": "887e5f1c874c7fb0deb600c58c06ad4e5dafb90f",
            "teea007_commit": "996950493cc1e703abefc3659a13177160caa8d0",
        },
        "room_types": room_types,
    })

    # Canonical TEEA006 handoff contains one literal control character in
    # non_station_furniture metadata. Preserve the source byte-for-byte and
    # relax JSON string control-character parsing only for this legacy candidate.
    # Runtime integration below consumes room_variants[*].stations, not the
    # malformed non-station furniture label.
    anchors = json.loads(T6_ANCHORS.read_text(encoding="utf-8"), strict=False)
    if anchors.get("schema") != 3 or anchors.get("approved") is not False or anchors.get("owner_approved") is not False:
        raise SystemExit("TEEA006 station candidate approval/schema contract mismatch")

    review_furn = json.loads(json.dumps(load(BASE_FURN)))
    overrides = review_furn.setdefault("variant_cell_overrides", {})
    station_count = 0
    target_rooms = {"music","cinema","artifact","workshop"}

    for variant_key, entry in anchors["room_variants"].items():
        room, variant = variant_key.split("/", 1)
        if room not in target_rooms:
            continue
        width = int(variant[1:])
        for module_index in range(width):
            overrides[f"{room}:{variant}:{module_index}"] = []
        for raw in entry.get("stations", []):
            module_index = int(raw["module_index"])
            key = f"{room}:{variant}:{module_index}"
            artist_pose = str(raw.get("pose_hint","IDLE_S"))
            artist_kind = str(raw.get("kind","standing"))
            if artist_pose not in POSE_MAP or artist_kind not in KIND_MAP:
                raise SystemExit(f"unsupported TEEA006 station semantics: {raw.get('id')}")
            overrides[key].append({
                "id": str(raw["id"]),
                "x": float(raw["cell_local_x"]),
                "z": float(raw["cell_local_z"]),
                "kind": KIND_MAP[artist_kind],
                "furniture_id": str(raw.get("furniture_id","")),
                "pose_hint": POSE_MAP[artist_pose],
                "approach_z": float(raw["approach_local_z"]),
                "source_batch": "TEEA_INT_20261123_006",
                "candidate_review": True,
            })
            station_count += 1

    if station_count != 31:
        raise SystemExit(f"TEEA006 expected 31 stations, got {station_count}")

    min_spacing = 999.0
    for key, items in overrides.items():
        if not key.startswith(("music:","cinema:","artifact:","workshop:")):
            continue
        for i, a in enumerate(items):
            for b in items[i+1:]:
                dx = float(a["x"]) - float(b["x"])
                dz = float(a["z"]) - float(b["z"])
                d = (dx*dx + dz*dz) ** 0.5
                min_spacing = min(min_spacing, d)
                if d < 0.60:
                    raise SystemExit(f"review station spacing below 0.60m in {key}: {d:.4f}")

    review_furn["source"] = str(review_furn.get("source","")) + " + ITER1 TEEA006 review overlay"
    review_furn["review_only"] = True
    review_furn["owner_approved"] = False
    write(FURN_OUT, review_furn)

    registry = load(ROOT / "data" / "asset_registry_nov2026.json")
    creatures = registry.get("creatures", {})
    missing_banks = [b for b in REQUIRED_CREATURE_BANKS if b not in creatures]
    if missing_banks:
        raise SystemExit("creature registry missing banks: " + ", ".join(missing_banks))

    props = []
    for pattern in (
        "assets/props/dragon_mug_*",
        "assets/props/media_holder_*",
        "assets/props/dragon_fur_rest_mat.*",
    ):
        for p in sorted(ROOT.glob(pattern)):
            if p.is_file():
                props.append({"path": p.relative_to(ROOT).as_posix(), "sha256": sha(p)})

    write(REPORT_OUT, {
        "schema": 1,
        "status": "ITER1_OWNER_REVIEW_CANDIDATE",
        "approved": False,
        "owner_approved": False,
        "production_base": "1216e2f1a737008e3d9fea0f5d240d54a78a6ea2",
        "staging_intake": "488ed009adab7b0a27989534c8fad7a55e3ead94",
        "teea006": {
            "commit": "887e5f1c874c7fb0deb600c58c06ad4e5dafb90f",
            "variants": t6_variants,
            "layers": t6_layers,
            "stations": station_count,
            "minimum_same_module_station_spacing_m": None if min_spacing == 999.0 else round(min_spacing, 6),
        },
        "teea007": {
            "commit": "996950493cc1e703abefc3659a13177160caa8d0",
            "guest_art_layer_count": guest_art,
            "centaur_room_art_gap": guest_art.get("guest_centaur", 0) == 0,
            "props": props,
        },
        "creature_banks_verified": REQUIRED_CREATURE_BANKS,
        "review_rules": {
            "separate_save": "user://dragon_house_iter1_owner_review.json",
            "candidate_room_art_does_not_overwrite_owner_approved_assets": True,
            "candidate_guests_autonomy_enabled": False,
            "media_hotspots_require_explicit_binding": True,
            "shurshun_owner": "RES_03",
            "unknown_pet_ownership_remains_unknown": True,
        },
    })

    print(
        "ITER1_OVERLAY_PASS "
        f"teea006_layers={t6_layers} stations={station_count} "
        f"guest_art={guest_art} creatures={len(REQUIRED_CREATURE_BANKS)}"
    )

if __name__ == "__main__":
    main()
