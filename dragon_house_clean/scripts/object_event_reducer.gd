extends RefCounted
## Pure object projection reducer. Accepted events are the only input.
## Renderer/journal state is deliberately outside this reducer.

var last_error: String = ""

func _fail(reason: String) -> Dictionary:
	last_error = reason
	return {}

func _history_entry(event: Dictionary, movement_kind: String,
		actor_id: String) -> Dictionary:
	return {
		"event":movement_kind,
		"actor_id":actor_id,
		"from":str(event.get("from","")),
		"to":str(event.get("to","")),
		"sim_clock":float((event.get("payload",{}) as Dictionary).get("sim_clock",0.0)),
		"event_id":str(event.get("event_id","")),
		"truth_class":str(event.get("truth_class","")),
		"authority":str(event.get("authority",""))
	}

func _append_history(object: Dictionary, entry: Dictionary) -> void:
	var history: Array = object.get("history",[])
	history.append(entry)
	while history.size() > 64:
		history.pop_front()
	object["history"] = history

func reduce(projection: Dictionary, event: Dictionary) -> Dictionary:
	last_error = ""
	var next: Dictionary = projection.duplicate(true)
	var event_type: String = str(event.get("event_type",""))
	var payload: Dictionary = event.get("payload",{})
	var event_id: String = str(event.get("event_id",""))
	var authority: String = str(event.get("authority",""))

	if event_type == "OBJECT_REGISTERED":
		var object_id: String = str(payload.get("object_id",""))
		if object_id == "" or next.has(object_id):
			return _fail("duplicate/invalid object registration")
		var metadata: Dictionary = payload.get("metadata",{})
		var home_room_id: String = str(payload.get("home_room_id",
			payload.get("current_location","")))
		var current_location: String = str(payload.get("current_location",home_room_id))
		var legacy_history: Array = metadata.get("legacy_history",[])
		var history: Array = legacy_history.duplicate(true)
		if history.is_empty():
			history.append(_history_entry(event,"REGISTERED",""))
		next[object_id] = {
			"id":object_id,
			"display_name":str(payload.get("display_name",object_id)),
			"canonical_owner_id":str(payload.get("canonical_owner","")),
			"home_room_id":home_room_id,
			"current_holder_id":str(payload.get("current_holder","")),
			"current_room_id":current_location,
			"state":str(payload.get("state","PLACED")),
			"movable":bool(payload.get("movable",true)),
			"recoverable":bool(payload.get("recoverable",true)),
			"ambient_pickup_allowed":bool(payload.get("ambient_move_allowed",false)),
			"ambient_hide_allowed":bool(payload.get("ambient_hide_allowed",false)),
			"ambient_protected":bool(payload.get("ambient_protected",false)),
			"description":str(metadata.get("description","")),
			"preview_path":str(metadata.get("preview_path","")),
			"asset_id":str(payload.get("asset_id",metadata.get("asset_id",""))),
			"viewer_category":str(metadata.get("viewer_category","artifacts")),
			"history":history,
			"last_explicit_location":str(payload.get("last_explicit_location",
				current_location)),
			"movement_reason":str(payload.get("movement_reason","REGISTERED")),
			"movement_authority":authority,
			"visibility":str(event.get("visibility","house_public")),
			"persistence_class":str(payload.get("persistence_class",
				"PERSISTENT_UNTIL_CHANGED")),
			"updated_event_id":event_id
		}
		return next

	var object_id: String = str(payload.get("object_id",""))
	if object_id == "" or not next.has(object_id):
		return _fail("unknown object")
	var object: Dictionary = next[object_id]

	if event_type == "OBJECT_POLICY_SET":
		for field in ["ambient_pickup_allowed","ambient_hide_allowed","ambient_protected"]:
			if payload.has(field):
				object[field] = bool(payload[field])
		object["updated_event_id"] = event_id
		object["movement_authority"] = authority
		return next

	if event_type == "OBJECT_OWNER_CHANGED":
		object["canonical_owner_id"] = str(payload.get("canonical_owner",""))
		object["updated_event_id"] = event_id
		object["movement_authority"] = authority
		return next

	if event_type == "OBJECT_MOVED":
		var movement_kind: String = str(payload.get("movement_kind",""))
		var actor_id: String = str(payload.get("actor_id",event.get("subject_id","")))
		object["current_holder_id"] = str(payload.get("current_holder",""))
		object["current_room_id"] = str(payload.get("current_location",""))
		object["state"] = str(payload.get("state",""))
		object["movement_reason"] = movement_kind
		object["movement_authority"] = authority
		object["visibility"] = str(event.get("visibility",
			object.get("visibility","house_public")))
		object["updated_event_id"] = event_id
		if str(event.get("truth_class","")) == "EXPLICIT_WORLD_FACT":
			var explicit_location: String = str(payload.get("current_location",""))
			if explicit_location == "":
				explicit_location = str(payload.get("previous_location",
					object.get("last_explicit_location","")))
			if explicit_location != "":
				object["last_explicit_location"] = explicit_location
		_append_history(object,_history_entry(event,movement_kind,actor_id))
		return next

	return _fail("unsupported event type: "+event_type)

func replay(events: Array) -> Dictionary:
	last_error = ""
	var projection: Dictionary = {}
	for raw_event in events:
		if typeof(raw_event) != TYPE_DICTIONARY:
			return _fail("event stream contains non-object row")
		var next: Dictionary = reduce(projection,raw_event)
		if next.is_empty() and not projection.is_empty():
			return {}
		if next.is_empty() and str((raw_event as Dictionary).get("event_type","")) != "":
			# Empty projection can only be valid before any registration; a
			# successfully reduced registration always makes it non-empty.
			return _fail(last_error if last_error != "" else "replay produced empty projection")
		projection = next
	return projection
