extends RefCounted
## One authoritative local simulation state. No chat/LLM interfaces.
const SAVE_PATH := "user://dragon_house_world_v01.json"
const ObjectEventRuntime = preload("res://scripts/object_event_runtime.gd")
const RoomSpaceV2 = preload("res://scripts/room_space_v2.gd")
const CanonicalHouseSeed = preload("res://scripts/canonical_house_seed.gd")
var canonical_house_seed := false
var room_space = RoomSpaceV2.new()
var save_path: String = SAVE_PATH
var sim_clock: float = 0.0
const MODULE_W := RoomSpaceV2.MODULE_W
const FLOOR_H := RoomSpaceV2.FLOOR_H
const GAME_DAY_SECONDS := 86400.0
const RETURN_PREPARE_SECONDS := 82800.0
var housekeeping_navigation=null
var next_housekeeping_check:float=0.0
const ROOM_TYPES := ["arrival", "corridor", "common", "study", "rest", "library", "cinema", "music", "workshop", "private", "guest", "lift", "artifact", "kitchen"]
const MERGEABLE_TYPES := ["common", "study", "rest", "library", "cinema", "music", "workshop", "artifact"]
const MAX_MERGE := 3
const SHARED_TYPES := ["arrival", "corridor", "common", "study", "rest", "library", "cinema", "music", "workshop", "lift", "artifact", "kitchen"]
const INITIAL_SEED_CELLS := {
	"-5:0":"arrival","-4:0":"corridor","-3:0":"study",
	"-2:0":"common","-1:0":"common","0:0":"common",
	"1:0":"rest","2:0":"library","3:0":"music","4:0":"cinema","5:0":"lift",
	"5:1":"lift","4:1":"corridor","3:1":"private","2:1":"private","1:1":"rest",
	"5:-1":"lift","4:-1":"corridor","3:-1":"private","2:-1":"private","1:-1":"artifact"
}

var rooms: Array = []
var residents: Dictionary = {}
# Non-humanoid ambient actors are persisted separately from resident/guest life.
var creatures: Dictionary = {}
# Bounded causal House journal. This is world evidence, not UI presentation text.
var journal: Array = []
# Runtime compatibility state for scheduler/event strangler. Presentation never owns this.
var runtime_state: Dictionary = {}
var media: Dictionary = {"books": [], "films": [], "tracks": []}
# Persistent physical-object identities. Registration is explicit; seed_world does not
# invent owner artifacts merely because the lifecycle exists.
var objects: Dictionary = {}
var object_events = ObjectEventRuntime.new()
var object_events_initialized := false
var object_events_save_path := ""
var next_room_id := 1
# Startup recovery is deliberately separate from ordinary simulation state.
# An unreadable established world is never interpreted as a first launch.
var recovery_blocked:bool=false
var load_status:String="NOT_LOADED"
var load_error:String=""
# Engineering checkpoint cadence, measured on the authoritative simulation
# clock, not wall time. A failed write freezes life instead of accumulating
# unbounded unsaved state. This watermark describes the last valid snapshot,
# not the (independently durable) object-event stream.
const CHECKPOINT_INTERVAL_SECONDS:=20.0
var last_checkpoint_clock:float=-1.0
# Cache only the digest of exact bytes that passed full snapshot validation.
# A changed primary always takes the full validation path before rotation.
var _verified_primary_path:String=""
var _verified_primary_sha:String=""
var _last_validated_snapshot_sha:String=""
var _snapshot_full_validation_count:int=0
var _snapshot_digest_hits:int=0

# Each simulation domain owns a separate random stream. The world keeps
# the live generators so every checkpoint (including explicit saves) captures
# the exact state, without depending on an end-of-frame copy.
const RNG_STREAM_SEEDS:Dictionary={"life":814223,"creatures":923118,"beverages":10520261125}
var _rng_streams:Dictionary={}

static func _valid_rng_state(value:Variant)->bool:
	# JSON numbers cannot exactly encode arbitrary signed 64-bit PCG states.
	return typeof(value)==TYPE_STRING and str(value).is_valid_int() and str(int(value))==str(value)

func decision_rng(domain:String)->RandomNumberGenerator:
	assert(RNG_STREAM_SEEDS.has(domain))
	if _rng_streams.has(domain):return _rng_streams[domain]
	var generator:=RandomNumberGenerator.new()
	generator.seed=int(RNG_STREAM_SEEDS[domain])
	var saved=runtime_state.get("decision_rng_v1",{}).get(domain,null)
	if saved==null and domain=="beverages":
		# Compatibility with the pre-registry beverage-only checkpoint.
		saved=runtime_state.get("beverages",{}).get("rng_state",null)
	if _valid_rng_state(saved):generator.state=int(saved)
	_rng_streams[domain]=generator
	return generator

func _capture_decision_rng()->void:
	var saved:Dictionary=runtime_state.get("decision_rng_v1",{}).duplicate(true)
	for domain in _rng_streams:
		saved[domain]=str(_rng_streams[domain].state)
	runtime_state["decision_rng_v1"]=saved
	# Preserve the older beverage state field for compatible readers.
	if saved.has("beverages") and runtime_state.has("beverages"):
		runtime_state["beverages"]["rng_state"]=saved["beverages"]

func _ensure_object_events() -> bool:
	if recovery_blocked:return false
	if object_events_initialized and object_events_save_path == save_path:
		return bool(object_events.ready)
	object_events_initialized = true
	object_events_save_path = save_path
	return object_events.setup(self)

func submit_object_event(event: Dictionary) -> Dictionary:
	if not _ensure_object_events():
		return {"ok":false,"error":str(object_events.last_error)}
	return object_events.submit(event)

func object_event_storage_paths() -> Array:
	if not object_events_initialized or object_events_save_path != save_path:
		object_events_save_path = save_path
	return [
		save_path+".world_events_v1.json",
		save_path+".world_events_v1.json.bak",
		save_path+".world_events_v1.json.tmp",
		save_path+".world_events_v1.json.corrupt"
	]

func object_event_revision() -> int:
	return int(runtime_state.get("object_event_revision",0))

func object_event_history(object_id: String, limit: int = 64) -> Array:
	if not _ensure_object_events():
		return []
	return object_events.events_for_object(object_id,limit)

func explain_physical_object(object_id: String) -> Dictionary:
	if not _ensure_object_events():
		return {}
	return object_events.explain_object(object_id)

func cell_key(x: int, level: int) -> String:
	return "%d:%d" % [x, level]

func get_room(x: int, level: int) -> Dictionary:
	for room in rooms:
		if room_space.covers_cell(room,x,level):
			return room
	return {}

func room_by_id(room_id: String) -> Dictionary:
	for room in rooms:
		if str(room["id"]) == room_id:
			return room
	return {}

func world_pos(x: int, level: int) -> Vector3:
	return Vector3(float(x) * MODULE_W, float(level) * FLOOR_H, 0.0)

func room_center_pos(room: Dictionary) -> Vector3:
	return room_space.center_world(room)

func room_local_to_world(room: Dictionary, local: Vector2) -> Vector3:
	return room_space.local_to_world(room,local)

func room_world_to_local(room: Dictionary, position: Vector3) -> Vector2:
	return room_space.world_to_local(room,position)

func room_contains_local(room: Dictionary, local: Vector2, margin: float = 0.0) -> bool:
	return room_space.local_contains(room,local,margin)

func room_size_modules(room: Dictionary) -> int:
	return room_space.size_modules(room)

func connection_between(a: Dictionary, b: Dictionary) -> Dictionary:
	return room_space.connection_between(a,b)

func make_room(x: int, level: int, room_type: String,
		size_modules: int = 1, immutable_topology: bool = false) -> Dictionary:
	var modules: int = int(room_space.normalize_size(size_modules))
	if room_type=="lift":
		modules=1
	var room: Dictionary = {
		"id": "ROOM_%04d" % next_room_id,
		"x": x,
		"level": level,
		"type": room_type,
		"size_modules":modules,
		"size_id":room_space.size_id(modules),
		"topology_version":2,
		"immutable_topology":immutable_topology,
		"topology_origin":"seed" if immutable_topology else "runtime_add",
		"privacy": "door_only" if room_type == "private" else "public",
		"owner_id": "",
		"public_frontage": room_type in ["private","guest"],
		"guest_access_state": "open" if room_type == "guest" else "",
		"display_name": "Гостевая" if room_type == "guest" else "",
	}
	room["connectors"]=room_space.default_connectors(room_type,modules)
	next_room_id += 1
	rooms.append(room)
	return room

func can_build_room(x: int, level: int, room_type: String, size_modules: int = 1) -> bool:
	if not ROOM_TYPES.has(room_type):
		return false
	var modules:=room_space.normalize_size(size_modules)
	if room_type=="lift" and modules!=1:
		return false
	if abs(x) > 28 or abs(level) > 5 or abs(x+modules-1)>28:
		return false
	for occupied_x in range(x,x+modules):
		if not get_room(occupied_x,level).is_empty():
			return false
	var candidate:Dictionary={
		"id":"__CANDIDATE__","x":x,"level":level,"type":room_type,
		"size_modules":modules,"privacy":"public",
		"public_frontage":room_type in ["private","guest"]
	}
	candidate["connectors"]=room_space.default_connectors(room_type,modules)
	if rooms.is_empty():
		return true
	for existing in rooms:
		if not connection_between(candidate,existing).is_empty() and allows_transit(existing):
			return true
	return false

