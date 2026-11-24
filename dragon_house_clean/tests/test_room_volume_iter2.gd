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

	var mountain:Node3D=scene.get_node("MountainMassBehindRooms")
	assert(mountain!=null and mountain.get_child_count()==1,
		"HOUSE mountain must be one continuous textured mass without floating support boxes")

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
	var structural_panel:MeshInstance3D=rear.get_node("PhysicalRearWall/StructuralRearPanel")
	var structural_box:BoxMesh=structural_panel.mesh as BoxMesh
	assert(structural_box!=null)
	var structural_front:float=structural_panel.position.z+structural_box.size.z*0.5
	assert(structural_front < scene.world.room_space.BACK_Z,
		"Fallback rear panel must stay behind authored backdrop/playable back plane")
	assert(_names(depth)==["PhysicalDepthVolume"],
		"R3 depth floor must be one continuous physical volume")
	var beams:Node3D=node.get_node_or_null("Layer_Structure/CeilingDepthBeams")
	assert(beams!=null and beams.get_child_count()==3)
	assert((beams.get_node("DepthBeam_0") as Node3D).position.z <
		(beams.get_node("DepthBeam_1") as Node3D).position.z)
	assert((beams.get_node("DepthBeam_1") as Node3D).position.z <
		(beams.get_node("DepthBeam_2") as Node3D).position.z)
	var physical_depth:Node3D=depth.get_node("PhysicalDepthVolume")
	for child in physical_depth.get_children():
		if child is Node3D:
			assert((child as Node3D).position.z > scene.world.room_space.BACK_Z+0.20,
				"Depth helpers must stay out of the rear art/backdrop zone")
	var guide0:MeshInstance3D=physical_depth.get_node("PerspectiveGuide_0")
	var guide1:MeshInstance3D=physical_depth.get_node("PerspectiveGuide_1")
	var guide2:MeshInstance3D=physical_depth.get_node("PerspectiveGuide_2")
	assert(guide0!=null and guide1!=null and guide2!=null)
	var width0:float=(guide0.mesh as BoxMesh).size.x
	var width1:float=(guide1.mesh as BoxMesh).size.x
	var width2:float=(guide2.mesh as BoxMesh).size.x
	assert(width0<width1 and width1<width2,
		"Floor depth guides must widen continuously toward the front")
	assert(physical_depth.get_node_or_null("PerspectiveRail_L")!=null)
	assert(physical_depth.get_node_or_null("PerspectiveRail_R")!=null)
	for name in _names(rear):
		assert(not str(name).begins_with("RearBay_"))
	for name in _names(depth):
		assert(not str(name).begins_with("Depth_"))

	scene._populate_furniture(node)
	var local:Node3D=node.get_node("LocalFurniture")
	assert(local.get_node_or_null("PhysicalFurniture")!=null)
	var common_dressing:Node3D=local.get_node_or_null("PhysicalDressing")
	assert(common_dressing!=null)
	assert(common_dressing.get_node_or_null("Dressing_Rug")!=null)
	assert(common_dressing.get_node_or_null("Dressing_CommonSideTable")==null,
		"Authored Common furniture must not be duplicated by greybox side-table geometry")
	var fireplace:Node3D=common_dressing.get_node_or_null("Dressing_Fireplace")
	assert(fireplace!=null and fireplace.position.z<=-1.0)
	for child in common_dressing.get_children():
		if child is Node3D and not str(child.name).contains("Rug"):
			assert((child as Node3D).position.z<0.70,
				"Solid supplemental dressing must stay behind the front connector aisle")
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
	assert(study_local.get_node_or_null("PhysicalDressing")!=null)
	assert(study_local.get_node("PhysicalDressing").get_node_or_null("Dressing_StudyRug")!=null)
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
	assert(backdrop==null,
		"Common R3 sparse black-frame backdrop is replaced by physical rear architecture")
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
	var front_sofa:Sprite3D=art.get_node("Art_foreground_sofa_front_left")
	var front_table:Sprite3D=art.get_node("Art_foreground_table_front_right")
	var front_chair:Sprite3D=art.get_node("Art_foreground_chair_front_right")
	assert(absf(front_sofa.position.z+0.4711)<0.001)
	assert(absf(front_table.position.z+0.4711)<0.001)
	assert(absf(front_chair.position.z+0.4711)<0.001)
	assert(front_sofa.scale.x > sofa.scale.x)
	assert(absf(float(shelf_left.get_meta("physical_x",0.0))+6.10)<0.01 and absf(shelf_left.position.z+1.70)<0.01)
	assert(absf(shelf_left.position.x) < absf(float(shelf_left.get_meta("physical_x",0.0))),
		"Rear visual component X must converge toward room center")
	assert(absf(float(shelf_mid.get_meta("physical_x",0.0))-0.95)<0.01 and absf(shelf_mid.position.z+1.70)<0.01)
	assert(absf(wall_light.position.z+1.70)<0.01)
	assert(absf(float(sofa.get_meta("physical_x",0.0))+5.25)<0.01 and absf(sofa.position.z+0.88)<0.01)
	assert(shelf_left.position.z < sofa.position.z-0.7,
		"Rear bookshelf must sort as a separate object behind the nearer sofa")
	assert(absf(float(side_table.get_meta("physical_x",0.0))+3.55)<0.01 and absf(side_table.position.z+0.10)<0.01)
	assert(absf(chair_left.position.z+0.72)<0.01)
	assert(absf(bench_right.position.z+0.82)<0.01)
	assert(absf(round_table.position.z-0.18)<0.01)
	assert(absf(chair_right.position.z+0.78)<0.01)
	assert(round_table.position.z > sofa.position.z+0.9,
		"Front table must occupy a visibly nearer Z plane than the rear sofa")
	assert(shelf_left.scale.x < sofa.scale.x)
	assert(sofa.scale.x < side_table.scale.x)
	assert(side_table.scale.x < round_table.scale.x,
		"Physical art components must grow continuously toward the front")
	assert(absf(shelf_left.scale.x-scene.world.room_space.perspective_scale(shelf_left.position.z))<0.001)
	assert(absf(sofa.scale.x-scene.world.room_space.perspective_scale(sofa.position.z))<0.001)
	assert(absf(round_table.scale.x-scene.world.room_space.perspective_scale(round_table.position.z))<0.001)
	var sofa_floor:float=sofa.position.y-float(sofa.texture.get_height())*sofa.pixel_size*sofa.scale.y*0.5
	var table_floor:float=side_table.position.y-float(side_table.texture.get_height())*side_table.pixel_size*side_table.scale.y*0.5
	assert(absf(sofa_floor-float(sofa.get_meta("floor_y",999.0)))<0.001)
	assert(absf(table_floor-float(side_table.get_meta("floor_y",999.0)))<0.001)
	assert(absf(sofa_floor-0.025)<0.03 and absf(table_floor-0.025)<0.03,
		"Depth scaling must preserve the physical floor contact point")
	assert(rear.visible,
		"Physical Stage_Backwall must remain visible when sparse backdrop is suppressed")
	var physical_rear:Node3D=rear.get_node("PhysicalRearWall")
	var rear_panel:MeshInstance3D=physical_rear.get_node("StructuralRearPanel")
	assert(rear_panel!=null)
	var rear_material:StandardMaterial3D=rear_panel.material_override as StandardMaterial3D
	assert(rear_material!=null and rear_material.albedo_texture!=null,
		"Common/Library physical rear wall must use the real stone albedo")
	var rear_arch:Node3D=physical_rear.get_node_or_null("RearArchitecture")
	assert(rear_arch!=null)
	assert(rear_arch.get_node_or_null("RearLightwell")!=null)
	assert(rear_arch.get_node_or_null("RearTimberHeader")!=null)
	for child in art.get_children():
		assert(str(child.name).begins_with("Art_") and not str(child.name).begins_with("@"),
			"Art reload must preserve stable layer node names")
	scene.zoom_current=16.0
	scene.yaw=0.0
	scene.update_cutaway_return_visibility()
	var return_l:Node3D=node.get_node_or_null("Layer_Structure/ConnectorRearReturn_L")
	var return_r:Node3D=node.get_node_or_null("Layer_Structure/ConnectorRearReturn_R")
	assert(return_l!=null and return_r!=null)
	assert(return_l.visible and not return_r.visible,
		"Positive close cutaway yaw must remove the near/right side wall")
	scene.yaw=-0.30
	scene.update_cutaway_return_visibility()
	assert(not return_l.visible and return_r.visible,
		"Negative cutaway yaw must remove the near/left side wall")
	scene.yaw=0.0

	# Library R2 uses the same physical component contract: rear chairs and
	# a front table are independent sprites, not one flat image.
	var library:Dictionary=scene.world.make_room(10,3,"library",2,false)
	var library_group:Dictionary=scene.world.merged_group(10,3)
	scene.make_room(library_group)
	var library_node:Node3D=scene.room_root.get_node(str(library["id"]))
	scene._load_room_art(library_node)
	var library_art:Node3D=library_node.get_node("Layer_ApprovedArt")
	assert(library_art.get_node_or_null("Art_backdrop")==null)
	assert(library_node.get_node("Layer_Background/Stage_Backwall").visible)
	assert(library_node.get_node_or_null(
		"Layer_Background/Stage_Backwall/PhysicalRearWall/RearArchitecture/RearLightwell")!=null)
	assert(library_art.get_node_or_null("Art_furniture_back")==null)
	assert(library_art.get_node_or_null("Art_back_decor")==null)
	assert(library_art.get_node_or_null("Art_foreground")==null)
	var lib_shelf_left:Sprite3D=library_art.get_node("Art_back_decor_bookshelf_left")
	var lib_shelf_mid:Sprite3D=library_art.get_node("Art_back_decor_bookshelf_mid")
	var lib_shelf_right:Sprite3D=library_art.get_node("Art_back_decor_bookshelf_right")
	var lib_left:Sprite3D=library_art.get_node("Art_furniture_back_chair_left")
	var lib_table:Sprite3D=library_art.get_node("Art_furniture_back_table")
	var lib_right:Sprite3D=library_art.get_node("Art_furniture_back_chair_right")
	var lib_front_left:Sprite3D=library_art.get_node("Art_foreground_chair_front_left")
	var lib_front_right:Sprite3D=library_art.get_node("Art_foreground_chair_front_right")
	assert(absf(lib_front_left.position.z+0.2436)<0.001)
	assert(absf(lib_front_right.position.z+0.2436)<0.001)
	assert(lib_front_left.scale.x > lib_left.scale.x)
	assert(absf(float(lib_shelf_left.get_meta("physical_x",0.0))+3.45)<0.01 and absf(lib_shelf_left.position.z+1.70)<0.01)
	assert(absf(float(lib_shelf_mid.get_meta("physical_x",0.0))-0.15)<0.01 and absf(lib_shelf_mid.position.z+1.70)<0.01)
	assert(absf(float(lib_shelf_right.get_meta("physical_x",0.0))-3.35)<0.01 and absf(lib_shelf_right.position.z+1.70)<0.01)
	assert(absf(float(lib_left.get_meta("physical_x",0.0))+2.15)<0.01 and absf(lib_left.position.z+0.68)<0.01)
	assert(lib_shelf_left.position.z < lib_left.position.z-0.9)
	assert(absf(float(lib_right.get_meta("physical_x",0.0))-2.15)<0.01 and absf(lib_right.position.z+0.68)<0.01)
	assert(absf(lib_table.position.x)<0.01 and absf(lib_table.position.z-0.18)<0.01)
	assert(lib_table.position.z > lib_left.position.z+0.8)
	assert(lib_shelf_left.scale.x < lib_left.scale.x and lib_left.scale.x < lib_table.scale.x,
		"Library R2 must show rear-to-front perspective scaling")
	assert(absf(lib_table.scale.x-scene.world.room_space.perspective_scale(lib_table.position.z))<0.001)

	var cinema_room:Dictionary=scene.world.get_room(4,0)
	var cinema_node:Node3D=scene.room_root.get_node(str(cinema_room["id"]))
	scene._populate_furniture(cinema_node)
	var cinema_dressing:Node3D=cinema_node.get_node("LocalFurniture/PhysicalDressing")
	assert(cinema_dressing.get_node_or_null("Dressing_CinemaSeats")==null)
	assert(cinema_dressing.get_node_or_null("Dressing_Speaker_L")==null)
	assert(cinema_dressing.get_node_or_null("Dressing_Speaker_R")==null)
	assert(cinema_dressing.get_node_or_null("Dressing_Curtain_L")==null)
	assert(cinema_dressing.get_node_or_null("Dressing_Curtain_R")==null)
	scene._load_room_art(cinema_node)
	var cinema_art:Node3D=cinema_node.get_node("Layer_ApprovedArt")
	assert(cinema_art.get_node_or_null("Art_furniture_back")!=null,
		"Accepted Cinema furniture art must own the visible seating/furniture")

	var artifact_room:Dictionary=scene.world.get_room(1,-1)
	var artifact_node:Node3D=scene.room_root.get_node(str(artifact_room["id"]))
	scene._populate_furniture(artifact_node)
	var artifact_dressing:Node3D=artifact_node.get_node("LocalFurniture/PhysicalDressing")
	assert(artifact_dressing.get_node_or_null("Dressing_ArtifactPedestal")==null,
		"Accepted Artifact furniture art must not be duplicated by a greybox pedestal")

	var workshop_room:Dictionary=scene.world.make_room(14,2,"workshop",1,false)
	var workshop_group:Dictionary=scene.world.merged_group(14,2)
	scene.make_room(workshop_group)
	var workshop_node:Node3D=scene.room_root.get_node(str(workshop_room["id"]))
	scene._populate_furniture(workshop_node)
	var workshop_dressing:Node3D=workshop_node.get_node("LocalFurniture/PhysicalDressing")
	assert(workshop_dressing.get_node_or_null("Dressing_Forge")==null)
	assert(workshop_dressing.get_node_or_null("Dressing_Workbench")==null,
		"Accepted Workshop furniture art must own the visible workstation")

	var actor:Dictionary=scene.world.residents["RES_01"]
	actor["room_id"]=str(common["id"])
	actor["x"]=scene.world.room_center_pos(common).x+5.0
	actor["z"]=scene.world.room_space.BACK_Z
	actor["visual_y"]=scene.world.room_center_pos(common).y
	scene.update_residents()
	var rear_visual_x:float=scene.actor_sprites["RES_01"].position.x
	assert(absf(rear_visual_x-scene.world.room_center_pos(common).x) < 5.0,
		"Rear actor visual X must converge toward the room center")

	print("ITER2_ROOM_VOLUME_PASS R3_single_shell=true authored_fallback=true component_depth=true rear_decor_sort=true depth_scale=true perspective_floor=true")
	quit(0)
