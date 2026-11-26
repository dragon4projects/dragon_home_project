extends RefCounted
## Explicit, opt-in TEEA008 review. Never changes canonical world or approval.
const SKETCHFAB_ROOT := "res://assets/sketchfab_review/decor_bank/"
const SKETCHFAB_DELTA := "res://data/sketchfab_common_review.json"
const ROOT := "res://assets/teea008_review/decor_bank/"
const LAYOUT := "res://data/teea008_review/room_layouts_xz.json"
const MEDIA := "res://data/teea008_review/media_surface_delta.json"
const LIVE_EXPORT_MARKER := "res://data/integration_candidates/TEEA008_LIVE_REVIEW.enabled"
var surfaces:Dictionary={}
var layouts:Dictionary={}
var enabled:=false
var sketchfab_common_enabled:=false
var live_physical_objects:=false
var packed_model_cache:Dictionary={}
var packed_model_lru:Array=[]
const MODEL_CACHE_LIMIT:=48
# One decorative set contains 20 separate books / 40 material surfaces.
# Compact only this static model. Each placement retains its own wrapper,
# support transform and conditional visibility; catalogue books are separate.
var compact_encyclopedia_enabled:=true
var _encyclopedia_mesh:ArrayMesh
var _encyclopedia_attempted:=false
var error:=""
func initialize(force_review:bool=false) -> bool:
	layouts.clear()
	surfaces.clear()
	packed_model_cache.clear()
	packed_model_lru.clear()
	_encyclopedia_mesh=null
	_encyclopedia_attempted=false
	enabled=false
	sketchfab_common_enabled=false
	error=""
	if not force_review and OS.get_environment("DRAGON_TEEA008_REVIEW")!="1" and not FileAccess.file_exists(LIVE_EXPORT_MARKER):
		return false
	var f:=FileAccess.open(LAYOUT,FileAccess.READ)
	if f==null:
		error="TEEA008 layout missing"
		return false
	var doc=JSON.parse_string(f.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):
		error="invalid candidate contract"
		return false
	for raw in doc.get("items",[]):
		if typeof(raw)!=TYPE_DICTIONARY or bool(raw.get("owner_approved",true)):
			error="invalid variant approval"
			layouts.clear()
			return false
		var id:String=str(raw.get("variant_id",""))
		if id=="" or layouts.has(id):
			error="invalid/duplicate variant"
			layouts.clear()
			return false
		for item in raw.get("instances",[]):
			var asset:String=str(item.get("asset_id",""))
			if asset=="" or not asset.is_valid_filename() or asset.contains("..") or not ResourceLoader.exists(ROOT+asset+"/model.gltf","PackedScene"):
				error="missing candidate asset "+asset
				layouts.clear()
				return false
		layouts[id]=_review_layout_delta(raw)
	if layouts.size()!=33:
		error="expected 33 room variants"
		return false
	_apply_sketchfab_common_delta()
	var media_file:=FileAccess.open(MEDIA,FileAccess.READ)
	if media_file==null:
		error="missing media aperture manifest"
		return false
	var media_doc=JSON.parse_string(media_file.get_as_text())
	if typeof(media_doc)!=TYPE_DICTIONARY or bool(media_doc.get("owner_approved",true)):
		error="invalid media aperture manifest"
		return false
	for raw in media_doc.get("items",[]):
		var id:String=str(raw.get("surface_id",""))
		var variant_id:String=str(raw.get("room_variant",""))
		var asset:String=str(raw.get("holder_asset_id",""))
		var aperture:Dictionary=raw.get("aperture",{})
		if id=="" or surfaces.has(id) or not layouts.has(variant_id) or not asset.is_valid_filename() or asset.contains("..") or not ResourceLoader.exists(ROOT+asset+"/model.gltf","PackedScene"):
			error="invalid media surface "+id
			return false
		if bool(raw.get("owner_approved",true)) or aperture.get("center_xyz",[]).size()!=3 or float(aperture.get("width_m",0))<=0 or float(aperture.get("height_m",0))<=0:
			error="invalid aperture "+id
			return false
		var carrier:String=str(raw.get("carrier_instance_id",""))
		if raw.get("holder_instance",{}).is_empty() and not layouts[variant_id]["instances"].any(func(item):return str(item["instance_id"])==carrier and str(item["asset_id"])==asset):
			error="screen carrier missing "+id
			return false
		surfaces[id]=raw
	enabled=surfaces.size()==32
	if not enabled:
		error="expected 32 media surfaces"
	return enabled

func variant(kind:String, width:int)->Dictionary:
	return layouts.get("%s/R%d" % [kind,width],{}) if enabled else {}

func _support_host_id(item:Dictionary)->String:
	var reference:String=str(item.get("support_ref",""))
	if reference=="":reference=str(item.get("decor_slot_id",""))
	if reference=="" or not reference.contains("."):return ""
	return reference.get_slice(".",0)

func _mount_pose(item:Dictionary,scale_at:Callable,instances:Dictionary)->Dictionary:
	var p:Array=item["room_local_xyz"]
	var physical:=Vector3(float(p[0]),float(p[1]),float(p[2]))
	var depth:float=float(scale_at.call(physical.z))
	var projected:=Vector3(physical.x*depth,physical.y,physical.z)
	var host_id:String=_support_host_id(item)
	var host:Dictionary=instances.get(host_id,{})
	if not host.is_empty():
		# A supported object's coordinates are in the measured room space,
		# not in the carrier's model space. Apply the SAME room-space depth
		# projection as its carrier, without double-applying model scale/yaw.
		var hp:Array=host["room_local_xyz"]
		var h:=Vector3(float(hp[0]),float(hp[1]),float(hp[2]))
		depth=float(scale_at.call(h.z))
		projected=Vector3(physical.x*depth,h.y+(physical.y-h.y)*depth,h.z+(physical.z-h.z)*depth)
	return {"position":projected,"depth":depth,"support_host_id":host_id if not host.is_empty() else ""}

func _collect_encyclopedia_surfaces(node:Node,xf:Transform3D,groups:Dictionary)->bool:
	if node is AnimationPlayer or node is Skeleton3D:return false
	if node is Node3D:
		if not node.visible:return false
		xf=xf*node.transform
	if node is MeshInstance3D:
		var source:MeshInstance3D=node
		if not source.mesh is ArrayMesh or source.skin!=null or source.get_blend_shape_count()!=0 or source.material_overlay!=null or source.transparency!=0.0 or source.layers!=1:return false
		var scale_value:Vector3=xf.basis.get_scale()
		if xf.basis.determinant()<=0.0 or not is_equal_approx(scale_value.x,scale_value.y) or not is_equal_approx(scale_value.x,scale_value.z):return false
		for surface in range(source.mesh.get_surface_count()):
			if source.mesh.surface_get_primitive_type(surface)!=Mesh.PRIMITIVE_TRIANGLES:return false
			var mat:Material=source.get_active_material(surface)
			if not mat is StandardMaterial3D or mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED or mat.next_pass!=null or mat.billboard_mode!=BaseMaterial3D.BILLBOARD_DISABLED:return false
			var fmt:int=source.mesh.surface_get_format(surface)
			if fmt & (Mesh.ARRAY_FORMAT_CUSTOM0|Mesh.ARRAY_FORMAT_CUSTOM1|Mesh.ARRAY_FORMAT_CUSTOM2|Mesh.ARRAY_FORMAT_CUSTOM3|Mesh.ARRAY_FORMAT_BONES|Mesh.ARRAY_FORMAT_WEIGHTS):return false
			var key:String=str(mat.get_instance_id())+"|"+str(fmt)
			if not groups.has(key):groups[key]=[]
			groups[key].append({"mesh":source.mesh,"surface":surface,"transform":xf,"material":mat})
	for child in node.get_children():
		if not _collect_encyclopedia_surfaces(child,xf,groups):return false
	return true

