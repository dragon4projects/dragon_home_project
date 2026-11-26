extends RefCounted
const JsonEventStore = preload("res://scripts/world_event_store.gd")
const SQLiteEventStore = preload("res://scripts/world_event_store_sqlite.gd")
const EventGate = preload("res://scripts/world_event_gate.gd")
const ObjectReducer = preload("res://scripts/object_event_reducer.gd")
const LearnedHabits=preload("res://scripts/learned_habits.gd")

## Strangler facade: keeps current WorldModel object APIs stable while moving
## their durable truth path to gate -> append-only event -> reducer projection.

# WorldModel owns this runtime. A strong reverse reference creates a
# RefCounted cycle and retains the SQLite store and its resources on exit.
var _world_ref:WeakRef
var world:
	get:
		return _world_ref.get_ref() if _world_ref!=null else null
	set(value):
		_world_ref=weakref(value) if value!=null else null
var store = JsonEventStore.new()
var backend_requested: String = "json"
var gate = EventGate.new()
var reducer = ObjectReducer.new()
var ready: bool = false
var status: String = "UNINITIALIZED"
var last_error: String = ""
var event_nonce: int = 0

func _sqlite_primary_path() -> String:
	return str(world.save_path)+".world_events_v1.sqlite"

func _sqlite_backup_path() -> String:
	return _sqlite_primary_path()+".bak"

func _sqlite_marker_path() -> String:
	return _sqlite_primary_path()+".canonical.json"

func _sqlite_storage_exists() -> bool:
	return FileAccess.file_exists(_sqlite_primary_path()) or 		FileAccess.file_exists(_sqlite_backup_path())

func _saved_backend_is_sqlite() -> bool:
	return str(world.runtime_state.get("object_event_backend","")).begins_with("sqlite_")

func _sqlite_marker_exists() -> bool:
	return FileAccess.file_exists(_sqlite_marker_path())

func _sqlite_marker_sequence() -> int:
	if not _sqlite_marker_exists():
		return -1
	var file := FileAccess.open(_sqlite_marker_path(),FileAccess.READ)
	if file == null:
		return -1
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	return int((parsed as Dictionary).get("sequence",-1))

func _write_sqlite_marker() -> bool:
	if backend_requested != "sqlite":
		return true
	var marker := {
		"schema":1,
		"backend":"sqlite_v021",
		"sequence":store.last_sequence(),
		"store_path":_sqlite_primary_path(),
		"updated_at":Time.get_unix_time_from_system()
	}
	var path := _sqlite_marker_path()
	var scratch := path+".tmp"
	var file := FileAccess.open(scratch,FileAccess.WRITE)
	if file == null:
		last_error = "Cannot open SQLite canonical marker temp file"
		return false
	file.store_string(JSON.stringify(marker,"\t")+"\n")
	file.flush()
	var err: Error = file.get_error()
	file.close()
	if err != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		last_error = "Cannot flush SQLite canonical marker"
		return false
	var verify = JSON.parse_string(FileAccess.get_file_as_string(scratch))
	if typeof(verify) != TYPE_DICTIONARY or int(
			(verify as Dictionary).get("sequence",-1)) != store.last_sequence():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		last_error = "Cannot verify SQLite canonical marker"
		return false
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_scratch := ProjectSettings.globalize_path(scratch)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	if DirAccess.rename_absolute(abs_scratch,abs_path) != OK:
		last_error = "Cannot commit SQLite canonical marker"
		return false
	return true

func _select_store() -> void:
	var requested: String = OS.get_environment(
		"DRAGON_OBJECT_EVENT_BACKEND").strip_edges().to_lower()
	var sticky_sqlite: bool = _sqlite_storage_exists() or \
		_sqlite_marker_exists() or _saved_backend_is_sqlite()
	var sqlite_available: bool = ClassDB.class_exists("SQLite")
	# A canonical SQLite world can never downgrade, even if the extension later
	# disappears; setup then fails closed and preserves evidence.
	if sticky_sqlite:
		store = SQLiteEventStore.new()
		backend_requested = "sqlite"
		return
	# Explicit JSON remains a dev/compatibility override only before cutover.
	if requested == "json":
		store = JsonEventStore.new()
		backend_requested = "json"
		return
	if requested == "sqlite":
		store = SQLiteEventStore.new()
		backend_requested = "sqlite"
		return
	# Production/default behavior: when the vendored extension is present, new
	# worlds and v0.20 JSON worlds enter the SQLite path automatically. A source
	# checkout missing native LFS bytes can still use JSON until SQLite exists.
	if sqlite_available:
		store = SQLiteEventStore.new()
		backend_requested = "sqlite"
	else:
		store = JsonEventStore.new()
		backend_requested = "json"

func _legacy_json_event_store_exists() -> bool:
	var base := str(world.save_path)+".world_events_v1.json"
	return FileAccess.file_exists(base) or FileAccess.file_exists(base+".bak")

