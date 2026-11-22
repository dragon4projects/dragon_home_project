extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	scene._import_media("res://data/media_catalog_demo.json")
	scene.media_panel.open_panel()
	scene.media_panel.switch_category("films")
	scene.media_panel.list.select(0)
	scene.media_panel._on_selected(0)
	scene.media_panel.play_selected()
	for i in range(50):
		await process_frame
	var image: Image = root.get_texture().get_image()
	image.save_png("/home/user/dragon-house-fresh/media-proof.png")
	print("MEDIA_PROOF_VIDEO_PLAYING:",scene.media_panel.video.is_playing()," size:",image.get_width(),"x",image.get_height())
	scene.media_panel.stop_playback()
	quit(0)

