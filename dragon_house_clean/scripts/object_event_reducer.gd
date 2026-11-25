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

func _legacy_anchor(object_id: String) -> Array:
	var code:int=0
	for i in range(object_id.length()):
		code=(code*33+object_id.unicode_at(i)) & 0x7fffffff
	return [(float(code%7)-3.0)*0.16,0.72+(float(int(code/7)%5)-2.0)*0.12]

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
		var display_anchor:Array=metadata.get("display_anchor",metadata.get("home_anchor",[]))
		var home_anchor:Array=payload.get("home_anchor",_legacy_anchor(object_id))
		if str(metadata.get("display_mode",""))=="wall" and display_anchor.size()==3:
			home_anchor=[float(display_anchor[0]),float(display_anchor[2])]
		var current_anchor:Array=payload.get("current_anchor",[] if str(payload.get("current_holder",""))!="" else home_anchor)
		if str(metadata.get("display_mode",""))=="wall" and display_anchor.size()==3:
			current_anchor=home_anchor.duplicate(true)
		next[object_id] = {
			"id":object_id,
			"display_name":str(payload.get("display_name",object_id)),
			"canonical_owner_id":str(payload.get("canonical_owner","")),
			"object_class":str(payload.get("object_class","display_object")),
			"home_room_id":home_room_id,
			"home_anchor":home_anchor.duplicate(true),
			"current_holder_id":str(payload.get("current_holder","")),
			"current_room_id":current_location,
			"current_anchor":current_anchor.duplicate(true),
			"state":str(payload.get("state","PLACED")),
			"movable":bool(payload.get("movable",true)),
			"recoverable":bool(payload.get("recoverable",true)),
			"ambient_pickup_allowed":bool(payload.get("ambient_move_allowed",false)),
			"ambient_hide_allowed":bool(payload.get("ambient_hide_allowed",false)),
			"ambient_protected":bool(payload.get("ambient_protected",false)),
			"reset_eligible":bool(payload.get("reset_eligible",payload.get("movable",true))),
			"description":str(metadata.get("description","")),
			"preview_path":str(metadata.get("preview_path","")),
			"full_image_path":str(metadata.get("full_image_path","")),
			"artifact_source_status":str(metadata.get("artifact_source_status","")),
			"asset_id":str(payload.get("asset_id",metadata.get("asset_id",""))),
			"viewer_category":str(metadata.get("viewer_category","artifacts")),
			"display_mode":str(metadata.get("display_mode","")),
			"display_anchor":display_anchor.duplicate(true),
			"interaction_station_id":str(metadata.get("interaction_station_id","")),
			"interaction_point":metadata.get("interaction_point",[]),
			"interaction_approach_z":float(metadata.get("interaction_approach_z",0.95)),
			"display_world_height":float(metadata.get("display_world_height",0.8)),
			"history":history,
			"last_explicit_location":str(payload.get("last_explicit_location",
				current_location)),
			"movement_reason":str(payload.get("movement_reason","REGISTERED")),
			"movement_authority":authority,
			"visibility":str(event.get("visibility","house_public")),
			"persistence_class":str(payload.get("persistence_class",
				"PERSISTENT_UNTIL_CHANGED")),
			"last_interaction_at":float(payload.get("sim_clock",0.0)),
			"updated_event_id":event_id
		}
		var initial_support:String=str(payload.get("home_support_id",""))
		if initial_support!="":
			next[object_id]["home_support_id"]=initial_support
			next[object_id]["current_support_id"]=initial_support
		return next

	var object_id: String = str(payload.get("object_id",""))
	if object_id == "" or not next.has(object_id):
		return _fail("unknown object")
	var object: Dictionary = next[object_id]

	if event_type == "OBJECT_POLICY_SET":
		for field in ["ambient_pickup_allowed","ambient_hide_allowed","ambient_protected","reset_eligible"]:
			if payload.has(field):
				object[field] = bool(payload[field])
		object["updated_event_id"] = event_id
		object["movement_authority"] = authority
		return next

	if event_type == "OBJECT_HOME_ASSIGNED":
		var old_home:String=str(object.get("home_room_id",""))
		var new_home:String=str(payload.get("home_room_id",""))
		var new_anchor:Array=payload.get("home_anchor",object.get("home_anchor",[0.0,0.72]))
		object["home_room_id"]=new_home
		object["home_anchor"]=new_anchor.duplicate(true)
		var support_id:String=str(payload.get("home_support_id",""))
		if support_id!="":
			object["home_support_id"]=support_id
		else:
			object.erase("home_support_id")
		object["movement_reason"]="HOME_ASSIGNED"
		object["movement_authority"]=authority
		object["updated_event_id"]=event_id
		if bool(payload.get("move_now",true)):
			object["current_holder_id"]=""
			object["current_room_id"]=new_home
			object["current_anchor"]=new_anchor.duplicate(true)
			if support_id!="":
				object["current_support_id"]=support_id
			else:
				object.erase("current_support_id")
			object["state"]="PLACED"
			object["last_explicit_location"]=new_home
			object["visibility"]=str(event.get("visibility","house_public"))
			if str(object.get("display_mode",""))=="wall":
				var old_display:Array=object.get("display_anchor",[])
				if old_display.size()==3:
					object["display_anchor"]=[new_anchor[0],float(payload.get("wall_height",old_display[1])),new_anchor[1]]
					object["interaction_point"]=[new_anchor[0],float(new_anchor[1])+0.30]
					object["interaction_station_id"]="WALL_DISPLAY_"+object_id
		_append_history(object,_history_entry(event,"HOME_ASSIGNED",
			str(event.get("subject_id",""))))
		object["last_interaction_at"]=float(payload.get("sim_clock",0.0))
		object["previous_home_room_id"]=old_home
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
		var raw_anchor=payload.get("current_anchor",[] if str(payload.get("current_holder",""))!="" else object.get("home_anchor",_legacy_anchor(object_id)))
		object["current_anchor"]=(raw_anchor as Array).duplicate(true) if typeof(raw_anchor)==TYPE_ARRAY else []
		# A normal placement is not proof of shelf placement merely because
		# its X/Z matches the home (several tiers can share those coordinates).
		if movement_kind=="RESTORED_HOME" and str(object.get("home_support_id",""))!="":
			object["current_support_id"]=str(object["home_support_id"])
		elif movement_kind=="HOUSEKEEPING_RETURNED" and str(payload.get("current_support_id",""))!="":
			object["current_support_id"]=str(payload["current_support_id"])
		else:
			object.erase("current_support_id")
		if movement_kind=="HOUSEKEEPING_RETURNED":
			object["housekeeping_cleaned_serving"]=str(payload.get("cleaned_serving_id",""))
			object["housekeeping_event_id"]=event_id
		object["last_interaction_at"]=float(payload.get("sim_clock",0.0))
		object["state"] = str(payload.get("state",""))
		object["movement_reason"] = movement_kind
		object["movement_authority"] = authority
		object["visibility"] = str(event.get("visibility",
			object.get("visibility","house_public")))
		object["updated_event_id"] = event_id
		if payload.has("reset_day"):
			object["last_home_reset_day"]=int(payload.get("reset_day",-1))
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
