extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func _cleanup(path: String) -> void:
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func run() -> void:
	var path := "user://level_mode_v019.json"
	_cleanup(path)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.world.save_path = path
	scene.world.seed_world()
	scene.semantic_view.install(scene.world,"HOUSE")
	scene.make_rooms()
	scene.make_residents()
	await process_frame
	await process_frame

	scene.set_mode("LEVEL")
	assert(scene.current_mode=="LEVEL")
	assert(scene.semantic_view.level==0)
	assert(scene.zoom>=12.0)
	var upper_private: Dictionary = scene.world.get_room(3,1)
	var upper_node: Node3D = scene.room_root.get_node(str(upper_private["id"]))
	scene.update_render_lod()
	assert(not upper_node.visible,"remote non-connector level must be hidden")

	var upper_lift: Dictionary = scene.world.get_room(5,1)
	var upper_lift_node: Node3D = scene.room_root.get_node(str(upper_lift["id"]))
	assert(upper_lift_node.visible,"adjacent lift remains connector context")

	scene.select_level(1)
	assert(scene.current_mode=="LEVEL" and scene.semantic_view.level==1)
	assert(upper_node.visible)
	assert(upper_node.get_node_or_null("LocalFurniture")==null,
		"private room remains facade-only in LEVEL")

	var common: Dictionary = scene.world.get_room(-1,0)
	scene.selected_room = str(common["id"])
	scene.set_mode("ROOM")
	assert(scene.current_mode=="ROOM" and scene.semantic_view.level==0)
	assert(scene.semantic_view.active_room==str(common["id"]))

	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	scene._input(esc)
	assert(scene.current_mode=="LEVEL" and scene.semantic_view.level==0)
	scene._input(esc)
	assert(scene.current_mode=="HOUSE")

	var actor: Dictionary = scene.world.residents["RES_01"]
	actor["room_id"] = str(common["id"])
	actor["level"] = 0
	actor["x"] = float(common["x"])*scene.W
	actor["visual_y"] = 0.0
	actor["z"] = 0.8
	scene.follow_actor("RES_01")
	assert(scene.current_mode=="FOLLOW" and scene.follow_id=="RES_01")
	assert(scene.semantic_view.level==0)

	var upper_corridor: Dictionary = scene.world.get_room(4,1)
	actor["room_id"] = str(upper_corridor["id"])
	actor["level"] = 1
	actor["x"] = float(upper_corridor["x"])*scene.W
	actor["visual_y"] = scene.H
	scene.apply_camera(0.1)
	assert(scene.follow_id=="RES_01","follow target must survive level crossing")
	assert(scene.semantic_view.level==1,"FOLLOW must switch semantic level with actor")
	assert(scene.semantic_view.active_room==str(upper_corridor["id"]))

	var calls_before: int = int(scene.life.planner_calls)
	scene.select_level(0)
	scene.select_level(1)
	assert(scene.life.planner_calls==calls_before,
		"camera/LEVEL changes must never wake high-level planning")

	_cleanup(path)
	print("LEVEL_MODE_V019_PASS hierarchy=yes remote_level_hidden=yes lift_context=yes private_facade=yes follow_cross_level=yes camera_no_planner_wake=yes")
	quit(0)
