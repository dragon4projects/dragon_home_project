extends SceneTree
const World = preload("res://scripts/world_model.gd")

func _initialize() -> void:
	call_deferred("run")

func _cleanup(path: String) -> void:
	for suffix in [
		"",".bak",".tmp",
		".world_events_v1.json",".world_events_v1.json.bak",
		".world_events_v1.json.tmp",".world_events_v1.json.corrupt",
		".world_events_v1.sqlite",".world_events_v1.sqlite.bak",
		".world_events_v1.sqlite-wal",".world_events_v1.sqlite-shm",
		".world_events_v1.sqlite.corrupt",
		".world_events_v1.sqlite.canonical.json",
		".world_events_v1.sqlite.canonical.json.tmp"
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func run() -> void:
	assert(ClassDB.class_exists("SQLite"),
		"QA requires the vendored SQLite GDExtension to be loaded")

	# Normal production launch has no backend environment override. With the
	# vendored extension available, a clean world must start directly on SQLite.
	var path := "user://object_event_default_sqlite_v021.json"
	_cleanup(path)
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")
	var world := World.new()
	world.save_path = path
	world.seed_world()
	var home: Dictionary = world.get_room(1,-1)
	assert(world.register_physical_object(
		"DEFAULT_SQLITE_OBJECT","Default SQLite object","RES_01",home["id"],
		true,true,false,false,false))
	assert(str(world.runtime_state.get("object_event_backend",""))=="sqlite_v021_proof")
	assert(world.object_event_revision()==1)
	assert(FileAccess.file_exists(path+".world_events_v1.sqlite"))
	assert(FileAccess.file_exists(path+".world_events_v1.sqlite.canonical.json"))
	assert(not FileAccess.file_exists(path+".world_events_v1.json"))
	world.object_events.store.close()

	# Explicit JSON remains available only as a pre-cutover developer /
	# compatibility override; it must not be the production default.
	var compat_path := "user://object_event_explicit_json_v021.json"
	_cleanup(compat_path)
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var compat := World.new()
	compat.save_path = compat_path
	compat.seed_world()
	var compat_home: Dictionary = compat.get_room(1,-1)
	assert(compat.register_physical_object(
		"EXPLICIT_JSON_OBJECT","Explicit JSON object","RES_01",compat_home["id"],
		true,true,false,false,false))
	assert(str(compat.runtime_state.get("object_event_backend",""))=="json_append_compat_v1")
	assert(FileAccess.file_exists(compat_path+".world_events_v1.json"))
	assert(not FileAccess.file_exists(compat_path+".world_events_v1.sqlite"))

	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")
	_cleanup(path)
	_cleanup(compat_path)
	print("OBJECT_EVENT_DEFAULT_SQLITE_V021_PASS no_env=sqlite clean_world=sqlite explicit_json=pre_cutover_override")
	quit(0)
