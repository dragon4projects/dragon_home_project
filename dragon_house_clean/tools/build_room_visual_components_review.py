#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

MODULE_W = 4.8
FLOOR_Y = 0.025
BACK_DECOR_Z = -1.70
DEFAULT_FURNITURE_Z = -0.85
ALPHA_THRESHOLD = 5
MIN_ALPHA_PIXELS = 20
NEAR_X_CLUSTER_M = 0.16

BATCHES = (
    ("TEEA_INT_20261123_005", "TEEA005_station_source.json",
     ("common","study","rest","library")),
    ("TEEA_INT_20261123_006", "TEEA006_station_source.json",
     ("music","cinema","artifact","workshop")),
)

def sha256(path: Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024), b""):
            h.update(block)
    return h.hexdigest()

def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def write(path: Path, data) -> None:
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

def variant_width(label: str) -> int:
    if not label.startswith("R"):
        raise ValueError(label)
    return int(label[1:])

def global_x(raw: dict, width: int) -> float:
    module_index=int(raw.get("module_index",0))
    local=float(raw.get("cell_local_x",raw.get("group_local_x",0.0)))
    return (module_index-(width-1)/2.0)*MODULE_W+local

def furniture_refs(entry: dict, width: int) -> list[dict]:
    grouped={}
    for raw in entry.get("stations",[]):
        fid=str(raw.get("furniture_id") or raw.get("id","station"))
        grouped.setdefault(fid,[]).append({
            "x":global_x(raw,width),
            "z":float(raw["cell_local_z"]),
            "confidence":str(raw.get("confidence","STATION_SOURCE")),
        })
    result=[]
    for fid,items in grouped.items():
        result.append({
            "id":fid,
            "x":sum(x["x"] for x in items)/len(items),
            "z":sum(x["z"] for x in items)/len(items),
            "confidence":"station_exact_xz",
            "source_confidence":";".join(sorted(set(x["confidence"] for x in items))),
        })
    for raw in entry.get("non_station_furniture",[]):
        result.append({
            "id":str(raw["furniture_id"]),
            "x":global_x(raw,width),
            "z":float(raw["authored_center_z"]),
            "confidence":"non_station_exact_xz",
            "source_confidence":str(raw.get("confidence","NON_STATION_SOURCE")),
        })
    result.sort(key=lambda x:(x["x"],x["id"]))
    return result

def alpha(path: Path) -> tuple[np.ndarray,int,int]:
    im=Image.open(path).convert("RGBA")
    arr=np.asarray(im)
    return arr[...,3] > ALPHA_THRESHOLD, im.width, im.height

def alpha_bbox(mask: np.ndarray, x0: int=0, x1: int|None=None):
    if x1 is None:
        x1=mask.shape[1]
    sub=mask[:,x0:x1]
    ys,xs=np.nonzero(sub)
    if len(xs)<MIN_ALPHA_PIXELS:
        return None
    left=int(xs.min())+x0
    right=int(xs.max())+x0+1
    top=int(ys.min())
    bottom=int(ys.max())+1
    return [left,top,right-left,bottom-top]

def cluster_refs(refs: list[dict]) -> list[list[dict]]:
    clusters=[]
    for ref in refs:
        if clusters and abs(ref["x"]-sum(x["x"] for x in clusters[-1])/len(clusters[-1])) < NEAR_X_CLUSTER_M:
            clusters[-1].append(ref)
        else:
            clusters.append([ref])
    return clusters

def furniture_components(path: Path, refs: list[dict], width: int) -> list[dict]:
    mask,w,h=alpha(path)
    pixel_size=(MODULE_W*width)/float(w)
    if not refs:
        box=alpha_bbox(mask)
        if box is None:
            return []
        x0,y0,bw,bh=box
        return [{
            "id":"unresolved_furniture",
            "rect":box,
            "x":round(((x0+bw/2.0)-w/2.0)*pixel_size,6),
            "y":round(FLOOR_Y+bh*pixel_size/2.0,6),
            "z":DEFAULT_FURNITURE_Z,
            "anchor_mode":"floor",
            "pixel_size":round(pixel_size,9),
            "confidence":"role_default_z",
            "source_anchor":"UNRESOLVED_NO_FURNITURE_SOURCE",
        }]

    clusters=cluster_refs(refs)
    centers=[sum(r["x"] for r in cluster)/len(cluster) for cluster in clusters]
    boundaries=[-math.inf]
    for a,b in zip(centers,centers[1:]):
        boundaries.append((a+b)/2.0)
    boundaries.append(math.inf)
    out=[]
    for i,cluster in enumerate(clusters):
        left_m,right_m=boundaries[i],boundaries[i+1]
        x0=0 if math.isinf(left_m) else max(0,int(math.floor(w/2.0+left_m/pixel_size)))
        x1=w if math.isinf(right_m) else min(w,int(math.ceil(w/2.0+right_m/pixel_size)))
        box=alpha_bbox(mask,x0,x1)
        if box is None:
            continue
        bx,by,bw,bh=box
        if len(cluster)==1:
            ref=cluster[0]
            item_id=ref["id"]
            z=ref["z"]
            confidence=ref["confidence"]
            source_anchor=ref["id"]
            source_confidence=ref.get("source_confidence","")
        else:
            item_id="composite_"+"_".join(r["id"] for r in cluster)
            z=sum(r["z"] for r in cluster)/len(cluster)
            confidence="composite_multi_anchor"
            source_anchor=";".join(r["id"] for r in cluster)
            source_confidence=";".join(r.get("source_confidence","") for r in cluster)
        out.append({
            "id":item_id,
            "rect":box,
            "x":round(((bx+bw/2.0)-w/2.0)*pixel_size,6),
            "y":round(FLOOR_Y+bh*pixel_size/2.0,6),
            "z":round(z,6),
            "anchor_mode":"floor",
            "pixel_size":round(pixel_size,9),
            "confidence":confidence,
            "source_anchor":source_anchor,
            "source_confidence":source_confidence,
        })
    return out

