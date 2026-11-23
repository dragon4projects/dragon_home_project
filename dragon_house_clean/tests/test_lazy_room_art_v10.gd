extends SceneTree
## Verify safe, memory-bounded transition from temporary sofa mesh to
## accepted photorealistic furniture art. This test image is QA-only synthetic.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var temp: String="res://assets/rooms/common/R3/__QA_PRIVATE_V10.png"
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://assets/rooms/common/R3"))
	var img:=Image.create(48,32,false,Image.FORMAT_RGBA8)
	img.fill(Color(0.5,0.2,0.18,0.45))
	assert(img.save_png(temp)==OK)

	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_lazy_art_v10.json"
	root.add_child(scene)
	current_scene=scene
	var merged: Dictionary=scene.world.merged_group(-2,0)
	var room_node: Node3D=scene.room_root.get_node(merged["primary_id"])
	var art_node:Node3D=room_node.get_node("Layer_ApprovedArt")
	var furniture:Node3D=room_node.get_node("LocalFurniture")
	assert(art_node.get_child_count()==0)
	assert(scene.art_layer_count==0)

	scene.interior_skin.config={
		"schema":1,
		"room_types":{"common":{"R3":{"layers":[{
			"role":"furniture_back",
			"path":"assets/rooms/common/R3/__QA_PRIVATE_V10.png",
			"approved":true
		}]}}}
	}
	scene.visual_room_groups[room_node.name]["has_art"]=true
	scene.visual_room_groups[room_node.name]["replaces_furniture"]=true
	scene.zoom_current=10.0
	scene.smooth_focus=Vector3(-scene.W,1.15,0.0)
	scene.update_render_lod()
	assert(scene.art_layer_count==1)
	assert(art_node.get_child_count()==1)
	assert(scene.art_loaded_groups.has(room_node.name))
	var module:Node3D=furniture.get_node_or_null(str(scene.world.get_room(-2,0)["id"])+"_furniture")
	assert(module!=null)
	var anchor:Node3D=module.get_node_or_null("common_sofa_left")
	assert(anchor!=null,"Physical sofa interaction anchor must remain")
	assert(anchor.get_child_count()==0,"Do not draw a second mesh sofa over approved art")
	assert(scene.life.stations.furniture.for_room(scene.world.get_room(-2,0)).size()==2)
	# A room with approved art is not allowed to show unreviewed 3D proxy
	# cues and a full-resolution image at the same time.
	assert(not room_node.get_node("Layer_OverviewCues").visible)
	var first_count:int=scene.detail_materialization_count
	scene.update_render_lod()
	assert(scene.art_layer_count==1)
	assert(art_node.get_child_count()==1)
	assert(scene.detail_materialization_count==first_count)
	scene.zoom_current=91.0
	scene.update_render_lod()
	assert(scene.art_layer_count==0,"Offscreen room art should be released")
	assert(not scene.art_loaded_groups.has(room_node.name))
	await process_frame
	await process_frame
	assert(art_node.get_child_count()==0)
	assert(room_node.get_node("Layer_OverviewCues").visible)
	# Returning loads once. Lazy props do not create duplicated seat meshes.
	scene.zoom_current=10.0
	scene.update_render_lod()
	assert(scene.art_layer_count==1)
	assert(art_node.get_child_count()==1)
	var private_room:Dictionary=scene.world.get_room(3,1)
	var private_node:Node3D=scene.room_root.get_node(private_room["id"])
	assert(private_node.get_node_or_null("LocalFurniture")==null)
	assert(private_node.get_node("Layer_ApprovedArt").get_child_count()==0)
	scene.zoom_current=91
	scene.update_render_lod()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+ext))
	print("LAZY_ART_V10_PASS approved=on_demand sofa_mesh=not_duplicated distance=evicted private=closed")
	quit(0)