func _compact_encyclopedia(scene:PackedScene)->ArrayMesh:
	if _encyclopedia_attempted:return _encyclopedia_mesh
	_encyclopedia_attempted=true
	var model:Node=scene.instantiate()
	var groups:Dictionary={}
	var ok:bool=_collect_encyclopedia_surfaces(model,Transform3D.IDENTITY,groups)
	if not ok or groups.size()!=3:
		model.free()
		return null
	var result:=ArrayMesh.new()
	var count:=0
	for records in groups.values():
		var tool:=SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for row in records:
			tool.append_from(row["mesh"],int(row["surface"]),row["transform"])
			count+=1
		tool.set_material(records[0]["material"])
		tool.commit(result)
	model.free()
	# The known source has exactly forty surfaces. A changed or unsupported
	# source falls back to the original scene instead of silently losing art.
	if count!=40 or result.get_surface_count()!=3:return null
	_encyclopedia_mesh=result
	return result

func _mount(parent:Node3D,item:Dictionary,scale_at:Callable,animate:bool=true,instances:Dictionary={})->Node3D:
	var asset:String=str(item["asset_id"])
	var position:Array=item["room_local_xyz"]
	var rotation:Array=item["rotation_deg_xyz"]
	var scene:PackedScene=packed_model_cache.get(asset)
	if scene==null:
		scene=ResourceLoader.load(_asset_path(asset),"PackedScene") as PackedScene
		if scene!=null:packed_model_cache[asset]=scene
	if scene!=null:
		packed_model_lru.erase(asset)
		packed_model_lru.append(asset)
		while packed_model_lru.size()>MODEL_CACHE_LIMIT:
			packed_model_cache.erase(packed_model_lru.pop_front())
	if scene==null:
		return null
	var wrapper:=Node3D.new()
	wrapper.name=str(item["instance_id"]).validate_node_name()
	var pose:Dictionary=_mount_pose(item,scale_at,instances)
	var depth:float=float(pose["depth"])
	wrapper.position=pose["position"]
	wrapper.set_meta("visual_support_host",str(pose["support_host_id"]))
	wrapper.rotation_degrees=Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2]))
	wrapper.scale=Vector3.ONE*float(item.get("uniform_scale",1.0))*depth
	wrapper.set_meta("candidate_instance_id",str(item["instance_id"]))
	wrapper.set_meta("candidate_asset_id",asset)
	wrapper.set_meta("physical_xyz",position)
	wrapper.set_meta("owner_approved",false)
	parent.add_child(wrapper)
	if str(item.get("decor_slot_id",""))!="":
		wrapper.set_meta("decor_slot_id",str(item["decor_slot_id"]))
		wrapper.set_meta("room_id",str(parent.get_meta("room_id","")))
		wrapper.add_to_group("canonical_conditional_dressing")
	var compact:ArrayMesh=_compact_encyclopedia(scene) if compact_encyclopedia_enabled and asset=="book_encyclopedia_set_01" else null
	if compact!=null:
		var mesh_node:=MeshInstance3D.new()
		mesh_node.name="CompactEncyclopedia"
		mesh_node.mesh=compact
		mesh_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wrapper.add_child(mesh_node)
	elif asset=="owner_theatre_riser_trim" and item.has("seat_plinth_height_m"):
		_mount_theatre_plinth(wrapper,scene,item,depth)
	else:
		wrapper.add_child(scene.instantiate())
	if animate and asset=="sketchfab_fireplace_animated":
		for player in wrapper.find_children("*","AnimationPlayer",true,false):
			if player.has_animation("Fire"):
				var clip:Animation=player.get_animation("Fire")
				clip.loop_mode=Animation.LOOP_LINEAR
				player.play("Fire")
				wrapper.set_meta("fire_playing",true)
				break
	return wrapper

# A raised base under each rear seat pair, not a step in the walkable aisle.
# The physical height is not depth-scaled: the seat's base pivot uses room Y.
# The owner trim is inset into the front edge; the plain timber block fills
# its support volume. X/Z remain inside the existing chair obstacle.
func _mount_theatre_plinth(wrapper:Node3D,scene:PackedScene,item:Dictionary,depth:float)->void:
	var width:float=float(item["seat_plinth_width_m"])
	var length:float=float(item["seat_plinth_depth_m"])
	var height:float=float(item["seat_plinth_height_m"])/maxf(depth,0.01)
	var trim_scale:float=width/3.899817
	var trim_depth:float=0.190024*trim_scale
	var trim_height:float=0.138397*trim_scale
	var block:=MeshInstance3D.new()
	block.name="RaisedSeatBase"
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(width,height,length-trim_depth)
	block.mesh=mesh
	block.position=Vector3(0,height*0.5,-trim_depth*0.5)
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("#55382c")
	material.roughness=0.86
	block.material_override=material
	wrapper.add_child(block)
	var edge:=Node3D.new()
	edge.name="OriginalRiserTrim"
	edge.position=Vector3(0,height-trim_height,length*0.5-trim_depth*0.5)
	edge.scale=Vector3.ONE*trim_scale
	wrapper.add_child(edge)
	edge.add_child(scene.instantiate())
	# Fill the lower edge under the taller rear-row trim.
	if height>trim_height+0.001:
		var lower:=MeshInstance3D.new()
		lower.name="RiserLowerSupport"
		var lower_mesh:=BoxMesh.new()
		lower_mesh.size=Vector3(width,height-trim_height,trim_depth)
		lower.mesh=lower_mesh
		lower.position=Vector3(0,(height-trim_height)*0.5,length*0.5-trim_depth*0.5)
		lower.material_override=material
		wrapper.add_child(lower)

