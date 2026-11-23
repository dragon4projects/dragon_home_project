extends SceneTree

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://v014_room_hud.json"
	root.add_child(scene)
	current_scene=scene

	var cinema:Dictionary=scene.world.get_room(4,0)
	assert(not cinema.is_empty())
	var actor:Dictionary=scene.world.residents["RES_01"]
	actor["phase"]="perform"
	actor["intent"]="WATCH_FILM"
	actor["room_id"]=cinema["id"]
	actor["station_room_id"]=cinema["id"]
	actor["activity_media_category"]="films"
	actor["activity_media_id"]="HUD_FILM"
	actor["activity_media_title"]="HUD проверка"
	scene.world.media["films"]=[{
		"id":"HUD_FILM","title":"HUD проверка",
		"file_path":"user://not_needed_for_display.ogv"
	}]

	var group:Dictionary=scene.world.merged_group(4,0)
	var lines:Array=scene.room_activity_lines(group)
	assert(lines.size()==1)
	assert(str(lines[0]).contains(str(actor["name"])))
	assert(str(lines[0]).contains("смотрит «HUD проверка»"))

	scene.selected_room=cinema["id"]
	scene.current_mode="ROOM"
	scene.update_hud()
	assert(scene.hud_status.text.contains("смотрит «HUD проверка»"))
	assert(not scene.hud_status.text.contains("\n\n\n"),
		"Activity summary must stay compact")

	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(
			scene.world.save_path+suffix))
	print("ROOM_ACTIVITY_HUD_V014_PASS concrete_title=visible floating_labels=unused")
	quit(0)
