extends SceneTree
const World = preload("res://scripts/world_model.gd")

func _initialize() -> void:
	call_deferred("run")

func _cleanup(path: String) -> void:
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func _has_event(entries: Array, event_name: String) -> bool:
	for entry in entries:
		if str(entry.get("event","")) == event_name:
			return true
	return false

func run() -> void:
	var path := "user://guest_room_access_v018.json"
	_cleanup(path)
	var world := World.new()
	world.save_path = path
	world.seed_world()
	var room := world.make_room(6,1,"guest")
	assert(str(room["type"])=="guest")
	assert(bool(room["public_frontage"]))
	assert(str(room["guest_access_state"])=="open")
	assert(world.public_cutaway_allowed(room))

	assert(world.register_guest_actor(
		"NPC_VAMPIRE_GIRL","Вампирша",room["id"],"humanoid","NPC_VAMPIRE_GIRL"))
	assert(str(room["owner_id"])=="NPC_VAMPIRE_GIRL")
	assert(str(world.residents["NPC_VAMPIRE_GIRL"]["home_room_id"])==str(room["id"]))
	assert(str(room["display_name"]).contains("Вампирша"))

	var visitor_id := "RES_01"
	var visitor: Dictionary = world.residents[visitor_id]
	var open_route: Array = world.find_route(str(visitor["room_id"]),str(room["id"]),visitor_id)
	assert(not open_route.is_empty())

	assert(world.set_guest_room_open(str(room["id"]),false))
	assert(str(room["guest_access_state"])=="closed")
	assert(not world.public_cutaway_allowed(room))
	assert(not world.is_accessible(room,visitor_id))
	assert(world.is_accessible(room,"NPC_VAMPIRE_GIRL"))
	assert(world.find_route(str(visitor["room_id"]),str(room["id"]),visitor_id).is_empty())
	assert(not world.find_route(str(room["id"]),str(room["id"]),"NPC_VAMPIRE_GIRL").is_empty())
	assert(world.allows_transit(room)) # public frontage remains passable

	assert(world.set_guest_room_open(str(room["id"]),true))
	assert(world.public_cutaway_allowed(room))
	assert(not world.find_route(str(visitor["room_id"]),str(room["id"]),visitor_id).is_empty())
	assert(_has_event(world.journal_entries(64),"GUEST_ROOM_ASSIGNED"))
	assert(_has_event(world.journal_entries(64),"GUEST_ROOM_ACCESS_CHANGED"))

	assert(world.set_guest_room_open(str(room["id"]),false))
	assert(world.save_world())
	var loaded := World.new()
	loaded.save_path = path
	loaded.load_or_seed()
	var loaded_room: Dictionary = loaded.room_by_id(str(room["id"]))
	assert(str(loaded_room["owner_id"])=="NPC_VAMPIRE_GIRL")
	assert(str(loaded_room["guest_access_state"])=="closed")
	assert(not loaded.public_cutaway_allowed(loaded_room))
	assert(loaded.is_accessible(loaded_room,"NPC_VAMPIRE_GIRL"))
	assert(not loaded.is_accessible(loaded_room,visitor_id))

	_cleanup(path)
	print("GUEST_ROOM_ACCESS_V018_PASS assigned=yes visit_open=yes closed_entry=no owner_entry=yes cutaway_closed=no frontage_transit=yes persisted=yes")
	quit(0)
