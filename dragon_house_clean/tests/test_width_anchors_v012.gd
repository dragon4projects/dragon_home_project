extends SceneTree
const World=preload("res://scripts/world_model.gd")
const Stations=preload("res://scripts/room_stations.gd")

func _initialize()->void:
	call_deferred("run")

func _ids(items:Array)->Array:
	var out:Array=[]
	for item in items:
		out.append(str(item.get("id","")))
	return out

func run()->void:
	var world=World.new()
	world.save_path="user://v012_width_anchor_test.json"
	world.seed_world()
	var stations=Stations.new()

	# Seeded Library is still R1 and must keep its procedural table contract.
	var library_r1:Dictionary=world.get_room(2,0)
	assert(int(world.merged_group(2,0)["width"])==1)
	assert(_ids(stations.layout_for_world(world,library_r1)).slice(0,2)==[
		"table_left","table_right"])

	# Synthetic R2 uses the owner-accepted measured R2 chair contract.
	var left:Dictionary=world.make_room(-1,2,"library")
	var right:Dictionary=world.make_room(0,2,"library")
	assert(int(world.merged_group(-1,2)["width"])==2)
	var left_layout:Array=stations.layout_for_world(world,left)
	var right_layout:Array=stations.layout_for_world(world,right)
	assert(str(left_layout[0]["id"])=="library_chair_left_seat_a")
	assert(str(left_layout[0]["furniture_id"])=="library_chair_left")
	assert(is_equal_approx(float(left_layout[0]["offset"].x),0.25))
	assert(is_equal_approx(float(left_layout[0]["offset"].y),-0.5835))
	assert(str(right_layout[0]["id"])=="library_chair_right_seat_a")
	assert(str(right_layout[0]["furniture_id"])=="library_chair_right")
	assert(is_equal_approx(float(right_layout[0]["offset"].x),-0.25))
	assert(is_equal_approx(float(right_layout[0]["offset"].y),-0.558))

	# The accepted Common anchors are likewise tied to a real R3, not world X.
	var common_left:Dictionary=world.get_room(-2,0)
	assert(str(stations.layout_for_world(world,common_left)[0]["id"])==
		"common_sofa_left_seat_a")
	# An isolated Common at the same x on another level must use the generic
	# procedural contract instead of leaking the accepted R3 sofa.
	var isolated:Dictionary=world.make_room(-2,3,"common")
	assert(int(world.merged_group(-2,3)["width"])==1)
	assert(str(stations.layout_for_world(world,isolated)[0]["id"])=="sofa_left")

	# Runtime materialization must create invisible furniture anchors from the
	# same width-specific contract when accepted Library R2 art replaces meshes.
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://v012_width_anchor_scene.json"
	root.add_child(scene)
	current_scene=scene
	scene.world.seed_world()
	var sleft:Dictionary=scene.world.make_room(-1,2,"library")
	scene.world.make_room(0,2,"library")
	scene.make_rooms()
	scene.zoom_current=10.0
	scene.smooth_focus=Vector3(-0.5*scene.W,2.0*scene.H,0.0)
	scene.update_render_lod()
	var group:Dictionary=scene.world.merged_group(-1,2)
	var node:Node3D=scene.room_root.get_node(group["primary_id"])
	assert(bool(scene.visual_room_groups[node.name]["replaces_furniture"]))
	var furniture:Node3D=node.get_node("LocalFurniture")
	var left_module:Node3D=furniture.get_node(str(sleft["id"])+"_furniture")
	var right_module:Node3D=furniture.get_node(str(group["cells"][1]["id"])+"_furniture")
	assert(left_module.get_node_or_null("library_chair_left")!=null)
	assert(left_module.get_node_or_null("TABLE_LIBRARY")==null)
	assert(right_module.get_node_or_null("library_chair_right")!=null)

	for p in [world.save_path,scene.world.save_path]:
		for suffix in ["",".bak",".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p+suffix))
	print("WIDTH_ANCHORS_V012_PASS library_R1=table library_R2=chairs common_R3=scoped")
	quit(0)
