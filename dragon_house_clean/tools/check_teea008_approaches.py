#!/usr/bin/env python3
"""Independent geometry-grid reachability check. Not live body/pose QA."""
import collections,json,math,pathlib,sys
path=pathlib.Path(sys.argv[1])
rooms=json.loads(path.read_text())["items"]
checked=0
missing=[]
failed=[]
for room in rooms:
    w=float(room["width_m"]); radius=.325; step=.05; back=-1.95; front=1.65
    obstacles=[(i["bounds_min_m"],i["bounds_max_m"]) for i in room["instances"] if i["placement_policy"]=="floor_fixed"]
    obstacles += [(i["bounds_min_m"],i["bounds_max_m"]) for i in room.get("preserve_existing_runtime_geometry",[])]
    n=round(w/step); m=round((front-back)/step)
    def xy(pt): return (-w/2+pt[0]*step,back+pt[1]*step)
    def clear(pt):
        x,z=xy(pt)
        if not (-w/2+radius-1e-6<=x<=w/2-radius+1e-6 and back+radius-1e-6<=z<=front-radius+1e-6): return False
        return all(math.hypot(max(lo[0]-x,0,x-hi[0]),max(lo[2]-z,0,z-hi[2]))>=radius-1e-6 for lo,hi in obstacles)
    seen={v for v in [(i,round((1.30-back)/step)) for i in range(n+1)] if clear(v)}
    q=collections.deque(seen)
    while q:
        i,j=q.popleft()
        for v in [(i+1,j),(i-1,j),(i,j+1),(i,j-1)]:
            if 0<=v[0]<=n and 0<=v[1]<=m and v not in seen and clear(v):
                seen.add(v); q.append(v)
    for obj in room["instances"]:
        for s in obj.get("station_candidates",[]):
            key=(room["variant_id"],s["station_candidate_id"]); a=s.get("room_approach_xz")
            if not a: missing.append(key); continue
            checked+=1; ix=round((a[0]+w/2)/step); iz=round((a[1]-back)/step)
            if not any((ix+dx,iz+dz) in seen and math.dist(xy((ix+dx,iz+dz)),a)<=step*1.5 for dx in [-1,0,1] for dz in [-1,0,1]):
                failed.append(key)
print(json.dumps({"rooms":len(rooms),"approaches":checked,"reachable":checked-len(failed),"missing":missing,"failed":failed},indent=2))
if failed or len(rooms)!=33 or checked!=82 or len(missing)!=2: raise SystemExit(1)
