#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CAND = ROOT / "data" / "integration_candidates"
T5 = CAND / "TEEA005_interiors_source.json"
T5_STATION_SOURCE = CAND / "TEEA005_station_source.json"
T6 = ROOT / "data" / "asset_proposals" / "TEEA_INT_20261123_006_interiors.json"
T6_STATION_SOURCE = CAND / "TEEA006_station_source.json"
BASE_FURN = ROOT / "data" / "furniture_interactions_v1.json"
ROOM_OUT = CAND / "ITER1_ROOM_ART_REVIEW.json"
FURN_OUT = CAND / "furniture_interactions_iter1_review.json"
REPORT_OUT = CAND / "ITER1_INTAKE_REPORT.json"

T5_PREFIX = "assets/room_candidates/TEEA_INT_20261123_005"
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
KIND_MAP = {
    "seat":"seat", "floor_rest":"floor_rest", "work":"work",
    "standing":"standing", "view":"standing",
}

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

def add_visual_batch(room_types: dict, doc: dict, prefix: str, batch: str,
                     expected_variants: int, expected_layers: int) -> tuple[int,int]:
    if doc.get("approved") is not False or doc.get("owner_approved", False) is True:
        raise SystemExit(f"{batch} candidate approval contract mismatch")
    raw_types = doc.get("room_types")
    if not isinstance(raw_types, dict):
        raise SystemExit(f"{batch} room_types missing")
    variants_count = 0
    layers_count = 0
    for room_type, variants in raw_types.items():
        if not isinstance(variants, dict):
            continue
        out_type = room_types.setdefault(room_type, {})
        for variant, entry in variants.items():
            variants_count += 1
            out_layers = []
            for item in entry.get("layers", []):
                src = str(item["path"])
                if not src.startswith("assets/rooms/"):
                    raise SystemExit(f"unsafe {batch} path: {src}")
                rel_after = src[len("assets/rooms/"):]
                candidate_rel = f"{prefix}/{rel_after}"
                candidate_abs = ROOT / candidate_rel
                if not candidate_abs.is_file():
                    raise SystemExit(f"missing {batch} candidate file: {candidate_rel}")
                expected = str(item.get("sha256",""))
                actual = sha(candidate_abs)
                if expected and actual != expected:
                    raise SystemExit(f"{batch} SHA mismatch: {candidate_rel}")
                copied = dict(item)
                copied["path"] = candidate_rel
                copied["approved"] = False
                copied["owner_approved"] = False
                copied["candidate_review"] = True
                copied["source_batch"] = batch
                out_layers.append(copied)
                layers_count += 1
            if variant in out_type:
                raise SystemExit(f"duplicate review room variant: {room_type}/{variant}")
            out_type[variant] = {
                "layers": out_layers,
                "source_batch": batch,
                "approved": False,
                "owner_approved": False,
            }
    if variants_count != expected_variants or layers_count != expected_layers:
        raise SystemExit(
            f"{batch} expected {expected_variants} variants/{expected_layers} layers, "
            f"got {variants_count}/{layers_count}"
        )
    return variants_count, layers_count

def apply_station_batch(overrides: dict, source: Path, batch: str,
                        allowed_rooms: set[str], expected_count: int,
                        required: bool) -> tuple[int, bool, str, float | None]:
    if not source.is_file():
        if required:
            raise SystemExit(f"{batch} station source missing after hydration")
        return 0, True, "MISSING_EXACT_SOURCE", None
    anchors = load(source)
    if anchors.get("approved") is not False:
        raise SystemExit(f"{batch} station approval contract mismatch")
    variants = anchors.get("room_variants")
    if not isinstance(variants, dict):
        raise SystemExit(f"{batch} station room_variants missing")

    count = 0
    batch_keys: set[str] = set()
    for variant_key, entry in variants.items():
        if "/" not in variant_key:
            continue
        room, variant = variant_key.split("/", 1)
        if room not in allowed_rooms:
            continue
        width = int(variant[1:])
        for module_index in range(width):
            key = f"{room}:{variant}:{module_index}"
            overrides[key] = []
            batch_keys.add(key)
        for raw in entry.get("stations", []):
            module_index = int(raw["module_index"])
            key = f"{room}:{variant}:{module_index}"
            artist_pose = str(raw.get("pose_hint","IDLE_S"))
            artist_kind = str(raw.get("kind","standing"))
            if artist_pose not in POSE_MAP or artist_kind not in KIND_MAP:
                raise SystemExit(
                    f"unsupported {batch} station semantics: {raw.get('id')}"
                )
            overrides[key].append({
                "id": str(raw["id"]),
                "x": float(raw["cell_local_x"]),
                "z": float(raw["cell_local_z"]),
                "kind": KIND_MAP[artist_kind],
                "furniture_id": str(raw.get("furniture_id","")),
                "pose_hint": POSE_MAP[artist_pose],
                "approach_z": float(raw["approach_local_z"]),
                "source_batch": batch,
                "candidate_review": True,
            })
            count += 1

    if count != expected_count:
        raise SystemExit(f"{batch} expected {expected_count} stations, got {count}")

    local_min = 999.0
    for key in sorted(batch_keys):
        items = overrides[key]
        for i, a in enumerate(items):
            for b in items[i+1:]:
                dx = float(a["x"]) - float(b["x"])
                dz = float(a["z"]) - float(b["z"])
                d = (dx*dx + dz*dz) ** 0.5
                local_min = min(local_min, d)
                if d < 0.60:
                    raise SystemExit(
                        f"{batch} review station spacing below 0.60m in {key}: {d:.4f}"
                    )
    minimum = None if local_min == 999.0 else round(local_min, 6)
    return count, False, source.relative_to(ROOT).as_posix(), minimum