func can_build(x: int, level: int, room_type: String) -> bool:
	return can_build_room(x,level,room_type,1)

func build_room(x: int, level: int, room_type: String, size_modules: int = 1) -> bool:
	if not can_build_room(x,level,room_type,size_modules):
		return false
	make_room(x,level,room_type,size_modules,false)
	save_world()
	return true

func build(x: int, level: int, room_type: String) -> bool:
	return build_room(x,level,room_type,1)

func can_reconfigure_room(room_id: String) -> bool:
	var room: Dictionary = room_by_id(room_id)
	return not room.is_empty() and not bool(room.get("immutable_topology",false))

func can_remove_room(room_id: String) -> bool:
	return can_reconfigure_room(room_id)

func is_accessible(room: Dictionary, actor_id: String = "") -> bool:
	if room.is_empty():
		return false
	if str(room.get("type","")) == "guest" and str(room.get("guest_access_state","open")) == "closed":
		return actor_id != "" and str(room.get("owner_id","")) == actor_id
	if room.get("privacy", "public") != "public":
		return actor_id != "" and room.get("owner_id", "") == actor_id
	return true

func public_cutaway_allowed(room: Dictionary) -> bool:
	if room.is_empty() or str(room.get("privacy","public")) != "public":
		return false
	if str(room.get("type","")) == "guest" and str(room.get("guest_access_state","open")) == "closed":
		return false
	return true

func configure_guest_room(room_id: String, guest_id: String,
		display_name: String = "") -> bool:
	var room: Dictionary = room_by_id(room_id)
	var guest: Dictionary = residents.get(guest_id,{})
	if room.is_empty() or str(room.get("type","")) != "guest":
		return false
	if guest.is_empty() or str(guest.get("entity_type","")) != "guest":
		return false
	room["owner_id"] = guest_id
	room["guest_access_state"] = "open"
	room["display_name"] = display_name if display_name != "" else (
		"Гостевая · " + str(guest.get("name",guest_id)))
	guest["home_room_id"] = room_id
	_append_journal("GUEST_ROOM_ASSIGNED",guest_id,room_id,"",room_id,
		{"display_name":str(room["display_name"])})
	return true

func set_guest_room_open(room_id: String, open: bool) -> bool:
	var room: Dictionary = room_by_id(room_id)
	if room.is_empty() or str(room.get("type","")) != "guest" or str(room.get("owner_id","")) == "":
		return false
	var previous := str(room.get("guest_access_state","open"))
	var next := "open" if open else "closed"
	if previous == next:
		return true
	room["guest_access_state"] = next
	_append_journal("GUEST_ROOM_ACCESS_CHANGED",str(room.get("owner_id","")),room_id,
		previous,next,{"public_cutaway":open})
	return true

func guest_room_for(guest_id: String) -> Dictionary:
	for room in rooms:
		if str(room.get("type","")) == "guest" and str(room.get("owner_id","")) == guest_id:
			return room
	return {}

func allows_transit(room: Dictionary) -> bool:
	# The publicly visible walking aisle is IN FRONT of a private door.
	# Walking past a room is not permission to enter its interior.
	if room.is_empty():
		return false
	return room.get("privacy", "public") == "public" or bool(room.get("public_frontage", false))

func neighbors(room: Dictionary, actor_id: String = "") -> Array:
	var out: Array = []
	for candidate in rooms:
		if str(candidate.get("id",""))==str(room.get("id","")):
			continue
		if connection_between(room,candidate).is_empty():
			continue
		if allows_transit(candidate) or is_accessible(candidate,actor_id):
			out.append(candidate)
	return out

# A short-lived geometry index keeps direct room mutation and save/reload safe.
# No privacy or ownership is cached. Ordering matches the original rooms array.
func route_geometry_index()->Dictionary:
	var cells:Dictionary={}
	var by_id:Dictionary={}
	var order:Dictionary={}
	for i in range(rooms.size()):
		var room:Dictionary=rooms[i]
		var rid:String=str(room["id"])
		by_id[rid]=room
		order[rid]=i
		for x in range(int(room["x"]),room_space.x_end(room)+1):
			cells[Vector2i(x,int(room["level"]))]=room
	return {"cells":cells,"by_id":by_id,"order":order}

func indexed_geometry_neighbors(room:Dictionary,index:Dictionary)->Array:
	var x:int=int(room["x"])
	var level:int=int(room["level"])
	var probes:Array=[Vector2i(x-1,level),Vector2i(room_space.x_end(room)+1,level)]
	if str(room["type"])=="lift":
		probes.append(Vector2i(x,level-1))
		probes.append(Vector2i(x,level+1))
	var result:Array=[]
	var ids:Dictionary={}
	var cells:Dictionary=index["cells"]
	var order:Dictionary=index["order"]
	for cell in probes:
		var candidate:Dictionary=cells.get(cell,{})
		if candidate.is_empty():continue
		var rid:String=str(candidate["id"])
		if ids.has(rid) or connection_between(room,candidate).is_empty():continue
		ids[rid]=true
		result.append(candidate)
	result.sort_custom(func(a,b):return int(order[str(a["id"])])<int(order[str(b["id"])]))
	return result

func find_route(start_id: String, destination_id: String, actor_id: String = "") -> Array:
	var index:Dictionary=route_geometry_index() if canonical_house_seed else {}
	var start: Dictionary = index["by_id"].get(start_id,{}) if canonical_house_seed else room_by_id(start_id)
	var target: Dictionary = index["by_id"].get(destination_id,{}) if canonical_house_seed else room_by_id(destination_id)
	if start.is_empty() or target.is_empty() or not is_accessible(target, actor_id):
		return []
	if start_id == destination_id:
		return [start_id]
	var seen: Dictionary = {start_id: true}
	var previous: Dictionary = {}
	var queue: Array = [start]
	var q_index := 0
	while q_index < queue.size():
		var current: Dictionary = queue[q_index]
		q_index += 1
		var adjacent:Array=indexed_geometry_neighbors(current,index) if canonical_house_seed else neighbors(current,actor_id)
		for next_room in adjacent:
			if canonical_house_seed and not allows_transit(next_room) and not is_accessible(next_room,actor_id):continue
			var key: String = next_room["id"]
			if seen.has(key):
				continue
			seen[key] = true
			previous[key] = current["id"]
			if key == destination_id:
				var path: Array = [destination_id]
				var cursor: String = destination_id
				while cursor != start_id:
					cursor = previous[cursor]
					path.push_front(cursor)
				return path
			queue.append(next_room)
	return []

func matching_rooms(types: Array, actor_id: String = "") -> Array:
	var out: Array = []
	for room in rooms:
		if types.has(room["type"]) and is_accessible(room, actor_id):
			out.append(room)
	return out

func merged_run_length(x: int, level: int) -> int:
	var room:=get_room(x,level)
	return 0 if room.is_empty() else room_size_modules(room)

func merged_group(x: int, level: int) -> Dictionary:
	var room:Dictionary=get_room(x,level)
	if room.is_empty():
		return {}
	var first:=int(room["x"])
	var width:=room_size_modules(room)
	return {
		"type":str(room["type"]),"level":int(room["level"]),
		"x_start":first,"x_end":first+width-1,"width":width,
		"cells":room_space.virtual_modules(room),
		"primary_id":str(room["id"]),"room_id":str(room["id"]),
		"immutable_topology":bool(room.get("immutable_topology",false)),
		"connectors":room.get("connectors",[])
	}

func visual_groups() -> Array:
	var groups:Array=[]
	var sorted_rooms:Array=rooms.duplicate()
	sorted_rooms.sort_custom(func(a,b):
		if int(a["level"])!=int(b["level"]):
			return int(a["level"])<int(b["level"])
		return int(a["x"])<int(b["x"]))
	for room in sorted_rooms:
		groups.append(merged_group(int(room["x"]),int(room["level"])))
	return groups

func _append_journal(event_name: String, actor_id: String = "", subject_id: String = "",
		from_value: String = "", to_value: String = "", details: Dictionary = {}) -> void:
	# Capture visibility at event time, not just when somebody opens the UI.
	# Legacy unmarked entries remain diagnostic-only.
	var public_rooms:Array=[]
	var public_ok:bool=str(details.get("visibility","house_public"))=="house_public"
	for value in [from_value,to_value,str(details.get("event_room_id",""))]:
		var event_room:Dictionary=room_by_id(value)
		if event_room.is_empty():continue
		if not public_cutaway_allowed(event_room):public_ok=false
		elif not public_rooms.has(value):public_rooms.append(value)
	var actor:Dictionary=residents.get(actor_id,creatures.get(actor_id,{}))
	if not actor.is_empty() and not public_cutaway_allowed(room_by_id(str(actor.get("room_id","")))):public_ok=false
	# Replayed object events do not contain historical guest-door visibility.
	if details.has("event_id"):
		for rid in public_rooms:
			if str(room_by_id(rid).get("type",""))=="guest":public_ok=false
	journal.append({
		"public_projection_allowed":public_ok and not public_rooms.is_empty(),
		"public_room_ids":public_rooms,
		"event": event_name,
		"actor_id": actor_id,
		"subject_id": subject_id,
		"from": from_value,
		"to": to_value,
		"details": details.duplicate(true),
		"sim_clock": float(details.get("event_sim_clock",sim_clock))
	})
	while journal.size() > 256:
		journal.pop_front()

