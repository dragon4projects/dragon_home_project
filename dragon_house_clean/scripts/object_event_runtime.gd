extends RefCounted
const EventStore = preload("res://scripts/world_event_store.gd")
const EventGate = preload("res://scripts/world_event_gate.gd")
const ObjectReducer = preload("res://scripts/object_event_reducer.gd")

## Strangler facade: keeps current WorldModel object APIs stable while moving
## their durable truth path to gate -> append-only event -> reducer projection.

var world
var store = EventStore.new()
var gate = EventGate.new()
var reducer = ObjectReducer.new()
var ready: bool = false
var status: String = "UNINITIALIZED"
var last_error: String = ""
var event_nonce: int = 0

func setup(p_world) -> bool:
	world = p_world
	ready = false
	status = "INITIALIZING"
	last_error = ""
	if not store.setup(str(world.save_path)):
		status = store.status
		last_error = store.last_error
		_update_runtime_state()
		return false
	event_nonce = store.last_sequence()
	if not store.events.is_empty():
		var projection: Dictionary = reducer.replay(store.snapshot_events())
		if projection.is_empty():
			status = "REDUCER_REPLAY_FAILED"
			last_error = reducer.last_error
			_update_runtime_state()
			return false
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
	ready = true
	_update_runtime_state()
	return true

func _update_runtime_state() -> void:
	if world == null:
		return
	world.runtime_state["object_event_revision"] = store.last_sequence()
	world.runtime_state["object_event_status"] = status
	world.runtime_state["object_event_backend"] = "json_append_compat_v1"
	world.runtime_state["object_event_store_path"] = store.storage_path()
	if last_error != "":
		world.runtime_state["object_event_last_error"] = last_error
	else:
		world.runtime_state.erase("object_event_last_error")

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

func _make_event_id() -> String:
	event_nonce += 1
	return "object-v1-%d-%d-%d" % [
		int(Time.get_unix_time_from_system()*1000000.0),
		Time.get_ticks_usec(),event_nonce]