def main():
    t5 = load(T5)
    t6 = load(T6)
    if t5.get("schema") != 1:
        raise SystemExit("TEEA005 schema mismatch")
    if t6.get("schema") != 2:
        raise SystemExit("TEEA006 schema mismatch")

    room_types: dict = {}
    t5_variants, t5_layers = add_visual_batch(
        room_types, t5, T5_PREFIX, "TEEA_INT_20261123_005", 8, 32)
    t6_variants, t6_layers = add_visual_batch(
        room_types, t6, T6_PREFIX, "TEEA_INT_20261123_006", 12, 40)

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
        "batch_id": "ITER2_PHYSICAL_ROOM_OWNER_REVIEW",
        "approved": False,
        "owner_approved": False,
        "review_only": True,
        "sources": {
            "teea005_payload_sha256": "5cc946bcba991d0d357b02310a16109dda866e79b8e961d76766f4aa24641fbd",
            "teea006_commit": "887e5f1c874c7fb0deb600c58c06ad4e5dafb90f",
            "teea007_commit": "996950493cc1e703abefc3659a13177160caa8d0",
        },
        "room_types": room_types,
    })

    review_furn = json.loads(json.dumps(load(BASE_FURN)))
    overrides = review_furn.setdefault("variant_cell_overrides", {})

    t5_station_count, t5_gap, t5_station_source, t5_min_spacing = apply_station_batch(
        overrides, T5_STATION_SOURCE, "TEEA_INT_20261123_005",
        {"common","study","rest","library"}, 26, True)

    t6_station_count, t6_gap, t6_station_source, t6_min_spacing = apply_station_batch(
        overrides, T6_STATION_SOURCE, "TEEA_INT_20261123_006",
        {"music","cinema","artifact","workshop"}, 31, False)

    review_furn["source"] = (
        str(review_furn.get("source",""))
        + " + ITER2 TEEA005/006 review overlays"
    )
    review_furn["review_only"] = True
    review_furn["owner_approved"] = False
    review_furn["teea005_station_source_gap"] = t5_gap
    review_furn["teea006_station_source_gap"] = t6_gap
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
        "schema": 2,
        "status": "ITER2_PHYSICAL_ROOM_OWNER_REVIEW_CANDIDATE",
        "approved": False,
        "owner_approved": False,
        "production_base": "1216e2f1a737008e3d9fea0f5d240d54a78a6ea2",
        "staging_intake": "488ed009adab7b0a27989534c8fad7a55e3ead94",
        "teea005": {
            "payload_sha256": "5cc946bcba991d0d357b02310a16109dda866e79b8e961d76766f4aa24641fbd",
            "variants": t5_variants,
            "layers": t5_layers,
            "stations_claimed": 26,
            "stations_applied": t5_station_count,
            "station_source_gap": t5_gap,
            "station_source": t5_station_source,
            "minimum_same_module_station_spacing_m": t5_min_spacing,
        },
        "teea006": {
            "commit": "887e5f1c874c7fb0deb600c58c06ad4e5dafb90f",
            "variants": t6_variants,
            "layers": t6_layers,
            "stations_claimed": 31,
            "stations_applied": t6_station_count,
            "station_source_gap": t6_gap,
            "station_source": t6_station_source,
            "minimum_same_module_station_spacing_m": t6_min_spacing,
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
            "exact_size_room_variants_only": True,
        },
    })

    print(
        "ITER2_OVERLAY_PASS "
        f"teea005={t5_layers}layers/{t5_station_count}stations "
        f"teea006={t6_layers}layers/{t6_station_count}stations "
        f"t6_station_gap={t6_gap} guest_art={guest_art} "
        f"creatures={len(REQUIRED_CREATURE_BANKS)}"
    )

if __name__ == "__main__":
    main()
