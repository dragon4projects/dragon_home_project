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
const MONITOR="res://assets/decor_bank/blendkit_34_inch_curved_ultrawide_monitor_black/model.gltf"
const ORB="res://assets/creatures/npc_ai_magic_sphere/hover_idle/hover_idle_0001.png"
const WALL_MARGIN:=.20
var removed:Array=[]
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
 var out:Array=[];var pending:Array=[];var issues:Array=[];var excluded:Array=[]
 var hw:float=float(room.w)*.5
 for p in source:
  var model:Dictionary=index.models.get(str(int(p.catalog)),{})
  if model.is_empty():issues.append({"id":p.instance,"reason":"missing catalog"});continue
  if str(model.id).begins_with("planter_box_") or (room_key=="L1_gallery" and model.id=="bronze_whale_statue" and str(p.support).begins_with("L1_gallery_F20 ")):
   excluded.append({"id":p.instance,"asset":model.id,"reason":"OWNER_REMOVE_PLANTER" if str(model.id).begins_with("planter_box_") else "OWNER_REPLACE_WITH_ORB"})
   continue
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
 # Relocate plants and a subset of shelves before their supported items
 # are fitted. Search actual measured space; never silently overlap.
 move_to_walls(out,hw,room_key)
 resolve_floor_overlaps(out,hw,room_key)
 var floors:Array=out.duplicate()
 var by_id:Dictionary={}
 for item in floors:by_id[item.id]=item
 var occupied:Dictionary={}
 var unresolved:Array=[]
 for item in source:
  if item.role in FLOOR_ROLES or excluded.any(func(x):return x.id==item.instance):continue
  var model:Dictionary=index.models[str(int(item.catalog))]
  var record:Dictionary={}
  if item.role=="supported_decor":
   var host:Dictionary=by_id.get(str(item.support).get_slice(" | ",0),{})
   record=fit_supported(item,model,host,occupied)
  elif item.role=="wall_or_ceiling":
   record=fit_wall(item,model,hw,out)
  if record.is_empty():unresolved.append({"id":item.instance,"role":item.role,"support":item.support,"asset":model.id})
  else:out.append(record)
 # Side-wall gallery frames use the same real models as the rear wall.
 if room_key in ["L2_cinema","L0_cinema"]:add_monitor(room_key,hw,out)
 add_side_frames(room_key,hw,out)
 if room_key=="L1_gallery":
  var table:Dictionary=by_id.get("L1_gallery_F20",{})
  if not table.is_empty():
   var box:=_bounds(table)
   var c:=box.get_center()
   out.append({"id":"L1_gallery_ORB","asset":"gallery_hover_orb","role":"hover_display","special":"TABLE_HOVER_ORB","pivot":[c.x,box.end.y+.63,c.z],"fits":true,"support_host":table.id})
 return {"key":room_key,"width":room.w,"placements":out,"pending":unresolved,"issues":issues,"excluded":excluded}
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

func _floor(p:Dictionary)->bool:
 return p.get("fits",false) and p.get("role","") in ["floor","screen_or_side_panel"] and p.has("bounds_min")

func _translate(p:Dictionary,delta:Vector3)->void:
 for field in ["pivot","bounds_min","bounds_max"]:p[field]=_arr(_vec(p[field])+delta)
 for station in p.get("station_candidates",[]):
  for field in ["room_local_xyz","room_pelvis_contact_xyz","room_feet_contact_xyz"]:
   if station.get(field,[]).size()==3:station[field]=_arr(_vec(station[field])+delta)
  var a:Array=station.get("room_approach_xz",[])
  if a.size()==2:station["room_approach_xz"]=[float(a[0])+delta.x,float(a[1])+delta.z]
 for slot in p.get("support_slots",[]):
  if slot.get("room_xyz",[]).size()==3:slot["room_xyz"]=_arr(_vec(slot["room_xyz"])+delta)

