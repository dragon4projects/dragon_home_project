extends SceneTree
const World = preload("res://scripts/world_model.gd")

func _initialize() -> void:
	call_deferred("run")

func _cleanup(path: String) -> void:
	var backup_abs := ProjectSettings.globalize_path(path+".world_events_v1.sqlite.bak")
	if DirAccess.dir_exists_absolute(backup_abs):
		DirAccess.remove_absolute(backup_abs)
	for suffix in [
		"",".bak",".tmp",
		".world_events_v1.sqlite",".world_events_v1.sqlite.bak",
		".world_events_v1.sqlite-wal",".world_events_v1.sqlite-shm",
		".world_events_v1.sqlite.corrupt",
		".world_events_v1.sqlite.canonical.json",
		".world_events_v1.sqlite.canonical.json.tmp"
	]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func run() -> void:
	var path := "user://object_event_sqlite_backup_warning_v021.json"
	_cleanup(path)
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","sqlite")

	var world := World.new()
	world.save_path = path
	world.seed_world()
	var home: Dictionary = world.get_room(1,-1)
	assert(world.register_physical_object(
		"BACKUP_WARNING_OBJECT","Backup warning object","RES_01",home["id"],
		true,true,false,false,false))
	assert(world.object_event_revision()==1)
	var backup_path := path+".world_events_v1.sqlite.bak"
	var backup_abs := ProjectSettings.globalize_path(backup_path)
	assert(FileAccess.file_exists(backup_path))
	DirAccess.remove_absolute(backup_abs)
	assert(DirAccess.make_dir_absolute(backup_abs)==OK)
	assert(DirAccess.dir_exists_absolute(backup_abs))

	# The primary event+projection transaction succeeds. Only the recovery copy
	# is sabotaged. The caller must not be told that the canonical mutation failed.
	assert(world.set_object_ambient_protection("BACKUP_WARNING_OBJECT",true))
	assert(world.object_event_revision()==2)
	assert(bool(world.physical_object("BACKUP_WARNING_OBJECT")["ambient_protected"]))
	assert(str(world.runtime_state.get("object_event_status",""))=="READY_BACKUP_STALE")
	assert(str(world.runtime_state.get("object_event_backup_warning",""))!="")
	var marker_path := path+".world_events_v1.sqlite.canonical.json"
	assert(FileAccess.file_exists(marker_path))
	var marker = JSON.parse_string(FileAccess.get_file_as_string(marker_path))
	assert(typeof(marker)==TYPE_DICTIONARY)
	assert(int((marker as Dictionary).get("sequence",-1))==2)
	world.object_events.store.close()

	# Remove only the sabotage. Primary SQLite remains canonical and must replay
	# sequence 2 even though no fresh recovery backup was created.
	assert(DirAccess.remove_absolute(backup_abs)==OK)
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")
	var restarted := World.new()
	restarted.save_path = path
	restarted.load_or_seed()
	assert(str(restarted.runtime_state.get("object_event_backend",""))=="sqlite_v021_proof")
	assert(restarted.object_event_revision()==2)
	assert(bool(restarted.physical_object("BACKUP_WARNING_OBJECT")["ambient_protected"]))
	assert(str(restarted.runtime_state.get("object_event_status",""))=="REPLAYED")
	restarted.object_events.store.close()

	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")
	_cleanup(path)
	print("OBJECT_EVENT_SQLITE_BACKUP_WARNING_V021_PASS commit=canonical backup=failure_warning caller=success marker=advanced restart=primary_replay")
	quit(0)
