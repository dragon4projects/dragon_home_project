extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func _save_view(path:String) -> Vector2i:
	var image:Image=root.get_texture().get_image()
	assert(image!=null and image.get_width()>0 and image.get_height()>0)
	assert(image.save_png(path)==OK)
	return Vector2i(image.get_width(),image.get_height())

func _settle(frames:int)->void:
	for i in range(frames):
		await process_frame

func capture() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://private_review"))
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://v014_capture_review.json"
	root.add_child(scene)
	current_scene=scene
	scene.world.seed_world()
	scene.make_rooms()

	scene.set_mode("HOUSE")
	await _settle(45)
	var house_size:=_save_view(ProjectSettings.globalize_path(
		"res://private_review/v014_house.png"))

	var common:Dictionary=scene.world.get_room(-2,0)
	scene.selected_room=common["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	await _settle(70)
	var common_size:=_save_view(ProjectSettings.globalize_path(
		"res://private_review/v014_common_r3.png"))

	# QA-only synthetic R2: prove that accepted Library R2 art can be
	# materialized with the exact R2 furniture contract without changing the
	# seeded production house.
	var left:Dictionary=scene.world.make_room(-1,2,"library")
	scene.world.make_room(0,2,"library")
	scene.make_rooms()
	var group:Dictionary=scene.world.merged_group(-1,2)
	assert(int(group["width"])==2)
	scene.selected_room=left["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	await _settle(70)
	var library_size:=_save_view(ProjectSettings.globalize_path(
		"res://private_review/v014_library_r2.png"))

	# QA-only concrete media activity: prove that ROOM HUD shows the exact
	# selected title while floating actor labels remain disabled.
	var cinema:Dictionary=scene.world.get_room(4,0)
	var actor:Dictionary=scene.world.residents["RES_01"]
	scene.world.media["films"]=[{
		"id":"V014_QA_FILM","title":"QA: конкретный фильм",
		"file_path":"user://v014_capture_fixture.ogv"
	}]
	actor["phase"]="perform"
	actor["intent"]="WATCH_FILM"
	actor["room_id"]=cinema["id"]
	actor["station_room_id"]=cinema["id"]
	actor["activity_media_category"]="films"
	actor["activity_media_id"]="V014_QA_FILM"
	actor["activity_media_title"]="QA: конкретный фильм"
	scene.selected_room=cinema["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	scene.update_hud()
	await _settle(40)
	assert(scene.hud_status.text.contains("смотрит «QA: конкретный фильм»"))
	var cinema_size:=_save_view(ProjectSettings.globalize_path(
		"res://private_review/v014_cinema_activity.png"))

	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			scene.world.save_path+suffix))
	print("V014_RENDER_REVIEW_PASS house=%dx%d common_R3=%dx%d library_R2=%dx%d cinema_activity=%dx%d" % [
		house_size.x,house_size.y,common_size.x,common_size.y,
		library_size.x,library_size.y,cinema_size.x,cinema_size.y])
	quit(0)
