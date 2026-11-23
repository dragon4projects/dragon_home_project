extends SceneTree
const World = preload("res://scripts/world_model.gd")

func _initialize() -> void:
	call_deferred("run")

func _cleanup(path: String) -> void:
	for suffix in [
		"",".bak",".tmp",
		".world_events_v1.json",
		".world_events_v1.json.bak",
		".world_events_v1.json.tmp",
		".world_events_v1.json.corrupt"
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func run() -> void:
	var path := "user://object_event_replay_v020.json"
	_cleanup(path)

	# No JSON snapshot is saved after these object events. The event stream must
	# be sufficient to reconstruct the object projection on restart.
	var world := World.new()
	world.save_path = path
	world.seed_world()
	var home: Dictionary = world.get_room(1,-1)
	var stash: Dictionary = world.get_room(-2,0)
	assert(world.register_physical_object(
		"CRASH_GAP_OBJECT","Crash gap object","RES_01",home["id"],
		true,true,true,true,false))
	var manjka: Dictionary = world.residents["MANJKA"]
	manjka["room_id"] = home["id"]
	manjka["x"] = float(home["x"])*World.MODULE_W
	manjka["level"] = int(home["level"])
	assert(world.pickup_physical_object("CRASH_GAP_OBJECT","MANJKA"))
	manjka["room_id"] = stash["id"]
	assert(world.place_physical_object(
		"CRASH_GAP_OBJECT","MANJKA",stash["id"],"STASHED"))
	var committed_revision: int = world.object_event_revision()
	assert(committed_revision==3)
	assert(not FileAccess.file_exists(path),
		"QA requires event commit without compatibility snapshot")

	var restarted := World.new()
	restarted.save_path = path
	restarted.load_or_seed()
	var object: Dictionary = restarted.physical_object("CRASH_GAP_OBJECT")
	assert(not object.is_empty())
	assert(str(object["state"])=="STASHED")
	assert(str(object["current_room_id"])==str(stash["id"]))
	assert(str(object["current_holder_id"])=="")
	assert(str(object["canonical_owner_id"])=="RES_01")
	assert(str(object["last_explicit_location"])==str(home["id"]),
		"ambient theft/stash must not overwrite explicit location")
	assert(str(object["movement_reason"])=="STASHED")
	assert(str(object["movement_authority"])=="AMBIENT")
	assert(str(object["updated_event_id"])!="")
	assert(restarted.object_event_revision()==committed_revision)
	assert(str(restarted.runtime_state.get("object_event_status",""))=="REPLAYED")
	assert((object.get("history",[]) as Array).size()==3)

	# load_or_seed writes a compatibility checkpoint after replay. A second
	# restart must produce exactly the same canonical object projection.
	var stable_snapshot: String = JSON.stringify(restarted.objects)
	var restarted_again := World.new()
	restarted_again.save_path = path
	restarted_again.load_or_seed()
	assert(JSON.stringify(restarted_again.objects)==stable_snapshot)
	assert(restarted_again.object_event_revision()==committed_revision)

	_cleanup(path)
	print("OBJECT_EVENT_REPLAY_V020_PASS crash_gap=recovered event_stream=authoritative ambient_keeps_explicit_location=yes restart=equivalent")
	quit(0)
