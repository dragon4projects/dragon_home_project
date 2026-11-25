extends SceneTree
const Store = preload("res://scripts/world_event_store.gd")
const W = preload("res://scripts/world_model.gd")

func _write(path:String, data:String)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(data)
	file.close()

func _initialize()->void:
	var base:String="user://test_event_recovery_revision_%d.json"%Time.get_ticks_usec()
	var path:String=base+".world_events_v1.json"
	var store=Store.new()
	assert(store.setup(base))
	var batch:Array=[]
	for i in range(40):
		batch.append({"event_id":"qa-%d"%i})
	assert(store.append_many(batch).size()==40)
	assert(store.last_sequence()==40)
	assert(store.append({"event_id":"qa-40"}).size()>0)
	assert(store.last_sequence()==41)
	var backup_hash:String=FileAccess.get_sha256(path+".bak")
	assert(backup_hash!="")
	# Damage primary after successful setup; a second write must retain backup.
	_write(path,"{torn")
	assert(not store.append({"event_id":"qa-41"}).is_empty())
	assert(FileAccess.get_sha256(path+".bak")==backup_hash)
	var reloaded=Store.new()
	assert(reloaded.setup(base))
	assert(reloaded.last_sequence()==42)
	assert(reloaded.snapshot_events().size()==42)
	assert(reloaded.append({"event_id":"qa-0"}).is_empty())
	assert(reloaded.last_sequence()==42)
	var bad:Array=[
		{"schema":1,"sequence":3,"events":[{"seq":1,"event_id":"a"},{"seq":3,"event_id":"b"}]},
		{"schema":1,"sequence":2,"events":[{"seq":2,"event_id":"b"},{"seq":1,"event_id":"a"}]},
		{"schema":1,"sequence":2,"events":[{"seq":1,"event_id":"a"},{"seq":1,"event_id":"b"}]},
		{"schema":1,"sequence":3,"events":[{"seq":1,"event_id":"a"}]},
		{"schema":1,"sequence":1,"events":[{"seq":1.5,"event_id":"a"}]}
	]
	for doc in bad:
		assert(reloaded._parse_document(JSON.stringify(doc),"fixture").is_empty())
	# A readable but older journal must not replace the saved projection or revision.
	var old_env:String=OS.get_environment("DRAGON_OBJECT_EVENT_BACKEND")
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var world=W.new()
	world.save_path=base
	world.runtime_state["object_event_revision"]=43
	world.objects={"fixture":{"id":"fixture","state":"PLACED"}}
	assert(not world._ensure_object_events())
	assert(world.object_events.status=="JSON_ROLLBACK_DETECTED")
	assert(world.object_event_revision()==43)
	assert(world.objects=={"fixture":{"id":"fixture","state":"PLACED"}})
	if old_env=="":
		OS.unset_environment("DRAGON_OBJECT_EVENT_BACKEND")
	else:
		OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND",old_env)
	for suffix in ["",".bak",".tmp",".corrupt"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	print("EVENT_RECOVERY_REVISION_TEST_PASS")
	quit(0)
