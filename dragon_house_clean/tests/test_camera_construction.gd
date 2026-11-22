extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.world.save_path = "user://test_camera_build_only.json"
	scene.world.seed_world()
	scene.make_rooms()
	await process_frame
	await process_frame
	assert(scene.world.rooms.size() == 21)
	assert(scene.room_root.get_child_count() == 19)
	var common: Dictionary = scene.world.get_room(-1,0)
	scene.selected_room = common["id"]
	scene.set_mode("ROOM")
	assert(scene.current_mode == "ROOM")
	assert(is_equal_approx(scene.desired_focus.x, -1.0*scene.W),
		"R3 selection targets visual group CENTER, not clicked cell edge")
	assert(scene.zoom > 15.0, "Three-module room has wider close-up view")
	scene.set_mode("HOUSE")
	assert(scene.zoom > 20.0)
	scene.toggle_build()
	assert(scene.current_mode == "BUILD")
	scene.build_type = "rest"
	for x in [0,-1]:
		scene.build_cell = Vector2i(x,1)
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = true
		scene._unhandled_input(e)
	assert(scene.world.merged_group(0,1)["width"] == 3)
	assert(scene.world.rooms.size() == 23)
	await process_frame
	await process_frame
	assert(scene.room_root.get_child_count() == 19,
		"Render must use one shell for merged R3, not 3 individual boxes")
	scene.build_cell = Vector2i(-2,1)
	var invalid := InputEventMouseButton.new()
	invalid.button_index = MOUSE_BUTTON_LEFT
	invalid.pressed = true
	scene._unhandled_input(invalid)
	assert(scene.world.rooms.size() == 23, "R4 attempt must not change geometry")
	scene.toggle_build()
	var actor: Dictionary = scene.world.residents["RES_01"]
	actor["room_id"] = scene.world.get_room(4,1)["id"]
	actor["phase"] = "perform"
	actor["until"] = scene.life.clock + 10000.0
	actor["x"] = 4.0*scene.W
	actor["level"] = 1
	actor["visual_y"] = scene.H
	actor["z"] = 1.0
	scene.follow_actor("RES_01")
	var before: float = scene.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	scene._input(wheel)
	assert(scene.follow_id == "RES_01" and scene.zoom < before,
		"Manual zoom must retain actor follow")
	for i in range(20):
		scene.apply_camera(0.1)
	assert(scene.desired_focus.y > 2.0, "Follow should track across a level")
	assert(scene.desired_focus.x > 2.0, "Follow should target moving actor with deadzone")
	for i in range(10):
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		scene._input(key)
	assert(scene.yaw <= 0.34001, "Shallow yaw clamp")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	scene._input(right)
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(14.0,-5.0)
	scene._input(mouse)
	assert(scene.follow_id == "" and scene.current_mode == "FREE",
		"User panning exits automatic follow")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+".bak"))
	print("CAMERA_CONSTRUCTION_TEST_PASS groups=19 R3=3 zoom=independent yaw=clamped")
	quit(0)