def back_decor_components(path: Path, width: int) -> list[dict]:
    raw,w,h=alpha(path)
    work=ndimage.binary_dilation(raw,iterations=1)
    labels,n=ndimage.label(work)
    slices=ndimage.find_objects(labels)
    pixel_size=(MODULE_W*width)/float(w)
    result=[]
    floor_line=h-1
    for label_id,sl in enumerate(slices,1):
        if sl is None:
            continue
        local=(labels[sl]==label_id) & raw[sl]
        if int(local.sum())<MIN_ALPHA_PIXELS:
            continue
        ys,xs=np.nonzero(local)
        yslice,xslice=sl
        x0=int(xs.min())+xslice.start
        x1=int(xs.max())+xslice.start+1
        y0=int(ys.min())+yslice.start
        y1=int(ys.max())+yslice.start+1
        bw,bh=x1-x0,y1-y0
        cx=(x0+x1)/2.0
        cy=(y0+y1)/2.0
        floor_anchor=(y1 >= floor_line-8)
        if floor_anchor:
            y=FLOOR_Y+bh*pixel_size/2.0
            anchor_mode="floor"
        else:
            y=FLOOR_Y+(floor_line-cy)*pixel_size
            anchor_mode="wall"
        result.append({
            "id":f"decor_{len(result):02d}",
            "rect":[x0,y0,bw,bh],
            "x":round((cx-w/2.0)*pixel_size,6),
            "y":round(y,6),
            "z":BACK_DECOR_Z,
            "anchor_mode":anchor_mode,
            "pixel_size":round(pixel_size,9),
            "confidence":"rear_plane_from_alpha",
            "source_anchor":"projected_back_wall",
        })
    result.sort(key=lambda x:(x["x"],x["y"],x["id"]))
    for i,item in enumerate(result):
        item["id"]=f"decor_{i:02d}"
    return result

def build(root: Path) -> dict:
    cand=root/"data"/"integration_candidates"
    variants={}
    report={}
    for batch,station_file,rooms in BATCHES:
        station_path=cand/station_file
        if not station_path.is_file():
            raise SystemExit(f"missing station source: {station_path}")
        stations=load(station_path)
        batch_root=root/"assets"/"room_candidates"/batch
        batch_report={}
        for room in rooms:
            room_dir=batch_root/room
            if not room_dir.is_dir():
                continue
            for variant_dir in sorted(room_dir.glob("R*")):
                if not variant_dir.is_dir():
                    continue
                variant=variant_dir.name
                width=variant_width(variant)
                key=f"{room}/{variant}"
                entry=stations.get("room_variants",{}).get(key,{})
                refs=furniture_refs(entry,width)
                role_components={}
                for role,builder in (
                    ("furniture_back",lambda p: furniture_components(p,refs,width)),
                    ("back_decor",lambda p: back_decor_components(p,width)),
                ):
                    source=variant_dir/f"{role}.png"
                    if not source.is_file():
                        continue
                    comps=builder(source)
                    if not comps:
                        continue
                    role_components[role]={
                        "source_path":source.relative_to(root).as_posix(),
                        "source_sha256":sha256(source),
                        "components":comps,
                    }
                if not role_components:
                    continue
                variants[key]={
                    "source_batch":batch,
                    "suppress_roles":sorted(role_components.keys()),
                    "role_components":role_components,
                }
                unresolved=sum(
                    1 for r in role_components.get("furniture_back",{}).get("components",[])
                    if r.get("confidence") in ("role_default_z","composite_multi_anchor")
                )
                batch_report[key]={
                    "furniture_refs":len(refs),
                    "furniture_components":len(role_components.get("furniture_back",{}).get("components",[])),
                    "back_decor_components":len(role_components.get("back_decor",{}).get("components",[])),
                    "unresolved_or_composite":unresolved,
                }
        report[batch]=batch_report
    return {
        "schema":1,
        "review_only":True,
        "approved":False,
        "owner_approved":False,
        "note":"Deterministic alpha/anchor component overlay generated from immutable hydrated TEEA005/006 PNGs plus exact station/non-station furniture sources. composite_multi_anchor is an explicit unresolved 2D overlap, not invented exact Z.",
        "pixel_size":0.003125,
        "variants":variants,
        "report":report,
    }

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--root",type=Path,default=Path(__file__).resolve().parents[1])
    parser.add_argument("--out",type=Path)
    args=parser.parse_args()
    root=args.root.resolve()
    out=args.out or root/"data"/"integration_candidates"/"room_visual_components_iter2_review.json"
    doc=build(root)
    write(out,doc)
    variants=len(doc["variants"])
    furn=sum(len(v.get("role_components",{}).get("furniture_back",{}).get("components",[])) for v in doc["variants"].values())
    decor=sum(len(v.get("role_components",{}).get("back_decor",{}).get("components",[])) for v in doc["variants"].values())
    composites=sum(1 for v in doc["variants"].values() for x in v.get("role_components",{}).get("furniture_back",{}).get("components",[]) if x.get("confidence")=="composite_multi_anchor")
    print(f"ITER2_COMPONENT_OVERLAY_PASS variants={variants} furniture={furn} decor={decor} composites={composites} out={out}")

if __name__=="__main__":
    main()
