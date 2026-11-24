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
	assert(scene.world.rooms.size() == 19)
	assert(scene.room_root.get_child_count() == 19)
	var common: Dictionary = scene.world.get_room(-1,0)
	assert(scene.world.room_size_modules(common)==3)
	scene.selected_room = common["id"]
	scene.set_mode("ROOM")
	assert(scene.current_mode == "ROOM")
	assert(is_equal_approx(scene.desired_focus.x, -1.0*scene.W),
		"R3 selection targets physical room center, not clicked module")
	assert(scene.zoom > 15.0, "R3 has a wider close-up view")
	scene.set_mode("HOUSE")
	assert(scene.zoom > 20.0)
	scene.zoom_current=16.0
	var close_yaw:float=scene.effective_camera_yaw()
	var close_height:float=scene.effective_camera_height_ratio()
	assert(close_yaw>0.14 and close_height>0.16,
		"Close cutaway must expose X/Z depth, not stay nearly frontal")
	scene.zoom_current=50.0
	assert(scene.effective_camera_yaw()<close_yaw)
	assert(scene.effective_camera_height_ratio()<close_height)
	scene.zoom_current=scene.zoom
	var bounds:Rect2=scene.camera_world_bounds()
	var viewport:Vector2=scene.get_viewport().get_visible_rect().size
	var aspect:float=maxf(1.0,viewport.x/maxf(1.0,viewport.y))
	var angle:float=deg_to_rad(scene.camera.fov*0.5)
	var legacy_horizontal:float=(bounds.size.x+3.0)/maxf(0.1,2.0*aspect*tan(angle))*1.12
	assert(scene.zoom < legacy_horizontal,
		"HOUSE framing must be tighter than the old diagram-like overview")
	scene.toggle_build()
	assert(scene.current_mode == "BUILD")
	scene.build_type = "rest"
	scene.build_size = 2
	scene.build_cell = Vector2i(6,1)
	var build_r2 := InputEventMouseButton.new()
	build_r2.button_index = MOUSE_BUTTON_LEFT
	build_r2.pressed = true
	scene._unhandled_input(build_r2)
	var new_r2:Dictionary=scene.world.get_room(6,1)
	assert(not new_r2.is_empty())
	assert(new_r2["id"]==scene.world.get_room(7,1)["id"])
	assert(scene.world.room_size_modules(new_r2)==2)
	assert(scene.world.rooms.size()==20)
	await process_frame
	await process_frame
	assert(scene.room_root.get_child_count()==20)
	scene.build_size = 1
	scene.build_cell = Vector2i(8,1)
	var build_r1 := InputEventMouseButton.new()
	build_r1.button_index = MOUSE_BUTTON_LEFT
	build_r1.pressed = true
	scene._unhandled_input(build_r1)
	assert(scene.world.rooms.size()==21)
	assert(scene.world.get_room(8,1)["id"]!=new_r2["id"])
	assert(scene.world.room_size_modules(new_r2)==2,
		"Adjacent construction must not resize an existing R2")
	scene.build_cell = Vector2i(7,1)
	var invalid := InputEventMouseButton.new()
	invalid.button_index = MOUSE_BUTTON_LEFT
	invalid.pressed = true
	scene._unhandled_input(invalid)
	assert(scene.world.rooms.size()==21,"Overlap must not alter topology")
	scene.toggle_build()
	var actor: Dictionary = scene.world.residents["RES_01"]
	var upper_corridor:Dictionary=scene.world.get_room(4,1)
	actor["room_id"] = upper_corridor["id"]
	actor["phase"] = "perform"
	actor["until"] = scene.life.clock + 10000.0
	actor["x"] = scene.world.room_center_pos(upper_corridor).x
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
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+suffix))
	print("CAMERA_CONSTRUCTION_TEST_PASS physical=19 R2_add=true no_auto_merge=true")
	quit(0)
