#!/usr/bin/env python3
"""Private source-vs-bank comparison sheet for manual identity/alpha review.

Reads the LFS checkout, never edits the original images. This is a review
artifact, not proof of artistic approval. Never publish on a public webpage.
"""
from __future__ import annotations
import argparse, json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps

BG=(27,26,32)
CARD=(44,40,47)
TEXT=(236,225,215)
MUTED=(184,169,159)
MISSING=(186,102,92)
W,H=470,380

def font(size):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
              "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf"]:
        if Path(p).exists():
            return ImageFont.truetype(p,size)
    return ImageFont.load_default()

def open_rgba(root:Path,relative:str):
    if not relative or ".." in Path(relative).parts or relative.startswith("/"):
        return None
    path=root/relative
    if not path.is_file():
        return None
    try:
        with Image.open(path) as im:
            if im.format not in {"PNG","WEBP","JPEG"}:
                return None
            return im.convert("RGBA")
    except Exception:
        return None

def pick_bank(resident):
    outfits=resident.get("wardrobes",{})
    order=[]
    if resident.get("default_wardrobe") in {"HOME","CITY","SHORT"}:
        order.append(resident["default_wardrobe"])
    for key in ["HOME","CITY","SHORT"]:
        if key not in order:order.append(key)
    for key in order:
        state=outfits.get(key,{}).get("states",{}).get("IDLE_S",{})
        if state.get("status")=="PASS" and state.get("frames"):
            return key,state["frames"][0]
    return "",None

def place(c,im,box):
    x,y,w,h=box
    if im is None:
        ImageDraw.Draw(c).rectangle((x,y,x+w,y+h),outline=(95,87,94),width=2)
        return
    fit=ImageOps.contain(im,(w,h),Image.Resampling.LANCZOS)
    c.alpha_composite(fit,(x+(w-fit.width)//2,y+(h-fit.height)//2))

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--project",required=True,type=Path)
    ap.add_argument("--output",required=True,type=Path)
    args=ap.parse_args()
    root=args.project
    doc=json.loads((root/"data/asset_registry_nov2026.json").read_text(encoding="utf8"))
    residents=doc["residents"]
    cols=5
    rows=math.ceil(len(residents)/cols)
    sheet=Image.new("RGBA",(cols*W,rows*H+52),BG+(255,))
    d=ImageDraw.Draw(sheet)
    d.text((20,10),"DRAGON HOUSE / PRIVATE IMAGE REVIEW  —  technical candidates, NOT artist-approved",
           fill=TEXT,font=font(21))
    count=0
    for i,(id,actor) in enumerate(sorted(residents.items())):
        x=(i%cols)*W
        y=(i//cols)*H+52
        d.rounded_rectangle((x+7,y+7,x+W-7,y+H-7),radius=10,fill=CARD+(255,))
        name=str(actor.get("display_name",id))
        d.text((x+18,y+16),id+"  "+name[:25],fill=TEXT,font=font(18))
        outfit,path=pick_bank(actor)
        reference=(actor.get("identity_references") or [None])[0]
        ref_img=open_rgba(root,reference)
        sprite=open_rgba(root,path)
        if sprite is not None:count+=1
        d.text((x+25,y+49),"IDENTITY REFERENCE",fill=MUTED,font=font(12))
        d.text((x+245,y+49),("IDLE_S  "+outfit) if outfit else "MISSING BANK",
               fill=MUTED if outfit else MISSING,font=font(12))
        place(sheet,ref_img,(x+18,y+75,202,242))
        place(sheet,sprite,(x+240,y+75,202,242))
        status="BANK QA PASS — NOT APPROVED" if sprite else "NO TECHNICAL BANK"
        d.text((x+20,y+335),status,fill=MUTED if sprite else MISSING,font=font(14))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    sheet.convert("RGB").save(args.output,optimize=True)
    print(json.dumps({"cards":len(residents),"sprite_banks_with_pixels":count,
        "canvas":list(sheet.size),"output":str(args.output)}))

if __name__=="__main__":
    main()

