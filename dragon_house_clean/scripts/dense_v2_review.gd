extends RefCounted
## Measured intake of the owner-supplied dense V2 plan. This is a separate
## visual review layer, not an authoritative station or support registry.
const SOURCE="res://data/interior_v2/dense_v2_source.zip"
const BANK=preload("res://scripts/teea008_review_bank.gd")
const H=preload("res://scripts/depth7_hearth.gd")
const FLOOR_ROLES=["floor","rug","screen_or_side_panel"]
var index:Dictionary={}
var source_archive:=ZIPReader.new()
var bounds_cache:Dictionary={}
var templates:Dictionary={}
var corrections:Array=[]
func load_json(path:String):
 return JSON.parse_string(source_archive.read_file(path).get_string_from_utf8())
func initialize()->bool:
 if source_archive.open(SOURCE)!=OK:return false
 var data=load_json("index.json")
 if typeof(data)!=TYPE_DICTIONARY:return false
 index=data
 var bank=BANK.new()
 if not bank.initialize(true):return false
 bank.apply_architecture_layouts()
 for row in bank.layouts.values():
  for item in row.get("instances",[]):
   var asset:String=str(item.get("asset_id",""))
   var key:String=bank._asset_path(asset)
   var score:int=item.get("station_candidates",[]).size()+item.get("support_slots",[]).size()
   if score==0:continue
   if not templates.has(key) or score>templates[key].get("station_candidates",[]).size()+templates[key].get("support_slots",[]).size():
    templates[key]=item
 return index.get("models",{}).size()==125 and index.get("rooms",[]).size()==19

func _collect_bounds(node:Node,xf:Transform3D,boxes:Array)->void:
 if node is Node3D:
  if not node.visible:return
  xf=xf*node.transform
 if node is MeshInstance3D and node.mesh!=null:
  boxes.append(xf*node.mesh.get_aabb())
 for child in node.get_children():_collect_bounds(child,xf,boxes)

func measured_bounds(path:String,yaw:float)->Dictionary:
 var key:String=path+"|"+str(yaw)
 if bounds_cache.has(key):return bounds_cache[key]
 if is_zero_approx(fposmod(yaw,90.0)) and bounds_cache.has(path+"|0.0"):
  var rotated:AABB=Transform3D(Basis(Vector3.UP,deg_to_rad(yaw)),Vector3.ZERO)*bounds_cache[path+"|0.0"].bounds
  return {"bounds":rotated}
 var scene:=ResourceLoader.load(path,"PackedScene") as PackedScene
 if scene==null:return {}
 var node:Node=scene.instantiate()
 var boxes:Array=[]
 _collect_bounds(node,Transform3D(Basis(Vector3.UP,deg_to_rad(yaw)),Vector3.ZERO),boxes)
 node.free()
 if boxes.is_empty():return {}
 var bounds:AABB=boxes[0]
 for b in boxes:bounds=bounds.merge(b)
 if not bounds.position.is_finite() or not bounds.size.is_finite() or bounds.size.x<=0 or bounds.size.y<=0 or bounds.size.z<=0:return {}
 var result={"bounds":bounds}
 bounds_cache[key]=result
 return result