func _migrate_json_event_store_to_sqlite() -> int:
	if backend_requested != "sqlite" or not store.events.is_empty() or 			not _legacy_json_event_store_exists():
		return 0
	var legacy = JsonEventStore.new()
	if not legacy.setup(str(world.save_path)):
		last_error = "Canonical v0.20 JSON event stream is unreadable: "+legacy.last_error
		return -1
	if legacy.last_sequence() < int(world.runtime_state.get("object_event_revision",0)):
		last_error = "Legacy JSON stream is older than saved object revision"
		return -1
	var source_events: Array = legacy.snapshot_events()
	if source_events.is_empty():
		return 0
	var projection: Dictionary = reducer.replay(source_events)
	if projection.is_empty():
		last_error = "Cannot reduce canonical v0.20 JSON stream: "+reducer.last_error
		return -1
	if not store.has_method("import_canonical_events"):
		last_error = "Selected SQLite backend cannot import canonical events"
		return -1
	var imported: Array = store.import_canonical_events(source_events,projection)
	if imported.size() != source_events.size():
		last_error = "SQLite canonical import failed: "+str(store.last_error)
		return -1
	for i in range(source_events.size()):
		var before: Dictionary = source_events[i]
		var after: Dictionary = imported[i]
		if str(before.get("event_id","")) != str(after.get("event_id","")) or 				int(before.get("seq",0)) != int(after.get("seq",0)):
			last_error = "SQLite migration changed canonical event identity/order"
			return -1
	if store.has_method("derived_objects_snapshot"):
		var persisted_projection: Dictionary = store.derived_objects_snapshot()
		if persisted_projection != projection:
			last_error = "SQLite migration projection differs from reducer projection"
			return -1
	_publish_projection(projection)
	world.runtime_state["object_event_migrated_from_backend"] = "json_append_compat_v1"
	world.runtime_state["object_event_migrated_event_count"] = imported.size()
	world.runtime_state["object_event_migration_source"] = 		str(world.save_path)+".world_events_v1.json"
	_reconcile_journal_from_store()
	return imported.size()

func setup(p_world) -> bool:
	world = p_world
	_select_store()
	ready = false
	status = "INITIALIZING"
	last_error = ""
	var sqlite_was_canonical: bool = _sqlite_marker_exists() or _saved_backend_is_sqlite()
	if backend_requested == "sqlite" and sqlite_was_canonical and 			not _sqlite_storage_exists():
		status = "SQLITE_CANONICAL_MISSING"
		last_error = "SQLite was canonical, but primary and backup are both missing; stale JSON is not eligible for rollback"
		_update_runtime_state()
		return false
	if not store.setup(str(world.save_path)):
		status = store.status
		last_error = store.last_error
		_update_runtime_state()
		return false
	# A previously canonical store must not replay, migrate, or publish
	# an older projection before checking the snapshot/marker revision.
	var saved_revision:int = int(world.runtime_state.get("object_event_revision",0))
	var marker_revision:int = _sqlite_marker_sequence() if backend_requested == "sqlite" else -1
	var required_revision:int = maxi(saved_revision,marker_revision)
	var can_migrate:bool = backend_requested == "sqlite" and not sqlite_was_canonical and store.events.is_empty() and _legacy_json_event_store_exists()
	if not can_migrate and store.last_sequence() < required_revision:
		status = "SQLITE_ROLLBACK_DETECTED" if backend_requested == "sqlite" else "JSON_ROLLBACK_DETECTED"
		last_error = "Readable object event revision %d is behind required revision %d" % [store.last_sequence(),required_revision]
		_update_runtime_state()
		return false
	var canonical_migrated:int = _migrate_json_event_store_to_sqlite() if can_migrate else 0
	if canonical_migrated < 0:
		status = "JSON_EVENT_MIGRATION_FAILED"
		_update_runtime_state()
		return false
	event_nonce = store.last_sequence()
	if canonical_migrated > 0:
		status = "MIGRATED_JSON_EVENT_STORE"
	elif not store.events.is_empty():
		var projection: Dictionary = reducer.replay(store.snapshot_events())
		if projection.is_empty():
			status = "REDUCER_REPLAY_FAILED"
			last_error = reducer.last_error
			_update_runtime_state()
			return false
		if store.has_method("derived_objects_snapshot"):
			var persisted_projection: Dictionary = store.derived_objects_snapshot()
			if persisted_projection != projection:
				if not store.has_method("rebuild_projection") or 						not bool(store.rebuild_projection(projection)):
					status = "PROJECTION_REBUILD_FAILED"
					last_error = str(store.last_error)
					_update_runtime_state()
					return false
				world.runtime_state["object_event_projection_rebuilt"] = true
			elif store.has_method("accept_verified_projection"):
				store.accept_verified_projection(projection)
		_publish_projection(projection)
		_reconcile_journal_from_store()
		status = "REPLAYED_FROM_BACKUP" if store.status == "RECOVERED_FROM_BACKUP" else "REPLAYED"
	elif not world.objects.is_empty():
		if not _migrate_snapshot_objects():
			status = "MIGRATION_FAILED"
			_update_runtime_state()
			return false
		status = "MIGRATED_JSON_SNAPSHOT"
	else:
		status = "READY_EMPTY"
	if backend_requested == "sqlite":
		var marker_sequence: int = _sqlite_marker_sequence()
		if marker_sequence > store.last_sequence():
			status = "SQLITE_ROLLBACK_DETECTED"
			last_error = "SQLite canonical marker sequence %d is ahead of readable store sequence %d" % [
				marker_sequence,store.last_sequence()]
			_update_runtime_state()
			return false
		if not _write_sqlite_marker():
			status = "SQLITE_MARKER_WRITE_FAILED"
			_update_runtime_state()
			return false
	# The snapshot revision and habit projection are written in one snapshot.
	# Durable view events newer than that checkpoint must project their credit
	# before the event revision is advanced. Legacy events lack completion IDs.
	for event in store.events:
		if int(event.get("seq",0))>saved_revision:
			_apply_view_completion(event,true)
	ready = true
	_update_runtime_state()
	return true

