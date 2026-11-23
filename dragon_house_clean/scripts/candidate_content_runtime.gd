extends RefCounted
## Explicit Integrator-only application of candidate content.
## Reading this file or having candidate assets present MUST NOT activate anything.
const DEFAULT_CONTRACT_PATH := "res://data/integration_candidates/TEEA_INT_20261123_007_runtime_contract.json"
const GUEST_MAP_KEY := "teea007_candidate_guest_room_map"
const GUEST_SOURCE_KEY := "teea007_candidate_guest_source"
const ALLOWED_MEDIA_CATEGORIES := ["books","films","tracks","artifacts"]

var contract: Dictionary = {}
var source_path: String = DEFAULT_CONTRACT_PATH
var last_error := ""

func initialize(path: String = DEFAULT_CONTRACT_PATH) -> bool:
	source_path = path
	contract = {}
	last_error = ""
	if not FileAccess.file_exists(source_path):
		last_error = "Candidate contract is missing: " + source_path
		return false
	var file := FileAccess.open(source_path,FileAccess.READ)
	if file == null:
		last_error = "Candidate contract is unreadable"
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Candidate contract is malformed JSON"
		return false
	var data: Dictionary = parsed
	if int(data.get("schema",0)) != 1 or 			str(data.get("status","")) != "INTEGRATOR_CANDIDATE_ONLY":
		last_error = "Candidate contract schema/status mismatch"
		return false
	if bool(data.get("approved",true)) or bool(data.get("owner_approved",true)):
		last_error = "Candidate contract must not claim approval"
		return false
	if typeof(data.get("guest_rooms",null)) != TYPE_ARRAY or 			typeof(data.get("media_surfaces",null)) != TYPE_ARRAY:
		last_error = "Candidate contract missing guest/media arrays"
		return false
	contract = data
	return true

func _fail(message: String) -> Dictionary:
	last_error = message
	return {"ok":false,"error":message}

func _mapping(world) -> Dictionary:
	var raw = world.runtime_state.get(GUEST_MAP_KEY,{})
	return raw.duplicate(true) if typeof(raw) == TYPE_DICTIONARY else {}

func guest_preflight(world) -> Dictionary:
	last_error = ""
	if contract.is_empty():
		return _fail("Candidate runtime is not initialized")
	var specs: Array = contract.get("guest_rooms",[])
	if specs.size() != 3:
		return _fail("TEEA007 guest contract must contain exactly three rooms")
	var mapping: Dictionary = _mapping(world)
	var seen_rooms: Dictionary = {}
	var seen_actors: Dictionary = {}
	var seen_cells: Dictionary = {}
	var plans: Array = []
	for raw in specs:
		if typeof(raw) != TYPE_DICTIONARY:
			return _fail("Guest contract contains non-dictionary entry")
		var spec: Dictionary = raw
		var proposed_id := str(spec.get("room_id",""))
		var actor_id := str(spec.get("actor_id",""))
		var display_name := str(spec.get("display_name",""))
		var cell = spec.get("cell",[])
		if proposed_id == "" or actor_id == "" or display_name == "" or 				typeof(cell) != TYPE_ARRAY or cell.size() != 2:
			return _fail("Guest contract has incomplete identity/cell data")
		if seen_rooms.has(proposed_id) or seen_actors.has(actor_id):
			return _fail("Guest contract duplicates room or actor identity")
		seen_rooms[proposed_id] = true
		seen_actors[actor_id] = true
		var x := int(cell[0])
		var level := int(cell[1])
		var cell_key := "%d:%d" % [x,level]
		if seen_cells.has(cell_key):
			return _fail("Guest contract duplicates a build cell")
		seen_cells[cell_key] = true
		var left: Dictionary = world.get_room(x-1,level)
		var right: Dictionary = world.get_room(x+1,level)
		if str(left.get("type","")) != "lift" and str(right.get("type","")) != "lift":
			return _fail("Guest candidate cell is not adjacent to the lift: "+cell_key)
		var existing: Dictionary = world.get_room(x,level)
		var mapped_id := str(mapping.get(proposed_id,""))
		if existing.is_empty():
			if mapped_id != "":
				return _fail("Guest mapping points to a missing room: "+proposed_id)
			if world.residents.has(actor_id):
				return _fail("Guest actor already exists without its mapped room: "+actor_id)
			if not world.can_build(x,level,"guest"):
				return _fail("Guest candidate cell cannot be built: "+cell_key)
		else:
			if mapped_id == "" or str(existing.get("id","")) != mapped_id or 					str(existing.get("type","")) != "guest":
				return _fail("Occupied guest cell is not the recorded candidate mapping: "+cell_key)
			var actor: Dictionary = world.residents.get(actor_id,{})
			if actor.is_empty() or str(actor.get("entity_type","")) != "guest" or 					str(actor.get("room_id","")) != mapped_id:
				return _fail("Mapped candidate guest actor/room state is inconsistent: "+actor_id)
		plans.append({
			"spec":spec.duplicate(true),
			"x":x,"level":level,
			"existing_room_id":str(existing.get("id",""))
		})
	return {"ok":true,"plans":plans,"mapping":mapping}

