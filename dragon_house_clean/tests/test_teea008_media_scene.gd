extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.teea008_review.enabled)
	var room:Dictionary=scene.world.get_room(4,0)
	var img:=Image.create(320,180,false,Image.FORMAT_RGB8)
	img.fill(Color("#68312a"))
	assert(img.save_png("user://qa_screen_preview.png")==OK)
	# Real preview bytes; no claim of video decoding in this test.
	var f:=FileAccess.open("user://qa_screen.ogv",FileAccess.WRITE)
	f.store_8(0);f.close()
	scene.world.media["films"]=[{"id":"QA_SCREEN","title":"QA screen","file_path":"user://qa_screen.ogv","preview":"user://qa_screen_preview.png"}]
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var screen:Node3D=null
	for anchor in get_nodes_in_group("teea008_media_surface"):
		if str(anchor.get_meta("room_id",""))==str(room["id"]) and str(anchor.get_meta("surface_id",""))=="cinema.r1.film.screen":screen=anchor
	assert(screen!=null)
	assert(scene.open_content_hotspot({"category":"teea008_surface","item_id":"cinema.r1.film.screen","room_id":room["id"]}))
	assert(scene.media_panel.surface_room_id==str(room["id"]))
	scene.media_panel.list.select(0)
	scene.media_panel._assign_selected_surface()
	assert(screen.get_node_or_null("BoundPreview")!=null)
	assert(scene.teea008_media_bindings.resolve(room["id"],"cinema.r1.film.screen")["id"]=="QA_SCREEN")
	assert(scene.open_content_hotspot({"category":"teea008_surface","item_id":"cinema.r1.film.screen","room_id":room["id"]}))
	assert(scene.content_viewer.visible and scene.content_viewer.item["id"]=="QA_SCREEN")
	scene._assign_teea008_media(room["id"],"cinema.r1.film.screen","films","")
	assert(screen.get_node_or_null("BoundPreview")==null)
	print("TEEA008_MEDIA_SCENE_PASS physical_preview=true panel_assignment=true exact_viewer=true clear=true")
	quit(0)
