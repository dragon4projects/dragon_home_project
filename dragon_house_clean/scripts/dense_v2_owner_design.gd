extends RefCounted
## Owner review correction overlay. Source plans and stable room identities
## remain untouched. Only unbound furniture may be removed/replaced here.
const PATH="res://data/interior_v2/owner_design_qa.json"
const REPAIRED="res://assets/decor_bank/blendkit_sofa/repaired.glb"
const SHELF="res://assets/teea008_review/decor_bank/wooden_bookshelf_worn/model.gltf"
static func v(a:Array)->Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
static func a(q:Vector3)->Array:return [q.x,q.y,q.z]
static func box(p:Dictionary)->AABB:return AABB(v(p.bounds_min),v(p.bounds_max)-v(p.bounds_min))
static func bound(compiled:Dictionary,p:Dictionary)->bool:
 if not p.get("station_candidates",[]).is_empty() or not p.get("support_slots",[]).is_empty():return true
 for child in compiled.placements:
  if child.get("support_host","")==p.id or str(child.get("support_slot","")).begins_with(str(p.id)+"."):return true
 for key in ["service_sources","service_cups"]:
  if JSON.stringify(compiled.get(key,[])).contains(str(p.id)):return true
 return false
static func apply_base(compiled:Dictionary,review)->bool:
 var key:String=compiled.key
 var library:bool=key in ["L2_library","L0_reading"]
 var cinema:bool=key in ["L2_cinema","L0_cinema"]
 # Replace only unbound display cabinets/duplicate wall plants. The
 # functional bookcases, 32 seats and coffee/bar hosts are retained.
 var remove_ids:Array=[]
 if key=="L2_library":remove_ids=["F01","F05","F07","F08","F11","F35","F37","F39","F42"]
 if key=="L0_reading":remove_ids=["F01","F04","F06","F07","F11","F35","F37","F39","F42"]
 var kept:Array=[]
 for p in compiled.placements:
  if not p.get("fits",false) or not p.has("bounds_min"):kept.append(p);continue
  if library and remove_ids.has(str(p.id).trim_prefix(key+"_")) and not bound(compiled,p):continue
  var asset:String=p.asset
  var frame:bool=p.get("role","")=="wall_or_ceiling" and (p.get("frame_holder",false) or asset.contains("picture_frame"))
  # Library walls are for books. Cinema's screen wall must not carry
  # artwork behind the projection surface. Stored artwork is not deleted.
  if frame and (library or (cinema and box(p).get_center().x>6.25)):continue
  if asset=="Shelf_01" and not bound(compiled,p) and key in ["L2_library","L0_reading","L1_gallery","L2_cinema","L2_music"]:continue
  if cinema and asset in ["owner_theatre_screen","owner_theatre_side_panel"] and not bound(compiled,p):
   var old:=box(p)
   var dx:float=7.00-old.end.x
   if dx>0:
    for field in ["pivot","bounds_min","bounds_max"]:
     p[field]=a(v(p[field])+Vector3(dx,0,0))
  if asset=="blendkit_sofa" and not bound(compiled,p):
   var old:=box(p)
   var m:Dictionary=review.measured_bounds(REPAIRED,float(p.yaw))
   if m.is_empty():return false
   var b:AABB=m.bounds
   var k:float=minf(float(p.scale),minf(old.size.x/b.size.x,minf(old.size.y/b.size.y,old.size.z/b.size.z)))
   if k<=0:return false
   var pivot:=Vector3(old.get_center().x-b.get_center().x*k,old.position.y-b.position.y*k,old.get_center().z-b.get_center().z*k)
   var new_box:=AABB(pivot+b.position*k,b.size*k)
   if not old.grow(.001).encloses(new_box):return false
   p["asset"]="blendkit_sofa/repaired.glb";p["path"]=REPAIRED;p["scale"]=k;p["pivot"]=a(pivot);p["bounds_min"]=a(new_box.position);p["bounds_max"]=a(new_box.end)
  kept.append(p)
 compiled.placements=kept
 return true
static func read_manifest()->Dictionary:
 if not FileAccess.file_exists(PATH):return {}
 var raw=JSON.parse_string(FileAccess.get_file_as_string(PATH))
 if typeof(raw)!=TYPE_DICTIONARY or int(raw.get("schema",0))!=1:return {}
 for path in raw.get("sources",{}):
  if FileAccess.get_sha256(path)!=raw.sources[path]:return {}
 return raw
static func apply_props(compiled:Dictionary,manifest:Dictionary)->bool:
 var key:String=compiled.key
 if not manifest.get("rooms",{}).has(key):return true
 var row:Dictionary=manifest.rooms[key]
 var hosts:Dictionary={}
 for p in compiled.placements:hosts[p.id]=p
 var pending:Array=[]
 for p in row.get("floor_additions",[]):
  if key not in ["L2_library","L0_reading"] or hosts.has(p.id) or p.asset!="wooden_bookshelf_worn" or p.path!=SHELF or p.role!="floor" or not p.get("fits",false):return false
  var b:=box(p)
  if b.position.x< -float(compiled.width)*.5 or b.end.x>float(compiled.width)*.5 or b.position.z< -8.05 or b.end.z>1.65 or b.position.y<0 or b.end.y>3.0:return false
  for h in hosts.values():
   if h.get("fits",false) and h.has("bounds_min") and h.get("role","") in ["floor","screen_or_side_panel"] and b.grow(.012).intersects(box(h)):return false
  hosts[p.id]=p
  pending.append(p)
 for p in row.get("placements",[]):
  var h:Dictionary=hosts.get(str(p.get("support_host","")),{})
  if h.is_empty() or hosts.has(p.id) or not p.get("fits",false) or p.get("role","")!="supported_decor" or not ResourceLoader.exists(str(p.path),"PackedScene"):return false
  if p.get("host_asset","")!=h.asset or v(p.host_pivot).distance_to(v(h.pivot))>.001 or not is_equal_approx(float(p.host_scale),float(h.scale)) or not is_equal_approx(float(p.host_yaw),float(h.yaw)):return false
  hosts[p.id]=p
  pending.append(p)
 compiled.placements.append_array(pending)
 return true