func compile_room(room_key:String)->Dictionary:
 var room:Dictionary={}
 for r in index.get("rooms",[]):
  if r.key==room_key:room=r;break
 if room.is_empty():return {}
 var source=load_json(room_key+".json")
 if typeof(source)!=TYPE_ARRAY:return {}
 var out:Array=[];var pending:Array=[];var issues:Array=[]
 var hw:float=float(room.w)*.5
 for p in source:
  var model:Dictionary=index.models.get(str(int(p.catalog)),{})
  if model.is_empty():issues.append({"id":p.instance,"reason":"missing catalog"});continue
  if not p.role in FLOOR_ROLES:
   pending.append({"id":p.instance,"role":p.role,"support":p.support})
   continue
  if model.id=="owner_sleeping_dragon":
   out.append({"id":p.instance,"asset":model.id,"special":"EXISTING_MEASURED_CROP","role":p.role})
   continue
  var k:float=float(p.final_scale)
  var yaw:float=float(p.yaw)
  var measured:Dictionary=measured_bounds(model.path,yaw)
  if measured.is_empty() or not is_finite(k) or k<=0:
   issues.append({"id":p.instance,"reason":"unmeasured model or scale"});continue
  var b:AABB=measured.bounds
  var requested:float=k
  # The source explicitly marks its footprints schematic. Uniformly fit
  # oversize real models inside them rather than overlap adjacent furniture.
  var target_x:float=float(p.footprint_x)
  var target_z:float=float(p.footprint_z)
  if target_x>0 and target_z>0:
   k=minf(k,minf((target_x+.004)/b.size.x,(target_z+.004)/b.size.z))
  k=minf(k,2.98/b.size.y)
  if k<requested-.0001:
   corrections.append({"room":room_key,"id":p.instance,"asset":model.id,"requested":requested,"applied":k})
  var center:=b.get_center()
  var pivot:=Vector3(float(p.x)-center.x*k,.025-b.position.y*k,float(p.z)-center.z*k)
  if p.role=="rug":pivot.y=.006-b.position.y*k
  var fitted:=AABB(pivot+b.position*k,b.size*k)
  var fit:bool=fitted.position.x>=-hw-.02 and fitted.end.x<=hw+.02 and fitted.position.z>=-8.05-.02 and fitted.end.z<=1.65+.02 and fitted.end.y<=3.02
  var footprint_error:=Vector2(fitted.size.x-float(p.footprint_x),fitted.size.z-float(p.footprint_z)).length()
  if not fit:
   issues.append({"id":p.instance,"asset":model.id,"reason":"real model outside room","bounds":[_arr(fitted.position),_arr(fitted.end)]})
  var compiled:Dictionary={"id":p.instance,"asset":model.id,"path":model.path,"role":p.role,"pivot":_arr(pivot),"scale":k,"requested_scale":requested,"yaw":yaw,"bounds_min":_arr(fitted.position),"bounds_max":_arr(fitted.end),"fits":fit,"footprint_error":footprint_error}
  if fit:attach_measured_templates(compiled,model.get("verified_aliases",[]))
  out.append(compiled)
 var floors:Array=out.duplicate()
 var by_id:Dictionary={}
 for item in floors:by_id[item.id]=item
 var occupied:Dictionary={}
 var unresolved:Array=[]
 for item in source:
  if item.role in FLOOR_ROLES:continue
  var model:Dictionary=index.models[str(int(item.catalog))]
  var record:Dictionary={}
  if item.role=="supported_decor":
   var host:Dictionary=by_id.get(str(item.support).get_slice(" | ",0),{})
   record=fit_supported(item,model,host,occupied)
  elif item.role=="wall_or_ceiling":
   record=fit_wall(item,model,hw,out)
  if record.is_empty():unresolved.append({"id":item.instance,"role":item.role,"support":item.support,"asset":model.id})
  else:out.append(record)
 return {"key":room_key,"width":room.w,"placements":out,"pending":unresolved,"issues":issues}
# Contact evidence remains tied to the exact source model, not inferred
# from a furniture name or an arbitrary bbox. Geometry measurements in
# original normalized coordinates are transformed into the new room.
func attach_measured_templates(p:Dictionary,aliases:Array)->void:
 var source:Dictionary=templates.get(p.path,{})
 if source.is_empty():
  # Catalog-index duplicate paths are byte-identical. In this branch the
  # normalized TEEA008 copy and the decor-bank copy share the same blob.
  for alternative in aliases:
   if templates.has(alternative):source=templates[alternative];break
 if source.is_empty():return
 var rot:=_vec(source["rotation_deg_xyz"])*PI/180.0
 var from:=Transform3D(Basis.from_euler(rot).scaled(Vector3.ONE*float(source["uniform_scale"])),_vec(source["room_local_xyz"]))
 var to:=Transform3D(Basis(Vector3.UP,deg_to_rad(float(p.yaw))).scaled(Vector3.ONE*float(p.scale)),_vec(p.pivot))
 var relative:=to*from.affine_inverse()
 var ratio:float=float(p.scale)/float(source["uniform_scale"])
 var stations:Array=[]
 for station in source.get("station_candidates",[]):
  var row:Dictionary=station.duplicate(true)
  row["station_candidate_id"]=str(p.id)+"."+str(row["id"])
  for f in ["room_local_xyz","room_pelvis_contact_xyz","room_feet_contact_xyz"]:
   if row.get(f,[]).size()==3:row[f]=_arr(relative*_vec(row[f]))
  if row.get("room_facing_xyz",[]).size()==3:row["room_facing_xyz"]=_arr((relative.basis*_vec(row["room_facing_xyz"])).normalized())
  var at:Array=row.get("room_approach_xz",[])
  if at.size()==2:
   var q:Vector3=relative*Vector3(float(at[0]),float(source["room_local_xyz"][1]),float(at[1]))
   row["room_approach_xz"]=[q.x,q.z]
  for f in ["seating_width_m","seat_depth_m"]:
   if row.has(f):row[f]=float(row[f])*ratio
  row["dense_v2_status"]="MEASURED_TEMPLATE_REPROJECTED_PENDING_SCENE_FIT"
  stations.append(row)
 var slots:Array=[]
 for slot in source.get("support_slots",[]):
  var row:Dictionary=slot.duplicate(true)
  if row.get("room_xyz",[]).size()!=3:continue
  row["room_slot_id"]=str(p.id)+"."+str(row["id"])
  row["room_xyz"]=_arr(relative*_vec(row["room_xyz"]))
  if row.get("max_dimensions_m",[]).size()==3:row["max_dimensions_m"]=_arr(_vec(row["max_dimensions_m"])*ratio)
  slots.append(row)
 p["station_candidates"]=stations
 p["support_slots"]=slots
 p["source_template_id"]=source["instance_id"]

