extends RefCounted
## First-pass migration of measured furnishing clusters, not independent scaling of children.
## Source rows stay untouched; preserve all IDs and support references.
const D=preload("res://scripts/depth7_space.gd")
const SOCIAL_KEYS=["rest_social_upper/R3","rest_social_lower/R3","kitchen/R3"]

const FUNCTION_KEYS=["library/R3","artifact/R3","study/R3","workshop/R3","music/R3","cinema/R3"]

static func v(p:Array)->Vector3:
 return Vector3(float(p[0]),float(p[1]),float(p[2]))
static func arr(p:Vector3)->Array:
 return [p.x,p.y,p.z]
static func host_id(item:Dictionary)->String:
 var ref:String=str(item.get("support_ref",""))
 if not ref.contains("."):ref=str(item.get("decor_slot_id",""))
 return ref.get_slice(".",0) if ref.contains(".") else ""
static func target_z(item:Dictionary,key:String)->float:
 var p:Array=item["room_local_xyz"]
 var z:float=float(p[2])
 var id:String=str(item["instance_id"])
 var policy:String=str(item.get("placement_policy",""))
 if key=="cinema/R3":
  if id.begins_with("owner_cinema_") or id=="cinema_r3_p3_main_screen":
   return D.center(4)+(z+.4)*D.scale_at(D.center(4))
  if id.contains("speaker"):return -7.94
  if id.contains("game_table"):return D.center(2)
  if id.contains("arcade"):return D.center(6)
  return D.center(7)
 if policy=="wall_mount":return -8.02
 if policy=="soft_floor":return D.center(4)
 if key in FUNCTION_KEYS:
  if key=="library/R3":
   if id.contains("chair"):return D.center(4) if id.ends_with("_b") else D.center(2)
   if id=="library_reading_table":return D.center(4)-.70
   if id=="library_side_table":return D.center(2)
   return D.center(7)
  if key=="artifact/R3":
   return D.center(4) if id.begins_with("gallery_display_table") else D.center(7)
  if key=="study/R3":
   if id=="study_r3_chair":return D.center(4)
   if id=="study_reading_chair":return D.center(2)
   if id.contains("desk") or id=="study_reference_table":return D.center(6)
   return D.center(7)
  if key=="workshop/R3":
   if id.contains("stool"):return D.center(4)
   if id.contains("rack"):return D.center(7)
   if id.contains("cart"):return D.center(2)
   return D.center(6)
  if key=="music/R3":
   if id=="music_listening_sofa_b":return D.center(4)
   if id=="music_r3_listening_sofa":return D.center(6)
   if id=="music_listening_chair":return D.center(2)
   if id=="music_record_table":return D.center(4)
   return D.center(7)
 if key=="kitchen/R3":
  if id.contains("stool"):return D.center(6)
  if id=="kitchen_social":return D.center(4)
  if id=="kitchen_social_chair":return D.center(6)
  return D.center(7) if z<-.6 else D.center(4)
 if id.contains("coffee_table") or id.ends_with("bar_counter"):return D.center(7)
 if z<-.7:return D.center(6)
 if z>.35:return D.center(2)
 return D.center(4)
static func transform_item(item:Dictionary,origin:Vector3,target:Vector3,k:float)->void:
 for field in ["room_local_xyz","bounds_min_m","bounds_max_m"]:
  if item.get(field,[]).size()==3:item[field]=arr(target+(v(item[field])-origin)*k)
 item["uniform_scale"]=float(item.get("uniform_scale",1.0))*k
 item["depth7_measured"]=true
 for p in item.get("physical_footprint_xz",[]):
  p[0]=target.x+(float(p[0])-origin.x)*k
  p[1]=target.z+(float(p[1])-origin.z)*k
 for station in item.get("station_candidates",[]):
  for field in ["room_local_xyz","room_pelvis_contact_xyz","room_feet_contact_xyz"]:
   if station.get(field,[]).size()==3:station[field]=arr(target+(v(station[field])-origin)*k)
  var p:Array=station.get("room_approach_xz",[])
  if p.size()==2:station["room_approach_xz"]=[target.x+(float(p[0])-origin.x)*k,target.z+(float(p[1])-origin.z)*k]
  for field in ["seating_width_m","seat_depth_m"]:
   if station.has(field):station[field]=float(station[field])*k
 for slot in item.get("support_slots",[]):
  if slot.get("room_xyz",[]).size()==3:slot["room_xyz"]=arr(target+(v(slot["room_xyz"])-origin)*k)
  if slot.get("max_dimensions_m",[]).size()==3:
   slot["unscaled_dimensions_m"]=slot["max_dimensions_m"].duplicate()
   slot["max_dimensions_m"]=arr(v(slot["max_dimensions_m"])*k)
static func convert(row:Dictionary,key:String)->Dictionary:
 var result:Dictionary=row.duplicate(true)
 var groups:Dictionary={}
 for item in row.get("instances",[]):
  if host_id(item)!="":continue
  var p:=v(item["room_local_xyz"])
  var q:=Vector3(p.x,p.y,target_z(item,key))
  var factor:float=D.scale_at(q.z)
  # Screen, curtains, seats and risers form a single side-facing theatre.
  # Uniform scale and shared floor datum preserve the exact riser contact.
  if key=="cinema/R3" and (str(item["instance_id"]).begins_with("owner_cinema_") or str(item["instance_id"])=="cinema_r3_p3_main_screen"):
   factor=D.scale_at(D.center(4))
   q.y=.025+(p.y-.025)*factor
  groups[str(item["instance_id"])]={"origin":p,"target":q,"scale":factor}
 for item in result.get("instances",[]):
  var id:String=str(item["instance_id"])
  var h:String=host_id(item)
  var g:Dictionary=groups.get(h if h!="" else id,{})
  if g.is_empty():return {}
  transform_item(item,g["origin"],g["target"],float(g["scale"]))
 result["depth7_measured"]=true
 result["playable_z_m"]=[D.BACK,D.FRONT]
 result["front_transit_band_z_m"]=[D.EDGES[1],D.FRONT]
 result["station_cap"]=maxi(24,int(result.get("station_cap",16)))
 result["depth7_revision"]="DEPTH7_FUNCTION_V1" if key in FUNCTION_KEYS else "DEPTH7_SOCIAL_V1"
 return result

static func move_media(surfaces:Dictionary,keys:Array)->void:
 for id in surfaces:
  var spec:Dictionary=surfaces[id]
  if not str(spec.get("room_variant","")) in keys:continue
  var item:Dictionary=spec.get("holder_instance",{})
  if item.is_empty():continue
  var p:=v(item["room_local_xyz"])
  var q:=Vector3(p.x,p.y,-7.96)
  transform_item(item,p,q,D.scale_at(q.z))
