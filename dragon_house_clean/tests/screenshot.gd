extends SceneTree
func _initialize():
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	for i in range(7):
		await process_frame
	var image = root.get_texture().get_image()
	image.save_png("/home/user/dragon-house-fresh/visual-proof.png")
	print("CAPTURE:", image.get_width(), "x", image.get_height())
	quit()
