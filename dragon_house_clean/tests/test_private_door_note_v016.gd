extends SceneTree

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://door_note_v016_test.json"
	root.add_child(scene)
	current_scene=scene
	scene.world.seed_world()

	var private_room:Dictionary=scene.world.get_room(3,1)
	assert(not private_room.is_empty())
	assert(str(private_room["privacy"])=="door_only")
	private_room["owner_id"]="RES_08"
	scene.make_rooms()
	scene.selected_room=str(private_room["id"])
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	await process_frame
	await process_frame

	var node:Node3D=null
	for key in scene.visual_room_groups:
		if str(scene.visual_room_groups[key]["primary_id"])==str(private_room["id"]):
			node=scene.room_root.get_node(str(key))
	assert(node!=null)
	assert(node.get_node("RoomRoofLabel").text=="Архитектор Сестринства")
	assert(node.get_node_or_null("DoorPublicNoteAnchor")!=null)
	assert(scene.door_note_anchors.has(str(private_room["id"])))

	var before_children:int=node.get_child_count()
	assert(scene.open_door_note(str(private_room["id"])))
	assert(scene.door_note_panel.visible)
	assert(scene.door_note_title.text=="Архитектор Сестринства")
	assert(scene.door_note_text.text.contains("PRIVATE ≠ SECRET"))
	assert(scene.door_note_text.text.contains("TECHNICAL ACCESS ≠ CONSENT"))
	assert(node.get_child_count()==before_children,
		"Opening public note must not materialize private interior")
	assert(scene.life.stations.layout_for_world(scene.world,private_room).is_empty(),
		"Door note must not create private interaction stations")
	scene.close_door_note()
	assert(not scene.door_note_panel.visible)

	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+suffix))
	print("PRIVATE_DOOR_NOTE_V016_PASS sign=owner_title note=fullscreen privacy=preserved")
	quit(0)
