extends RefCounted
## Adapted from old RC1.5 semantic_stream_v2.gd/runtime_camera.gd.
## Keeps semantic HOUSE/LEVEL/ROOM/FOLLOW state independent from camera numerics.

const MODES := ["HOUSE","LEVEL","ROOM","FOLLOW"]

var mode := "HOUSE"
var level := 0
var active_room := ""
var revision := 0
# Visibility of the building is independent from semantic camera focus.
var all_levels_visible := false

func install(world, initial_mode: String = "HOUSE") -> void:
	mode = initial_mode if initial_mode in MODES else "HOUSE"
	var levels := available_levels(world)
	level = 0 if levels.has(0) else (int(levels[0]) if not levels.is_empty() else 0)

func available_levels(world) -> Array:
	var seen: Dictionary = {}
	for room in world.rooms:
		seen[int(room.get("level",0))] = true
	var levels: Array = seen.keys()
	levels.sort()
	return levels

func select_level(world, requested: int) -> int:
	var levels := available_levels(world)
	if levels.is_empty():
		level = 0
		return level
	if levels.has(requested):
		level = requested
	else:
		var best := int(levels[0])
		var distance: int = absi(best-requested)
		for raw in levels:
			var candidate := int(raw)
			var d: int = absi(candidate-requested)
			if d < distance:
				distance = d
				best = candidate
		level = best
	revision += 1
	return level

func step_level(world, delta: int) -> int:
	var levels := available_levels(world)
	if levels.is_empty():
		return select_level(world,0)
	var index := levels.find(level)
	if index < 0:
		index = 0
	index = clampi(index+delta,0,levels.size()-1)
	return select_level(world,int(levels[index]))

func set_view(world, view_mode: String, room_id: String = "",
		follow_level: Variant = null) -> void:
	var next_mode := view_mode if view_mode in MODES else mode
	var next_room := room_id
	var next_level := level
	if follow_level != null:
		next_level = int(follow_level)
	elif room_id != "":
		var room: Dictionary = world.room_by_id(room_id)
		if not room.is_empty():
			next_level = int(room.get("level",level))
	var changed := next_mode != mode or next_room != active_room or next_level != level
	mode = next_mode
	active_room = next_room
	level = next_level
	if changed:
		revision += 1

func group_visible(group: Dictionary) -> bool:
	if all_levels_visible or mode == "HOUSE":
		return true
	var group_level := int(group.get("level",0))
	if group_level == level:
		return true
	# Keep one adjacent lift cell as connector context, mirroring the old RC
	# semantic-stream rule without loading remote floor detail.
	return str(group.get("type","")) == "lift" and abs(group_level-level) == 1

func actor_visible(actor: Dictionary) -> bool:
	if all_levels_visible or mode == "HOUSE":
		return true
	return int(actor.get("level",0)) == level

func snapshot() -> Dictionary:
	return {
		"mode":mode,
		"level":level,
		"active_room":active_room,
		"revision":revision
	}