func populate(parent:Node3D, kind:String, width:int, scale_at:Callable)->int:
	var row:Dictionary=variant(kind,width)
	var count:=0
	var nodes:Dictionary={}
	var instances:Dictionary={}
	for item in row.get("instances",[]):
		instances[str(item["instance_id"])]=item
	for item in row.get("instances",[]):
		if live_physical_objects and str(item.get("asset_id","")) in ["candidate_dragon_mug_red","candidate_guest_mug_blue"]:
			continue
		var wrapper:Node3D=_mount(parent,item,scale_at,true,instances)
		if wrapper!=null:
			nodes[str(item["instance_id"])]=wrapper
			count+=1
	for id in surfaces:
		var spec:Dictionary=surfaces[id]
		if str(spec["room_variant"])!=str(row.get("variant_id","")):
			continue
		var holder:Dictionary=spec.get("holder_instance",{})
		var carrier:Node3D
		if holder.is_empty():
			# Three screens already exist in the room layout: never duplicate.
			carrier=nodes.get(str(spec.get("carrier_instance_id","")))
		else:
			carrier=_mount(parent,holder,scale_at,true,instances)
		if carrier==null:
			push_error("TEEA008 missing mounted media holder "+str(id))
			continue
		var aperture:Dictionary=spec["aperture"]
		var center:Array=aperture["center_xyz"]
		var anchor:=Node3D.new()
		anchor.name="Aperture_"+str(id).validate_node_name()
		anchor.position=Vector3(float(center[0]),float(center[1]),float(center[2]))
		var rotation:Array=aperture.get("rotation_deg_xyz",[0,0,0])
		anchor.rotation_degrees=Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2]))
		anchor.set_meta("surface_id",str(id))
		anchor.set_meta("surface_category",str(spec["legacy_runtime_category"]))
		anchor.set_meta("carrier_hit_only",bool(spec.get("carrier_hit_only",false)))
		anchor.set_meta("surface_size",Vector2(float(aperture["width_m"]),float(aperture["height_m"])))
		anchor.set_meta("room_id",str(parent.get_meta("room_id","")))
		anchor.set_meta("owner_approved",false)
		carrier.add_child(anchor)
		anchor.add_to_group("teea008_media_surface")
	return count

func aperture_hit(camera:Camera3D, point:Vector2)->Dictionary:
	if not enabled or camera==null or camera.get_tree()==null:
		return {}
	var ray_origin:Vector3=camera.project_ray_origin(point)
	var ray_direction:Vector3=camera.project_ray_normal(point)
	var nearest:float=INF
	var result:Dictionary={}
	for node in camera.get_tree().get_nodes_in_group("teea008_media_surface"):
		if not node is Node3D or not node.is_visible_in_tree():
			continue
		var inv:Transform3D=node.global_transform.affine_inverse()
		var start:Vector3=inv*ray_origin
		var direction:Vector3=inv.basis*ray_direction
		if direction.z>=-0.00001:
			continue
		var distance:float=-start.z/direction.z
		if distance<0.0 or distance>=nearest:
			continue
		var hit:Vector3=start+direction*distance
		var half:Vector2=node.get_meta("surface_size",Vector2.ZERO)*0.5
		if absf(hit.x)>half.x or absf(hit.y)>half.y:
			continue
		nearest=distance
		result={"anchor":node,"category":"teea008_surface","item_id":str(node.get_meta("surface_id","")),"display_name":str(node.get_meta("surface_id","")),"room_id":str(node.get_meta("room_id",""))}
	return result

func _review_layout_delta(raw:Dictionary)->Dictionary:
	# TEEA008 source stays immutable. The centaur's visual lying width is
	# ~1.99 m at the live-review canvas scale; 1.56 m textile was too short.
	var row:Dictionary=raw.duplicate(true)
	if str(row.get("variant_id",""))!="guest_centaur/R1":
		return row
	for item in row.get("instances",[]):
		if str(item.get("instance_id",""))!="guest_centaur_01_rest_mat":
			continue
		var factor:=1.35
		var position:Array=item["room_local_xyz"]
		var lo:Array=item["bounds_min_m"]
		var hi:Array=item["bounds_max_m"]
		for axis in range(3):
			lo[axis]=float(position[axis])+(float(lo[axis])-float(position[axis]))*factor
			hi[axis]=float(position[axis])+(float(hi[axis])-float(position[axis]))*factor
		item["uniform_scale"]=float(item.get("uniform_scale",1.0))*factor
		item["bounds_min_m"]=lo
		item["bounds_max_m"]=hi
		item["physical_footprint_xz"]=[[lo[0],lo[2]],[hi[0],lo[2]],[hi[0],hi[2]],[lo[0],hi[2]]]
		item["station_candidates"]=[{"id":"floor_rest","kind":"floor_rest",
			"station_candidate_id":"guest_centaur_01_rest_mat.floor_rest",
			"room_local_xyz":[position[0],hi[1],position[2]],
			"pose_hint":"LIE_SIDE_CURLED","status":"INTEGRATOR_VISUAL_FIT_CANDIDATE"}]
		row["runtime_review_delta"]="CENTAU_RUG_SCALE_1_35_NOT_OWNER_APPROVED"
	return row

func _asset_path(asset:String)->String:
	if asset=="blendkit_sofa_set_chair":return "res://assets/decor_bank/blendkit_sofa_set/chair.gltf"
	if asset.begins_with("owner_theatre_") or asset.begins_with("blendkit_") or asset=="owner_hp_notebook_lowpoly" or asset in ["owner_sleeping_dragon","artifact_glass_cube_s","artifact_glass_cube_m","artifact_glass_cube_l"]:
		return "res://assets/decor_bank/"+asset+"/model.gltf"
	var base:String=SKETCHFAB_ROOT if asset.begins_with("sketchfab_") else ROOT
	return base+asset+"/model.gltf"

func _apply_sketchfab_common_delta()->void:
	var f:=FileAccess.open(SKETCHFAB_DELTA,FileAccess.READ)
	if f==null:return
	var doc=JSON.parse_string(f.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)) or str(doc.get("variant_id",""))!="common/R3":return
	var row:Dictionary=layouts.get("common/R3",{}).duplicate(true)
	if row.is_empty():return
	for item in doc.get("instances",[]):
		if not ResourceLoader.exists(_asset_path(str(item.get("asset_id",""))),"PackedScene"):
			return
	var preserved:Array=[]
	for item in row.get("preserve_existing_runtime_geometry",[]):
		if not str(item.get("instance_id","")) in doc.get("remove_geometry_ids",[]):
			preserved.append(item)
	row["preserve_existing_runtime_geometry"]=preserved
	row["instances"].append_array(doc["instances"])
	row["runtime_review_geometry_revision"]="SKETCHFAB_COMMON_R3_20261125_V1"
	layouts["common/R3"]=row
	sketchfab_common_enabled=true


