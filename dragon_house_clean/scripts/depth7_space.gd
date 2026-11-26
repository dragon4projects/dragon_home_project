extends RefCounted
## Physical depth contract, front to back. Shared by the hearth and future room migrations.
const EDGES: Array[float] = [1.65,0.65,-0.85,-1.75,-3.60,-4.50,-6.65,-8.05]
const FRONT:float=1.65
const BACK:float=-8.05
const NEAR_CENTER:float=1.15
const FAR_CENTER:float=-7.35
const NEAR_SCALE:float=1.0
const FAR_SCALE:float=0.60
static func band(z:float)->int:
 for i in range(7):
  if z<=EDGES[i]+0.0001 and z>=EDGES[i+1]-0.0001:return i+1
 return 0
static func center(index:int)->float:
 assert(index>=1 and index<=7)
 return (EDGES[index-1]+EDGES[index])*0.5
static func passage(z:float)->bool:
 return band(z) in [1,3,5]
static func scale_at(z:float)->float:
 return lerpf(FAR_SCALE,NEAR_SCALE,clampf((z-FAR_CENTER)/(NEAR_CENTER-FAR_CENTER),0.0,1.0))
static func enabled_for(room:Dictionary)->bool:
 return bool(room.get("depth7",false)) and str(room.get("type",""))!="lift"
