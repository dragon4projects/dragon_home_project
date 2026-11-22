extends RefCounted
## Explicit, deterministic local station reservations. No AI/external dependency.
## Reservations live on actor state so save/load can reconstruct occupancy.
## PRIVATE rooms are never public station pools.
const CAPACITY_BY_TYPE := {
	"common": 10, "library": 4, "rest": 5, "study": 4,
	"workshop": 4, "cinema": 8, "music": 6, "artifact": 6,
	"arrival": 4, "corridor": 2, "private": 1, "lift": 0
}
const FLOOR_X_LIMIT := 2.05
const BACK_Z := -0.70
const FRONT_Z := 0.51

func capacity(room: Dictionary) -> int:
	if room.is_empty():
		return 0
	return int(CAPACITY_BY_TYPE.get(str(room.get("type","")),2))

func layout(room: Dictionary) -> Array:
	# Stations are true local XYZ offsets (x,z) inside one module, not UI dots.
	# Common R3 = 3 modules * 10 physical gathering positions = 30.
	var count := capacity(room)
	var columns := 5 if count >= 10 else 4 if count >= 8 else 3 if count >= 6 else 2
	var rows := int(ceil(float(count)/float(columns)))
	var x_span: float = minf(3.72, float(columns-1)*0.87)
	var result: Array = []
	for row in range(rows):
		var z: float = BACK_Z if rows == 1 else lerpf(BACK_Z,FRONT_Z,float(row)/float(rows-1))
		for column in range(columns):
			if result.size() >= count:
				break
			var x: float = -x_span*0.5+float(column)*(x_span/maxf(1.0,float(columns-1)))
			assert(absf(x) < FLOOR_X_LIMIT)
			result.append(Vector2(x,z))
	return result

func used_slots(world, room_id: String, ignore_ids: Array = []) -> Dictionary:
	var used: Dictionary = {}
	for id in world.residents:
		if ignore_ids.has(id):
			continue
		var actor: Dictionary = world.residents[id]
		if not bool(actor.get("active",false)):
			continue
		if str(actor.get("station_room_id","")) == room_id:
			var slot := int(actor.get("station_slot",-1))
			if slot >= 0 and str(actor.get("phase","idle")) in ["travel","perform"]:
				used[slot] = id
	return used

func available_count(world, room: Dictionary) -> int:
	if room.is_empty() or room.get("privacy","public") != "public":
		return 0
	return maxi(0,capacity(room)-used_slots(world,str(room["id"])).size())

func _claim(room: Dictionary, index: int, position: Vector2) -> Dictionary:
	return {"room_id":str(room["id"]),"slot":index,"offset":position}

func single(world, actor: Dictionary, room: Dictionary) -> Dictionary:
	var id: String = str(actor.get("id",""))
	if room.is_empty() or not world.is_accessible(room,id) or capacity(room)==0:
		return {}
	var used: Dictionary = used_slots(world,str(room["id"]),[id])
	var points: Array = layout(room)
	# If the actor is continuing a reservation, keep its exact location.
	var prior := int(actor.get("station_slot",-1))
	if str(actor.get("station_room_id","")) == room["id"] and prior >= 0 and prior < points.size() and not used.has(prior):
		return _claim(room,prior,points[prior])
	# Deterministic id rotation distributes arrivals across the room.
	var start: int = 0
	for ch in id:
		start = posmod(start*31+ch.unicode_at(0),997)
	for step in range(points.size()):
		var idx: int = (start+step)%points.size()
		if not used.has(idx):
			return _claim(room,idx,points[idx])
	return {}

func pair(world, actor: Dictionary, partner: Dictionary, room: Dictionary) -> Dictionary:
	if room.is_empty() or not world.is_accessible(room,str(actor.get("id",""))) or not world.is_accessible(room,str(partner.get("id",""))):
		return {}
	var used: Dictionary = used_slots(world,str(room["id"]),[str(actor["id"]),str(partner["id"])])
	var points: Array = layout(room)
	var columns := 5 if points.size() >= 10 else 4 if points.size() >= 8 else 3 if points.size() >= 6 else 2
	# Pair must be adjacent on the same depth row; never across the aisle.
	for left in range(points.size()-1):
		var right := left+1
		if int(left/columns) != int(right/columns) or used.has(left) or used.has(right):
			continue
		if absf(points[right].x-points[left].x) > 1.30:
			continue
		return {"actor":_claim(room,left,points[left]),
			"partner":_claim(room,right,points[right])}
	return {}

func can_reserve(world, room: Dictionary, pair_needed: bool = false) -> bool:
	if available_count(world,room) <= (1 if pair_needed else 0):
		return false
	if not pair_needed:
		return true
	# At least one adjacent free pair must exist.
	var used: Dictionary = used_slots(world,str(room["id"]))
	var points: Array = layout(room)
	var cols: int = 5 if points.size() >= 10 else 4 if points.size() >= 8 else 3 if points.size() >= 6 else 2
	for left in range(points.size()-1):
		if int(left/cols) == int((left+1)/cols) and not used.has(left) and not used.has(left+1):
			return true
	return false

func commit_claim(actor: Dictionary, claim: Dictionary) -> void:
	if claim.is_empty():
		return
	actor["station_room_id"] = claim["room_id"]
	actor["station_slot"] = claim["slot"]
	var offset: Vector2 = claim["offset"]
	actor["station_point"] = [offset.x,offset.y]

func release(actor: Dictionary) -> void:
	actor.erase("station_room_id")
	actor.erase("station_slot")
	actor.erase("station_point")

func reconcile(world) -> int:
	# Restore station invariants after loading a snapshot, without new life.
	# Prefer the lexicographically first existing claim if an old save has
	# duplicates; later actors replan normally instead of overlapping.
	var claimed: Dictionary = {}
	var fixed := 0
	var ordered: Array = world.residents.keys()
	ordered.sort()
	for id in ordered:
		var actor: Dictionary = world.residents[id]
		var room_id: String = str(actor.get("station_room_id",""))
		var slot: int = int(actor.get("station_slot",-1))
		if room_id == "" and slot == -1:
			continue
		var room: Dictionary = world.room_by_id(room_id)
		var key: String = "%s:%d" % [room_id,slot]
		var invalid: bool = not bool(actor.get("active",false)) or room.is_empty() or (
			not world.is_accessible(room,str(id))) or slot < 0 or slot >= capacity(room) or (
			not ["travel","perform"].has(str(actor.get("phase","idle")))) or claimed.has(key)
		if invalid:
			release(actor)
			# Don't keep an invalid station waypoint from a corrupted save.
			if actor.get("phase","") == "travel":
				actor["phase"] = "idle"
				actor["waypoints"] = []
				actor["waypoint_index"] = 0
				actor["until"] = world.sim_clock
			fixed += 1
		else:
			claimed[key] = true
	return fixed
