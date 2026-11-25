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
var error:=""
func initialize(force_review:bool=false) -> bool:
	layouts.clear()
	surfaces.clear()
	packed_model_cache.clear()
	packed_model_lru.clear()
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

func _mount(parent:Node3D,item:Dictionary,scale_at:Callable,animate:bool=true,support_items:Dictionary={})->Node3D:
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
	var z:float=float(position[2])
	# Match existing artistic depth correction, while retaining unwarped
	# room coordinates as metadata for inspection.
	var depth:float=float(scale_at.call(z))
	wrapper.position=Vector3(float(position[0])*depth,float(position[1]),z)
	# A supported child must use its carrier coordinate transform, not a second
	# independent depth warp. This fixes render-space gaps even when physical AABBs touch.
	var support_id:String=str(item.get("support_ref","")).get_slice(".",0)
	if not support_items.has(support_id):support_id=str(item.get("decor_slot_id","")).get_slice(".",0)
	if support_items.has(support_id):
		var carrier:Array=support_items[support_id]["room_local_xyz"]
		depth=float(scale_at.call(float(carrier[2])))
		wrapper.position=Vector3(float(position[0])*depth,float(carrier[1])+(float(position[1])-float(carrier[1]))*depth,float(carrier[2])+(z-float(carrier[2]))*depth)
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

func populate(parent:Node3D, kind:String, width:int, scale_at:Callable)->int:
	var row:Dictionary=variant(kind,width)
	var count:=0
	var nodes:Dictionary={}
	var support_items:Dictionary={}
	for item in row.get("instances",[]):support_items[str(item["instance_id"])]=item
	for item in row.get("instances",[]):
		if live_physical_objects and str(item.get("asset_id","")) in ["candidate_dragon_mug_red","candidate_guest_mug_blue"]:
			continue
		var wrapper:Node3D=_mount(parent,item,scale_at,true,support_items)
		if wrapper!=null:
			nodes[str(item["instance_id"])]=wrapper
			count+=1
	for id in surfaces:
		var spec:Dictionary=surfaces[id]
		if str(spec["room_variant"])!=str(row.get("variant_id","")):
			continue
		var holder:Dictionary=spec.get("holder_instance",{})
		var carrier:Node3D
		var direct_carrier:=false
		var category:String=str(spec.get("legacy_runtime_category",""))
		var carrier_id:String=str(spec.get("carrier_instance_id",""))
		if str(row.get("variant_id","")) in ["library/R3","artifact/R3","music/R3"] and category in ["books","artifacts","tracks"]:
			if category=="tracks":
				var audio_ids:Dictionary={"music.r3.audio.01":"music_r3_p2_boombox","music.r3.audio.02":"music_r3_p2_cassette","music.r3.audio.03":"music_cassette_deck"}
				carrier_id=str(audio_ids.get(str(id),""))
			if not nodes.has(carrier_id):continue
			carrier=nodes[carrier_id]
			direct_carrier=true
		elif holder.is_empty():
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
		if direct_carrier:
			var item:Dictionary=support_items[carrier_id]
			var lo:Array=item["bounds_min_m"]
			var hi:Array=item["bounds_max_m"]
			var origin:Array=item["room_local_xyz"]
			var factor:float=maxf(0.001,float(item.get("uniform_scale",1.0)))
			anchor.position=Vector3((float(lo[0])+float(hi[0]))*0.5-float(origin[0]),(float(lo[1])+float(hi[1]))*0.5-float(origin[1]),float(hi[2])-float(origin[2])+0.008)/factor
			anchor.set_meta("direct_carrier",true)
		anchor.set_meta("surface_id",str(id))
		anchor.set_meta("surface_category",str(spec["legacy_runtime_category"]))
		anchor.set_meta("surface_size",Vector2(float(aperture["width_m"]),float(aperture["height_m"])))
		if direct_carrier:
			var item:Dictionary=support_items[carrier_id]
			var lo:Array=item["bounds_min_m"]
			var hi:Array=item["bounds_max_m"]
			anchor.set_meta("surface_size",Vector2(float(hi[0])-float(lo[0]),float(hi[1])-float(lo[1]))/maxf(0.001,float(item.get("uniform_scale",1.0))))
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
	if asset in ["owner_sleeping_dragon","artifact_glass_cube_s","artifact_glass_cube_m","artifact_glass_cube_l"]:
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
		if str(item["instance_id"])=="common_r3_p3_plant":
			continue
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
	# Provisional 4.5x scale (1.575 m long) makes the sleeping animal legible beside the sofa.
	# Exact AABB, no pickup, no AI, no animation, no sleeping timer.
	items.append({
		"instance_id":"canonical_hearth_sleeping_dragon",
		"asset_id":"owner_sleeping_dragon",
		"room_local_xyz":[6.30,0.0,-1.30],
		"rotation_deg_xyz":[0,0,0],
		"uniform_scale":4.5,
		"bounds_min_m":[5.5125,0.0,-1.91801425],
		"bounds_max_m":[7.0875,0.2032245,-0.68198575],
		"physical_footprint_xz":[[5.5125,-1.91801425],[7.0875,-1.91801425],[7.0875,-0.68198575],[5.5125,-0.68198575]],
		"placement_policy":"floor_fixed","station_candidates":[],"support_slots":[],
		"support_ref":null,"owner_approved":false
	})
	hearth["instances"]=items
	_apply_hearth_interior_v1(hearth)
	hearth["runtime_review_geometry_revision"]="CANONICAL_HEARTH_INTERIOR_20261125_V1"
	layouts["common/R3"]=hearth
	_apply_social_interiors()

