extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func _save_view(path:String) -> void:
	var image:Image=root.get_texture().get_image()
	assert(image!=null and image.get_width()>0 and image.get_height()>0)
	assert(image.save_png(path)==OK)

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://private_review"))
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://v011_capture_review.json"
	root.add_child(scene)
	current_scene=scene

	scene.set_mode("HOUSE")
	for i in range(45):
		await process_frame
	_save_view(ProjectSettings.globalize_path(
		"res://private_review/v011_house.png"))

	var common:Dictionary=scene.world.get_room(-2,0)
	assert(not common.is_empty())
	scene.selected_room=common["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	for i in range(70):
		await process_frame
	_save_view(ProjectSettings.globalize_path(
		"res://private_review/v011_common_r3.png"))

	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			scene.world.save_path+suffix))
	print("V011_RENDER_REVIEW_PASS house=1280x720 common_R3=1280x720")
	quit(0)
