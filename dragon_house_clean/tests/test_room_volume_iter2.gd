extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func _names(node: Node) -> Array:
	var out:Array=[]
	for child in node.get_children():
		out.append(str(child.name))
	return out

func _span_x(node: Node3D) -> float:
	var lo:=INF
	var hi:=-INF
	for child in node.get_children():
		if child is Node3D:
			lo=minf(lo,(child as Node3D).position.x)
			hi=maxf(hi,(child as Node3D).position.x)
	return 0.0 if is_inf(lo) or is_inf(hi) else hi-lo

func _alpha_stats(tex: Texture2D) -> Dictionary:
	var img:Image=tex.get_image()
	if img==null or img.is_empty():
		return {"ok":false}
	var step_x:int=maxi(1,img.get_width()/96)
	var step_y:int=maxi(1,img.get_height()/64)
	var total:int=0
	var visible:int=0
	var solid:int=0
	var alpha_sum:float=0.0
	for y in range(0,img.get_height(),step_y):
		for x in range(0,img.get_width(),step_x):
			var a:float=img.get_pixel(x,y).a
			total+=1
			alpha_sum+=a
			if a>0.05:
				visible+=1
			if a>0.95:
				solid+=1
	var used:Rect2i=img.get_used_rect()
	var used_frac:float=float(used.size.x*used.size.y)/maxf(1.0,float(img.get_width()*img.get_height()))
	return {
		"ok":true,
		"visible_ratio":float(visible)/maxf(1.0,float(total)),
		"solid_ratio":float(solid)/maxf(1.0,float(total)),
		"mean_alpha":alpha_sum/maxf(1.0,float(total)),
		"used_frac":used_frac,
		"used":[used.position.x,used.position.y,used.size.x,used.size.y],
		"size":[img.get_width(),img.get_height()]
	}

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame

	var common:Dictionary=scene.world.get_room(-2,0)
	assert(scene.world.room_size_modules(common)==3)
	var node:Node3D=scene.room_root.get_node(str(common["id"]))
	assert(node!=null)
	var background:Node3D=node.get_node("Layer_Background")
	var rear:Node3D=background.get_node("Stage_Backwall")
	var depth:Node3D=node.get_node("Layer_Structure/Stage_CutawayDepth")
	var rear_backup:MeshInstance3D=background.get_node("StructuralRearBackup")
	assert(rear!=null and depth!=null and rear_backup!=null)
	var rear_box:BoxMesh=rear_backup.mesh as BoxMesh
	assert(rear_box!=null)
	var rear_front:float=rear_backup.position.z+rear_box.size.z*0.5
	assert(rear_front < scene.world.room_space.BACK_Z,
		"Structural rear wall must stay behind the playable room boundary")
	assert(_names(rear)==["PhysicalRearWall"],
		"R3 rear wall must be one continuous physical wall")
	assert(_names(depth)==["PhysicalDepthVolume"],
		"R3 depth floor must be one continuous physical volume")
	for name in _names(rear):
		assert(not str(name).begins_with("RearBay_"))
	for name in _names(depth):
		assert(not str(name).begins_with("Depth_"))

	scene._populate_furniture(node)
	var local:Node3D=node.get_node("LocalFurniture")
	assert(local.get_child_count()==1)
	assert(str(local.get_child(0).name)=="PhysicalFurniture")
	for child in local.get_children():
		assert(not str(child.name).ends_with("_furniture"))

	# Synthetic wide room without accepted art: use one pinned authoring layout.
	var study:Dictionary=scene.world.make_room(10,2,"study",3,false)
	var study_group:Dictionary=scene.world.merged_group(10,2)
	scene.make_room(study_group)
	var study_node:Node3D=scene.room_root.get_node(str(study["id"]))
	assert(study_node!=null)
	assert(scene.room_visual_layout.has_variant("study",3))
	scene._populate_furniture(study_node)
	var study_local:Node3D=study_node.get_node("LocalFurniture")
	assert(study_local.get_child_count()==1)
	var physical:Node3D=study_local.get_node("PhysicalFurniture")
	assert(physical!=null)
	assert(physical.get_child_count()>=3,
		"Authored R3 fallback must materialize tangible objects across one room")
	assert(_span_x(physical)>5.0,
		"R3 authored fallback must occupy the physical width, not one R1 module")

	# Room art planes are physically separated in Z.
	var art:Node3D=node.get_node("Layer_ApprovedArt")
	scene._load_room_art(node)
	var backdrop:Sprite3D=art.get_node_or_null("Art_backdrop")
	var furniture_back:Sprite3D=art.get_node_or_null("Art_furniture_back")
	assert(backdrop!=null and furniture_back!=null)
	assert(not rear.visible,
		"Procedural Stage_Backwall must be hidden while a real backdrop is loaded")
	for child in art.get_children():
		assert(str(child.name).begins_with("Art_") and not str(child.name).begins_with("@"),
			"Art reload must preserve stable layer node names")
	assert(backdrop.position.z < furniture_back.position.z)
	assert(backdrop.position.z > rear_front,
		"Backdrop must render in front of the structural rear wall")
	assert(backdrop.position.z < scene.world.room_space.BACK_Z,
		"Backdrop must stay behind the deepest playable actor position")
	assert(absf(backdrop.position.z+2.02)<0.01)
	assert(absf(furniture_back.position.z+0.82)<0.01)
	for role in ["backdrop","back_decor","furniture_back","foreground"]:
		var sprite:Sprite3D=art.get_node_or_null("Art_"+role)
		if sprite!=null and sprite.texture!=null:
			print("ITER2_ALPHA role=%s stats=%s" % [role,str(_alpha_stats(sprite.texture))])

	print("ITER2_ROOM_VOLUME_PASS R3_single_shell=true authored_fallback=true art_depth=true")
	quit(0)