func _visibility_for_room(room_id: String) -> String:
	var room: Dictionary = world.room_by_id(room_id)
	if room.is_empty():
		return "house_public"
	return "house_public" if str(room.get("privacy","public")) == "public" else 		"owner_controlled"

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
	var metadata := {
		"description":str(object.get("description","")),
		"preview_path":str(object.get("preview_path","")),
		"asset_id":str(object.get("asset_id","")),
		"viewer_category":str(object.get("viewer_category","artifacts")),
		"legacy_history":(object.get("history",[]) as Array).duplicate(true)
	}
	var payload := {
		"object_id":object_id,
		"object_type":"physical_object",
		"display_name":str(object.get("display_name",object_id)),
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"home_room_id":home_room_id,
		"current_holder":current_holder,
		"current_location":current_location,
		"state":state,
		"movable":bool(object.get("movable",true)),
		"recoverable":bool(object.get("recoverable",true)),
		"ambient_move_allowed":bool(object.get("ambient_pickup_allowed",false)),
		"ambient_hide_allowed":bool(object.get("ambient_hide_allowed",false)),
		"ambient_protected":bool(object.get("ambient_protected",false)),
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
	var committed: Array = store.append_many(migration_events)
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
		"provenance":str(event.get("provenance",""))
	}
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
	elif event_type == "OBJECT_MOVED":
		var movement_kind: String = str(payload.get("movement_kind","MOVED"))
		world._append_journal("OBJECT_"+movement_kind,
			str(payload.get("actor_id",event.get("subject_id",""))),object_id,
			str(event.get("from","")),str(event.get("to","")),details)
	elif event_type == "OBJECT_OWNER_CHANGED":
		world._append_journal("OBJECT_OWNER_CHANGED",
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
	# Replay is authoritative for object state. Journal is an explanation view:
	# fill only missing accepted object events and never surface migration rows as
	# if they were fresh household activity.
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
	var committed: Dictionary = store.append(event)
	if committed.is_empty():
		last_error = store.last_error
		status = store.status
		_update_runtime_state()
		return {"ok":false,"error":last_error}
	_publish_projection(candidate)
	status = "READY"
	last_error = ""
	_update_runtime_state()
	if write_journal:
		_journal_accepted(committed)
	return {"ok":true,"event":committed}

func register_object(object_id: String, display_name: String,
		canonical_owner_id: String, home_room_id: String,
		movable: bool, recoverable: bool, ambient_pickup_allowed: bool,
		ambient_hide_allowed: bool, ambient_protected: bool,
		metadata: Dictionary) -> bool:
	var payload := {
		"object_id":object_id,
		"object_type":"physical_object",
		"display_name":display_name,
		"canonical_owner":canonical_owner_id,
		"home_room_id":home_room_id,
		"current_holder":"",
		"current_location":home_room_id,
		"state":"PLACED",
		"movable":movable,
		"recoverable":recoverable,
		"ambient_move_allowed":ambient_pickup_allowed,
		"ambient_hide_allowed":ambient_hide_allowed,
		"ambient_protected":ambient_protected,
		"asset_id":str(metadata.get("asset_id","")),
		"last_explicit_location":home_room_id,
		"movement_reason":"REGISTERED",
		"persistence_class":"PERSISTENT_UNTIL_CHANGED",
		"metadata":{
			"description":str(metadata.get("description","")),
			"preview_path":str(metadata.get("preview_path","")),
			"asset_id":str(metadata.get("asset_id","")),
			"viewer_category":str(metadata.get("viewer_category","artifacts"))
		},
		"sim_clock":float(world.sim_clock)
	}
	var event := _base_event(
		"OBJECT_REGISTERED","EXPLICIT_WORLD_FACT","system","world_model",
		"SYSTEM_RULE",_visibility_for_room(home_room_id),
		"PERSISTENT_UNTIL_CHANGED",canonical_owner_id,object_id,home_room_id,
		"",home_room_id,"WORLD_MODEL_OBJECT_REGISTRATION_V020",
		"Explicit object registration through WorldModel",payload)
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
		"current_holder":actor_id,"current_location":"","state":"HELD",
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
		state: String) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var context: Dictionary = _movement_context(actor_id)
	var payload := {
		"object_id":object_id,"movement_kind":state,"actor_id":actor_id,
		"previous_holder":str(object.get("current_holder_id","")),
		"previous_location":str(object.get("current_room_id","")),
		"current_holder":"","current_location":target_room_id,"state":state,
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
	var payload := {
		"object_id":object_id,"movement_kind":"RECOVERED_TO_LOST_FOUND",
		"actor_id":"HOUSE_SPIRIT","previous_holder":previous_holder,
		"previous_location":previous_location,"current_holder":"",
		"current_location":target_room_id,"state":"LOST_FOUND",
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"sim_clock":float(world.sim_clock)
	}
	var event := _base_event(
		"OBJECT_MOVED","AMBIENT_SIMULATION","system","HOUSE_SPIRIT",
		"SYSTEM_RULE",_visibility_for_room(target_room_id),"AMBIENT_REVERTIBLE",
		"HOUSE_SPIRIT",object_id,target_room_id,from_value,target_room_id,
		"HOUSE_SPIRIT_RECOVERY_RULE_V020","House-spirit lost/found recovery",payload)
	return bool(submit(event).get("ok",false))

func restore_home(object_id: String) -> bool:
	var object: Dictionary = world.objects.get(object_id,{})
	if object.is_empty():
		return false
	var home_room_id: String = str(object.get("home_room_id",""))
	var previous_holder: String = str(object.get("current_holder_id",""))
	var previous_location: String = str(object.get("current_room_id",""))
	var from_value: String = previous_holder if previous_holder != "" else previous_location
	var payload := {
		"object_id":object_id,"movement_kind":"RESTORED_HOME","actor_id":"",
		"previous_holder":previous_holder,"previous_location":previous_location,
		"current_holder":"","current_location":home_room_id,"state":"PLACED",
		"canonical_owner":str(object.get("canonical_owner_id","")),
		"sim_clock":float(world.sim_clock)
	}
	var event := _base_event(
		"OBJECT_MOVED","EXPLICIT_WORLD_FACT","system","world_model",
		"SYSTEM_RULE",_visibility_for_room(home_room_id),
		"PERSISTENT_UNTIL_CHANGED","",object_id,home_room_id,from_value,
		home_room_id,"EXPLICIT_OBJECT_RESTORE_API_V020",
		"Explicit restore to canonical home",payload)
	return bool(submit(event).get("ok",false))

func storage_paths() -> Array:
	var base: String = store.storage_path()
	if base == "":
		base = str(world.save_path)+".world_events_v1.json" if world != null else ""
	return [base,base+".bak",base+".tmp",base+".corrupt"]