func _apply_view_completion(event:Dictionary,recovering:bool)->void:
	if str(event.get("event_type",""))!="OBJECT_INTERACTED":return
	var payload:Dictionary=event.get("payload",{})
	var completion_id:String=str(payload.get("view_completion_id",""))
	if completion_id=="" or completion_id!=str(event.get("event_id","")) or not completion_id.begins_with("view-v1-"):return
	var actor:Dictionary=world.residents.get(str(payload.get("actor_id","")),{})
	var seq:int=int(event.get("seq",0))
	if actor.is_empty() or seq<=int(actor.get("last_view_credit_seq",0)):return
	var event_time:float=float(payload.get("sim_clock",-1))
	if not is_finite(event_time) or event_time<0:return
	var subject:String=str(payload.get("object_id",""))
	var matched:bool=EventGate.view_completion_id(actor,subject)==completion_id
	# A post-checkpoint fact can be newer than the restored world. Preserve
	# its real timestamp as provenance, but do not age unrelated activities.
	LearnedHabits.record(actor,"VIEW_ART",minf(event_time,world.sim_clock),subject,str(payload.get("context","")),{"event_id":completion_id,"event_sim_clock":event_time,"room_id":str(event.get("room_id","")),"station_id":str(payload.get("station_id",""))})
	actor["last_view_credit_seq"]=seq
	if matched:
		actor.erase("solo_habit_commitment")
		if recovering and str(actor.get("intent",""))=="VIEW_ART" and str(actor.get("phase",""))=="perform" and str(actor.get("viewing_object_id",""))==subject:
			# Life.setup releases this exact already-completed station/route.
			# Never cancel a different commitment on the same resident.
			actor["recovered_view_completion"]=completion_id

func _update_runtime_state() -> void:
	if world == null:
		return
	# A failed recovery must not erase the last known committed revision.
	var reported_revision: int = maxi(store.last_sequence(),int(world.runtime_state.get("object_event_revision",0)))
	if backend_requested == "sqlite":
		var marker_sequence: int = _sqlite_marker_sequence()
		if marker_sequence > reported_revision:
			reported_revision = marker_sequence
	world.runtime_state["object_event_revision"] = reported_revision
	world.runtime_state["object_event_status"] = status
	world.runtime_state["object_event_backend"] = str(store.backend_name()) if store.has_method("backend_name") else backend_requested
	world.runtime_state["object_event_store_path"] = store.storage_path()
	if last_error != "":
		world.runtime_state["object_event_last_error"] = last_error
	else:
		world.runtime_state.erase("object_event_last_error")
	var store_warning: String = str(store.last_warning)
	if store_warning != "":
		world.runtime_state["object_event_backup_warning"] = store_warning
	else:
		world.runtime_state.erase("object_event_backup_warning")

func _publish_projection(projection: Dictionary) -> void:
	# Preserve existing Dictionary identity so callers holding object references
	# observe accepted reducer changes without needing to refetch the object.
	for raw_id in world.objects.keys().duplicate():
		var object_id: String = str(raw_id)
		if not projection.has(object_id):
			world.objects.erase(object_id)
	for raw_id in projection:
		var object_id: String = str(raw_id)
		var projected: Dictionary = projection[raw_id]
		if world.objects.has(object_id):
			var current: Dictionary = world.objects[object_id]
			current.clear()
			current.merge(projected.duplicate(true),true)
		else:
			world.objects[object_id] = projected.duplicate(true)
		# Reconcile cleanup after a crash between the durable object event
		# and the next beverage snapshot. Never empty a later serving.
		var cups:Dictionary=world.runtime_state.get("beverages",{}).get("cups",{})
		var cup:Dictionary=cups.get(object_id,{})
		if not cup.is_empty() and str(projected.get("housekeeping_event_id",""))!="" and str(projected.get("housekeeping_cleaned_serving",""))==str(cup.get("choice_instance_id","")) and str(projected.get("housekeeping_cleaned_pickup",""))==str(cup.get("serving_pickup_event_id","")):
			cup["remaining_ml"]=0.0
			cup.erase("pending_choice")

func _make_event_id() -> String:
	event_nonce += 1
	return "object-v1-%d-%d-%d" % [
		int(Time.get_unix_time_from_system()*1000000.0),
		Time.get_ticks_usec(),event_nonce]

func _visibility_for_room(room_id: String) -> String:
	var room: Dictionary = world.room_by_id(room_id)
	if room.is_empty():
		return "house_public"
	return "house_public" if str(room.get("privacy","public")) == "public" else "owner_controlled"

func _default_anchor(object_id: String) -> Array:
	var code:int=0
	for i in range(object_id.length()):
		code=(code*33+object_id.unicode_at(i)) & 0x7fffffff
	var x:float=(float(code%7)-3.0)*0.16
	var z:float=0.72+(float(int(code/7)%5)-2.0)*0.12
	return [x,z]

func _anchor_or_default(raw, object_id: String) -> Array:
	if raw is Vector2:
		var point:Vector2=raw
		return [point.x,point.y]
	if typeof(raw)==TYPE_ARRAY:
		var value:Array=raw
		if value.size()==2 and typeof(value[0]) in [TYPE_INT,TYPE_FLOAT] and (
				typeof(value[1]) in [TYPE_INT,TYPE_FLOAT]):
			return [float(value[0]),float(value[1])]
	return _default_anchor(object_id)