func _bounds(p:Dictionary)->AABB:
 var lo:=_vec(p.bounds_min)
 return AABB(lo,_vec(p.bounds_max)-lo)

func fit_supported(item:Dictionary,model:Dictionary,host:Dictionary,occupied:Dictionary)->Dictionary:
 if host.is_empty() or not host.get("fits",false):return {}
 var slots:Array=host.get("support_slots",[])
 if slots.is_empty():return {}
 var yaw:float=float(host.yaw)
 var measured:Dictionary=measured_bounds(model.path,yaw)
 if measured.is_empty():return {}
 var b:AABB=measured.bounds
 var desired:float=float(item.depth_scale)
 for slot in slots:
  var id:String=str(slot.room_slot_id)
  if occupied.has(id) or slot.get("max_dimensions_m",[]).size()!=3:continue
  var size:=_vec(slot.max_dimensions_m)
  if size.x<=0 or size.y<=0 or size.z<=0:continue
  if absf(fposmod(yaw,180.0)-90.0)<.01:size=Vector3(size.z,size.y,size.x)
  var k:float=minf(desired,minf(size.x/b.size.x,minf(size.y/b.size.y,size.z/b.size.z)))
  # Unspecified decorative scales may be fitted, but never shrink a
  # functional cup/coffee machine into a misleading miniature.
  if k<desired*.72:continue
  var at:=_vec(slot.room_xyz)
  var center:=b.get_center()
  var pivot:=at-Vector3(center.x,b.position.y,center.z)*k
  var fitted:=AABB(pivot+b.position*k,b.size*k)
  if fitted.end.y>3.0:continue
  occupied[id]=true
  return {"id":item.instance,"asset":model.id,"path":model.path,"role":item.role,"pivot":_arr(pivot),"scale":k,"requested_scale":desired,"yaw":yaw,"bounds_min":_arr(fitted.position),"bounds_max":_arr(fitted.end),"fits":true,"support_slot":id,"support_host":host.id,"review_status":"MEASURED_SLOT_CANDIDATE"}
 return {}

func fit_wall(item:Dictionary,model:Dictionary,hw:float,placed:Array)->Dictionary:
 var note:String=str(item.note)
 if not note.begins_with("rear wall:"):return {}
 var y:float=2.25 if note.contains("2.25") else 1.35
 var measured:Dictionary=measured_bounds(model.path,0.0)
 if measured.is_empty():return {}
 var b:AABB=measured.bounds
 var k:float=float(item.depth_scale)
 var center:=b.get_center()
 var pivot:=Vector3(float(item.x)-center.x*k,y-center.y*k,-8.02-b.position.z*k)
 var fitted:=AABB(pivot+b.position*k,b.size*k)
 if fitted.position.x< -hw or fitted.end.x>hw or fitted.position.y<.05 or fitted.end.y>3.0 or fitted.end.z> -7.55:return {}
 for p in placed:
  if not p.get("fits",false) or not p.has("bounds_min"):continue
  if fitted.intersects(_bounds(p)):return {}
 return {"id":item.instance,"asset":model.id,"path":model.path,"role":item.role,"pivot":_arr(pivot),"scale":k,"yaw":0.0,"bounds_min":_arr(fitted.position),"bounds_max":_arr(fitted.end),"fits":true,"review_status":"REAR_MOUNT_CANDIDATE_ORIENTATION_PENDING"}

func _arr(p:Vector3)->Array:return [p.x,p.y,p.z]
func _vec(p:Array)->Vector3:return Vector3(float(p[0]),float(p[1]),float(p[2]))

func mount_review(parent:Node3D,compiled:Dictionary)->int:
 var count:=0
 for p in compiled.placements:
  if p.get("special","")=="EXISTING_MEASURED_CROP":
   var hearth=H.new();hearth.stage=parent;hearth.dragon_crop();count+=1;continue
  if not p.get("fits",false):continue
  var scene:=ResourceLoader.load(str(p.path),"PackedScene") as PackedScene
  if scene==null:continue
  var wrapper:=Node3D.new()
  wrapper.name=str(p.id)
  wrapper.set_meta("dense_v2_source_asset",p.asset)
  wrapper.position=_vec(p.pivot)
  wrapper.rotation_degrees.y=float(p.yaw)
  wrapper.scale=Vector3.ONE*float(p.scale)
  parent.add_child(wrapper)
  wrapper.add_child(scene.instantiate())
  for player in wrapper.find_children("*","AnimationPlayer",true,false):player.stop()
  count+=1
 return count
