extends RefCounted
## Measured service overlay is bound to the exact dense partitions and
## artifact grid geometry. No stale geometry fallback or private room entry.
const PATH="res://data/interior_v2/services_qa.json"
const SOURCE="res://data/interior_v2/dense_v2_source.zip"
const GRIDS="res://data/interior_v2/artifact_grids_qa.json"
const KEYS=["L0_workshop","L1_gallery","L1_study","L2_library","L0_reading","L0_kitchen","L0_cinema","L2_cinema","L2_music","L1_lounge","L2_lounge"]
var rooms:Dictionary={}
func initialize()->bool:
 var f:=FileAccess.open(PATH,FileAccess.READ)
 if f==null:return false
 var doc=JSON.parse_string(f.get_as_text())
 if typeof(doc)!=TYPE_DICTIONARY or int(doc.get("schema",0))!=1 or doc.get("source_sha256","")!=FileAccess.get_sha256(SOURCE) or doc.get("grid_sha256","")!=FileAccess.get_sha256(GRIDS):return false
 for i in range(3):
  if doc.get("compiled_sha256",{}).get(str(i),"")!=FileAccess.get_sha256("res://data/interior_v2/dense_v2_compiled_%d.zip"%i):return false
 var raw:Dictionary=doc.get("rooms",{})
 if raw.size()!=KEYS.size():return false
 for k in KEYS:
  if not raw.has(k):return false
  var row:Dictionary=raw[k]
  if row.get("services",[]).size()!=2 or row.get("cups",[]).size()!=2:return false
  var ids:Dictionary={}
  for p in row.get("placements",[]):
   var id:String=str(p.get("id",""))
   if id=="" or ids.has(id) or not p.get("fits",false) or p.get("role","")!="supported_decor" or not ResourceLoader.exists(p.get("path",""),"PackedScene"):return false
   ids[id]=p
  var types:Dictionary={}
  for source in row.services:
   if not ids.has(source.id) or types.has(source.type) or not source.type in ["COFFEE_NOOK","BAR"] or source.get("approach",[]).size()!=2:return false
   types[source.type]=true
  for cup in row.cups:
   if cup.get("xyz",[]).size()!=3 or cup.get("approach",[]).size()!=2 or not cup.get("asset","") in ["candidate_dragon_mug_red","candidate_guest_mug_blue"] or float(cup.get("scale",0))<=0:return false
 rooms=raw
 return true

func apply(compiled:Dictionary)->bool:
 var key:String=compiled.key
 if not rooms.has(key):return true
 var spec:Dictionary=rooms[key]
 var ids:Dictionary={}
 for p in compiled.placements:ids[p.id]=p
 for p in spec.placements:
  if ids.has(p.id) or not ids.has(p.support_host):return false
  ids[p.id]=p
 for c in spec.cups:
  if not ids.has(c.furniture_id):return false
 for p in spec.placements:compiled.placements.append(p.duplicate(true))
 compiled["service_sources"]=spec.services.duplicate(true)
 compiled["service_cups"]=spec.cups.duplicate(true)
 var included:Dictionary={}
 for p in spec.placements:included[p.id]=true
 compiled.pending=compiled.pending.filter(func(p):return not included.has(p.id))
 return true