func _base_event(event_type: String, truth_class: String,
		source_type: String, source_id: String, authority: String,
		visibility: String, reversibility: String, subject_id: String,
		object_id: String, room_id: String, from_value: String,
		to_value: String, provenance: String, notes: String,
		payload: Dictionary) -> Dictionary:
	var now: float = Time.get_unix_time_from_system()
	return {
		"event_id":_make_event_id(),
		"created_at":now,
		"timestamp":now,
		"source_type":source_type,
		"source_id":source_id,
		"authority":authority,
		"truth_class":truth_class,
		"visibility":visibility,
		"event_type":event_type,
		"subject_id":subject_id,
		"object_id":object_id,
		"room_id":room_id,
		"from":from_value,
		"to":to_value,
		"expires_at":null,
		"reversibility":reversibility,
		"provenance":provenance,
		"notes":notes,
		"payload":payload.duplicate(true)
	}

func _migration_registration(object: Dictionary) -> Dictionary:
	var object_id: String = str(object.get("id",""))
	var home_room_id: String = str(object.get("home_room_id",
		object.get("current_room_id","")))
	var current_location: String = str(object.get("current_room_id",""))
	var current_holder: String = str(object.get("current_holder_id",""))
	var state: String = str(object.get("state",
		"HELD" if current_holder != "" else "PLACED"))
	var visible_room: String = current_location if current_location != "" else home_room_id
	var home_anchor:Array=_anchor_or_default(object.get("home_anchor",[]),object_id)
	var wall_anchor=object.get("display_anchor",object.get("home_anchor",[]))
	if str(object.get("display_mode",""))=="wall" and typeof(wall_anchor)==TYPE_ARRAY and wall_anchor.size()==3:
		home_anchor=[float(wall_anchor[0]),float(wall_anchor[2])]
	var current_anchor:Array=_anchor_or_default(object.get("current_anchor",home_anchor),object_id)
	var metadata := {
		"description":str(object.get("description","")),
		"preview_path":str(object.get("preview_path","")),
		"full_image_path":str(object.get("full_image_path","")),
		"artifact_source_status":str(object.get("artifact_source_status","")),
		"asset_id":str(object.get("asset_id","")),
		"viewer_category":str(object.get("viewer_category","artifacts")),
		"display_mode":str(object.get("display_mode","")),
		"display_anchor":object.get("display_anchor",object.get("home_anchor",[])),
		"interaction_station_id":str(object.get("interaction_station_id","")),
		"interaction_point":object.get("interaction_point",[]),
		"interaction_approach_z":float(object.get("interaction_approach_z",0.95)),
		"display_world_height":float(object.get("display_world_height",0.8)),
		"legacy_history":(object.get("history",[]) as Array).duplicate(true)
	}
	var payload := {
		"object_id":object_id,
		"object_type":"physical_object",
		"object_class":str(object.get("object_class","display_object")),
		"display_name":str(object.get("display_name",object_id)),
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"home_room_id":home_room_id,
		"home_anchor":home_anchor,
		"current_holder":current_holder,
		"current_location":current_location,
		"current_anchor":[] if current_holder!="" else current_anchor,
		"state":state,
		"movable":bool(object.get("movable",true)),
		"recoverable":bool(object.get("recoverable",true)),
		"ambient_move_allowed":bool(object.get("ambient_pickup_allowed",false)),
		"ambient_hide_allowed":bool(object.get("ambient_hide_allowed",false)),
		"ambient_protected":bool(object.get("ambient_protected",false)),
		"reset_eligible":bool(object.get("reset_eligible",object.get("movable",true))),
		"asset_id":str(object.get("asset_id","")),
		"last_explicit_location":str(object.get("last_explicit_location",
			visible_room)),
		"movement_reason":str(object.get("movement_reason","MIGRATION_IMPORT")),
		"persistence_class":str(object.get("persistence_class",
			"PERSISTENT_UNTIL_CHANGED")),
		"metadata":metadata,
		"sim_clock":float(world.sim_clock)
	}
	return _base_event(
		"OBJECT_REGISTERED","EXPLICIT_WORLD_FACT","migration_import",
		"world_model_snapshot_v1","HISTORICAL_IMPORT",
		_visibility_for_room(visible_room),"PERSISTENT_UNTIL_CHANGED",
		str(object.get("canonical_owner_id","")),object_id,visible_room,"",
		current_location if current_location != "" else current_holder,
		"MIGRATION_FROM_JSON_SNAPSHOT_V1","Non-destructive object migration",
		payload)

func _migrate_snapshot_objects() -> bool:
	var ids: Array = world.objects.keys()
	ids.sort()
	var migration_events: Array = []
	var candidate: Dictionary = {}
	for raw_id in ids:
		var object: Dictionary = world.objects[raw_id]
		var event: Dictionary = _migration_registration(object)
		if not gate.validate(world,candidate,event):
			last_error = "migration gate: "+gate.last_error
			return false
		var next: Dictionary = reducer.reduce(candidate,event)
		if next.is_empty():
			last_error = "migration reducer: "+reducer.last_error
			return false
		candidate = next
		migration_events.append(event)
	var committed: Array = store.append_many_with_projection(migration_events,candidate) if store.has_method("append_many_with_projection") else store.append_many(migration_events)
	if committed.size() != migration_events.size():
		last_error = "migration store: "+store.last_error
		return false
	_publish_projection(candidate)
	world.runtime_state["object_event_migrated_count"] = committed.size()
	return true