func apply_architecture_layouts()->void:
	# Reuse measured R1 furniture without scaling up the entire guest room.
	# R2 is a single 9.6 m physical room; the remainder is unoccupied space.
	var centaur:Dictionary=layouts.get("guest_centaur/R1",{}).duplicate(true)
	if not centaur.is_empty():
		centaur["variant_id"]="guest_centaur/R2"
		centaur["size"]="R2"
		centaur["width_m"]=9.6
		centaur["station_cap"]=8
		centaur["shell_reference"]="R2"
		layouts["guest_centaur/R2"]=centaur
	var hearth:Dictionary=layouts.get("common/R3",{}).duplicate(true)
	if hearth.is_empty() or not ResourceLoader.exists(_asset_path("owner_sleeping_dragon"),"PackedScene"):
		push_warning("Canonical hearth: sleeping dragon asset not imported")
		return
	var items:Array=[]
	for raw in hearth.get("instances",[]):
		var item:Dictionary=raw.duplicate(true)
		if str(item["instance_id"]) in ["common_r3_p3_plant","common_r3_p3_sconce_1"]:
			continue
		if str(item["instance_id"])=="common_r3_animated_hearth_review":
			# Uniform model scale, measured footprint and floor pivot stay in sync.
			_resize_floor_item(item,1.72)
			_translate_hearth_item(item,-0.35,-1.02)
		if str(item["instance_id"])=="common_r3_p3_fur_right":
			# Translate the rug AND the physical contact point; keep aisle open.
			var delta:=Vector3(5.36,0.0,0.62)
			for field in ["room_local_xyz","bounds_min_m","bounds_max_m"]:
				var p:Array=item[field]
				item[field]=[float(p[0])+delta.x,float(p[1]),float(p[2])+delta.z]
			for p in item.get("physical_footprint_xz",[]):
				p[0]=float(p[0])+delta.x
				p[1]=float(p[1])+delta.z
			for station in item.get("station_candidates",[]):
				var p:Array=station["room_local_xyz"]
				station["room_local_xyz"]=[float(p[0])+delta.x,float(p[1]),float(p[2])+delta.z]
		items.append(item)
	# Teea normalized to 0.35 x 0.045161 x 0.274673 m at floor pivot.
	# Owner requested a larger dragon. Review scale 6.5x = 2.275 m long.
	# Refit the nook and its approach points rather than enlarging the mesh alone.
	# Exact AABB, no pickup, no AI, no animation, no sleeping timer.
	items.append({
		"instance_id":"canonical_hearth_sleeping_dragon",
		"asset_id":"owner_sleeping_dragon",
		"room_local_xyz":[6.02,0.0,-0.98],
		"rotation_deg_xyz":[0,0,0],
		"uniform_scale":6.5,
		"bounds_min_m":[4.8825,0.0,-1.87268725],
		"bounds_max_m":[7.1575,0.2935465,-0.08731275],
		"physical_footprint_xz":[[4.8825,-1.87268725],[7.1575,-1.87268725],[7.1575,-0.08731275],[4.8825,-0.08731275]],
		"placement_policy":"floor_fixed","station_candidates":[],"support_slots":[],
		"support_ref":null,"owner_approved":false
	})
	hearth["instances"]=items
	_apply_hearth_interior_v1(hearth)
	hearth["runtime_review_geometry_revision"]="CANONICAL_HEARTH_INTERIOR_20261125_V1"
	layouts["common/R3"]=hearth
	_apply_social_interiors()
	_apply_owner_theatre()
	_apply_canonical_device_bindings()

func _apply_owner_theatre()->void:
	var file:=FileAccess.open("res://data/canonical_owner_theatre_20261126.json",FileAccess.READ)
	if file==null:return
	var data=JSON.parse_string(file.get_as_text())
	if typeof(data)!=TYPE_DICTIONARY or bool(data.get("owner_approved",true)):return
	var row:Dictionary=data["variant"]
	for item in row["instances"]:
		if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):
			push_error("Owner theatre missing "+str(item["asset_id"]))
			return
	layouts["cinema/R3"]=row
	var surface:Dictionary=surfaces["cinema.r3.film.screen"]
	surface["holder_asset_id"]="owner_theatre_screen"
	surface["aperture"]["center_xyz"]=[0,0.89795,-0.026]
	surface["aperture"]["width_m"]=2.926616
	surface["aperture"]["height_m"]=1.661989
	surface["aperture"]["rotation_deg_xyz"]=[0,180,0]
	surface["aperture"]["measurement"]="Measured Material.031 screen face"

func _apply_canonical_device_bindings()->void:
	# Preserve surface IDs (saved room-instance assignments). The canonical
	# R3 audio surfaces now belong to existing physical media devices instead
	# of separate wall rectangles. TV has its own independent catalog target.
	# Keep the original measured wall sleeve above the primary boombox as
	# a real cover display; the device itself remains separately clickable.
	var primary:Dictionary=surfaces.get("music.r3.audio.01",{})
	if not primary.is_empty():
		var sleeve:Dictionary=primary.duplicate(true)
		sleeve["surface_id"]="music.r3.audio.now_playing"
		sleeve["holder_instance"]["instance_id"]="music_r3_now_playing_sleeve"
		sleeve["carrier_instance_id"]=""
		sleeve["binding_alias"]="music.r3.audio.01"
		surfaces["music.r3.audio.now_playing"]=sleeve
	var targets:Dictionary={
		"music.r3.audio.01":["music/R3","music_r3_p2_boombox"],
		"music.r3.audio.02":["music/R3","music_r3_p2_cassette"],
		"music.r3.audio.03":["music/R3","music_cassette_deck"],
		"music.r3.audio.04":["music/R3","music_shelf_cassette_player"],
		"cinema.r3.film.tv":["cinema/R3","cinema_r3_p2_tv"]
	}
	for surface_id in targets:
		var key:String=str(targets[surface_id][0])
		var carrier_id:String=str(targets[surface_id][1])
		var source_id:String="cinema.r3.film.poster.02" if surface_id=="cinema.r3.film.tv" else str(surface_id)
		if not surfaces.has(source_id):continue
		var source:Dictionary=surfaces[source_id].duplicate(true)
		for item in layouts.get(key,{}).get("instances",[]):
			if str(item["instance_id"])!=carrier_id:continue
			var lo:Array=item["bounds_min_m"]
			var hi:Array=item["bounds_max_m"]
			var p:Array=item["room_local_xyz"]
			var scale_value:float=float(item["uniform_scale"])
			if scale_value<=0.0:continue
			source["surface_id"]=surface_id
			source["holder_asset_id"]=str(item["asset_id"])
			source["carrier_instance_id"]=carrier_id
			source["holder_instance"]={}
			# Measured device-front envelope, not a fabricated video-screen
			# aperture. Do not cover the real device with an album/poster quad.
			source["aperture"]["center_xyz"]=[((float(lo[0])+float(hi[0]))*0.5-float(p[0]))/scale_value,((float(lo[1])+float(hi[1]))*0.5-float(p[1]))/scale_value,(float(hi[2])-float(p[2]))/scale_value+0.005]
			source["aperture"]["width_m"]=(float(hi[0])-float(lo[0]))/scale_value
			source["aperture"]["height_m"]=(float(hi[1])-float(lo[1]))/scale_value
			source["aperture"]["measurement"]="Measured device envelope; hit target only"
			source["carrier_hit_only"]=true
			if surface_id=="cinema.r3.film.tv":
				# Candidate inset on the measured device envelope. Actual CRT
				# aperture is not independently verified; keep bezel visible.
				source["aperture"]["width_m"]*=0.66
				source["aperture"]["height_m"]*=0.60
				source["aperture"]["center_xyz"][1]+=0.025
				source["aperture"]["measurement"]="Candidate inset within measured TV front envelope; visual QA required"
				source["carrier_hit_only"]=false
			surfaces[surface_id]=source
			break

