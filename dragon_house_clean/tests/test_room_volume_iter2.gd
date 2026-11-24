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

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.world.save_path="user://test_room_volume_iter2.json"
	scene.world.seed_world()
	scene.make_rooms()
	await process_frame

	var common:Dictionary=scene.world.get_room(-2,0)
	assert(scene.world.room_size_modules(common)==3)
	var node:Node3D=scene.room_root.get_node(str(common["id"]))
	assert(node!=null)
	var rear:Node3D=node.get_node("Layer_Background/Stage_Backwall")
	var depth:Node3D=node.get_node("Layer_Structure/Stage_CutawayDepth")
	assert(rear!=null and depth!=null)
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
	scene.make_rooms()
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
	assert(backdrop.position.z < furniture_back.position.z)
	assert(absf(backdrop.position.z+1.90)<0.01)
	assert(absf(furniture_back.position.z+0.82)<0.01)

	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+suffix))
	print("ITER2_ROOM_VOLUME_PASS R3_single_shell=true authored_fallback=true art_depth=true")
	quit(0)