func _journal_accepted(event: Dictionary) -> void:
	var event_type: String = str(event.get("event_type",""))
	var payload: Dictionary = event.get("payload",{})
	var object_id: String = str(payload.get("object_id",event.get("object_id","")))
	var object: Dictionary = world.objects.get(object_id,{})
	var details := {
		"display_name":str(object.get("display_name",object_id)),
		"event_id":str(event.get("event_id","")),
		"truth_class":str(event.get("truth_class","")),
		"authority":str(event.get("authority","")),
		"provenance":str(event.get("provenance","")),
		"visibility":str(event.get("visibility","")),
		"event_room_id":str(event.get("room_id",""))
	}
	var event_time=payload.get("sim_clock",null)
	if typeof(event_time) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(event_time)) and float(event_time)>=0:
		details["event_sim_clock"]=float(event_time)
	if event_type == "OBJECT_REGISTERED":
		details["canonical_owner_id"] = str(object.get("canonical_owner_id",""))
		world._append_journal("OBJECT_REGISTERED","",object_id,
			str(event.get("from","")),str(event.get("to","")),details)
	elif event_type == "OBJECT_POLICY_SET":
		var target := "POLICY_CHANGED"
		if payload.has("ambient_protected"):
			target = "PROTECTED" if bool(payload["ambient_protected"]) else "ELIGIBLE"
		world._append_journal("OBJECT_AMBIENT_PROTECTION_CHANGED","",object_id,
			"",target,details)
	elif event_type=="OBJECT_INTERACTED":
		world._append_journal("OBJECT_VIEWED",str(payload.get("actor_id","")),object_id,
			str(event.get("from","")),str(event.get("to","")),details)
	elif event_type == "OBJECT_MOVED":
		var movement_kind: String = str(payload.get("movement_kind","MOVED"))
		world._append_journal("OBJECT_"+movement_kind,
			str(payload.get("actor_id",event.get("subject_id",""))),object_id,
			str(event.get("from","")),str(event.get("to","")),details)
	elif event_type == "OBJECT_OWNER_CHANGED":
		world._append_journal("OBJECT_OWNER_CHANGED",
			str(event.get("subject_id","")),object_id,
			str(event.get("from","")),str(event.get("to","")),details)
	elif event_type == "OBJECT_HOME_ASSIGNED":
		world._append_journal("OBJECT_HOME_ASSIGNED",
			str(event.get("subject_id","")),object_id,
			str(event.get("from","")),str(event.get("to","")),details)

func _journal_has_event_id(event_id: String) -> bool:
	if event_id == "":
		return false
	for raw_entry in world.journal:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = raw_entry
		var details: Dictionary = entry.get("details",{})
		if str(details.get("event_id","")) == event_id:
			return true
	return false

func _reconcile_journal_from_store() -> void:
	# Replay is authoritative for object state. Journal is an explanation view.
	# First remove only v0.20 object rows whose event_id is no longer canonical
	# (e.g. primary corruption forced replay from an older backup). Legacy rows
	# without event_id are preserved because they predate this authority layer.
	var canonical_ids: Dictionary = {}
	for raw_event in store.events:
		var event: Dictionary = raw_event
		if str(event.get("source_type","")) != "migration_import":
			canonical_ids[str(event.get("event_id",""))] = event
	for index in range(world.journal.size()-1,-1,-1):
		var entry: Dictionary = world.journal[index]
		if not str(entry.get("event","")).begins_with("OBJECT_"):
			continue
		var details: Dictionary = entry.get("details",{})
		var event_id: String = str(details.get("event_id",""))
		if event_id != "" and not canonical_ids.has(event_id):
			world.journal.remove_at(index)
		elif canonical_ids.has(event_id):
			var event_time=canonical_ids[event_id].get("payload",{}).get("sim_clock",null)
			if typeof(event_time) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(event_time)) and float(event_time)>=0:
				entry["sim_clock"]=float(event_time)
				details["event_sim_clock"]=float(event_time)
	# Then fill missing accepted object events; migration rows remain provenance,
	# not fresh household activity.
	for raw_event in store.events:
		var event: Dictionary = raw_event
		if str(event.get("source_type","")) == "migration_import":
			continue
		var event_id: String = str(event.get("event_id",""))
		if _journal_has_event_id(event_id):
			continue
		_journal_accepted(event)

func events_for_object(object_id: String, limit: int = 64) -> Array:
	return store.events_for_object(object_id,limit) if ready else []

func explain_object(object_id: String) -> Dictionary:
	if not ready or not world.objects.has(object_id):
		return {}
	var object: Dictionary = world.objects[object_id]
	var history: Array = store.events_for_object(object_id,64)
	var latest: Dictionary = history[history.size()-1] if not history.is_empty() else {}
	return {
		"object_id":object_id,
		"display_name":str(object.get("display_name",object_id)),
		"canonical_owner_id":str(object.get("canonical_owner_id","")),
		"current_holder_id":str(object.get("current_holder_id","")),
		"current_room_id":str(object.get("current_room_id","")),
		"current_anchor":object.get("current_anchor",[]),
		"home_room_id":str(object.get("home_room_id","")),
		"home_anchor":object.get("home_anchor",[]),
		"object_class":str(object.get("object_class","display_object")),
		"state":str(object.get("state","")),
		"last_explicit_location":str(object.get("last_explicit_location","")),
		"movement_reason":str(object.get("movement_reason","")),
		"movement_authority":str(object.get("movement_authority","")),
		"event_count":history.size(),
		"latest_event":latest.duplicate(true)
	}