func journal_entries(limit: int = 64) -> Array:
	if limit <= 0:
		return []
	var start: int = maxi(0, journal.size() - limit)
	return journal.slice(start, journal.size())

func register_physical_object(object_id: String, display_name: String,
		canonical_owner_id: String, home_room_id: String,
		movable: bool = true, recoverable: bool = true,
		ambient_pickup_allowed: bool = false, ambient_hide_allowed: bool = false,
		ambient_protected: bool = false, metadata: Dictionary = {}) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.register_object(
		object_id,display_name,canonical_owner_id,home_room_id,movable,recoverable,
		ambient_pickup_allowed,ambient_hide_allowed,ambient_protected,metadata)

func physical_object(object_id: String) -> Dictionary:
	return objects.get(object_id, {})

func _physical_actor(actor_id: String) -> Dictionary:
	if residents.has(actor_id):
		return residents[actor_id]
	return creatures.get(actor_id, {})

func can_ambient_pickup_object(object_id: String) -> bool:
	var object: Dictionary = physical_object(object_id)
	if object.is_empty():
		return false
	return (str(object.get("object_class","display_object"))=="small_artifact"
		and bool(object.get("movable",false))
		and bool(object.get("ambient_pickup_allowed",false))
		and not bool(object.get("ambient_protected",false))
		and str(object.get("current_holder_id","")) == ""
		and str(object.get("current_room_id","")) != "")

func set_object_ambient_protection(object_id: String, protected: bool) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.set_ambient_protection(object_id,protected)

func pickup_physical_object(object_id: String, actor_id: String) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.pickup(object_id,actor_id)

func place_physical_object(object_id: String, actor_id: String,
		target_room_id: String, state: String = "PLACED",
		target_anchor: Variant = null) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.place(object_id,actor_id,target_room_id,state,target_anchor)

func recover_physical_object_to_lost_found(object_id: String,
		lost_found_room_id: String) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.recover_to_lost_found(object_id,lost_found_room_id)

func restore_physical_object_home(object_id: String, reset_day: int = -1) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.restore_home(object_id,reset_day)

func assign_physical_object_home(object_id: String, target_room_id: String,
		home_anchor: Vector2, move_now: bool = true, support_id:String="",wall_height:float=-1.0) -> bool:
	if not _ensure_object_events():
		return false
	return object_events.assign_home(
		object_id,target_room_id,home_anchor,move_now,"LOCAL_DRAGON",support_id,wall_height)

func game_day_index() -> int:
	return maxi(0,int(floor(sim_clock/GAME_DAY_SECONDS)))

func _anchors_equal(a, b) -> bool:
	if typeof(a)!=TYPE_ARRAY or typeof(b)!=TYPE_ARRAY:
		return false
	var aa:Array=a
	var bb:Array=b
	if aa.size()!=2 or bb.size()!=2:
		return false
	return absf(float(aa[0])-float(bb[0]))<0.001 and (
		absf(float(aa[1])-float(bb[1]))<0.001)

func object_is_displaced(object: Dictionary) -> bool:
	if object.is_empty() or not bool(object.get("movable",false)) or not bool(object.get("reset_eligible",true)):
		return false
	var home_room:String=str(object.get("home_room_id",""))
	if home_room=="" or room_by_id(home_room).is_empty():
		return false
	if str(object.get("current_holder_id",""))!="":
		return true
	if str(object.get("current_room_id",""))!=home_room:
		return true
	if str(object.get("state","PLACED"))!="PLACED":
		return true
	# Legacy home anchors without a support ID may acquire a measured support.
	var home_support:String=str(object.get("home_support_id",""))
	if home_support!="" and str(object.get("current_support_id",""))!=home_support:
		return true
	return not _anchors_equal(
		object.get("current_anchor",[]),object.get("home_anchor",[]))

# Object events own possession. Actor fields are cached projections, not
# a second authority. Run once after journal replay, before life starts.
func reconcile_object_carriers()->bool:
	var creature_items:Dictionary={}
	var cup_items:Dictionary={}
	var issues:Array=[]
	for id in objects:
		var item:Dictionary=objects[id]
		var holder:String=str(item.get("current_holder_id",""))
		if holder=="":continue
		if creatures.has(holder):
			if creature_items.has(holder):
				issues.append({"reason":"MULTIPLE_CREATURE_ITEMS","actor_id":holder})
			else:creature_items[holder]=str(id)
		elif residents.has(holder) and str(item.get("viewer_category",""))=="cups":
			if cup_items.has(holder):
				issues.append({"reason":"MULTIPLE_HELD_CUPS","actor_id":holder})
			else:cup_items[holder]=str(id)
		elif not residents.has(holder):
			issues.append({"reason":"UNKNOWN_OBJECT_HOLDER","object_id":str(id)})
	if not issues.is_empty():
		runtime_state["object_carrier_recovery_issues"]=issues
		return false
	runtime_state.erase("object_carrier_recovery_issues")
	for id in creatures:
		creatures[id]["carried_object_id"]=str(creature_items.get(id,""))
	return true

func _clear_carrier_reference(object_id: String, previous_holder: String) -> void:
	if previous_holder=="":
		return
	if creatures.has(previous_holder):
		var creature:Dictionary=creatures[previous_holder]
		if str(creature.get("carried_object_id",""))==object_id:
			creature["carried_object_id"]=""
	if residents.has(previous_holder):
		var actor:Dictionary=residents[previous_holder]
		if str(actor.get("carried_object_id",""))==object_id:
			actor["carried_object_id"]=""

# A derived deadline, never an independent object location or ownership.
func object_interaction_at(object:Dictionary)->float:
	if object.has("last_interaction_at"):
		return float(object["last_interaction_at"])
	# Older projections may have been cached before this field existed.
	var history:Array=object.get("history",[])
	for i in range(history.size()-1,-1,-1):
		var entry:Dictionary=history[i]
		if entry.has("sim_clock") and str(entry.get("event","")) in ["REGISTERED","PICKED_UP","PLACED","STASHED","HOME_ASSIGNED","RESTORED_HOME","RECOVERED_TO_LOST_FOUND","HOUSEKEEPING_RETURNED"]:
			return float(entry["sim_clock"])
	# Conservative migration for missing evidence: start the clock once.
	var migration:Dictionary=runtime_state.get("housekeeping_legacy_clock",{})
	var id:String=str(object.get("id",""))
	if not migration.has(id):
		migration[id]=sim_clock
		runtime_state["housekeeping_legacy_clock"]=migration
	return float(migration[id])

func object_active_use(object:Dictionary)->bool:
	if str(object.get("current_holder_id",""))!="":return true
	var id:String=str(object.get("id",""))
	for actor in residents.values():
		if not bool(actor.get("active",false)):continue
		if str(actor.get("cup_task_id",""))==id and str(actor.get("cup_task_stage","")) in ["fetch","serve","hold","return"]:return true
		if str(actor.get("phase","")) in ["travel","perform"] and (str(actor.get("activity_media_id",""))==id or str(actor.get("viewing_object_id",""))==id):return true
	return false

func record_object_view(object_id:String,actor_id:String,context:String)->bool:
	if not _ensure_object_events():return false
	return object_events.record_view(object_id,actor_id,context)

func object_needs_housekeeping(object:Dictionary)->bool:
	if object.is_empty() or not bool(object.get("movable",false)) or not bool(object.get("recoverable",false)) or not bool(object.get("reset_eligible",true)):return false
	if object_is_displaced(object):return true
	if str(object.get("viewer_category",""))=="cups":
		return float(runtime_state.get("beverages",{}).get("cups",{}).get(str(object.get("id","")),{}).get("remaining_ml",0))>0
	return false

func housekeeping_age(object:Dictionary)->float:
	return sim_clock-object_interaction_at(object)

func housekeeping_slot_free(object:Dictionary,room_id:String,anchor:Array,support_id:String)->bool:
	if anchor.size()!=2:return false
	if support_id!="":
		# Books, cups and other objects cannot share one physical support.
		for book_id in runtime_state.get("teea008_book_slot_assignments",{}):
			if str(book_id)==str(object.get("id","")):continue
			var assigned:Dictionary=runtime_state["teea008_book_slot_assignments"][book_id]
			if str(assigned.get("room_id",""))==room_id and str(assigned.get("slot_id",""))==support_id:return false
		for actor in residents.values():
			if not bool(actor.get("active",false)):continue
			if str(actor.get("book_task_id",""))!=str(object.get("id","")) and str(actor.get("book_task_stage",""))=="return" and str(actor.get("book_return_room",""))==room_id and str(actor.get("book_return_slot",""))==support_id:return false
		for actor in residents.values():
			if not bool(actor.get("active",false)):continue
			if str(actor.get("cup_task_id",""))==str(object.get("id","")):continue
			if str(actor.get("cup_task_room",""))==room_id and str(actor.get("cup_task_slot",""))==support_id and str(actor.get("cup_task_stage","")) in ["fetch","serve","hold","return"]:return false
	for other in objects.values():
		if str(other.get("id",""))==str(object.get("id","")):continue
		# Keep other assigned homes reserved, as well as physical occupants.
		for prefix in ["home","current"]:
			if str(other.get(prefix+"_room_id",""))!=room_id:continue
			var other_support:String=str(other.get(prefix+"_support_id",""))
			if support_id!="" and other_support!="":
				if support_id==other_support:return false
			elif _anchors_equal(anchor,other.get(prefix+"_anchor",[])):return false
	return true