func populate_overview(parent:Node3D,kind:String,width:int,scale_at:Callable)->int:
	# Actual normalized model silhouettes, not box proxies. Shared imported
	# resources can use Godot mesh LOD; no media hotspots or running fire clips.
	var row:Dictionary=variant(kind,width)
	var count:=0
	var instances:Dictionary={}
	for item in row.get("instances",[]):
		instances[str(item["instance_id"])]=item
	for item in row.get("instances",[]):
		var asset:String=str(item["asset_id"])
		var policy:String=str(item.get("placement_policy",""))
		if policy not in ["floor_fixed","soft_floor"] and asset not in ["owner_theatre_screen","owner_theatre_side_panel","media_holder_film_screen","Television_01","boombox","classic_laptop","sketchfab_steampunk_coffee_machine"]:
			continue
		var wrapper:Node3D=_mount(parent,item,scale_at,false,instances)
		if wrapper==null:continue
		for player in wrapper.find_children("*","AnimationPlayer",true,false):
			player.stop()
			player.active=false
		for mesh in wrapper.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.lod_bias=0.5
		count+=1
	return count

func _resize_floor_item(item:Dictionary,factor:float)->void:
	# For station-free measured floor models only. Never scale contact data
	# or supported children independently of their carrier.
	var origin:Array=item["room_local_xyz"]
	for field in ["bounds_min_m","bounds_max_m"]:
		var p:Array=item[field]
		for axis in range(3):
			p[axis]=float(origin[axis])+(float(p[axis])-float(origin[axis]))*factor
	for p in item.get("physical_footprint_xz",[]):
		p[0]=float(origin[0])+(float(p[0])-float(origin[0]))*factor
		p[1]=float(origin[2])+(float(p[1])-float(origin[2]))*factor
	item["uniform_scale"]=float(item.get("uniform_scale",1.0))*factor

func _translate_hearth_item(item:Dictionary,x:float,z:float)->void:
	# Move physical bounds, rendered pivot and every world-space contact together.
	# Local measured seat data stays unchanged; cups/chess/table supports are pinned.
	var origin:Array=item["room_local_xyz"]
	var dx:float=x-float(origin[0])
	var dz:float=z-float(origin[2])
	for field in ["room_local_xyz","bounds_min_m","bounds_max_m"]:
		var p:Array=item[field]
		p[0]=float(p[0])+dx
		p[2]=float(p[2])+dz
	for p in item.get("physical_footprint_xz",[]):
		p[0]=float(p[0])+dx
		p[1]=float(p[1])+dz
	for station in item.get("station_candidates",[]):
		for field in ["room_local_xyz","room_pelvis_contact_xyz","room_feet_contact_xyz"]:
			if station.has(field):
				var p:Array=station[field]
				p[0]=float(p[0])+dx
				p[2]=float(p[2])+dz
		if station.has("room_approach_xz"):
			var p:Array=station["room_approach_xz"]
			p[0]=float(p[0])+dx
			p[1]=float(p[1])+dz

func _apply_hearth_interior_v1(hearth:Dictionary)->void:
	# Keep permanent shell and existing object homes intact.
	# Three islands: coffee/conversation, hearth, sleeping-dragon nook.
	var positions:Dictionary={
		"common_r3_p3_fur_left":Vector2(-1.64,0.23),
		"common_r3_p3_fur_right":Vector2(3.05,0.65),
		"common_r3_p3_chair_center":Vector2(-2.60,-0.08),
		"common_r3_p3_sofa_right":Vector2(3.95,-1.37),
		"common_r3_p3_chair_right":Vector2(5.90,0.72),
		"common_r3_p3_rug_right":Vector2(4.45,0.08),
		"common_r3_p3_right_coffee_table":Vector2(4.20,0.28),
		"common_r3_p3_chess_set":Vector2(4.20,0.28)
	}
	var extra:Dictionary={}
	for item in hearth["instances"]:
		var id:String=str(item["instance_id"])
		if id=="common_r3_p3_chair_center":
			extra=item.duplicate(true)
		if positions.has(id):
			var p:Vector2=positions[id]
			_translate_hearth_item(item,p.x,p.y)
	if not extra.is_empty():
		extra["instance_id"]="canonical_hearth_extra_chair"
		for station in extra.get("station_candidates",[]):
			station["station_candidate_id"]="canonical_hearth_extra_chair."+str(station["id"])
		_translate_hearth_item(extra,1.50,0.25)
		hearth["instances"].append(extra)
	var count:=0
	for item in hearth["instances"]:
		count+=item.get("station_candidates",[]).size()
	hearth["station_count"]=count
	hearth["interior_zones"]=[
		{"id":"coffee_conversation","x_range":[-7.2,-2.3]},
		{"id":"hearth_rest","x_range":[-2.3,2.4]},
		{"id":"dragon_nook","x_range":[2.4,7.2]}
	]

func _apply_social_interiors()->void:
	var file:=FileAccess.open("res://data/canonical_social_interiors_20261125.json",FileAccess.READ)
	if file==null:return
	var data=JSON.parse_string(file.get_as_text())
	if typeof(data)!=TYPE_DICTIONARY or bool(data.get("owner_approved",true)):return
	for row in data.get("variants",[]):
		for item in row.get("instances",[]):
			if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):
				push_error("Missing social interior asset "+str(item["asset_id"]))
				return
	for item in data.get("hearth_additions",[]):
		if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):return
	for row in data["variants"]:
		layouts[str(row["variant_id"])]=row
	var hearth:Dictionary=layouts["common/R3"]
	for raw in data["hearth_additions"]:
		var item:Dictionary=raw.duplicate(true)
		# The larger fireplace needs the former bar corner. Translate the
		# entire supported ensemble together; keep object IDs and heights.
		if str(item["instance_id"]) in ["hearth_bar_counter","hearth_bar_bottles","hearth_bar_goblets"]:
			var origin:Array=item["room_local_xyz"]
			_translate_hearth_item(item,float(origin[0])+0.65,float(origin[2]))
		hearth["instances"].append(item)
	hearth["runtime_review_geometry_revision"]=str(data["revision"])
	layouts["common/R3"]=hearth
	_apply_library_gallery_dressing()
	_apply_media_work_dressing()
	_apply_guest_display_dressing()
	_apply_guest_composition_v2()
	_apply_conditional_shelf_dressing()
	_apply_hearth_conversation_v2()
	_apply_social_zones_v3()
	_apply_owner_decor_refresh()
	_apply_owner_room_clusters()
	_apply_owner_chair_and_glass_v1()
	_apply_reading_guest_details()