func _clear_box(box:AABB,items:Array,id:String,hw:float,margin:float=.015)->bool:
 if box.position.x< -hw+.18 or box.end.x>hw-.18 or box.position.z< -8.04 or box.end.z>1.65 or box.position.y<0 or box.end.y>3.02:return false
 for other in items:
  if other.id==id or not _floor(other):continue
  var b:=_bounds(other)
  if minf(box.end.x,b.end.x)-maxf(box.position.x,b.position.x)>-margin and minf(box.end.z,b.end.z)-maxf(box.position.z,b.position.z)>-margin:return false
 return true

func move_to_walls(items:Array,hw:float,room_key:String)->void:
 var side_shelves:=0
 for p in items:
  if not _floor(p):continue
  var asset:String=str(p.asset).to_lower()
  var plant:bool=asset.begins_with("potted_plant") or asset.contains("flower")
  var shelf:bool=asset.contains("shelf") or asset.contains("shelv") or asset.contains("rack")
  var b:=_bounds(p)
  if plant and (b.position.z<=-7.65 or b.position.x< -hw+.65 or b.end.x>hw-.65):continue
  if not plant and (not shelf or side_shelves>=2 or not room_key in ["L1_gallery","L2_library","L0_reading","L1_study","L0_workshop"]):continue
  var c:=b.get_center()
  var preferred:float=-1.0 if c.x<0 else 1.0
  var best:=Vector3.INF
  var distance:=INF
  # Keep the wall-side return clear of the three connector lanes.
  for side in [preferred,-preferred]:
   for z in [-6.1,-5.25,-3.05,-2.3,-.42,.10]:
    var target:=Vector3(side*(hw-WALL_MARGIN-b.size.x*.5),c.y,z)
    var shift:=target-c
    var candidate:=AABB(b.position+shift,b.size)
    if not _clear_box(candidate,items,p.id,hw,.04):continue
    if shift.length()<distance:best=shift;distance=shift.length()
  if best.is_finite():
   _translate(p,best)
   p["wall_relocated"]=true
   if shelf:side_shelves+=1
   corrections.append({"room":room_key,"id":p.id,"asset":p.asset,"reason":"OWNER_WALL_RELOCATION","delta":_arr(best)})

func resolve_floor_overlaps(items:Array,hw:float,room_key:String)->void:
 for p in items:
  if not _floor(p):continue
  var b:=_bounds(p)
  if _clear_box(b,items,p.id,hw,-.012):continue
  # Do not move the fixed theatre screen or the hearth. Move only the
  # conflicting furnishing within a small measured neighbourhood.
  if str(p.asset) in ["owner_theatre_screen","owner_sleeping_dragon"]:continue
  var found:=false
  for step in range(1,9):
   if found:break
   for direction in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
    var delta:Vector3=direction*float(step)*.04
    if not _clear_box(AABB(b.position+delta,b.size),items,p.id,hw,.008):continue
    _translate(p,delta)
    corrections.append({"room":room_key,"id":p.id,"asset":p.asset,"reason":"MEASURED_CLEARANCE","delta":_arr(delta)})
    found=true;break

func _wall_fit(id:String,model:Dictionary,side:int,z:float,y:float,hw:float,k:float,items:Array)->Dictionary:
 var yaw:float=90.0*float(-side)
 var measured:=measured_bounds(model.path,yaw)
 if measured.is_empty():return {}
 var b:AABB=measured.bounds
 var c:=b.get_center()
 var x:float= -hw+.19 if side<0 else hw-.19
 var pivot:=Vector3(x-c.x*k,y-c.y*k,z-c.z*k)
 if side<0:pivot.x=x-b.position.x*k
 else:pivot.x=x-b.end.x*k
 var fitted:=AABB(pivot+b.position*k,b.size*k)
 if fitted.position.y<.10 or fitted.end.y>2.90 or fitted.position.z< -7.95 or fitted.end.z>-.15:return {}
 for other in items:
  if other.get("fits",false) and other.has("bounds_min") and fitted.intersects(_bounds(other).grow(.035)):return {}
 return {"id":id,"asset":model.id,"path":model.path,"role":"wall_or_ceiling","pivot":_arr(pivot),"scale":k,"yaw":yaw,"bounds_min":_arr(fitted.position),"bounds_max":_arr(fitted.end),"fits":true,"frame_holder":true}

