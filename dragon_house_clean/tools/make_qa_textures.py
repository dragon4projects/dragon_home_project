#!/usr/bin/env python3
"""Generate lightweight original QA-only tiling textures; no downloaded game art."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

OUT=Path(__file__).resolve().parents[1]/"assets"/"textures"
OUT.mkdir(parents=True,exist_ok=True)
SIZE=256
yy,xx=np.indices((SIZE,SIZE),dtype=np.float32)

def periodic_noise(seed,kind):
    rng=np.random.default_rng(seed)
    total=np.zeros((SIZE,SIZE),dtype=np.float32)
    for grid,weight in [(3,0.46),(7,0.29),(17,0.17),(43,0.08)]:
        small=(rng.random((grid,grid))*255).astype(np.uint8)
        # Repeated margins make large-scale texture transitions less visible.
        im=Image.fromarray(small,"L").resize((SIZE,SIZE),Image.Resampling.BICUBIC)
        arr=np.asarray(im).astype(np.float32)
        total+=(arr-127)*weight
    return total

def rock(seed,palette,grid=4):
    rng=np.random.default_rng(seed)
    variants=[]
    for i in range(grid):
        for j in range(grid):
            variants.append((i,j,((i+0.5+rng.uniform(-.28,.28))*SIZE/grid)%SIZE,
                       ((j+0.5+rng.uniform(-.28,.28))*SIZE/grid)%SIZE,
                       rng.uniform(-10,10)))
    best=np.full((SIZE,SIZE),999999.,dtype=np.float32)
    second=np.full_like(best,999999.)
    shade=np.zeros_like(best)
    for _,_,x,y,tone in variants:
        dx=np.abs(xx-x);dx=np.minimum(dx,SIZE-dx)
        dy=np.abs(yy-y);dy=np.minimum(dy,SIZE-dy)
        dist=dx*dx+dy*dy
        better=dist<best
        second=np.where(better,best,np.minimum(second,dist))
        shade=np.where(better,tone,shade)
        best=np.minimum(best,dist)
    noise=periodic_noise(seed+1,'rock')
    seam=np.exp(-np.maximum(second-best,0)/145.0)*14.0
    edge=np.clip((xx%16-1)/6.0,0,1)
    value=shade+noise*.25-seam+np.sin(yy/25.0)*1.4
    colors=np.stack([palette[k]+value*(.8+0.1*k) for k in range(3)],axis=-1)
    colors=np.clip(colors,0,255).astype("uint8")
    return Image.fromarray(colors,"RGB")

def wood(seed):
    rng=np.random.default_rng(seed)
    noise=periodic_noise(seed+2,'wood')
    wave=np.sin((yy+2.2*np.sin(xx/17.0)+4.0*np.sin(xx/61.0))/6.0)
    fine=np.sin((yy+np.sin(xx/29.)*2.3)/1.9)
    v=noise*.17+wave*9+fine*2
    colors=np.stack([133+v,102+v*.8,80+v*.55],axis=-1)
    return Image.fromarray(np.clip(colors,0,255).astype("uint8"),"RGB")

for name,im in [
    ("basalt",rock(1207,[101,86,83],4)),
    ("floor",rock(5023,[132,110,101],5)),
    ("wood",wood(9914))]:
    outfile=OUT/(name+".jpg")
    im.save(outfile,quality=83,optimize=True)
    print(outfile.name,outfile.stat().st_size)