# Supported, noninteractive replacements only. Preserve existing table/support
# IDs and skip any candidate which cannot fit its real carrier or peers.
func _apply_owner_decor_refresh()->void:
	var f:=FileAccess.open("res://data/canonical_new_decor_20261126.json",FileAccess.READ)
	if f==null:return
	var doc=JSON.parse_string(f.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):return
	for key in doc["replacements"]:
		var row:Dictionary=layouts.get(key,{})
		if row.is_empty():continue
		var items:Array=row["instances"]
		for spec in doc["replacements"][key]:
			var matches:Array=items.filter(func(item):return item["instance_id"]==spec["instance_id"])
			if matches.size()!=1:continue
			var item:Dictionary=matches[0]
			var host_id:String=_support_host_id(item)
			var hosts:Array=items.filter(func(other):return other["instance_id"]==host_id)
			if hosts.size()!=1 or not item.get("station_candidates",[]).is_empty() or not item.get("support_slots",[]).is_empty():continue
			if not ResourceLoader.exists(_asset_path(spec["asset_id"]),"PackedScene"):continue
			var host:Dictionary=hosts[0]
			var pos:Array=item["room_local_xyz"]
			var d:Array=spec["dimensions_m"]
			var scale_value:float=float(spec["uniform_scale"])
			var lo:Array=[float(pos[0])-float(d[0])*scale_value*0.5,float(pos[1]),float(pos[2])-float(d[2])*scale_value*0.5]
			var hi:Array=[float(pos[0])+float(d[0])*scale_value*0.5,float(pos[1])+float(d[1])*scale_value,float(pos[2])+float(d[2])*scale_value*0.5]
			if float(lo[0])<float(host["bounds_min_m"][0]) or float(hi[0])>float(host["bounds_max_m"][0]) or float(lo[2])<float(host["bounds_min_m"][2]) or float(hi[2])>float(host["bounds_max_m"][2]):continue
			if absf(float(lo[1])-float(host["bounds_max_m"][1]))>0.015:continue
			var collision:=false
			for other in items:
				if other["instance_id"]==item["instance_id"] or _support_host_id(other)!=host_id:continue
				var a:Array=other["bounds_min_m"]
				var b:Array=other["bounds_max_m"]
				if minf(float(hi[0]),float(b[0]))>maxf(float(lo[0]),float(a[0])) and minf(float(hi[2]),float(b[2]))>maxf(float(lo[2]),float(a[2])) and minf(float(hi[1]),float(b[1]))>maxf(float(lo[1]),float(a[1])):collision=true
			if collision:continue
			item["asset_id"]=spec["asset_id"]
			item["uniform_scale"]=scale_value
			item["rotation_deg_xyz"]=[0,0,0]
			item["bounds_min_m"]=lo
			item["bounds_max_m"]=hi
			item["physical_footprint_xz"]=[[lo[0],lo[2]],[hi[0],lo[2]],[hi[0],hi[2]],[lo[0],hi[2]]]
			item["decor_refresh_revision"]="OWNER_DECOR_V1"

# Functional clusters, not extra catalogue display. All moving hosts have
# no persistent support slots. Translate their decorative children and
# station approaches as one measured ensemble.
func _apply_owner_room_clusters()->void:
	var changes:Dictionary={
		"library/R3":{"library_reading_table":Vector2(-3.7,-1.3),"library_side_table":Vector2(5.05,0.10)},
		"music/R3":{"music_record_table":Vector2(2.30,-1.42),"music_listening_chair":Vector2(4.20,-1.37)},
		"study/R3":{"study_reference_table":Vector2(-3.2,-1.33),"study_reading_chair":Vector2(-4.7,-0.40)},
		"workshop/R3":{"workshop_tool_cart":Vector2(-3.55,-1.36),"workshop_lab_table":Vector2(4.30,-1.34)}
	}
	for key in changes:
		var row:Dictionary=layouts.get(key,{})
		if row.is_empty():continue
		for id in changes[key]:_move_social_ensemble(row,id,changes[key][id])
		row["owner_cluster_revision"]="OWNER_ROOM_CLUSTERS_V1"

# The original sofa-set mesh has a visually defective imported material.
# Use a measured single-chair derivative with a plain fabric review finish.
# Do not activate the perforated sofa or the composite table/chair mesh.
func _apply_owner_chair_and_glass_v1()->void:
	if not ResourceLoader.exists(_asset_path("blendkit_sofa_set_chair"),"PackedScene"):return
	var changes:Dictionary={"rest_social_upper/R3":"rest_r3_armchair","rest_social_lower/R3":"rest_r3_armchair","music/R3":"music_listening_chair"}
	for key in changes:
		var row:Dictionary=layouts.get(key,{})
		if row.is_empty():continue
		for item in row["instances"]:
			if item["instance_id"]!=changes[key]:continue
			assert(item.get("support_slots",[]).is_empty() and item["station_candidates"].size()==1)
			var pos:Array=item["room_local_xyz"]
			var x:float=float(pos[0])
			var y:float=float(pos[1])
			var z:float=float(pos[2])
			var scale_value:float=1.15
			var hw:float=0.816706*scale_value*0.5
			var hd:float=0.852862*scale_value*0.5
			item["asset_id"]="blendkit_sofa_set_chair"
			item["uniform_scale"]=scale_value
			item["rotation_deg_xyz"]=[0,0,0]
			item["bounds_min_m"]=[x-hw,y,z-hd]
			item["bounds_max_m"]=[x+hw,y+0.635204*scale_value,z+hd]
			item["physical_footprint_xz"]=[[x-hw,z-hd],[x+hw,z-hd],[x+hw,z+hd],[x-hw,z+hd]]
			var st:Dictionary=item["station_candidates"][0]
			st["room_pelvis_contact_xyz"]=[x,y+0.385*scale_value,z]
			st["room_feet_contact_xyz"]=[x,y,z+hd+0.07]
			st["room_approach_xz"]=[x,z+hd+0.40]
			st["room_facing_xyz"]=[0,0,1]
			st["seating_width_m"]=0.52*scale_value
			row["owner_chair_revision"]="OWNER_CHAIR_V1"
	# A laboratory beaker is a fixed decorative tool, not a physical CUP.
	# This small spare portion of the lab table is outside all existing props.
	var lab:Dictionary=layouts.get("workshop/R3",{})
	if not lab.is_empty():
		_add_owner_supported_glass(lab,"workshop_lab_table","owner_lab_beaker","blendkit_beaker_flask",Vector2(4.30,-1.08),Vector3(0.099607,0.0994,0.099607))
	var gallery:Dictionary=layouts.get("artifact/R3",{})
	if not gallery.is_empty():
		_add_owner_supported_glass(gallery,"gallery_display_table","owner_gallery_glass_cover","blendkit_decorational_glass_cover_storage",Vector2(-4.8,0.05),Vector3(0.26,0.393966,0.26))