func housekeeping_target(object:Dictionary)->Dictionary:
	if not object_needs_housekeeping(object) or object_active_use(object):return {}
	var current:Dictionary=room_by_id(str(object.get("current_room_id","")))
	# A closed/private source is not permission for invisible entry.
	if not public_cutaway_allowed(current):return {}
	if canonical_house_seed and housekeeping_navigation==null:return {}
	var home:String=str(object.get("home_room_id",""))
	var home_room:Dictionary=room_by_id(home)
	var anchor:Array=object.get("home_anchor",[])
	var support:String=str(object.get("home_support_id",""))
	var category:String=str(object.get("viewer_category",""))
	if public_cutaway_allowed(home_room) and anchor.size()==2 and housekeeping_slot_free(object,home,anchor,support):
		var home_ok:=true
		if housekeeping_navigation!=null and category in ["artifacts","cups"] and str(object.get("display_mode",""))!="wall":
			home_ok=false
			var slots:Array=housekeeping_navigation.cup_slots(home_room) if category=="cups" else housekeeping_navigation.artifact_slots(home_room)
			for slot in slots:
				var p:Array=slot["xyz"]
				if (support=="" or str(slot["id"])==support) and _anchors_equal(anchor,[p[0],p[2]]) and _housekeeping_slot_fits(object,slot):
					home_ok=true
					if category=="artifacts":support=str(slot["id"])
					break
		if home_ok:return {"room_id":home,"anchor":anchor,"support_id":support}
	# Do not invent furniture or a free position if measured supports are absent.
	if housekeeping_navigation==null or str(object.get("display_mode",""))=="wall" or not category in ["artifacts","cups"]:return {}
	var candidates:Array=matching_rooms(["common","rest","kitchen"] if category=="cups" else ["artifact"])
	for room in candidates:
		if not public_cutaway_allowed(room):continue
		var slots:Array=housekeeping_navigation.cup_slots(room) if category=="cups" else housekeeping_navigation.artifact_slots(room)
		for slot in slots:
			if not _housekeeping_slot_fits(object,slot):continue
			var pos:Array=slot["xyz"]
			var a:Array=[pos[0],pos[2]]
			var sid:String=str(slot["id"])
			if str(object.get("current_room_id",""))==str(room["id"]) and str(object.get("state",""))=="PLACED" and _anchors_equal(a,object.get("current_anchor",[])) and (str(object.get("current_support_id",""))==sid or category=="cups"):
				# Already safely on an alternate support; do not repeatedly move it there.
				if category!="cups" or float(runtime_state.get("beverages",{}).get("cups",{}).get(str(object["id"]),{}).get("remaining_ml",0))<=0:continue
			if housekeeping_slot_free(object,str(room["id"]),a,sid):
				return {"room_id":str(room["id"]),"anchor":a,"support_id":sid}
	return {}

func _housekeeping_slot_fits(object:Dictionary,slot:Dictionary)->bool:
	if str(object.get("viewer_category",""))=="cups":return true
	var dims:Array=slot.get("dimensions",[])
	var size:float=float(object.get("display_world_height",0.0))
	return size>0 and dims.size()==3 and float(dims[0])>=size and float(dims[1])>=size and float(dims[2])>=size

func tick_object_home_reset() -> int:
	# Compatibility name; no calendar-day sweep. Each accepted interaction
	# starts its own rolling deadline. Pending candidates are derived state.
	var pending:Dictionary={}
	var restored:=0
	var ids:Array=objects.keys()
	ids.sort()
	for raw_id in ids:
		var id:String=str(raw_id)
		var object:Dictionary=objects[id]
		if not object_needs_housekeeping(object):continue
		var age:float=housekeeping_age(object)
		if age<=RETURN_PREPARE_SECONDS:continue
		pending[id]={"due_at":object_interaction_at(object)+GAME_DAY_SECONDS,"reason":"WAIT_DUE"}
		if age<GAME_DAY_SECONDS:continue
		if object_active_use(object):
			pending[id]["reason"]="ACTIVE_USE"
			continue
		var target:Dictionary=housekeeping_target(object)
		if target.is_empty():
			pending[id]["reason"]="NO_COMPATIBLE_AUTHORIZED_SLOT"
			continue
		# Commit synchronously through the event gate, which rechecks the
		# chosen slot. The next item sees the committed occupancy.
		if _ensure_object_events() and object_events.housekeeping_return(id,target):
			pending.erase(id)
			restored+=1
		else:
			pending[id]["reason"]="EVENT_REJECTED"
	runtime_state["housekeeping_pending_objects"]=pending
	runtime_state.erase("object_home_reset_day")
	runtime_state["object_home_reset_last_count"]=restored
	return restored

func register_creature(creature_id: String, display_name: String,
		room_id: String, bank_id: String = "", owner_id: String = "",
		can_pickup: bool = false, can_hide: bool = false, guest: bool = false) -> bool:
	if creature_id == "" or display_name == "" or creatures.has(creature_id) or residents.has(creature_id):
		return false
	var room: Dictionary = room_by_id(room_id)
	if room.is_empty() or str(room.get("privacy","public")) != "public":
		return false
	creatures[creature_id] = {
		"id":creature_id, "name":display_name, "active":true,
		"entity_type":"creature", "guest":guest, "owner_id":owner_id,
		"bank_id":bank_id, "room_id":room_id,
		"x":room_center_pos(room).x, "level":int(room["level"]), "z":0.25,
		"can_pickup_objects":can_pickup, "can_hide_objects":can_hide,
		"carried_object_id":"", "next_decision_at":sim_clock
	}
	_append_journal("CREATURE_REGISTERED", creature_id, creature_id, "", room_id,
		{"display_name":display_name,"owner_id":owner_id,"guest":guest})
	return true

func creature_display_label(creature_id: String) -> String:
	var creature: Dictionary = creatures.get(creature_id,{})
	if creature.is_empty():
		return ""
	var label := str(creature.get("name",creature_id))
	var owner_id := str(creature.get("owner_id",""))
	if owner_id == "" or not residents.has(owner_id):
		return label
	var owner_name := str(residents[owner_id].get("name",""))
	if owner_name == "":
		return label
	return "%s · хозяйка %s" % [label,owner_name]

func register_guest_actor(actor_id: String, display_name: String,
		room_id: String, species: String = "", bank_id: String = "") -> bool:
	if actor_id == "" or display_name == "" or residents.has(actor_id) or creatures.has(actor_id):
		return false
	var room: Dictionary = room_by_id(room_id)
	if room.is_empty() or str(room.get("privacy","public")) != "public":
		return false
	residents[actor_id] = {
		"id":actor_id, "name":display_name, "active":true,
		"entity_type":"guest", "guest":true, "species":species, "bank_id":bank_id,
		"room_id":room_id, "home_room_id":room_id,
		"x":room_center_pos(room).x, "level":int(room["level"]), "z":0.15,
		"intent":"REST", "phase":"idle", "until":0.0,
		"needs":{"rest":0.4,"social":0.35,"curiosity":0.55},
		"traits":{"reading":0.35,"music":0.35},
		"habits":{}, "last_location":"", "route":[], "path_index":0,
		"production_visual_ready":false, "visual_status":"CANDIDATE"
	}
	_append_journal("GUEST_REGISTERED", actor_id, actor_id, "", room_id,
		{"display_name":display_name,"species":species,"bank_id":bank_id})
	if str(room.get("type","")) == "guest":
		configure_guest_room(room_id,actor_id)
	return true

func merge_reference_book_metadata(items: Array) -> int:
	# The documented cloud catalog is NOT a shelf inventory. No copy may be borrowed.
	var existing: Dictionary = {}
	for entry in media.get("books", []):
		existing[str(entry.get("id", ""))] = true
	var added := 0
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var id: String = str(item.get("id", ""))
		var title: String = str(item.get("title", ""))
		if id == "" or title == "" or existing.has(id) or str(item.get("status", "")) != "METADATA_ONLY":
			continue
		var byline = item.get("author", "")
		media["books"].append({
			"id": id, "title": title, "author": "" if byline == null else str(byline),
			"catalog_only": true, "physical": false,
			"provenance": str(item.get("source", "")),
			"preview": "", "holder_id": "", "location_room_id": "",
			"idle_since": 0, "progress_by_actor": {}
		})
		existing[id] = true
		added += 1
	if added > 0:
		save_world()
	return added

