extends RefCounted
## Book supports are measured in actual imported triangles; this manifest is
## bound to the source plans, compiled layouts, and I89 service overlay.
const PATH="res://data/interior_v2/book_supports_qa.json"
const SOURCE="res://data/interior_v2/dense_v2_source.zip"
const SERVICES="res://data/interior_v2/services_qa.json"
const ROOMS={"L2_library":60,"L0_reading":65}
var rooms:Dictionary={}
func initialize()->bool:
 var f:=FileAccess.open(PATH,FileAccess.READ)
 if f==null:return false
 var data=JSON.parse_string(f.get_as_text())
 if typeof(data)!=TYPE_DICTIONARY or int(data.get("schema",0))!=1 or data.get("source_sha256","")!=FileAccess.get_sha256(SOURCE) or data.get("services_sha256","")!=FileAccess.get_sha256(SERVICES):return false
 for i in range(3):
  if data.get("compiled_sha256",{}).get(str(i),"")!=FileAccess.get_sha256("res://data/interior_v2/dense_v2_compiled_%d.zip"%i):return false
 var raw:Dictionary=data.get("rooms",{})
 if raw.size()!=ROOMS.size():return false
 for k in ROOMS:
  if not raw.has(k) or raw[k].get("slots",[]).size()!=ROOMS[k] or not raw[k].get("withheld_old",[]).is_empty():return false
 rooms=raw
 return true
func apply(compiled:Dictionary,row:Dictionary)->bool:
 var k:String=compiled.key
 if not rooms.has(k):return true
 var hosts:Dictionary={}
 for p in compiled.placements:
  if p.get("asset","")=="wooden_bookshelf_worn" and p.get("fits",false) and not p.get("station_candidates",[]).is_empty():hosts[p.id]=p
 if hosts.size()!=2:return false
 var seen:Dictionary={}
 var old:=0
 var boxes:Array=[]
 var translated:Array=[]
 for s in rooms[k].slots:
  var id:String=str(s.get("id",""))
  var host:Dictionary=hosts.get(str(s.get("furniture_id","")),{})
  if id=="" or seen.has(id) or host.is_empty() or not id.begins_with(host.id+"."):return false
  if s.get("support_evidence","")!="ACTUAL_IMPORTED_TRIANGLE_FOOTPRINT_CLEARANCE":return false
  if s.get("xyz",[]).size()!=3 or s.get("instance_xyz",[]).size()!=3 or s.get("dimensions",[]).size()!=3 or s.get("box_min",[]).size()!=3 or s.get("box_max",[]).size()!=3:return false
  var station:String=str(s.get("station_id",""))
  if not host.get("station_candidates",[]).any(func(x):return str(x.get("station_candidate_id",""))==station and x.get("kind","")=="standing"):return false
  # Immutable support measurement in host-local translation space.
  # A rigid editor move carries both physical book and slot by the same
  # delta; support IDs, dimensions, and catalog ownership are unchanged.
  var slot:Dictionary=s.duplicate(true)
  var inst:=Vector3(s.instance_xyz[0],s.instance_xyz[1],s.instance_xyz[2])
  var moved:=Vector3(host.pivot[0],host.pivot[1],host.pivot[2])-inst
  for field in ["xyz","instance_xyz","box_min","box_max"]:
   var p:Array=slot[field]
   slot[field]=[float(p[0])+moved.x,float(p[1])+moved.y,float(p[2])+moved.z]
  var lo:=Vector3(slot.box_min[0],slot.box_min[1],slot.box_min[2])
  var hi:=Vector3(slot.box_max[0],slot.box_max[1],slot.box_max[2])
  var box:=AABB(lo,hi-lo)
  if not lo.is_finite() or not hi.is_finite() or minf(box.size.x,minf(box.size.y,box.size.z))<=0 or boxes.any(func(x):return box.intersects(x)):return false
  boxes.append(box)
  if host.get("support_slots",[]).any(func(x):return x.get("room_slot_id","")==id):old+=1
  seen[id]=true
  translated.append(slot)
 if old!=20:return false
 row["measured_book_slots"]=translated
 return true