func _add_owner_supported_glass(row:Dictionary,host_id:String,id:String,asset:String,at:Vector2,d:Vector3)->void:
	if not ResourceLoader.exists(_asset_path(asset),"PackedScene"):return
	var host:Dictionary={}
	for i in row["instances"]:
		if i["instance_id"]==host_id:host=i
	if host.is_empty() or not host.get("support_slots",[]).is_empty():return
	var y:float=float(host["bounds_max_m"][1])
	var lo:Array=[at.x-d.x*0.5,y,at.y-d.z*0.5]
	var hi:Array=[at.x+d.x*0.5,y+d.y,at.y+d.z*0.5]
	if lo[0]<host["bounds_min_m"][0] or hi[0]>host["bounds_max_m"][0] or lo[2]<host["bounds_min_m"][2] or hi[2]>host["bounds_max_m"][2]:return
	for other in row["instances"]:
		if _support_host_id(other)!=host_id:continue
		var a:Array=other["bounds_min_m"]
		var b:Array=other["bounds_max_m"]
		if minf(hi[0],b[0])>maxf(lo[0],a[0]) and minf(hi[2],b[2])>maxf(lo[2],a[2]):return
	row["instances"].append({"instance_id":id,"asset_id":asset,"room_local_xyz":[at.x,y,at.y],"rotation_deg_xyz":[0,0,0],"uniform_scale":1.0,"bounds_min_m":lo,"bounds_max_m":hi,"physical_footprint_xz":[[lo[0],lo[2]],[hi[0],lo[2]],[hi[0],hi[2]],[lo[0],hi[2]]],"placement_policy":"supported_on","support_ref":host_id+"."+id,"station_candidates":[],"support_slots":[],"owner_approved":false})

# Measured noninteractive detail. Keep existing book/cup/artifact homes
# fixed, and reject any supported prop which overlaps its carrier's peers.
func _apply_reading_guest_details()->void:
	var file:=FileAccess.open("res://data/canonical_reading_guest_details_20261126.json",FileAccess.READ)
	if file==null:return
	var doc=JSON.parse_string(file.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):return
	for key in doc["additions"]:
		var row:Dictionary=layouts.get(key,{})
		if row.is_empty():continue
		for spec in doc["additions"][key]:
			if not ResourceLoader.exists(_asset_path(spec["asset_id"]),"PackedScene"):continue
			var pos:Array=spec["room_local_xyz"].duplicate()
			var policy:String=spec["placement_policy"]
			var host_id:String=spec["support_host_id"]
			var host:Dictionary={}
			if policy=="supported":
				for other in row["instances"]:
					if other["instance_id"]==host_id:host=other
				if host.is_empty() or not host.get("support_slots",[]).is_empty():continue
				pos[1]=host["bounds_max_m"][1]
			var lo:Array=[]
			var hi:Array=[]
			for axis in range(3):
				lo.append(float(pos[axis])+float(spec["local_min_m"][axis])*float(spec["uniform_scale"]))
				hi.append(float(pos[axis])+float(spec["local_max_m"][axis])*float(spec["uniform_scale"]))
			if policy=="supported" and (lo[0]<host["bounds_min_m"][0] or hi[0]>host["bounds_max_m"][0] or lo[2]<host["bounds_min_m"][2] or hi[2]>host["bounds_max_m"][2]):continue
			var collision:=false
			for other in row["instances"]:
				if policy=="supported" and _support_host_id(other)!=host_id:continue
				if policy=="floor_fixed" and other["placement_policy"]!="floor_fixed":continue
				if policy not in ["supported","floor_fixed"]:continue
				var a:Array=other["bounds_min_m"]
				var b:Array=other["bounds_max_m"]
				if minf(hi[0],b[0])-maxf(lo[0],a[0])>0.001 and minf(hi[2],b[2])-maxf(lo[2],a[2])>0.001:collision=true
			if collision:continue
			row["instances"].append({"instance_id":spec["instance_id"],"asset_id":spec["asset_id"],"room_local_xyz":pos,"rotation_deg_xyz":[0,0,0],"uniform_scale":spec["uniform_scale"],"bounds_min_m":lo,"bounds_max_m":hi,"physical_footprint_xz":[[lo[0],lo[2]],[hi[0],lo[2]],[hi[0],hi[2]],[lo[0],hi[2]]],"placement_policy":policy,"support_ref":host_id+"."+str(spec["instance_id"]) if policy=="supported" else null,"station_candidates":[],"support_slots":[],"owner_approved":false,"reading_guest_detail_revision":"READING_GUEST_DETAILS_V1"})
		row["reading_guest_detail_revision"]="READING_GUEST_DETAILS_V1"

# Owner permits furniture relocation. Only two unsupported chairs move;
# preserve support IDs, cup homes, dragon and the authored shell.
func _apply_hearth_conversation_v2()->void:
	var row:Dictionary=layouts.get("common/R3",{})
	if row.is_empty():return
	var positions:Dictionary={"common_r3_p3_chair_center":Vector2(-2.6,-1.4),"canonical_hearth_extra_chair":Vector2(1.8,-0.5)}
	for item in row.get("instances",[]):
		var id:String=str(item["instance_id"])
		if positions.has(id):
			var at:Vector2=positions[id]
			_translate_hearth_item(item,at.x,at.y)
	row["runtime_review_geometry_revision"]="CANONICAL_SOCIAL_INTERIOR_20261125_V2_HEARTH"

# Move unsupported furniture and its purely decorative children as a unit.
# Leave all registered cup homes and measured return supports pinned.
func _move_social_ensemble(row:Dictionary,id:String,at:Vector2)->void:
	var host:Dictionary={}
	for item in row["instances"]:
		if str(item["instance_id"])==id:host=item
	if host.is_empty():return
	assert(host.get("support_slots",[]).is_empty())
	var origin:Array=host["room_local_xyz"]
	var delta:=at-Vector2(float(origin[0]),float(origin[2]))
	for item in row["instances"]:
		if _support_host_id(item)!=id:continue
		assert(str(item.get("asset_id","")) not in ["candidate_dragon_mug_red","candidate_guest_mug_blue"])
		var p:Array=item["room_local_xyz"]
		_translate_hearth_item(item,float(p[0])+delta.x,float(p[2])+delta.y)
	_translate_hearth_item(host,at.x,at.y)

