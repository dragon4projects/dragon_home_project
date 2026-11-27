extends RefCounted
## Exact source-bound geometry candidates. Actor pose acceptance remains in NAV.
const PATH="res://data/interior_v2/reading_seats_qa.json"
const SOURCE="res://data/interior_v2/dense_v2_source.zip"
const SERVICES="res://data/interior_v2/services_qa.json"
const BOOKS="res://data/interior_v2/book_supports_qa.json"
const EXPECTED={"L2_library":4,"L0_reading":6}
const REPLACEMENTS={"L2_library_F19":"res://assets/teea008_review/decor_bank/modern_arm_chair_01/model.gltf","L0_reading_F30":"res://assets/teea008_review/decor_bank/modern_arm_chair_01/model.gltf","L0_reading_F33":"res://assets/decor_bank/blendkit_sofa/repaired.glb","L2_library_F32":"res://assets/teea008_review/decor_bank/painted_wooden_chair_02/model.gltf","L0_reading_F32":"res://assets/teea008_review/decor_bank/painted_wooden_chair_02/model.gltf"}
var rooms:Dictionary={}
func _vec(v:Array)->Vector3:return Vector3(float(v[0]),float(v[1]),float(v[2]))
func initialize()->bool:
 var f:=FileAccess.open(PATH,FileAccess.READ)
 if f==null:return false
 var d=JSON.parse_string(f.get_as_text())
 if typeof(d)!=TYPE_DICTIONARY or int(d.get("schema",0))!=1:return false
 if d.get("source_sha256")!=FileAccess.get_sha256(SOURCE) or d.get("services_sha256")!=FileAccess.get_sha256(SERVICES) or d.get("books_sha256")!=FileAccess.get_sha256(BOOKS):return false
 for i in range(3):
  if d.get("compiled_sha256",{}).get(str(i),"")!=FileAccess.get_sha256("res://data/interior_v2/dense_v2_compiled_%d.zip"%i):return false
 var raw:Dictionary=d.get("rooms",{})
 if raw.size()!=2:return false
 for k in EXPECTED:
  if int(raw.get(k,{}).get("count",-1))!=EXPECTED[k]:return false
 rooms=raw
 return true
func apply(compiled:Dictionary)->bool:
 var key:String=compiled.key
 if not rooms.has(key):return true
 var by_id:Dictionary={}
 for p in compiled.placements:by_id[p.id]=p
 var pending:Dictionary={}
 var count:=0
 for spec in rooms[key].hosts:
  var id:String=spec.id
  var p:Dictionary=by_id.get(id,{})
  if p.is_empty() or pending.has(id) or not p.get("station_candidates",[]).is_empty() or p.path!=spec.path or not is_equal_approx(float(p.scale),float(spec.scale)) or not is_equal_approx(float(p.yaw),float(spec.yaw)) or _vec(p.pivot).distance_to(_vec(spec.pivot))>.0001:return false
  var target:Dictionary=p.duplicate(true)
  var replacement:Dictionary=spec.get("replacement",{})
  if not replacement.is_empty():
   if REPLACEMENTS.get(id,"")!=replacement.get("path","") or replacement.id!=id or not ResourceLoader.exists(replacement.path,"PackedScene"):return false
   var old:=AABB(_vec(p.bounds_min),_vec(p.bounds_max)-_vec(p.bounds_min))
   var box:=AABB(_vec(replacement.bounds_min),_vec(replacement.bounds_max)-_vec(replacement.bounds_min))
   if not old.grow(.001).encloses(box) or not is_equal_approx(float(replacement.yaw),float(p.yaw)):return false
   # Only these visual/geometry fields may change. No authored support or
   # service identity is replaced.
   for f in ["asset","path","scale","pivot","bounds_min","bounds_max"]:target[f]=replacement[f]
  var stations:Array=[]
  for st in spec.stations:
   if st.get("status")!="I92_SAMPLED_SEAT_SURFACE_AND_ROUTE_CANDIDATE" or st.get("kind")!="seat" or str(st.station_candidate_id)!=id+".seat_"+str(stations.size()+1):return false
   for f in ["room_local_xyz","room_pelvis_contact_xyz","room_feet_contact_xyz","room_facing_xyz"]:
    if st.get(f,[]).size()!=3 or not _vec(st[f]).is_finite():return false
   if st.get("room_approach_xz",[]).size()!=2 or float(st.seating_width_m)<.18 or float(st.seat_depth_m)<.12:return false
   stations.append(st)
   count+=1
  target.station_candidates=stations
  pending[id]=target
 if count!=EXPECTED[key]:return false
 for i in range(compiled.placements.size()):
  var p:Dictionary=compiled.placements[i]
  if pending.has(p.id):compiled.placements[i]=pending[p.id]
 return true