func add_side_frames(room_key:String,hw:float,items:Array)->void:
 var ids:Array=["121","92","122","123","93"]
 var count:=0
 for side in [-1,1]:
  for z in [-6.8,-5.6,-4.4,-3.2,-2.0,-.8]:
   for y in [1.18,1.93,2.57]:
    var model:Dictionary=index.models[ids[count%ids.size()]]
    var record:=_wall_fit(room_key+"_SIDE_FRAME_%02d"%count,model,side,z,y,hw,.85,items)
    if not record.is_empty():items.append(record)
    count+=1

func add_monitor(room_key:String,hw:float,items:Array)->void:
 var model:Dictionary={"id":"blendkit_34_inch_curved_ultrawide_monitor_black","path":MONITOR}
 # Real monitor model, not a painted-on rectangle.
 var measured:=measured_bounds(MONITOR,90.0)
 if measured.is_empty():return
 var b:AABB=measured.bounds
 var k:float=minf(1.15/b.size.z,minf(.65/b.size.y,.35/b.size.x))
 for y in [1.75,2.02,1.45,2.35]:
  for z in [-4.15,-3.1,-5.1,-2.1,-6.1,-.9]:
   var record:=_wall_fit(room_key+"_TV_MONITOR",model,-1,z,y,hw,k,items)
   if not record.is_empty():
    record.erase("frame_holder");record["device_kind"]="monitor";items.append(record);return

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
  if p.get("special","")=="TABLE_HOVER_ORB":
   var tex:Texture2D=null
   if ResourceLoader.exists(ORB,"Texture2D"):tex=ResourceLoader.load(ORB,"Texture2D") as Texture2D
   elif FileAccess.file_exists(ORB):
    var image:=Image.new()
    if image.load(ORB)==OK:tex=ImageTexture.create_from_image(image)
   if tex==null:continue
   var orb:=Sprite3D.new()
   orb.name=str(p.id);orb.texture=tex
   # Visible alpha width of the existing frame is 375px, not the
   # 1024px padded canvas. Target a full metre of visible orb.
   orb.pixel_size=1.0/375.0
   orb.billboard=BaseMaterial3D.BILLBOARD_ENABLED
   orb.no_depth_test=false
   orb.position=_vec(p.pivot)+Vector3.UP*.17
   parent.add_child(orb)
   var animation:=orb.create_tween().set_loops()
   animation.tween_property(orb,"position:y",orb.position.y+.20,1.8).set_trans(Tween.TRANS_SINE)
   animation.tween_property(orb,"position:y",orb.position.y-.20,1.8).set_trans(Tween.TRANS_SINE)
   count+=1;continue
  if p.get("special","")=="EXISTING_MEASURED_CROP":
   var hearth=H.new();hearth.stage=parent;hearth.dragon_crop();count+=1;continue
  if not p.get("fits",false):continue
  if p.get("asset","") in ["candidate_dragon_mug_red","candidate_guest_mug_blue"] and str(parent.get_meta("room_id",""))!="":continue
  var scene:=ResourceLoader.load(str(p.path),"PackedScene") as PackedScene
  if scene==null:continue
  var wrapper:=Node3D.new()
  wrapper.name=str(p.id)
  wrapper.set_meta("dense_v2_source_asset",p.asset)
  if p.get("frame_holder",false) or str(p.asset).contains("picture_frame") and p.role=="wall_or_ceiling":
   wrapper.set_meta("display_slot_id",p.id)
   wrapper.set_meta("display_slot_kind","EMPTY_ARTWORK_HOLDER")
  wrapper.position=_vec(p.pivot)
  wrapper.rotation_degrees.y=float(p.yaw)
  wrapper.scale=Vector3.ONE*float(p.scale)
  parent.add_child(wrapper)
  wrapper.add_child(scene.instantiate())
  if wrapper.has_meta("display_slot_id"):
   add_frame_surface(parent,p)
  for player in wrapper.find_children("*","AnimationPlayer",true,false):player.stop()
  count+=1
 return count

