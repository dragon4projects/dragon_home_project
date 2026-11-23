extends RefCounted
## Low-frequency ambient creature actions.
## This layer may move only explicit creature actors and explicit opt-in objects.
## It never opens private rooms, invents ownership, or duplicates an object identity.

var world
var rng := RandomNumberGenerator.new()
var max_actions_per_tick := 1
const DECISION_MIN := 6.0
const DECISION_MAX := 18.0

func setup(p_world) -> void:
	world = p_world
	rng.seed = 923118
	for id in world.creatures:
		var creature: Dictionary = world.creatures[id]
		if not creature.has("next_decision_at"):
			creature["next_decision_at"] = world.sim_clock
		if not creature.has("carried_object_id"):
			creature["carried_object_id"] = ""

func _creature(creature_id: String) -> Dictionary:
	return world.creatures.get(creature_id, {}) if world != null else {}

func public_neighbors(creature_id: String) -> Array:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty():
		return []
	var room: Dictionary = world.room_by_id(str(creature.get("room_id","")))
	if room.is_empty():
		return []
	var out: Array = []
	for candidate in world.neighbors(room, ""):
		# Public frontage of a private room is transit geometry, not creature access.
		if str(candidate.get("privacy","public")) == "public":
			out.append(candidate)
	return out

func roam_one_step(creature_id: String, target_room_id: String = "") -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or not bool(creature.get("active",false)):
		return false
	var candidates: Array = public_neighbors(creature_id)
	if candidates.is_empty():
		return false
	var target: Dictionary = {}
	if target_room_id != "":
		for candidate in candidates:
			if str(candidate.get("id","")) == target_room_id:
				target = candidate
				break
		if target.is_empty():
			return false
	else:
		target = candidates[rng.randi_range(0,candidates.size()-1)]
	var previous: String = str(creature.get("room_id",""))
	creature["room_id"] = str(target["id"])
	creature["x"] = float(target["x"]) * world.MODULE_W
	creature["level"] = int(target["level"])
	creature["z"] = 0.25
	world._append_journal("CREATURE_ROAMED", creature_id, creature_id,
		previous, str(target["id"]), {"carrying":str(creature.get("carried_object_id",""))})
	return true

func pickup_eligible_here(creature_id: String, object_id: String = "") -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or not bool(creature.get("active",false)):
		return false
	if not bool(creature.get("can_pickup_objects",false)):
		return false
	if str(creature.get("carried_object_id","")) != "":
		return false
	var room_id: String = str(creature.get("room_id",""))
	var candidates: Array = []
	for id in world.objects:
		var object: Dictionary = world.objects[id]
		if str(object.get("current_room_id","")) != room_id:
			continue
		if not world.can_ambient_pickup_object(str(id)):
			continue
		if object_id != "" and str(id) != object_id:
			continue
		candidates.append(str(id))
	if candidates.is_empty():
		return false
	var selected: String = candidates[0] if object_id != "" else candidates[rng.randi_range(0,candidates.size()-1)]
	if not world.pickup_physical_object(selected, creature_id):
		return false
	creature["carried_object_id"] = selected
	return true

func stash_carried(creature_id: String, target_room_id: String = "") -> bool:
	var creature: Dictionary = _creature(creature_id)
	if creature.is_empty() or not bool(creature.get("active",false)):
		return false
	if not bool(creature.get("can_hide_objects",false)):
		return false
	var object_id: String = str(creature.get("carried_object_id",""))
	if object_id == "":
		return false
	var object: Dictionary = world.physical_object(object_id)
	if object.is_empty() or not bool(object.get("ambient_hide_allowed",false)):
		return false
	var room_id: String = str(creature.get("room_id",""))
	if target_room_id != "" and target_room_id != room_id:
		# Hiding is physical: the creature must actually be in the destination room.
		return false
	var room: Dictionary = world.room_by_id(room_id)
	if room.is_empty() or str(room.get("privacy","public")) != "public":
		return false
	if not world.place_physical_object(object_id, creature_id, room_id, "STASHED"):
		return false
	creature["carried_object_id"] = ""
	return true

func tick(_delta: float) -> void:
	if world == null or world.creatures.is_empty():
		return
	var actions := 0
	for id in world.creatures:
		if actions >= max_actions_per_tick:
			break
		var creature: Dictionary = world.creatures[id]
		if not bool(creature.get("active",false)):
			continue
		if float(creature.get("next_decision_at",0.0)) > world.sim_clock:
			continue
		var acted := false
		if str(creature.get("carried_object_id","")) != "":
			if bool(creature.get("can_hide_objects",false)) and rng.randf() < 0.38:
				acted = stash_carried(str(id))
			if not acted:
				acted = roam_one_step(str(id))
		else:
			if bool(creature.get("can_pickup_objects",false)) and rng.randf() < 0.24:
				acted = pickup_eligible_here(str(id))
			if not acted:
				acted = roam_one_step(str(id))
		creature["next_decision_at"] = world.sim_clock + rng.randf_range(DECISION_MIN,DECISION_MAX)
		if acted:
			actions += 1