func _zna_duration_seconds(value:String)->int:
	var parts:PackedStringArray=value.strip_edges().split(":")
	if parts.size()<2 or parts.size()>3:return 0
	var seconds:=0
	for i in range(parts.size()):
		if not parts[i].is_valid_int():return 0
		var n:int=int(parts[i])
		if n<0 or (i>0 and n>=60):return 0
		seconds=seconds*60+n
	return seconds

func merge_zna_media_previews() -> int:
	# ZNA004 delivered actual previews and source metadata, not local media
	# files. Owner clarified that the YouTube source is the audio library.
	# Original ZNA categories remain provenance. Four explicit nonmusic
	# titles are retained for inspection but not selected by residents.
	var file:=FileAccess.open("res://assets/manifests/media_preview_index.json",FileAccess.READ)
	if file==null:return 0
	var manifest=JSON.parse_string(file.get_as_text())
	if typeof(manifest)!=TYPE_DICTIONARY:return 0
	var added:=0
	var changed:=false
	for pair in [["audio","tracks","audio"],["unclassified","tracks","unclassified"]]:
		var source_key:String=pair[0]
		var category:String=pair[1]
		var folder:String=pair[2]
		var incoming=manifest.get(source_key,[])
		if typeof(incoming)!=TYPE_ARRAY:continue
		var records:Array=media.get(category,[])
		var existing:Dictionary={}
		for entry in records:
			existing[str(entry.get("id",""))]=entry
		for entry in incoming:
			if typeof(entry)!=TYPE_DICTIONARY:continue
			var id:String=str(entry.get("id",entry.get("content_id","")))
			var title:String=str(entry.get("title",""))
			var relative:String=str(entry.get("preview_path",""))
			if id=="" or title=="" or not relative.begins_with("assets/media/previews/"+folder+"/") or relative.contains("..") or relative.contains("\\"):
				continue
			if not relative.get_extension().to_lower() in ["webp","png","jpg","jpeg"]:continue
			var preview_path:String="res://"+relative
			if not ResourceLoader.exists(preview_path,"Texture2D") and not FileAccess.file_exists(preview_path):continue
			var duration_seconds:int=_zna_duration_seconds(str(entry.get("duration","")))
			var nonmusic:bool=id in ["YT_ExiWrVHAx0g","YT_TBjGUZJivg4","YT_k1GTx3aZ4iU","YT_Hpp9iO0I-9A"]
			var timing:Dictionary={"runtime_seconds":duration_seconds,"simulation_only":true,"autonomous_music":not nonmusic and duration_seconds>0,"source_classification":source_key,"classification_authority":"OWNER_20261125_YOUTUBE_AUDIO_LIBRARY"}
			if existing.has(id):
				# Preserve imported local file, user edits and existing artwork.
				var old:Dictionary=existing[id]
				if str(old.get("preview",old.get("preview_path","")))=="":
					old["preview"]=preview_path
					changed=true
				for key in timing:
					if old.get(key,null)!=timing[key]:
						old[key]=timing[key]
						changed=true
				continue
			var record:Dictionary={"id":id,"title":title,"artist":str(entry.get("artist","")),"duration":str(entry.get("duration","")),"preview":preview_path,"file_path":"","catalog_only":true,"provenance":"ZNA004 · source-derived preview","source_url":str(entry.get("source_url","")),"owner_approved":bool(entry.get("owner_approved",false))}
			record.merge(timing,true)
			records.append(record)
			existing[id]=record
			added+=1
			changed=true
		media[category]=records
	if changed:save_world()
	return added

# Owner-approved repository bundle and optional local catalog ingestion.
# A partial recovery must not erase researched
# durations or change the identity of a work with saved resident progress.
func _positive_catalog_seconds(value)->bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>0.0

func _valid_cinema_record(raw:Dictionary,verify_preview:bool=true)->bool:
	var id:String=str(raw.get("id",""))
	if not id.begins_with("FILMIX_") or id.length()<=7 or id.contains("/") or id.contains("\\") or id.contains("..") or str(raw.get("title","")).strip_edges()=="":return false
	var kind:String=str(raw.get("media_type",""))
	if not kind in ["film","series"]:return false
	var path:String=str(raw.get("preview",""))
	if path not in ["user://filmix_previews/"+id+".webp","user://filmix_bundle_previews/"+id+".webp"]:return false
	if verify_preview:
		if not FileAccess.file_exists(path):return false
		var digest:String=str(raw.get("preview_sha256",""))
		if digest!="" and FileAccess.get_sha256(path)!=digest:return false
	if kind=="film":
		var value=raw.get("runtime_seconds",0)
		return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value)) and float(value)>=0
	for field in ["episode_imdb_ids","episode_duration_sources"]:
		if typeof(raw.get(field,{}))!=TYPE_DICTIONARY:return false
	var season:int=int(raw.get("latest_season",0))
	var episode:int=int(raw.get("latest_episode",0))
	if season<0 or episode<0:return false
	var table=raw.get("episode_runtime_seconds",{})
	var complete=raw.get("complete_seasons",[])
	if typeof(table)!=TYPE_DICTIONARY or typeof(complete)!=TYPE_ARRAY:return false
	for key in table:
		if not str(key).is_valid_int():return false
		var s:int=int(key)
		if s<1 or s>season:return false
		var values=table[key]
		if typeof(values)!=TYPE_ARRAY:return false
		if s==season and episode>0 and values.size()>episode:return false
		for value in values:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or float(value)<0:return false
	for s_raw in complete:
		if typeof(s_raw) not in [TYPE_INT,TYPE_FLOAT]:return false
		var s:int=int(s_raw)
		if not table.has(str(s)) or table[str(s)].is_empty():return false
		for value in table[str(s)]:
			if not _positive_catalog_seconds(value):return false
	return true

func _merge_cinema_record(previous:Dictionary,incoming:Dictionary)->Dictionary:
	if previous.is_empty():return incoming.duplicate(true)
	# Only identical stable IDs and types enter this function. Preserve
	# positive old timings against unknown/zero fields in recovered input.
	# A reused card ID cannot silently change the work or episode identity.
	var previous_imdb:String=str(previous.get("imdb_id",""))
	var incoming_imdb:String=str(incoming.get("imdb_id",""))
	if previous_imdb!="" and incoming_imdb!="" and previous_imdb!=incoming_imdb:return {}
	var row:Dictionary=incoming.duplicate(true)
	if incoming_imdb=="" and previous_imdb!="":row["imdb_id"]=previous_imdb
	if str(row.get("media_type",""))=="film":
		if _positive_catalog_seconds(previous.get("runtime_seconds",0)) and not _positive_catalog_seconds(row.get("runtime_seconds",0)):
			row["runtime_seconds"]=previous["runtime_seconds"]
			for field in ["duration_status","duration_source","duration_evidence","runtime_edition","imdb_id","imdb_release_year"]:
				if previous.has(field):row[field]=previous[field]
		return row
	var ps:int=int(previous.get("latest_season",0))
	var pe:int=int(previous.get("latest_episode",0))
	var ns:int=int(row.get("latest_season",0))
	var ne:int=int(row.get("latest_episode",0))
	if ps>ns or (ps==ns and pe>ne):
		row["latest_season"]=ps
		row["latest_episode"]=pe
	var old:Dictionary=previous.get("episode_runtime_seconds",{})
	var updated:Dictionary=row.get("episode_runtime_seconds",{}).duplicate(true)
	var old_ids:Dictionary=previous.get("episode_imdb_ids",{}).duplicate(true)
	var new_ids:Dictionary=row.get("episode_imdb_ids",{})
	for unit in new_ids:
		var prior_id:String=str(old_ids.get(unit,""))
		var next_id:String=str(new_ids[unit])
		if prior_id!="" and next_id!="" and prior_id!=next_id:return {}
	var old_sources:Dictionary=previous.get("episode_duration_sources",{}).duplicate(true)
	var new_sources:Dictionary=row.get("episode_duration_sources",{})
	var sources:Dictionary=old_sources.duplicate(true)
	sources.merge(new_sources,true)
	var ids:Dictionary=old_ids.duplicate(true)
	for unit in new_ids:
		if str(new_ids[unit])!="":ids[unit]=new_ids[unit]
	# Keep evidence attached to the duration that actually survives the merge.
	for key in updated:
		var vals:Array=updated[key]
		for i in range(vals.size()):
			var unit:String="%s:%d"%[str(key),i+1]
			if _positive_catalog_seconds(vals[i]) and not new_sources.has(unit):
				var prior:Array=old.get(str(key),[])
				if i>=prior.size() or vals[i]!=prior[i]:sources.erase(unit)
	for key in old:
		if typeof(old[key])!=TYPE_ARRAY:continue
		var values:Array=updated.get(str(key),[]).duplicate()
		var prior:Array=old[key]
		while values.size()<prior.size():values.append(0)
		for i in range(prior.size()):
			if not _positive_catalog_seconds(values[i]) and _positive_catalog_seconds(prior[i]):
				values[i]=prior[i]
				var unit:String="%s:%d"%[str(key),i+1]
				if old_sources.has(unit):sources[unit]=old_sources[unit]
				else:sources.erase(unit)
				# Do not attach newly discovered IDs to unidentified old timings.
				if old_ids.has(unit):ids[unit]=old_ids[unit]
				else:ids.erase(unit)
		updated[str(key)]=values
	row["episode_runtime_seconds"]=updated
	var complete:Array=[]
	var declared:Dictionary=incoming.get("episode_runtime_seconds",{})
	# A complete-season assertion must describe the entire retained table.
	for s in incoming.get("complete_seasons",[]):
		var key:String=str(int(s))
		var incoming_values:Array=declared.get(key,[])
		var retained:Array=updated.get(key,[])
		if incoming_values.size()==retained.size() and not complete.has(s):complete.append(s)
	for s in previous.get("complete_seasons",[]):
		var key:String=str(int(s))
		var prior:Array=old.get(key,[])
		var merged_values:Array=updated.get(key,[])
		if not complete.has(s) and prior.size()==merged_values.size():complete.append(s)
	# A later bookmark boundary can expose episodes whose runtimes are unknown.
	var last_s:int=int(row.get("latest_season",0))
	var last_e:int=int(row.get("latest_episode",0))
	var last_values:Array=updated.get(str(last_s),[])
	if last_e>last_values.size():
		complete.erase(last_s)
	row["complete_seasons"]=complete
	row["episode_imdb_ids"]=ids
	row["episode_duration_sources"]=sources
	if not old.is_empty() and str(row.get("duration_status",""))=="UNVERIFIED":
		row["duration_status"]=str(previous.get("duration_status","PARTIAL"))
		for field in ["duration_source","duration_evidence"]:
			if previous.has(field):row[field]=previous[field]
	return row