func _apply_social_zones_v3()->void:
	var changes:Dictionary={
		"kitchen/R3":{
			"kitchen_prep":Vector2(-2.65,-1.30),
			"kitchen_stove":Vector2(-1.66,-1.35),
			"kitchen_micro_table":Vector2(-0.68,-1.30),
			"kitchen_storage":Vector2(1.05,-1.45),
			"kitchen_social":Vector2(5.95,0.35),
			"kitchen_social_chair":Vector2(6.45,-1.35)
		},
		"rest_social_upper/R3":{
			"rest_r3_armchair":Vector2(2.00,-1.38),
			"rest_social_upper_rug":Vector2(0.85,0.08)
		},
		"rest_social_lower/R3":{
			"rest_r3_armchair":Vector2(1.65,-0.74),
			"rest_social_lower_side":Vector2(-2.0,-0.20),
			"rest_social_lower_rug":Vector2(-0.20,0.12)
		}
	}
	for key in changes:
		var row:Dictionary=layouts.get(key,{})
		if row.is_empty():continue
		for id in changes[key]:_move_social_ensemble(row,id,changes[key][id])
		if key=="kitchen/R3":
			# Two actual reading/rest-compatible chairs share the social nook.
			var extra:Dictionary={}
			for item in row["instances"]:
				if str(item["instance_id"])=="kitchen_social_chair":extra=item.duplicate(true)
			if not extra.is_empty():
				extra["instance_id"]="kitchen_social_chair_b"
				for station in extra["station_candidates"]:
					station["station_candidate_id"]="kitchen_social_chair_b."+str(station["id"])
				_translate_hearth_item(extra,5.26,-1.35)
				row["instances"].append(extra)
		row["social_zone_revision"]="SOCIAL_ZONES_V3"
		var count:=0
		for item in row["instances"]:count+=item.get("station_candidates",[]).size()
		row["station_count"]=count

func _apply_library_gallery_dressing()->void:
	var file:=FileAccess.open("res://data/canonical_library_gallery_20261125.json",FileAccess.READ)
	if file==null:return
	var doc=JSON.parse_string(file.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):return
	for key in doc.get("additions",{}):
		if not layouts.has(key):continue
		var valid:=true
		for item in doc["additions"][key]:
			if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):
				valid=false
				push_error("Library/gallery missing model "+str(item["asset_id"]))
		if valid:
			layouts[key]["instances"].append_array(doc["additions"][key])
			layouts[key]["canonical_dressing_revision"]="LIBRARY_GALLERY_V1"
			if key=="library/R3":
				# The two existing reading chairs faced the rear wall, so
				# neither could bind the measured front-facing READ pose.
				# Rotate the complete contact/footprint contract in place.
				for chair in layouts[key]["instances"]:
					if str(chair.get("instance_id","")) in ["library_r3_reading_chair","library_r3_reading_chair_b"]:
						_face_library_chair_front(chair)
				layouts[key]["canonical_dressing_revision"]="LIBRARY_GALLERY_V2_READING"

func _face_library_chair_front(chair:Dictionary)->void:
	var p:Array=chair["room_local_xyz"]
	var lo:Array=chair["bounds_min_m"].duplicate()
	var hi:Array=chair["bounds_max_m"].duplicate()
	chair["rotation_deg_xyz"][1]=0.0
	chair["bounds_min_m"]=[2.0*float(p[0])-float(hi[0]),lo[1],2.0*float(p[2])-float(hi[2])]
	chair["bounds_max_m"]=[2.0*float(p[0])-float(lo[0]),hi[1],2.0*float(p[2])-float(lo[2])]
	for point in chair.get("physical_footprint_xz",[]):
		point[0]=2.0*float(p[0])-float(point[0])
		point[1]=2.0*float(p[2])-float(point[1])
	for station in chair.get("station_candidates",[]):
		for field in ["room_pelvis_contact_xyz","room_feet_contact_xyz"]:
			var point:Array=station[field]
			point[0]=2.0*float(p[0])-float(point[0])
			point[2]=2.0*float(p[2])-float(point[2])
		var approach:Array=station["room_approach_xz"]
		approach[0]=2.0*float(p[0])-float(approach[0])
		approach[1]=2.0*float(p[2])-float(approach[1])
		var facing:Array=station["room_facing_xyz"]
		facing[0]=-float(facing[0])
		facing[2]=-float(facing[2])

func _apply_media_work_dressing()->void:
	var file:=FileAccess.open("res://data/canonical_media_work_interiors_20261125.json",FileAccess.READ)
	if file==null:return
	var doc=JSON.parse_string(file.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):return
	for key in doc.get("additions",{}):
		if not layouts.has(key):continue
		var valid:=true
		for item in doc["additions"][key]:
			if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):
				valid=false
				push_error("Media/work missing model "+str(item["asset_id"]))
		if valid:
			layouts[key]["instances"].append_array(doc["additions"][key])
			layouts[key]["canonical_dressing_revision"]="MEDIA_WORK_V1"

func _apply_guest_display_dressing()->void:
	var file:=FileAccess.open("res://data/canonical_guest_display_interiors_20261125.json",FileAccess.READ)
	if file==null:return
	var doc=JSON.parse_string(file.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):return
	for key in doc.get("additions",{}):
		if not layouts.has(key):continue
		var valid:=true
		for item in doc["additions"][key]:
			if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):
				valid=false
				push_error("Guest/display missing model "+str(item["asset_id"]))
		if valid:
			layouts[key]["instances"].append_array(doc["additions"][key])
			layouts[key]["guest_display_revision"]="GUEST_DISPLAY_V1"

func _apply_guest_composition_v2()->void:
	# Keep the larger body space open: enlarge only the soft mat, and
	# relocate the table plus its decorative children toward the storage.
	var centaur:Dictionary=layouts.get("guest_centaur/R2",{})
	if centaur.is_empty():return
	_move_social_ensemble(centaur,"guest_centaur_01_table",Vector2(1.85,-1.55))
	for item in centaur["instances"]:
		if str(item["instance_id"])=="guest_centaur_01_rest_mat":
			# This textile already owns a real floor-rest candidate from
			# the R1 review delta. Scale its top contact as well.
			_resize_floor_item(item,1.55)
			for station in item["station_candidates"]:
				assert(station["kind"]=="floor_rest")
				station["room_local_xyz"][1]=item["bounds_max_m"][1]
			_translate_hearth_item(item,-2.05,-0.65)
		if str(item["instance_id"])=="centaur_textile":
			_translate_hearth_item(item,1.85,0.05)
	centaur["guest_composition_revision"]="CENTAUR_COMPOSITION_V2"

func _apply_conditional_shelf_dressing()->void:
	var file:=FileAccess.open("res://data/canonical_conditional_shelves_20261125.json",FileAccess.READ)
	if file==null:return
	var doc=JSON.parse_string(file.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY or bool(doc.get("owner_approved",true)):return
	for key in doc.get("additions",{}):
		if not layouts.has(key):continue
		for item in doc["additions"][key]:
			if not ResourceLoader.exists(_asset_path(str(item["asset_id"])),"PackedScene"):
				push_error("Missing conditional shelf model "+str(item["asset_id"]))
				continue
			layouts[key]["instances"].append(item)