func _restore_snapshot(world, snapshot: Dictionary) -> void:
	world.rooms = snapshot["rooms"]
	world.residents = snapshot["residents"]
	world.journal = snapshot["journal"]
	world.runtime_state = snapshot["runtime_state"]
	world.next_room_id = int(snapshot["next_room_id"])

func apply_guest_candidate(world) -> Dictionary:
	var preflight := guest_preflight(world)
	if not bool(preflight.get("ok",false)):
		return preflight
	var snapshot := {
		"rooms":world.rooms.duplicate(true),
		"residents":world.residents.duplicate(true),
		"journal":world.journal.duplicate(true),
		"runtime_state":world.runtime_state.duplicate(true),
		"next_room_id":world.next_room_id
	}
	var mapping: Dictionary = preflight["mapping"].duplicate(true)
	for plan in preflight["plans"]:
		var spec: Dictionary = plan["spec"]
		var proposed_id := str(spec["room_id"])
		var actor_id := str(spec["actor_id"])
		var display_name := str(spec["display_name"])
		var room: Dictionary = {}
		if str(plan.get("existing_room_id","")) != "":
			room = world.room_by_id(str(plan["existing_room_id"]))
		else:
			room = world.make_room(int(plan["x"]),int(plan["level"]),"guest")
			if room.is_empty():
				_restore_snapshot(world,snapshot)
				return _fail("Failed to create guest candidate room: "+proposed_id)
			mapping[proposed_id] = str(room["id"])
		room["candidate_source"] = "TEEA_INT_20261123_007"
		room["candidate_room_id"] = proposed_id
		room["candidate_owner_approved"] = false
		if not world.residents.has(actor_id):
			if not world.register_guest_actor(
					actor_id,display_name,str(room["id"]),"",actor_id):
				_restore_snapshot(world,snapshot)
				return _fail("Failed to register guest candidate actor: "+actor_id)
		else:
			if not world.configure_guest_room(
					str(room["id"]),actor_id,"Гостевая · "+display_name):
				_restore_snapshot(world,snapshot)
				return _fail("Failed to configure guest candidate room: "+proposed_id)
		room["guest_access_state"] = str(spec.get("access_state","open"))
	world.runtime_state[GUEST_MAP_KEY] = mapping
	world.runtime_state[GUEST_SOURCE_KEY] = {
		"batch_id":"TEEA_INT_20261123_007",
		"owner_approved":false,
		"approved":false,
		"source_sha256":contract.get("source_sha256",{}).duplicate(true)
	}
	if not world.save_world():
		_restore_snapshot(world,snapshot)
		return _fail("Guest candidate state could not be persisted")
	return {"ok":true,"mapping":mapping.duplicate(true),"guest_count":mapping.size()}

func guest_room_mapping(world) -> Dictionary:
	return _mapping(world)

func bound_media_specs(bindings: Dictionary) -> Array:
	# No binding map means no hotspots. Asset availability is never a content decision.
	var out: Array = []
	if contract.is_empty():
		return out
	for raw in contract.get("media_surfaces",[]):
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var surface: Dictionary = raw
		var surface_id := str(surface.get("surface_id",""))
		var category := str(surface.get("category",""))
		if surface_id == "" or not ALLOWED_MEDIA_CATEGORIES.has(category):
			continue
		var raw_binding = bindings.get(surface_id,{})
		if typeof(raw_binding) != TYPE_DICTIONARY:
			continue
		var binding: Dictionary = raw_binding
		var item_id := str(binding.get("item_id",""))
		var display_name := str(binding.get("display_name",""))
		if item_id == "" or display_name == "":
			continue
		var merged := surface.duplicate(true)
		merged["item_id"] = item_id
		merged["display_name"] = display_name
		out.append(merged)
	return out

func unbound_media_surface_ids(bindings: Dictionary) -> Array:
	var bound: Dictionary = {}
	for item in bound_media_specs(bindings):
		bound[str(item.get("surface_id",""))] = true
	var out: Array = []
	for surface in contract.get("media_surfaces",[]):
		var id := str(surface.get("surface_id",""))
		if id != "" and not bound.has(id):
			out.append(id)
	return out

func common_r2_candidate() -> Dictionary:
	var common = contract.get("common_r2",{})
	return common.duplicate(true) if typeof(common) == TYPE_DICTIONARY else {}
