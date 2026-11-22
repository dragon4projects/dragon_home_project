extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene.selected_room = scene.world.get_room(-1, 0)["id"]
	scene.set_mode("ROOM")
	for i in range(110):
		await process_frame
	var img: Image = root.get_texture().get_image()
	img.save_png("/home/user/dragon-house-fresh/room-proof.png")
	print("ROOM_PROOF:",img.get_width(),"x",img.get_height())
	quit(0)
