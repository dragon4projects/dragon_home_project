extends RefCounted
## Explicit, opt-in TEEA008 review. Never changes canonical world or approval.
const ROOT := "res://assets/teea008_review/decor_bank/"
const LAYOUT := "res://data/teea008_review/room_layouts_xz.json"
const MEDIA := "res://data/teea008_review/media_surface_delta.json"
var surfaces:Dictionary={}
var layouts:Dictionary={}
var enabled:=false
var error:=""
func initialize() -> bool:
	layouts.clear()
	surfaces.clear()
	enabled=false
	error=""
	if OS.get_environment("DRAGON_TEEA008_REVIEW")!="1":
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

func _mount(parent:Node3D,item:Dictionary,scale_at:Callable)->Node3D:
	var asset:String=str(item["asset_id"])
	var position:Array=item["room_local_xyz"]
	var rotation:Array=item["rotation_deg_xyz"]
	var scene:=ResourceLoader.load(ROOT+asset+"/model.gltf","PackedScene") as PackedScene
	if scene==null:
		return null
	var wrapper:=Node3D.new()
	wrapper.name=str(item["instance_id"]).validate_node_name()
	var z:float=float(position[2])
	# Match existing artistic depth correction, while retaining unwarped
	# room coordinates as metadata for inspection.
	var depth:float=float(scale_at.call(z))
	wrapper.position=Vector3(float(position[0])*depth,float(position[1]),z)
	wrapper.rotation_degrees=Vector3(float(rotation[0]),float(rotation[1]),float(rotation[2]))
	wrapper.scale=Vector3.ONE*float(item.get("uniform_scale",1.0))*depth
	wrapper.set_meta("candidate_instance_id",str(item["instance_id"]))
	wrapper.set_meta("candidate_asset_id",asset)
	wrapper.set_meta("physical_xyz",position)
	wrapper.set_meta("owner_approved",false)
	parent.add_child(wrapper)
	wrapper.add_child(scene.instantiate())
	return wrapper

func populate(parent:Node3D, kind:String, width:int, scale_at:Callable)->int:
	var row:Dictionary=variant(kind,width)
	var count:=0
	var nodes:Dictionary={}
	for item in row.get("instances",[]):
		var wrapper:Node3D=_mount(parent,item,scale_at)
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
			carrier=_mount(parent,holder,scale_at)
		if carrier==null:
			push_error("TEEA008 missing mounted media holder "+str(id))
			continue
		var aperture:Dictionary=spec["aperture"]
		var center:Array=aperture["center_xyz"]
		var anchor:=Node3D.new()
		anchor.name="Aperture_"+str(id).validate_node_name()
		anchor.position=Vector3(float(center[0]),float(center[1]),float(center[2]))
		anchor.set_meta("surface_id",str(id))
		anchor.set_meta("surface_category",str(spec["legacy_runtime_category"]))
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