const FILMIX_BUNDLE_ROOT:="res://data/filmix_bundle/"
const FILMIX_BUNDLE_CACHE:="user://filmix_bundle_previews/"
const FILMIX_BUNDLE_SHA256:="29b7b1c2f59bcc2d01538e9fbbe3382ef2eea7f4214d39e6356b299d70e8185f"

func _read_cinema_batch(path:String,check_preview:bool)->Dictionary:
	if not FileAccess.file_exists(path):return {"ok":true,"rows":[]}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null:return {"ok":false,"rows":[]}
	var parsed=JSON.parse_string(file.get_as_text())
	if typeof(parsed)!=TYPE_DICTIONARY or typeof(parsed.get("films",null))!=TYPE_ARRAY:return {"ok":false,"rows":[]}
	var rows:Array=[]
	var seen:Dictionary={}
	for raw in parsed["films"]:
		if typeof(raw)!=TYPE_DICTIONARY or not _valid_cinema_record(raw,check_preview):return {"ok":false,"rows":[]}
		var id:String=str(raw["id"])
		if seen.has(id):return {"ok":false,"rows":[]}
		seen[id]=true
		var row:Dictionary=raw.duplicate(true)
		row["simulation_only"]=true
		row["file_path"]=""
		row.erase("source_url")
		rows.append(row)
	return {"ok":true,"rows":rows}

func _ensure_bundled_cinema_previews(rows:Array)->bool:
	if rows.is_empty():return false
	var needed:Array=[]
	for row in rows:
		var digest:String=str(row.get("preview_sha256",""))
		var path:String=str(row.get("preview",""))
		if path!=FILMIX_BUNDLE_CACHE+str(row["id"])+".webp" or digest.length()!=64:return false
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=digest:needed.append(row)
	if needed.is_empty():return true
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILMIX_BUNDLE_CACHE))!=OK:return false
	var scratch:="user://filmix_bundle_extract.tmp.zip"
	var out:=FileAccess.open(scratch,FileAccess.WRITE)
	if out==null:return false
	for i in range(8):
		var part:String=FILMIX_BUNDLE_ROOT+"posters.part%02d.bin"%i
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes(part)
		if bytes.size()!=(397600 if i==7 else 537600):
			out.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
			return false
		out.store_buffer(bytes)
	out.flush()
	out.close()
	if FileAccess.get_sha256(scratch)!=FILMIX_BUNDLE_SHA256:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		return false
	var archive:=ZIPReader.new()
	if archive.open(scratch)!=OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		return false
	var ok:=true
	for row in needed:
		var path:String=str(row["preview"])
		var member:String="filmix_previews/"+str(row["id"])+".webp"
		var bytes:PackedByteArray=archive.read_file(member)
		if bytes.is_empty():
			ok=false
			break
		var tmp:String=path+".tmp"
		var file:=FileAccess.open(tmp,FileAccess.WRITE)
		if file==null:
			ok=false
			break
		file.store_buffer(bytes)
		file.flush()
		file.close()
		if FileAccess.get_sha256(tmp)!=str(row["preview_sha256"]):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
			ok=false
			break
		# Only the dedicated reproducible cache is replaced, never local overrides.
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(ProjectSettings.globalize_path(path))!=OK:
			ok=false
			break
		if DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(path))!=OK:
			ok=false
			break
	archive.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	return ok

func load_private_cinema_catalog()->int:
	# Historical function name retained. The owner approved repository
	# publication of media catalog and posters on 2026-11-25. No viewing
	# history, credentials, door notes or personal source PDF is bundled.
	var incoming:Array=[]
	var bundled:Dictionary=_read_cinema_batch(FILMIX_BUNDLE_ROOT+"filmix_catalog.json",false)
	if bool(bundled["ok"]) and not bundled["rows"].is_empty():
		if _ensure_bundled_cinema_previews(bundled["rows"]):
			var checked:Dictionary=_read_cinema_batch(FILMIX_BUNDLE_ROOT+"filmix_catalog.json",true)
			if bool(checked["ok"]):incoming.append_array(checked["rows"])
		else:push_warning("Filmix bundle preview integrity check failed; retaining installed data")
	elif not bool(bundled["ok"]):push_warning("Filmix bundled catalog rejected")
	# Optional local research is applied last; zero/missing values cannot
	# replace known durations. Separate cache prevents poster collisions.
	var local:Dictionary=_read_cinema_batch("user://filmix_catalog.json",true)
	if bool(local["ok"]):incoming.append_array(local["rows"])
	else:push_warning("Filmix local catalog rejected; retaining bundled and installed data")
	var changed:=false
	var kept:Array=[]
	var archived:Dictionary=runtime_state.get("superseded_zna_film_records",{}).duplicate(true)
	for entry in media.get("films",[]):
		if str(entry.get("classification_authority",""))=="OWNER_20261125_ALL_UNCLASSIFIED_ARE_FILMS":
			archived[str(entry["id"])]=entry
			changed=true
		else:kept.append(entry)
	var index:Dictionary={}
	for i in range(kept.size()):index[str(kept[i].get("id",""))]=i
	var count:=0
	for row in incoming:
		var id:String=str(row["id"])
		if not index.has(id):
			index[id]=kept.size()
			kept.append(row)
			count+=1
			changed=true
		else:
			var at:int=int(index[id])
			var previous:Dictionary=kept[at]
			if str(previous.get("media_type",""))!=str(row.get("media_type","")):return 0
			var merged:Dictionary=_merge_cinema_record(previous,row)
			if merged.is_empty():
				push_warning("Filmix catalog identity conflict; retaining installed record "+id)
				continue
			if not _valid_cinema_record(merged,false):return 0
			if previous!=merged:
				kept[at]=merged
				changed=true
	if kept!=media.get("films",[]) or archived!=runtime_state.get("superseded_zna_film_records",{}):
		media["films"]=kept
		runtime_state["superseded_zna_film_records"]=archived
		save_world()
	return count

func read_resident_profiles() -> Array:
	var f := FileAccess.open("res://data/resident_profiles.json", FileAccess.READ)
	if f == null:
		return []
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	var roster = parsed.get("residents", [])
	return roster if typeof(roster) == TYPE_ARRAY else []

func sync_resident_profiles() -> void:
	for profile in read_resident_profiles():
		var id: String = str(profile.get("id", ""))
		if residents.has(id):
			var actor: Dictionary = residents[id]
			actor["name"] = str(profile.get("display_name", actor.get("name", "")))
			actor["appearance_profile"] = str(profile.get("appearance_profile", ""))
			if not actor.has("production_visual_ready"):
				actor["production_visual_ready"] = false # asset validation is separate