# Adapter for the actual navigation core. The row is scoped to one physical
# room; no reuse across two same-type but differently furnished rooms.
func navigation_row(compiled:Dictionary,kind:String,width:int)->Dictionary:
 var row:Dictionary={"variant_id":"dense_v2_"+str(compiled.key)+"/R"+str(width),"room_type":kind,"size":"R"+str(width),"depth7_measured":true,"width_m":compiled.width,"station_cap":64,"instances":[],"preserve_existing_runtime_geometry":[]}
 for p in compiled.placements:
  if not p.get("fits",false) or not p.has("bounds_min"):continue
  var role:String=str(p.role)
  var policy:String="floor_fixed" if role in ["floor","screen_or_side_panel"] else ("supported" if role=="supported_decor" else "nonblocking")
  row.instances.append({"instance_id":p.id,"asset_id":p.asset,"room_local_xyz":p.pivot,"rotation_deg_xyz":[0.0,p.yaw,0.0],"uniform_scale":p.scale,"depth7_measured":true,"bounds_min_m":p.bounds_min,"bounds_max_m":p.bounds_max,"placement_policy":policy,"support_ref":p.get("support_slot",""),"station_candidates":p.get("station_candidates",[]),"support_slots":p.get("support_slots",[])})
 return row

# Empty real frame holders with a per-slot image, never a generated
# illustration or baked replacement of the entire room.
static func artwork_path(id:String)->String:
 return "user://dense_v2_qa/wall_holders/"+id.validate_filename()+".png"

func add_frame_surface(parent:Node3D,p:Dictionary)->void:
 var b:=_bounds(p)
 var yaw:float=float(p.yaw)
 var normal:=Vector3(sin(deg_to_rad(yaw)),0,cos(deg_to_rad(yaw)))
 var side:bool=absf(normal.x)>.9
 var width:float=b.size.z if side else b.size.x
 var height:float=b.size.y
 var aperture:=Vector2(width*.72,height*.72)
 if aperture.x<.035 or aperture.y<.035:return
 var center:=b.get_center()+normal*((b.size.x if side else b.size.z)*.5+.003)
 var node:=MeshInstance3D.new()
 node.name=(str(p.id)+"_ARTWORK").validate_node_name()
 var quad:=QuadMesh.new();quad.size=aperture;node.mesh=quad
 node.position=center
 node.rotation_degrees.y=yaw
 node.set_meta("slot_id",str(p.id))
 node.set_meta("room_id",str(parent.get_meta("room_id","")))
 node.set_meta("surface_size",aperture)
 node.add_to_group("dense_v2_wall_holder")
 parent.add_child(node)
 refresh_artwork(node)

static func refresh_artwork(node:MeshInstance3D)->void:
 var aperture:Vector2=node.get_meta("surface_size",Vector2.ONE)
 var path:String=artwork_path(str(node.get_meta("slot_id","")))
 var image:=Image.new()
 var material:=StandardMaterial3D.new()
 material.albedo_color=Color("#302e30")
 material.roughness=.95
 var mesh:=QuadMesh.new()
 mesh.size=aperture
 if FileAccess.file_exists(path) and image.load(path)==OK:
  var ratio:float=float(image.get_width())/float(image.get_height())
  mesh.size=Vector2(minf(aperture.x,aperture.y*ratio),minf(aperture.y,aperture.x/ratio))
  material.albedo_color=Color.WHITE
  material.albedo_texture=ImageTexture.create_from_image(image)
 node.mesh=mesh
 node.material_override=material