func submit(event: Dictionary, write_journal: bool = true) -> Dictionary:
	if not ready:
		last_error = "object event runtime is not ready: "+status
		_update_runtime_state()
		return {"ok":false,"error":last_error}
	var event_id: String = str(event.get("event_id",""))
	if store.has_event(event_id):
		return {"ok":false,"duplicate":true,"error":"duplicate event_id"}
	if not gate.validate(world,world.objects,event):
		last_error = gate.last_error
		return {"ok":false,"error":last_error}
	var candidate: Dictionary = reducer.reduce(world.objects,event)
	if candidate.is_empty():
		last_error = reducer.last_error
		return {"ok":false,"error":last_error}
	var committed: Dictionary = store.append_with_projection(event,candidate) if store.has_method("append_with_projection") else store.append(event)
	if committed.is_empty():
		last_error = store.last_error
		status = store.status
		_update_runtime_state()
		return {"ok":false,"error":last_error}
	_publish_projection(candidate)
	_apply_view_completion(committed,false)
	# Live creature carrier cache follows the same committed movement that
	# owns possession. A rejected event cannot change the actor cache.
	if str(committed.get("event_type",""))=="OBJECT_MOVED":
		var movement:Dictionary=committed.get("payload",{})
		var object_id:String=str(movement.get("object_id",""))
		var previous:String=str(movement.get("previous_holder",""))
		var current:String=str(movement.get("current_holder",""))
		if previous!=current:
			world._clear_carrier_reference(object_id,previous)
		if world.creatures.has(current):
			world.creatures[current]["carried_object_id"]=object_id
	status = "READY_BACKUP_STALE" if str(store.status) == "READY_BACKUP_STALE" else "READY"
	last_error = ""
	if backend_requested == "sqlite" and not _write_sqlite_marker():
		world.runtime_state["object_event_marker_warning"] = last_error
	else:
		world.runtime_state.erase("object_event_marker_warning")
	_update_runtime_state()
	if write_journal:
		_journal_accepted(committed)
	return {"ok":true,"event":committed}

func register_object(object_id: String, display_name: String,
		canonical_owner_id: String, home_room_id: String,
		movable: bool, recoverable: bool, ambient_pickup_allowed: bool,
		ambient_hide_allowed: bool, ambient_protected: bool,
		metadata: Dictionary) -> bool:
	var home_anchor:Array=_anchor_or_default(metadata.get("home_anchor",[]),object_id)
	var wall_anchor=metadata.get("display_anchor",metadata.get("home_anchor",[]))
	if str(metadata.get("display_mode",""))=="wall" and typeof(wall_anchor)==TYPE_ARRAY and wall_anchor.size()==3:
		home_anchor=[float(wall_anchor[0]),float(wall_anchor[2])]
	var payload := {
		"object_id":object_id,
		"object_type":"physical_object",
		"object_class":str(metadata.get("object_class","display_object")),
		"display_name":display_name,
		"canonical_owner":canonical_owner_id,
		"home_room_id":home_room_id,
		"home_anchor":home_anchor,
		"current_holder":"",
		"current_location":home_room_id,
		"current_anchor":home_anchor.duplicate(true),
		"state":"PLACED",
		"movable":movable,
		"recoverable":recoverable,
		"ambient_move_allowed":ambient_pickup_allowed,
		"ambient_hide_allowed":ambient_hide_allowed,
		"ambient_protected":ambient_protected,
		"reset_eligible":bool(metadata.get("reset_eligible",movable)),
		"asset_id":str(metadata.get("asset_id","")),
		"last_explicit_location":home_room_id,
		"movement_reason":"REGISTERED",
		"persistence_class":"PERSISTENT_UNTIL_CHANGED",
		"metadata":{
			"description":str(metadata.get("description","")),
			"preview_path":str(metadata.get("preview_path","")),
			"asset_id":str(metadata.get("asset_id","")),
			"viewer_category":str(metadata.get("viewer_category","artifacts")),
			"display_mode":str(metadata.get("display_mode","")),
			"display_anchor":metadata.get("display_anchor",metadata.get("home_anchor",[])),
			"interaction_station_id":str(metadata.get("interaction_station_id","")),
			"interaction_point":metadata.get("interaction_point",[]),
			"interaction_approach_z":float(metadata.get("interaction_approach_z",0.95)),
			"display_world_height":float(metadata.get("display_world_height",0.8))
		},
		"sim_clock":float(world.sim_clock)
	}
	# Optional measured initial support belongs to registration itself,
	# not to a synthetic owner assignment event.
	if metadata.has("home_support_id"):
		payload["home_support_id"]=metadata["home_support_id"]
	var event := _base_event(
		"OBJECT_REGISTERED","EXPLICIT_WORLD_FACT","system","world_model",
		"SYSTEM_RULE",_visibility_for_room(home_room_id),
		"PERSISTENT_UNTIL_CHANGED",canonical_owner_id,object_id,home_room_id,
		"",home_room_id,"WORLD_MODEL_OBJECT_REGISTRATION_V022",
		"Explicit object registration through WorldModel",payload)
	return bool(submit(event).get("ok",false))

