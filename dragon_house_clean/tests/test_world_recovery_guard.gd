extends SceneTree
const W=preload("res://scripts/world_model.gd")

func _write(path:String,content:String)->void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	assert(f!=null)
	f.store_string(content)
	f.close()

func _cleanup(path:String)->void:
	for suffix in ["",".bak",".tmp",".corrupt",".world_events_v1.json",".world_events_v1.json.bak",".world_events_v1.json.tmp",".world_events_v1.json.corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func _initialize()->void:
	var old_env:String=OS.get_environment("DRAGON_OBJECT_EVENT_BACKEND")
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var base:String="user://test_world_recovery_guard_%d.json"%Time.get_ticks_usec()
	var fresh=W.new()
	fresh.save_path=base
	assert(fresh.load_or_seed())
	assert(fresh.load_status=="SEEDED")
	fresh.sim_clock=111.0
	assert(fresh.save_world())
	fresh.sim_clock=222.0
	assert(fresh.save_world())
	var valid_backup:String=FileAccess.get_file_as_string(base+".bak")
	_write(base,"{broken primary")
	var restored=W.new()
	restored.save_path=base
	assert(restored.load_or_seed())
	assert(restored.load_status=="RECOVERED_BACKUP")
	assert(restored.sim_clock==111.0)
	# Syntactically valid JSON with wrong types must be rejected too.
	var invalid:Dictionary=JSON.parse_string(valid_backup)
	invalid["runtime_state"]=[]
	_write(base+".bak",JSON.stringify(invalid))
	var hashes:Array=[FileAccess.get_sha256(base),FileAccess.get_sha256(base+".bak")]
	var blocked=W.new()
	blocked.save_path=base
	assert(not blocked.load_or_seed())
	assert(blocked.recovery_blocked and blocked.load_status=="SNAPSHOT_RECOVERY_REQUIRED")
	assert(blocked.rooms.is_empty())
	assert(not blocked.save_world())
	assert(not blocked._ensure_object_events())
	assert(hashes==[FileAccess.get_sha256(base),FileAccess.get_sha256(base+".bak")])
	# Orphaned scratch and event evidence are not first launch.
	var orphan:String=base+".orphan"
	_write(orphan+".tmp",valid_backup)
	blocked=W.new()
	blocked.save_path=orphan
	assert(not blocked.load_or_seed())
	assert(not FileAccess.file_exists(orphan))
	assert(FileAccess.get_file_as_string(orphan+".tmp")==valid_backup)
	_cleanup(orphan)
	_write(orphan+".world_events_v1.json","{orphan event evidence")
	blocked=W.new()
	blocked.save_path=orphan
	assert(not blocked.load_or_seed())
	assert(not FileAccess.file_exists(orphan))
	assert(FileAccess.get_file_as_string(orphan+".world_events_v1.json")=="{orphan event evidence")
	_cleanup(orphan)
	# A readable snapshot is not sufficient if its object journal is behind.
	var saved:Dictionary=JSON.parse_string(valid_backup)
	saved["runtime_state"]["object_event_revision"]=12
	_write(base,JSON.stringify(saved))
	_write(base+".world_events_v1.json",JSON.stringify({"schema":1,"sequence":0,"events":[]}))
	var snapshot_hash:String=FileAccess.get_sha256(base)
	blocked=W.new()
	blocked.save_path=base
	assert(not blocked.load_or_seed())
	assert(blocked.load_status=="EVENT_RECOVERY_REQUIRED")
	assert(blocked.sim_clock==111.0)
	assert(not blocked.save_world())
	assert(FileAccess.get_sha256(base)==snapshot_hash)
	_cleanup(base)
	if old_env=="":OS.unset_environment("DRAGON_OBJECT_EVENT_BACKEND")
	else:OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND",old_env)
	print("WORLD_RECOVERY_GUARD_TEST_PASS")
	quit(0)
