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
	var path := "user://object_event_sqlite_canonical_loss_v021.json"
	_cleanup(path)
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")

	# Create an accepted v0.20 JSON stream that will intentionally become stale.
	var legacy := World.new()
	legacy.save_path = path
	legacy.seed_world()
	var home: Dictionary = legacy.get_room(1,-1)
	assert(legacy.register_physical_object(
		"CANONICAL_LOSS_OBJECT","Canonical loss object","RES_01",home["id"],
		true,true,false,false,false))
	assert(legacy.save_world())
	var stale_json_path := path+".world_events_v1.json"
	var stale_json_sha := FileAccess.get_sha256(stale_json_path)
	assert(stale_json_sha!="")

	# Cut over to SQLite and advance one event beyond the old JSON stream.
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","sqlite")
	var cutover := World.new()
	cutover.save_path = path
	cutover.load_or_seed()
	assert(str(cutover.runtime_state.get("object_event_backend",""))=="sqlite_v021_proof")
	assert(cutover.object_event_revision()==1)
	assert(cutover.set_object_ambient_protection("CANONICAL_LOSS_OBJECT",true))
	assert(cutover.object_event_revision()==2)
	assert(cutover.save_world())
	var sqlite_path := path+".world_events_v1.sqlite"
	var backup_path := sqlite_path+".bak"
	var marker_path := sqlite_path+".canonical.json"
	assert(FileAccess.file_exists(sqlite_path))
	assert(FileAccess.file_exists(backup_path))
	assert(FileAccess.file_exists(marker_path))
	assert(FileAccess.get_sha256(stale_json_path)==stale_json_sha)
	cutover.object_events.store.close()

	# Missing primary must restore the latest readable backup BEFORE SQLite can
	# create a fresh empty file at the same path.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sqlite_path))
	for suffix in ["-wal","-shm"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sqlite_path+suffix))
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var recovered := World.new()
	recovered.save_path = path
	recovered.load_or_seed()
	assert(str(recovered.runtime_state.get("object_event_backend",""))=="sqlite_v021_proof")
	assert(str(recovered.runtime_state.get("object_event_status",""))=="REPLAYED_FROM_BACKUP")
	assert(recovered.object_event_revision()==2)
	assert(bool(recovered.physical_object("CANONICAL_LOSS_OBJECT")["ambient_protected"]))
	assert(FileAccess.get_sha256(stale_json_path)==stale_json_sha)
	recovered.object_events.store.close()

	# Now remove BOTH canonical SQLite copies. Marker + saved backend prove that
	# SQLite had already won. Stale JSON must never be promoted back to truth.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sqlite_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
	for suffix in ["-wal","-shm"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sqlite_path+suffix))
	assert(FileAccess.file_exists(marker_path))
	assert(FileAccess.file_exists(stale_json_path))

	var fail_closed := World.new()
	fail_closed.save_path = path
	fail_closed.load_or_seed()
	assert(str(fail_closed.runtime_state.get("object_event_backend",""))=="sqlite_v021_proof")
	assert(str(fail_closed.runtime_state.get("object_event_status",""))=="SQLITE_CANONICAL_MISSING")
	assert(fail_closed.object_event_revision()==2,
		"last-known canonical sequence must remain visible for diagnosis")
	assert(bool(fail_closed.physical_object("CANONICAL_LOSS_OBJECT")["ambient_protected"]),
		"compatibility snapshot remains inspectable")
	var revision_before := fail_closed.object_event_revision()
	assert(not fail_closed.set_object_ambient_protection("CANONICAL_LOSS_OBJECT",false))
	assert(fail_closed.object_event_revision()==revision_before)
	assert(not FileAccess.file_exists(sqlite_path),
		"fail-closed startup must not invent a replacement SQLite database")
	assert(FileAccess.get_sha256(stale_json_path)==stale_json_sha)

	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","")
	_cleanup(path)
	print("OBJECT_EVENT_SQLITE_CANONICAL_LOSS_V021_PASS missing_primary=backup_restored canonical_loss=fail_closed stale_json=no_rollback revision=evidence_preserved")
	quit(0)