func assign_home(object_id: String, target_room_id: String, home_anchor: Vector2,
		move_now: bool = true, source_id: String = "LOCAL_DRAGON", support_id:String="",wall_height:float=-1.0) -> bool:
	var object:Dictionary=world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var target:Dictionary=world.room_by_id(target_room_id)
	if target.is_empty() or not world.room_contains_local(target,home_anchor,0.08):
		return false
	var previous_home:String=str(object.get("home_room_id",""))
	var event:=_base_event(
		"OBJECT_HOME_ASSIGNED","EXPLICIT_WORLD_FACT","dragon",source_id,
		"DRAGON_DECLARED",_visibility_for_room(target_room_id),
		"PERSISTENT_UNTIL_CHANGED",source_id,object_id,target_room_id,
		previous_home,target_room_id,"DRAGON_OBJECT_HOME_ASSIGNMENT_V022",
		"Dragon assigned a new persistent object home",{
			"object_id":object_id,
			"previous_home_room_id":previous_home,
			"previous_home_anchor":object.get("home_anchor",[]),
			"home_room_id":target_room_id,
			"home_anchor":[home_anchor.x,home_anchor.y],
			"home_support_id":support_id,
			"move_now":move_now,
			"sim_clock":float(world.sim_clock)
		})
	if wall_height!=-1.0:
		event["payload"]["wall_height"]=wall_height
	return bool(submit(event).get("ok",false))

func set_ambient_protection(object_id: String, protected: bool) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var room_id: String = str(object.get("current_room_id",
		object.get("home_room_id","")))
	var event := _base_event(
		"OBJECT_POLICY_SET","EXPLICIT_WORLD_FACT","system","world_model",
		"SYSTEM_RULE",_visibility_for_room(room_id),
		"PERSISTENT_UNTIL_CHANGED","",object_id,room_id,"",
		"PROTECTED" if protected else "ELIGIBLE",
		"WORLD_MODEL_OBJECT_POLICY_V020","Explicit object ambient policy change",
		{"object_id":object_id,"ambient_protected":protected,
		 "sim_clock":float(world.sim_clock)})
	return bool(submit(event).get("ok",false))

func _movement_context(actor_id: String) -> Dictionary:
	var ambient: bool = actor_id == "MANJKA" or world.creatures.has(actor_id)
	return {
		"truth_class":"AMBIENT_SIMULATION" if ambient else "EXPLICIT_WORLD_FACT",
		"source_type":"ambient_simulation" if ambient else "system",
		"authority":"AMBIENT" if ambient else "SYSTEM_RULE",
		"reversibility":"AMBIENT_REVERTIBLE" if ambient else "PERSISTENT_UNTIL_CHANGED",
		"provenance":"AMBIENT_OBJECT_RUNTIME_V020" if ambient else "WORLD_MODEL_OBJECT_MOVE_V020"
	}

func pickup(object_id: String, actor_id: String) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var from_room: String = str(object.get("current_room_id",""))
	var context: Dictionary = _movement_context(actor_id)
	var payload := {
		"object_id":object_id,"movement_kind":"PICKED_UP","actor_id":actor_id,
		"previous_holder":str(object.get("current_holder_id","")),
		"previous_location":from_room,
		"previous_anchor":object.get("current_anchor",[]),
		"current_holder":actor_id,"current_location":"","current_anchor":[],"state":"HELD",
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"sim_clock":float(world.sim_clock)
	}
	var event := _base_event(
		"OBJECT_MOVED",str(context["truth_class"]),str(context["source_type"]),
		actor_id,str(context["authority"]),_visibility_for_room(from_room),
		str(context["reversibility"]),actor_id,object_id,from_room,from_room,
		actor_id,str(context["provenance"]),"Object pickup",payload)
	return bool(submit(event).get("ok",false))

func place(object_id: String, actor_id: String, target_room_id: String,
		state: String, target_anchor: Variant = null) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var context: Dictionary = _movement_context(actor_id)
	var anchor:Array=_anchor_or_default(target_anchor,object_id)
	var payload := {
		"object_id":object_id,"movement_kind":state,"actor_id":actor_id,
		"previous_holder":str(object.get("current_holder_id","")),
		"previous_location":str(object.get("current_room_id","")),
		"previous_anchor":object.get("current_anchor",[]),
		"current_holder":"","current_location":target_room_id,
		"current_anchor":anchor,"state":state,
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"sim_clock":float(world.sim_clock)
	}
	var event := _base_event(
		"OBJECT_MOVED",str(context["truth_class"]),str(context["source_type"]),
		actor_id,str(context["authority"]),_visibility_for_room(target_room_id),
		str(context["reversibility"]),actor_id,object_id,target_room_id,
		actor_id,target_room_id,str(context["provenance"]),"Object placement",payload)
	return bool(submit(event).get("ok",false))

