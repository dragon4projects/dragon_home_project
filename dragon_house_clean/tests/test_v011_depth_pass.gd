extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func _box_size(node: Node) -> Vector3:
	assert(node is MeshInstance3D)
	var mesh = (node as MeshInstance3D).mesh
	assert(mesh is BoxMesh)
	return (mesh as BoxMesh).size

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene

	var common: Dictionary = scene.world.get_room(-1,0)
	assert(not common.is_empty())
	var group: Dictionary = scene.world.merged_group(-1,0)
	var room_node: Node3D = scene.room_root.get_node(group["primary_id"])
	var structure: Node3D = room_node.get_node("Layer_Structure")
	var foreground: Node3D = room_node.get_node("Layer_Foreground")

	var floor_slab: MeshInstance3D = structure.get_node("CutawayFloorSlab")
	var ceiling_slab: MeshInstance3D = structure.get_node("CutawayCeilingSlab")
	var front_lip: MeshInstance3D = foreground.get_node("CutawayFrontLip")
	var floor_size := _box_size(floor_slab)
	var ceiling_size := _box_size(ceiling_slab)
	var lip_size := _box_size(front_lip)

	assert(floor_size.y <= 0.1001, "Floor slab must stay visually thin")
	assert(ceiling_size.y <= 0.0901, "Ceiling slab must stay visually thin")
	assert(lip_size.y <= 0.0701 and lip_size.z <= 0.0901,
		"Front cutaway lip must not become a thick foreground shelf")
	assert(floor_slab.position.z + floor_size.z * 0.5 <= 1.341,
		"Floor geometry must stop before the public aisle/front trim")
	assert(ceiling_slab.position.z + ceiling_size.z * 0.5 <= 0.741,
		"Ceiling must not project deep into the close-room foreground")

	scene.selected_room = common["id"]
	scene.set_mode("ROOM")
	assert(absf(scene.desired_focus.y - 1.45) < 0.001,
		"ROOM camera should target the vertical centre of the cutaway")
	scene.zoom_current = 13.3
	scene.zoom = 13.3
	scene.yaw = 0.0
	assert(absf(scene.effective_camera_yaw()) < 0.08,
		"Automatic close yaw must remain subtle; manual Q/E supplies stronger parallax")
	scene.smooth_focus = scene.desired_focus
	scene.apply_camera(1.0)
	assert(scene.camera.global_position.y - scene.smooth_focus.y < 1.0,
		"Close camera must stay nearly frontal instead of looking down at empty floor")

	print("DRAGON_V011_DEPTH_PASS floor=thin ceiling=thin lip=thin close_camera=frontal")
	quit(0)
