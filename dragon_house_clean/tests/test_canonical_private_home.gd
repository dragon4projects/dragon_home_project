extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var life=scene.life
	var checked:=0
	for profile in world.read_resident_profiles():
		var id:String=str(profile["id"])
		var actor:Dictionary=world.residents[id]
		var home:Dictionary=world.room_by_id(str(actor["home_room_id"]))
		assert(not world.public_cutaway_allowed(home))
		assert(life.stations.capacity(home)==1)
		var claim:Dictionary=life.stations.single(world,actor,home,"SLEEP")
		assert(not claim.is_empty() and claim["anchor_id"]=="PRIVATE_HOME_REST")
		assert(life.stations.single(world,actor,home,"TALK_PAIR").is_empty())
		var stranger:Dictionary={"id":"MANJKA"}
		assert(life.stations.single(world,stranger,home,"SLEEP").is_empty())
		var route:Array=world.find_route(str(actor["room_id"]),str(home["id"]),id)
		assert(not route.is_empty())
		assert(not life.locomotion.build_waypoints(world,actor,route,"SLEEP",claim["offset"]).is_empty())
		var group:Node3D=scene.room_root.get_node(str(home["id"]))
		assert(group.get_node_or_null("LocalFurniture")==null)
		assert(group.get_node_or_null("PrivateFacadeWall")!=null)
		assert(group.get_node_or_null("FacadeDoor")!=null)
		assert(group.get_node_or_null("DoorNamePlaque")!=null)
		assert(group.get_node_or_null("DoorWallName")!=null)
		assert(group.get_node_or_null("DoorNotePaper")!=null)
		var note:Node3D=group.get_node("DoorPublicNoteAnchor")
		assert(note.position.x < -1.04 and note.position.z < 1.35)
		assert(scene.door_note_anchors[str(home["id"])]==note)
		assert(scene.open_door_note(str(home["id"])))
		assert(scene.door_note_text.text==scene.door_registry.note_text(id))
		if not scene.door_registry.has_public_note(id):
			assert(scene.door_note_text.text=="")
		scene.close_door_note()
		checked+=1
	assert(checked==24)
	assert(int(world.runtime_state.get("canonical_shell_draws_saved",0))>0)
	print("CANONICAL_PRIVATE_HOME_PASS owners=",checked," invisible=true all_facades_and_sheets=true static_draws_saved=",world.runtime_state["canonical_shell_draws_saved"])
	quit(0)