func seed_world() -> void:
	_rng_streams.clear()
	rooms.clear()
	residents.clear()
	creatures.clear()
	journal.clear()
	runtime_state.clear()
	object_events_initialized = false
	object_events_save_path = ""
	next_room_id = 1
	sim_clock = 0.0
	# Physical seed topology. These rooms are immutable after creation:
	# runtime may add rooms, but it must never merge, resize, move or rebuild seed rooms.
	if canonical_house_seed:
		CanonicalHouseSeed.build(self)
		CanonicalHouseSeed.apply_social_purposes(self)
	else:
		for record in [
			[-5,0,"arrival",1],[-4,0,"corridor",1],[-3,0,"study",1],
			[-2,0,"common",3],
			[1,0,"rest",1],[2,0,"library",1],[3,0,"music",1],
			[4,0,"cinema",1],[5,0,"lift",1],
			[5,1,"lift",1],[4,1,"corridor",1],[3,1,"private",1],
			[2,1,"private",1],[1,1,"rest",1],
			[5,-1,"lift",1],[4,-1,"corridor",1],[3,-1,"private",1],
			[2,-1,"private",1],[1,-1,"artifact",1]
		]:
			make_room(record[0],record[1],record[2],record[3],true)
	# All 24 canonical names/profile IDs come from 2026-11-12 approved map.
	# Only the original eight QA silhouettes are active pending actual sprite banks.
	var profiles: Array = read_resident_profiles()
	var public_start_rooms: Array = matching_rooms(["common","rest","library","study","music","cinema","workshop","artifact"]) if canonical_house_seed else []
	for i in range(profiles.size()):
		var profile: Dictionary = profiles[i]
		var id: String = profile["id"]
		if i < 8:
			var r: Dictionary = public_start_rooms[i % public_start_rooms.size()] if canonical_house_seed else get_room(-3 + i, 0)
			if r.is_empty() or not is_accessible(r):
				r = get_room(1, 0)
			residents[id] = {
				"id": id, "name": profile["display_name"], "active": true,
				"room_id": r["id"], "x": room_center_pos(r).x,
				"level": int(r["level"]), "z": 0.15,
				"intent": "REST", "phase": "idle", "until": 0.0,
				"needs": {"rest": 0.5, "social": 0.4, "curiosity": 0.5},
				"traits": {"reading": 0.45 + float(i % 3) * 0.15,
					"music": 0.2 + float(i % 4) * 0.12},
				"habits": {}, "last_location": "", "route": [], "path_index": 0,
				"appearance_profile": profile["appearance_profile"],
				"production_visual_ready": false, "visual_status": "QA_ONLY"
			}
		else:
			residents[id] = {
				"id": id, "name": profile["display_name"], "active": false,
				"room_id": "", "appearance_profile": profile["appearance_profile"],
				"production_visual_ready": false,
				"visual_status": "ASSET_GATED"
			}
	if canonical_house_seed:
		CanonicalHouseSeed.assign_homes(self,profiles)
	# Manka is not a generic human resident.
	var manka_room:Dictionary=get_room(-3,1) if canonical_house_seed else get_room(0,0)
	residents["MANJKA"] = {"id": "MANJKA", "name": "Манька", "active": true,
		"room_id": manka_room["id"], "x": room_center_pos(manka_room).x if canonical_house_seed else 0.0, "level": int(manka_room["level"]), "z": 0.7,
		"intent": "EXPLORE", "phase": "idle", "until": 0.0,
		"needs": {"rest": 0.4, "social": 0.15, "curiosity": 0.9},
		"traits": {"reading": 0.0, "music": 0.0}, "habits": {}, "last_location": "",
		"route": [], "path_index": 0}
	media = {"books": [], "films": [], "tracks": []}
	objects = {}
	creatures = {}
	journal = []
	runtime_state = {"architecture_revision":CanonicalHouseSeed.REVISION} if canonical_house_seed else {}

func _initial_seed_cell(room: Dictionary) -> bool:
	var key: String = cell_key(int(room.get("x",0)),int(room.get("level",0)))
	return INITIAL_SEED_CELLS.get(key,"")==str(room.get("type",""))

func _remap_room_references(mapping: Dictionary) -> void:
	for collection in [residents,creatures]:
		for id in collection:
			var entity:Dictionary=collection[id]
			for key in ["room_id","home_room_id","station_room_id","route_target_room_id","route_origin_room_id"]:
				var old_id: String = str(entity.get(key,""))
				if mapping.has(old_id):
					entity[key]=mapping[old_id]
			var route:Array=entity.get("route",[])
			var remapped:Array=[]
			for old_id in route:
				var next_id: String = str(mapping.get(str(old_id),str(old_id)))
				if remapped.is_empty() or str(remapped[-1])!=next_id:
					remapped.append(next_id)
			if not route.is_empty():
				entity["route"]=remapped
			for point in entity.get("waypoints",[]):
				if typeof(point)==TYPE_DICTIONARY:
					var point_room: String = str(point.get("room_id",""))
					if mapping.has(point_room):
						point["room_id"]=mapping[point_room]
	for object_id in objects:
		var object:Dictionary=objects[object_id]
		for key in ["current_room_id","home_room_id","canonical_home_room_id","location_room_id"]:
			var old_id: String = str(object.get(key,""))
			if mapping.has(old_id):
				object[key]=mapping[old_id]
	for category in media:
		for item in media.get(category,[]):
			if typeof(item)==TYPE_DICTIONARY:
				var old_id: String = str(item.get("location_room_id",""))
				if mapping.has(old_id):
					item["location_room_id"]=mapping[old_id]

func _migrate_legacy_topology() -> bool:
	var needs_migration: bool = false
	for room in rooms:
		if int(room.get("topology_version",0))<2:
			needs_migration=true
			break
	if not needs_migration:
		for room in rooms:
			room_space.ensure_room_shape(room)
		return false
	var source:Array=rooms.duplicate(true)
	source.sort_custom(func(a,b):
		if int(a["level"])!=int(b["level"]):
			return int(a["level"])<int(b["level"])
		return int(a["x"])<int(b["x"]))
	var visited:Dictionary={}
	var mapping:Dictionary={}
	var migrated:Array=[]
	for legacy in source:
		var legacy_id: String = str(legacy.get("id",""))
		if visited.has(legacy_id):
			continue
		var run:Array=[legacy]
		visited[legacy_id]=true
		if MERGEABLE_TYPES.has(str(legacy.get("type",""))):
			var next_x: int = int(legacy.get("x",0))+1
			var legacy_is_seed: bool = _initial_seed_cell(legacy)
			while run.size()<3:
				var found:Dictionary={}
				for candidate in source:
					if visited.has(str(candidate.get("id",""))):
						continue
					if int(candidate.get("level",0))==int(legacy.get("level",0)) and (
							int(candidate.get("x",0))==next_x) and (
							str(candidate.get("type",""))==str(legacy.get("type",""))) and (
							_initial_seed_cell(candidate)==legacy_is_seed):
						found=candidate
						break
				if found.is_empty():
					break
				run.append(found)
				visited[str(found["id"])]=true
				next_x+=1
		var physical:Dictionary=run[0].duplicate(true)
		var immutable: bool = true
		for member in run:
			if not _initial_seed_cell(member):
				immutable=false
				break
		physical["size_modules"]=run.size()
		physical["size_id"]=room_space.size_id(run.size())
		physical["topology_version"]=2
		physical["immutable_topology"]=immutable
		physical["topology_origin"]="seed_migration" if immutable else "legacy_migration"
		physical["connectors"]=room_space.default_connectors(str(physical.get("type","")),run.size())
		for member in run:
			mapping[str(member.get("id",""))]=str(physical.get("id",""))
		migrated.append(physical)
	rooms=migrated
	_remap_room_references(mapping)
	return true

func _read_snapshot(path: String) -> Dictionary:
	_last_validated_snapshot_sha=""
	_snapshot_full_validation_count+=1
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var expected_length:int=file.get_length()
	var bytes:PackedByteArray=file.get_buffer(expected_length)
	file.close()
	if bytes.size()!=expected_length:return {}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var parsed = parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var schema=parsed.get("schema",0)
	if typeof(schema) not in [TYPE_INT,TYPE_FLOAT] or float(schema) not in [1.0,2.0]:return {}
	if typeof(parsed.get("rooms",null))!=TYPE_ARRAY or typeof(parsed.get("residents",null))!=TYPE_DICTIONARY:return {}
	# Validate containers before typed assignment or migration. Legacy schema 1
	# may omit newer optional containers; schema 2 writes all of them.
	for key in ["media","objects","creatures","runtime_state"]:
		if (int(schema)==2 or parsed.has(key)) and typeof(parsed.get(key,null))!=TYPE_DICTIONARY:return {}
	if (int(schema)==2 or parsed.has("journal")) and typeof(parsed.get("journal",null))!=TYPE_ARRAY:return {}
	var state:Dictionary=parsed.get("runtime_state",{})
	var streams=state.get("decision_rng_v1",{})
	if typeof(streams)!=TYPE_DICTIONARY:return {}
	for domain in streams:
		if not RNG_STREAM_SEEDS.has(domain) or not _valid_rng_state(streams[domain]):return {}
	var drinks=state.get("beverages",{})
	if typeof(drinks)!=TYPE_DICTIONARY:return {}
	if drinks.has("rng_state") and not _valid_rng_state(drinks["rng_state"]):return {}
	if streams.has("beverages") and drinks.has("rng_state") and streams["beverages"]!=drinks["rng_state"]:return {}
	var saved_clock=parsed.get("sim_clock",0.0)
	if typeof(saved_clock) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(saved_clock)) or float(saved_clock)<0.0:return {}
	if int(schema)==2 and not parsed.has("sim_clock"):return {}
	var next_id=parsed.get("next_room_id",parsed["rooms"].size()+1)
	if typeof(next_id) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(next_id)) or float(next_id)<1.0 or floor(float(next_id))!=float(next_id):return {}
	var room_ids:Dictionary={}
	if parsed["rooms"].is_empty():return {}
	for room in parsed["rooms"]:
		if typeof(room)!=TYPE_DICTIONARY:return {}
		var id:String=str(room.get("id",""))
		if id=="" or room_ids.has(id):return {}
		room_ids[id]=true
		for field in ["x","level"]:
			var coordinate=room.get(field,null)
			if typeof(coordinate) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(coordinate)):return {}
		if typeof(room.get("type",null))!=TYPE_STRING:return {}
	for key in ["residents","objects","creatures"]:
		for row in parsed.get(key,{}).values():
			if typeof(row)!=TYPE_DICTIONARY:return {}
	var catalog:Dictionary=parsed.get("media",{})
	for key in ["books","films","tracks"]:
		if catalog.has(key) and typeof(catalog[key])!=TYPE_ARRAY:return {}
	var hashing:=HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256)!=OK or hashing.update(bytes)!=OK:return {}
	_last_validated_snapshot_sha=hashing.finish().hex_encode()
	return parsed