func populate_overview(parent:Node3D,kind:String,width:int,scale_at:Callable)->int:
	# Actual normalized model silhouettes, not box proxies. Shared imported
	# resources can use Godot mesh LOD; no media hotspots or running fire clips.
	var row:Dictionary=variant(kind,width)
	var count:=0
	var support_items:Dictionary={}
	for item in row.get("instances",[]):support_items[str(item["instance_id"])]=item
	for item in row.get("instances",[]):
		var asset:String=str(item["asset_id"])
		var policy:String=str(item.get("placement_policy",""))
		if policy not in ["floor_fixed","soft_floor"] and asset not in ["media_holder_film_screen","Television_01","boombox","classic_laptop","sketchfab_steampunk_coffee_machine"]:
			continue
		var wrapper:Node3D=_mount(parent,item,scale_at,false,support_items)
		if wrapper==null:continue
		for player in wrapper.find_children("*","AnimationPlayer",true,false):
			player.stop()
			player.active=false
		for mesh in wrapper.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.lod_bias=0.5
		count+=1
	return count

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
		"common_r3_p3_fur_right":Vector2(6.45,0.65),
		"common_r3_p3_chair_center":Vector2(-2.60,-0.08),
		"common_r3_p3_sofa_right":Vector2(3.95,-1.37),
		"common_r3_p3_chair_right":Vector2(5.80,-0.04),
		"common_r3_p3_rug_right":Vector2(4.45,0.08)
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
	hearth["instances"].append_array(data["hearth_additions"])
	hearth["runtime_review_geometry_revision"]=str(data["revision"])
	layouts["common/R3"]=hearth
	_apply_library_gallery_dressing()
	_apply_media_work_dressing()
	_apply_guest_display_dressing()
	_apply_conditional_shelf_dressing()
	# Old decorative empty cube and miniature are not physical artifact identities.
	if layouts.has("artifact/R3"):
		var gallery:Dictionary=layouts["artifact/R3"]
		gallery["instances"]=gallery["instances"].filter(func(item):return not str(item["instance_id"]) in ["artifact_r3_p2_neutral_cube","artifact_r3_toy_elephant_candidate"])

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