func recover_to_lost_found(object_id: String, target_room_id: String) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var previous_holder: String = str(object.get("current_holder_id",""))
	var previous_location: String = str(object.get("current_room_id",""))
	var from_value: String = previous_holder if previous_holder != "" else previous_location
	var anchor:Array=_default_anchor(object_id)
	var payload := {
		"object_id":object_id,"movement_kind":"RECOVERED_TO_LOST_FOUND",
		"actor_id":"HOUSE_SPIRIT","previous_holder":previous_holder,
		"previous_location":previous_location,"previous_anchor":object.get("current_anchor",[]),
		"current_holder":"","current_location":target_room_id,
		"current_anchor":anchor,"state":"LOST_FOUND",
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"sim_clock":float(world.sim_clock)
	}
	var event := _base_event(
		"OBJECT_MOVED","AMBIENT_SIMULATION","system","HOUSE_SPIRIT",
		"SYSTEM_RULE",_visibility_for_room(target_room_id),"AMBIENT_REVERTIBLE",
		"HOUSE_SPIRIT",object_id,target_room_id,from_value,target_room_id,
		"HOUSE_SPIRIT_RECOVERY_RULE_V020","House-spirit lost/found recovery",payload)
	return bool(submit(event).get("ok",false))

func restore_home(object_id: String, reset_day: int = -1) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var home_room_id: String = str(object.get("home_room_id",""))
	var previous_holder: String = str(object.get("current_holder_id",""))
	var previous_location: String = str(object.get("current_room_id",""))
	var from_value: String = previous_holder if previous_holder != "" else previous_location
	var home_anchor:Array=_anchor_or_default(object.get("home_anchor",[]),object_id)
	var payload := {
		"object_id":object_id,"movement_kind":"RESTORED_HOME","actor_id":"",
		"previous_holder":previous_holder,"previous_location":previous_location,
		"previous_anchor":object.get("current_anchor",[]),
		"current_holder":"","current_location":home_room_id,
		"current_anchor":home_anchor,"state":"PLACED",
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"sim_clock":float(world.sim_clock)
	}
	if reset_day>=0:
		payload["reset_day"]=reset_day
	var event := _base_event(
		"OBJECT_MOVED","EXPLICIT_WORLD_FACT","system",
		"object_home_scheduler" if reset_day>=0 else "world_model",
		"SYSTEM_RULE",_visibility_for_room(home_room_id),
		"PERSISTENT_UNTIL_CHANGED","",object_id,home_room_id,from_value,
		home_room_id,
		"DAILY_OBJECT_HOME_RESET_V022" if reset_day>=0 else "EXPLICIT_OBJECT_RESTORE_API_V022",
		"Daily home reset" if reset_day>=0 else "Explicit restore to canonical home",payload)
	return bool(submit(event).get("ok",false))

func record_view(object_id:String,actor_id:String,context:String)->bool:
	var obj:Dictionary=world.physical_object(object_id)
	if obj.is_empty():return false
	var room_id:String=str(obj.get("current_room_id",""))
	var actor:Dictionary=world.residents.get(actor_id,{})
	var marker:Dictionary=actor.get("solo_habit_commitment",{})
	var completion_id:String=EventGate.view_completion_id(actor,object_id)
	if completion_id=="":return false
	var event:=_base_event("OBJECT_INTERACTED","AMBIENT_SIMULATION","system","world_model","SYSTEM_RULE",
		_visibility_for_room(room_id),"AMBIENT_REVERTIBLE",actor_id,object_id,room_id,room_id,room_id,
		"OBJECT_VIEW_COMPLETED_V024","Resident completed an object view",
		{"object_id":object_id,"actor_id":actor_id,"sim_clock":float(world.sim_clock),"view_completion_id":completion_id,"station_id":str(marker.get("station_id","")),"started_at":float(marker.get("started_at",-1)),"ends_at":float(marker.get("ends_at",-1)),"context":context})
	event["event_id"]=completion_id
	return bool(submit(event).get("ok",false))

func housekeeping_return(object_id:String,target:Dictionary)->bool:
	var obj:Dictionary=world.physical_object(object_id)
	if obj.is_empty():return false
	var room_id:String=str(target.get("room_id",""))
	var previous:String=str(obj.get("current_room_id",""))
	var cup:Dictionary=world.runtime_state.get("beverages",{}).get("cups",{}).get(object_id,{})
	var payload:Dictionary={"object_id":object_id,"movement_kind":"HOUSEKEEPING_RETURNED","actor_id":"HOUSE_SPIRIT",
		"previous_holder":str(obj.get("current_holder_id","")),"previous_location":previous,
		"current_holder":"","current_location":room_id,"current_anchor":target.get("anchor",[]),
		"current_support_id":str(target.get("support_id","")),"state":"PLACED","canonical_owner":str(obj.get("canonical_owner_id","")),
		"cleaned_serving_id":str(cup.get("choice_instance_id","")),"cleaned_serving_pickup":str(cup.get("serving_pickup_event_id","")),"sim_clock":float(world.sim_clock)}
	var event:=_base_event("OBJECT_MOVED","AMBIENT_SIMULATION","system","HOUSE_SPIRIT","SYSTEM_RULE",
		_visibility_for_room(room_id),"AMBIENT_REVERTIBLE","HOUSE_SPIRIT",object_id,room_id,previous,room_id,
		"ROLLING_HOUSEKEEPING_V023","Rolling inactivity return",payload)
	return bool(submit(event).get("ok",false))

func storage_paths() -> Array:
	var base: String = store.storage_path()
	if base == "":
		base = str(world.save_path)+".world_events_v1.json" if world != null else ""
	var paths: Array = [base,base+".bak",base+".tmp",base+".corrupt"]
	if backend_requested == "sqlite" and world != null:
		paths.append(_sqlite_marker_path())
		paths.append(_sqlite_marker_path()+".tmp")
	return paths