func _primary_is_valid_for_rotation()->bool:
	if _verified_primary_path==save_path and _verified_primary_sha!="" and FileAccess.get_sha256(save_path)==_verified_primary_sha:
		_snapshot_digest_hits+=1
		return true
	return not _read_snapshot(save_path).is_empty()

func _existing_world_evidence()->bool:
	# Scratch files and sidecars are evidence too. Never automatically adopt
	# an uncommitted scratch generation or reseed over orphaned event truth.
	for suffix in ["",".bak",".tmp",".corrupt",
			".world_events_v1.json",".world_events_v1.json.bak",
			".world_events_v1.json.tmp",".world_events_v1.json.corrupt",
			".world_events_v1.sqlite",".world_events_v1.sqlite.bak",
			".world_events_v1.sqlite.corrupt",".world_events_v1.sqlite-wal",
			".world_events_v1.sqlite-shm",".world_events_v1.sqlite.canonical.json",
			".world_events_v1.sqlite.canonical.json.tmp"]:
		var candidate:String=save_path+str(suffix)
		if FileAccess.file_exists(candidate) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate)):return true
	return false

func _block_world_recovery(status:String,message:String)->bool:
	recovery_blocked=true
	load_status=status
	load_error=message
	push_warning(message)
	return false

func load_or_seed() -> bool:
	recovery_blocked=false
	load_status="LOADING"
	load_error=""
	last_checkpoint_clock=-1.0
	_verified_primary_path=""
	_verified_primary_sha=""
	_rng_streams.clear()
	var parsed: Dictionary = _read_snapshot(save_path)
	if not parsed.is_empty():
		_verified_primary_path=save_path
		_verified_primary_sha=_last_validated_snapshot_sha
	var from_backup:bool=false
	if parsed.is_empty():
		parsed = _read_snapshot(save_path + ".bak")
		from_backup=not parsed.is_empty()
	if parsed.is_empty():
		if _existing_world_evidence():
			return _block_world_recovery("SNAPSHOT_RECOVERY_REQUIRED","No valid world snapshot; existing save evidence retained.")
		seed_world()
		if not _ensure_object_events():
			return _block_world_recovery("EVENT_RECOVERY_REQUIRED","Cannot initialize object event store; world not started.")
		if not save_world():
			return _block_world_recovery("INITIAL_SAVE_FAILED","Cannot commit initial world snapshot; world not started.")
		load_status="SEEDED"
		return true
	rooms.assign(parsed["rooms"])
	var social_changed:bool=CanonicalHouseSeed.apply_social_purposes(self) if canonical_house_seed else false
	residents = parsed["residents"]
	media = parsed.get("media", {"books": [], "films": [], "tracks": []})
	objects = parsed.get("objects", {})
	creatures = parsed.get("creatures", {})
	journal = parsed.get("journal", [])
	runtime_state = parsed.get("runtime_state", {})
	next_room_id = int(parsed.get("next_room_id", rooms.size() + 1))
	sim_clock = float(parsed.get("sim_clock", 0.0))
	last_checkpoint_clock=sim_clock
	for saved_room in rooms:
		if saved_room.get("type", "") == "private" and not saved_room.has("public_frontage"):
			saved_room["public_frontage"] = true
		if saved_room.get("type","") == "guest":
			if not saved_room.has("public_frontage"):
				saved_room["public_frontage"] = true
			if not saved_room.has("guest_access_state"):
				saved_room["guest_access_state"] = "open"
			if not saved_room.has("display_name"):
				saved_room["display_name"] = "Гостевая"
	var migrated: bool = _migrate_legacy_topology()
	sync_resident_profiles()
	object_events_initialized = false
	object_events_save_path = ""
	if not _ensure_object_events():
		return _block_world_recovery("EVENT_RECOVERY_REQUIRED","Object event recovery failed; saved world retained.")
	if not reconcile_object_carriers():
		return _block_world_recovery("CARRIER_RECOVERY_REQUIRED","Object holder conflicts require recovery; saved world retained.")
	if migrated or social_changed:
		if not save_world():
			return _block_world_recovery("MIGRATION_SAVE_FAILED","Cannot commit migrated world; saved world retained.")
	load_status="RECOVERED_BACKUP" if from_backup else "LOADED"
	return true

func checkpoint_if_due() -> bool:
	if recovery_blocked:return false
	if last_checkpoint_clock<0.0 or sim_clock-last_checkpoint_clock>=CHECKPOINT_INTERVAL_SECONDS:
		return save_world()
	return true

func save_world() -> bool:
	if recovery_blocked:return false
	if not _write_snapshot():
		return _block_world_recovery("CHECKPOINT_WRITE_FAILED","Cannot commit world checkpoint; simulation stopped and recovery files retained.")
	last_checkpoint_clock=sim_clock
	return true

func _write_snapshot() -> bool:
	_capture_decision_rng()
	var scratch: String = save_path + ".tmp"
	var backup: String = save_path + ".bak"
	var data: Dictionary = {"schema": 2,"rooms": rooms,"residents": residents,
		"creatures":creatures,"journal":journal,"runtime_state":runtime_state,"media": media,"objects": objects,
		"next_room_id": next_room_id,"sim_clock": sim_clock}
	var file := FileAccess.open(scratch,FileAccess.WRITE)
	if file == null:
		return false
	# Same schema and numeric encoding; no presentation whitespace needed
	# in the frequently written machine checkpoint.
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error:Error=file.get_error()
	file.close()
	if write_error!=OK:return false
	# Verify before touching the last readable snapshot.
	if _read_snapshot(scratch).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
		return false
	var scratch_sha:String=_last_validated_snapshot_sha
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_tmp := ProjectSettings.globalize_path(scratch)
	var absolute_backup := ProjectSettings.globalize_path(backup)
	# Never rotate a corrupt primary over the last readable generation.
	# If interrupted after rotation, load_or_seed can still read .bak.
	if FileAccess.file_exists(save_path):
		if _primary_is_valid_for_rotation():
			if FileAccess.file_exists(backup) and DirAccess.remove_absolute(absolute_backup)!=OK:
				return false
			if DirAccess.rename_absolute(absolute_save,absolute_backup)!=OK:
				return false
		else:
			# Recovery from .bak: retain it until a later VALID primary can
			# replace it. A failed promotion must not consume that backup.
			if DirAccess.remove_absolute(absolute_save)!=OK:
				return false
	if DirAccess.rename_absolute(absolute_tmp,absolute_save)!=OK:
		return false
	_verified_primary_path=save_path
	_verified_primary_sha=scratch_sha
	return true

func import_catalog(path: String) -> bool:
	# Explicit import of verified manifest, preserving physical book truth.
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return false
	var parsed: Dictionary = parser.data
	var imported: Dictionary = {}
	for category in ["books","films","tracks"]:
		var items = parsed.get(category,parsed.get("audio",[]) if category == "tracks" else [])
		if typeof(items) != TYPE_ARRAY:
			return false
		var unique: Dictionary = {}
		for item in items:
			if typeof(item) != TYPE_DICTIONARY or not item.has("id") or not item.has("title"):
				return false
			var id: String = str(item["id"])
			if id == "" or unique.has(id):
				return false
			unique[id] = true
		imported[category] = items
	# Import is additive. An unrelated category or omitted item must not erase a
	# physical volume, its holder, reading progress, or the existing catalogue.
	var merged:Dictionary=media.duplicate(true)
	for category in ["books","films","tracks"]:
		var records:Array=merged.get(category,[])
		var indices:Dictionary={}
		for idx in range(records.size()):
			indices[str(records[idx].get("id",""))]=idx
		for incoming in imported[category]:
			var id:String=str(incoming["id"])
			if not indices.has(id):
				records.append(incoming.duplicate(true))
				indices[id]=records.size()-1
				continue
			var index:int=int(indices[id])
			var old:Dictionary=records[index]
			var updated:Dictionary=old.duplicate(true)
			updated.merge(incoming,true)
			if category=="books":
				for field in ["holder_id","location_room_id","idle_since","progress_by_actor","owner_id","borrowed_at","home_room_id","last_interaction_at","physical_item_id","work_id","home_slot_id"]:
					if old.has(field):
						updated[field]=old[field]
				if bool(old.get("physical",true)):
					updated["physical"]=true
					updated["catalog_only"]=false
			records[index]=updated
		merged[category]=records
	var previous:Dictionary=media
	media=merged
	if save_world():
		return true
	media=previous
	return false
