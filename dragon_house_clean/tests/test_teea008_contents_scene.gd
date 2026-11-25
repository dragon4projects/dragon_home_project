extends SceneTree
func _initialize()->void:
	call_deferred("run")
func show_room(scene,room:Dictionary)->void:
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	OS.set_environment("DRAGON_TEEA008_LIVE","1")
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.teea008_live)
	var library:Dictionary=scene.world.get_room(2,0)
	var artifact:Dictionary=scene.world.get_room(1,-1)
	var cover:=Image.create(128,144,false,Image.FORMAT_RGB8)
	cover.fill(Color("#91572c"))
	assert(cover.save_png("user://qa_book_cover.png")==OK)
	scene.world.media["books"]=[{"id":"QA_SLOT_BOOK","title":"QA shelf volume","physical":true,"location_room_id":library["id"],"home_room_id":library["id"],"holder_id":"","preview":"user://qa_book_cover.png"},{"id":"QA_CATALOG_ONLY","title":"QA metadata only","physical":false}]
	scene.life.media_runtime.setup(scene.world)
	assert(scene.life.media_runtime.book_slot("QA_SLOT_BOOK").get("id","")!="")
	assert(scene.life.media_runtime.book_slot("QA_CATALOG_ONLY").is_empty())
	show_room(scene,library)
	scene._update_physical_books()
	assert(scene.book_nodes.has("QA_SLOT_BOOK") and not scene.book_nodes.has("QA_CATALOG_ONLY"))
	var node:Node3D=scene.book_nodes["QA_SLOT_BOOK"]
	assert(node.is_visible_in_tree())
	assert(scene.open_content_hotspot({"category":"books","item_id":"QA_SLOT_BOOK","physical_book":true}))
	assert(scene.content_viewer.item["id"]=="QA_SLOT_BOOK")
	scene.content_viewer.close_viewer()
	assert(scene.world.register_physical_object("QA_SHELF_ART","QA object","RES_01",artifact["id"],true,true,false,false,true,{"viewer_category":"artifacts","home_anchor":[0,0.7],"preview_path":"user://qa_book_cover.png","display_world_height":0.12}))
	scene.make_physical_objects()
	show_room(scene,artifact)
	assert(scene.open_content_hotspot({"category":"teea008_surface","item_id":"artifact.r1.label.01","room_id":artifact["id"]}))
	assert(scene.media_panel.category=="artifacts")
	var index:int=scene.media_panel.item_ids.find("QA_SHELF_ART")
	assert(index>=0)
	scene.media_panel.list.select(index)
	scene.media_panel._place_selected_artifact()
	var obj:Dictionary=scene.world.physical_object("QA_SHELF_ART")
	assert(str(obj.get("home_support_id",""))!="")
	assert(obj["current_support_id"]==obj["home_support_id"])
	assert(scene.object_nodes["QA_SHELF_ART"].visible)
	assert(scene.teea008_media_bindings.resolve(artifact["id"],"artifact.r1.label.01")["id"]=="QA_SHELF_ART")
	scene.media_panel.close_panel()
	scene.content_viewer.close_viewer()
	if not DisplayServer.get_name()=="headless":
		for i in range(8):await process_frame
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://private_review"))
		assert(root.get_texture().get_image().save_png("res://private_review/teea008_artifact_support.png")==OK)
		show_room(scene,library)
		scene._update_physical_books()
		for i in range(8):await process_frame
		assert(root.get_texture().get_image().save_png("res://private_review/teea008_book_support.png")==OK)
	print("TEEA008_CONTENTS_SCENE_PASS exact_book_visual=true metadata_not_rendered=true artifact_ui=true support_visible=true")
	quit(0)
