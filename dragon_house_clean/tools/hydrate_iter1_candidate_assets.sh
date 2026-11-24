#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dragon-house-iter1-assets.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

T6_URL="https://d2ol7oe51mr4n9.cloudfront.net/user_3JdI9kJ82xObF8Bi3EgU4P6DaoR/b50aa9af-cd2c-4101-b16a-553e561c9c55.zip"
T6_SHA="5ae489046eefb6dc3718f2334945bb6fc7786dc59fc0758060e7f7e1d010e275"
T7_URL="https://d2ol7oe51mr4n9.cloudfront.net/user_3JdI9kJ82xObF8Bi3EgU4P6DaoR/13095c35-c1b0-4b5d-b0cf-9a0a7dbba489.zip"
T7_SHA="05f734b2af745a062a4942653834e38149b10301c9bb035b4682ae7004a78cbb"
T7_CLOSURE_URL="https://d2ol7oe51mr4n9.cloudfront.net/user_3JdI9kJ82xObF8Bi3EgU4P6DaoR/b5c3b121-8d02-4aae-b278-499c886f6033.zip"
T7_CLOSURE_SHA="abc63bc791fb5bd90e08dcc57bf9447df68385373675fec2ecd4a928f562292b"

download_verify() {
  local url="$1" sha="$2" out="$3"
  curl -fLsS --retry 3 --retry-delay 2 -o "$out" "$url"
  printf '%s  %s\n' "$sha" "$out" | sha256sum -c -
}

download_verify "$T6_URL" "$T6_SHA" "$TMP/teea006.zip"
download_verify "$T7_URL" "$T7_SHA" "$TMP/teea007.zip"
download_verify "$T7_CLOSURE_URL" "$T7_CLOSURE_SHA" "$TMP/teea007_closure.zip"

mkdir -p "$TMP/t6" "$TMP/t7"
unzip -q "$TMP/teea006.zip" -d "$TMP/t6"
unzip -q "$TMP/teea007.zip" -d "$TMP/t7"

T6_MARKER="$(find "$TMP/t6" -type f -path '*/assets/rooms/music/R1/backdrop.png' -print -quit)"
T7_MARKER="$(find "$TMP/t7" -type f -path '*/assets/props/dragon_mug_lod0_empty.glb' -print -quit)"
test -n "$T6_MARKER"
test -n "$T7_MARKER"
T6_ROOT="${T6_MARKER%/assets/rooms/music/R1/backdrop.png}"
T7_ROOT="${T7_MARKER%/assets/props/dragon_mug_lod0_empty.glb}"

STATION_DST="$ROOT/data/integration_candidates/TEEA006_station_source.json"
rm -f "$STATION_DST"
python3 - "$T6_ROOT" "$STATION_DST" <<'PY'
import json, pathlib, shutil, sys
root = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
matches = []
for p in root.rglob("*.json"):
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except Exception:
        continue
    variants = data.get("room_variants")
    if not isinstance(variants, dict):
        continue
    count = sum(len(v.get("stations", [])) for v in variants.values()
                if isinstance(v, dict) and isinstance(v.get("stations", []), list))
    if count == 31:
        matches.append(p)
if len(matches) == 1:
    out.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(matches[0], out)
    print("TEEA006_STATION_SOURCE_FOUND", matches[0])
elif len(matches) > 1:
    normalized = []
    for p in matches:
        data = json.loads(p.read_text(encoding="utf-8"))
        normalized.append((json.dumps(data, sort_keys=True, separators=(",", ":")), p))
    if all(x[0] == normalized[0][0] for x in normalized):
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(normalized[0][1], out)
        print("TEEA006_STATION_SOURCE_FOUND_EQUIVALENT", normalized[0][1])
    else:
        raise SystemExit("multiple non-equivalent exact-31 TEEA006 station sources in immutable ZIP")
else:
    print("TEEA006_STATION_SOURCE_GAP: immutable ZIP contains no valid exact-31 room_variants manifest")
PY

T6_DST="$ROOT/assets/room_candidates/TEEA_INT_20261123_006"
T7_DST="$ROOT/assets/room_candidates/TEEA_INT_20261123_007"
rm -rf "$T6_DST" "$T7_DST"
mkdir -p "$T6_DST" "$T7_DST"

for room in music cinema artifact workshop; do
  test -d "$T6_ROOT/assets/rooms/$room"
  mkdir -p "$T6_DST/$room"
  cp -R "$T6_ROOT/assets/rooms/$room/." "$T6_DST/$room/"
done

for room in guest_centaur guest_vampire guest_miu; do
  if [ -d "$T7_ROOT/assets/rooms/$room" ]; then
    mkdir -p "$T7_DST/$room"
    cp -R "$T7_ROOT/assets/rooms/$room/." "$T7_DST/$room/"
  fi
done

mkdir -p "$ROOT/assets/props"
for pattern in dragon_mug_* media_holder_* dragon_fur_rest_mat.*; do
  found=0
  for src in "$T7_ROOT"/assets/props/$pattern; do
    if [ -e "$src" ]; then
      cp -f "$src" "$ROOT/assets/props/"
      found=1
    fi
  done
  if [ "$found" -eq 0 ]; then
    echo "WARNING: TEEA007 runtime prop pattern missing: $pattern" >&2
  fi
done

python3 "$ROOT/tools/build_iter1_review_overlay.py"
echo "ITER1_HYDRATE_PASS t6_sha=$T6_SHA t7_sha=$T7_SHA closure_sha=$T7_CLOSURE_SHA"
