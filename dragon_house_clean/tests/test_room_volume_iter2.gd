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
	var physical_depth:Node3D=depth.get_node("PhysicalDepthVolume")
	for child in physical_depth.get_children():
		if child is Node3D:
			assert((child as Node3D).position.z > scene.world.room_space.BACK_Z+0.20,
				"Depth helpers must stay out of the rear art/backdrop zone")
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

	# Room art is physically layered. Common R3 replaces the monolithic
	# furniture_back plane with calibrated object sprites at real X/Z.
	var art:Node3D=node.get_node("Layer_ApprovedArt")
	scene._load_room_art(node)
	var backdrop:Sprite3D=art.get_node_or_null("Art_backdrop")
	assert(backdrop!=null)
	assert(art.get_node_or_null("Art_furniture_back")==null,
		"Common R3 must not keep a monolithic furniture_back plane")
	assert(art.get_node_or_null("Art_back_decor")==null,
		"Common R3 must not keep a monolithic transparent back_decor plane")
	assert(art.get_node_or_null("Art_foreground")==null,
		"Common R3 global foreground mask is suppressed after component split")
	var shelf_left:Sprite3D=art.get_node("Art_back_decor_bookshelf_left")
	var shelf_mid:Sprite3D=art.get_node("Art_back_decor_bookshelf_mid")
	var wall_light:Sprite3D=art.get_node("Art_back_decor_wall_light_mid")
	var sofa:Sprite3D=art.get_node("Art_furniture_back_sofa_left")
	var side_table:Sprite3D=art.get_node("Art_furniture_back_side_table")
	var chair_left:Sprite3D=art.get_node("Art_furniture_back_chair_left")
	var bench_right:Sprite3D=art.get_node("Art_furniture_back_bench_right")
	var round_table:Sprite3D=art.get_node("Art_furniture_back_round_table")
	var chair_right:Sprite3D=art.get_node("Art_furniture_back_chair_right")
	assert(absf(shelf_left.position.x+6.10)<0.01 and absf(shelf_left.position.z+1.70)<0.01)
	assert(absf(shelf_mid.position.x-0.95)<0.01 and absf(shelf_mid.position.z+1.70)<0.01)
	assert(absf(wall_light.position.z+1.70)<0.01)
	assert(absf(sofa.position.x+5.25)<0.01 and absf(sofa.position.z+0.88)<0.01)
	assert(shelf_left.position.z < sofa.position.z-0.7,
		"Rear bookshelf must sort as a separate object behind the nearer sofa")
	assert(absf(side_table.position.x+3.55)<0.01 and absf(side_table.position.z+0.10)<0.01)
	assert(absf(chair_left.position.z+0.72)<0.01)
	assert(absf(bench_right.position.z+0.82)<0.01)
	assert(absf(round_table.position.z-0.18)<0.01)
	assert(absf(chair_right.position.z+0.78)<0.01)
	assert(round_table.position.z > sofa.position.z+0.9,
		"Front table must occupy a visibly nearer Z plane than the rear sofa")
	assert(not rear.visible,
		"Procedural Stage_Backwall must be hidden while a real backdrop is loaded")
	for child in art.get_children():
		assert(str(child.name).begins_with("Art_") and not str(child.name).begins_with("@"),
			"Art reload must preserve stable layer node names")
	assert(backdrop.position.z > rear_front,
		"Backdrop must render in front of the structural rear wall")
	assert(backdrop.position.z < scene.world.room_space.BACK_Z,
		"Backdrop must stay behind the deepest playable actor position")
	assert(absf(backdrop.position.z+2.02)<0.01)

	# Library R2 uses the same physical component contract: rear chairs and
	# a front table are independent sprites, not one flat image.
	var library:Dictionary=scene.world.make_room(10,3,"library",2,false)
	var library_group:Dictionary=scene.world.merged_group(10,3)
	scene.make_room(library_group)
	var library_node:Node3D=scene.room_root.get_node(str(library["id"]))
	scene._load_room_art(library_node)
	var library_art:Node3D=library_node.get_node("Layer_ApprovedArt")
	assert(library_art.get_node_or_null("Art_furniture_back")==null)
	assert(library_art.get_node_or_null("Art_back_decor")==null)
	assert(library_art.get_node_or_null("Art_foreground")==null)
	var lib_shelf_left:Sprite3D=library_art.get_node("Art_back_decor_bookshelf_left")
	var lib_shelf_mid:Sprite3D=library_art.get_node("Art_back_decor_bookshelf_mid")
	var lib_shelf_right:Sprite3D=library_art.get_node("Art_back_decor_bookshelf_right")
	var lib_left:Sprite3D=library_art.get_node("Art_furniture_back_chair_left")
	var lib_table:Sprite3D=library_art.get_node("Art_furniture_back_table")
	var lib_right:Sprite3D=library_art.get_node("Art_furniture_back_chair_right")
	assert(absf(lib_shelf_left.position.x+3.45)<0.01 and absf(lib_shelf_left.position.z+1.70)<0.01)
	assert(absf(lib_shelf_mid.position.x-0.15)<0.01 and absf(lib_shelf_mid.position.z+1.70)<0.01)
	assert(absf(lib_shelf_right.position.x-3.35)<0.01 and absf(lib_shelf_right.position.z+1.70)<0.01)
	assert(absf(lib_left.position.x+2.15)<0.01 and absf(lib_left.position.z+0.68)<0.01)
	assert(lib_shelf_left.position.z < lib_left.position.z-0.9)
	assert(absf(lib_right.position.x-2.15)<0.01 and absf(lib_right.position.z+0.68)<0.01)
	assert(absf(lib_table.position.x)<0.01 and absf(lib_table.position.z-0.18)<0.01)
	assert(lib_table.position.z > lib_left.position.z+0.8)

	print("ITER2_ROOM_VOLUME_PASS R3_single_shell=true authored_fallback=true component_depth=true rear_decor_sort=true")
	quit(0)
