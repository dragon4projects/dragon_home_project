extends SceneTree
const WorldScript = preload("res://scripts/world_model.gd")
const LifeScript = preload("res://scripts/life.gd")
const LocomotionScript = preload("res://scripts/room_locomotion.gd")
func _initialize() -> void:
	var w = WorldScript.new()
	w.seed_world()
	var actor: Dictionary = w.residents["RES_01"]
	var start: Dictionary = w.get_room(-3,0)
	var upper: Dictionary = w.get_room(4,1)
	actor["room_id"] = start["id"]
	actor["x"] = float(start["x"])*w.MODULE_W
	actor["level"] = 0
	actor["visual_y"] = 0.0
	actor["z"] = -0.75
	var route: Array = w.find_route(start["id"],upper["id"],"RES_01")
	assert(route.size() >= 8)
	var mover = LocomotionScript.new()
	var points: Array = mover.build_waypoints(w,actor,route,"PURPOSEFUL_EXPLORE")
	assert(points.size() > route.size())
	var lift_count := 0
	var station_count := 0
	var crossed_levels := false
	for i in range(points.size()):
		var point: Dictionary = points[i]
		if point["kind"] == "lift":
			lift_count += 1
			var room: Dictionary = w.room_by_id(point["room_id"])
			assert(room["type"] == "lift", "Vertical motion is lift-only")
			crossed_levels = true
		if point["kind"] == "station":
			station_count += 1
			assert(float(point["position"][2]) != mover.AISLE_Z)
	assert(crossed_levels and lift_count == 1 and station_count == 1)
	var life = LifeScript.new()
	life.setup(w)
	life._assign(actor,{"intent":"PURPOSEFUL_EXPLORE","room":upper})
	assert(actor["phase"] == "travel")
	var visited_depth := false
	var visited_lift := false
	for i in range(650):
		life._move(actor,0.1)
		if absf(float(actor["z"])-mover.AISLE_Z) < 0.05:
			visited_depth = true
		if float(actor.get("visual_y",0.0)) > 0.5:
			visited_lift = true
		if actor["phase"] == "perform":
			break
	assert(actor["phase"] == "perform","Must complete local station and cross-level route")
	assert(actor["room_id"] == upper["id"])
	assert(absf(float(actor["visual_y"])-w.FLOOR_H) < 0.05)
	assert(visited_depth and visited_lift)
	assert(absf(float(actor["z"])-mover.AISLE_Z) > 0.05,"Destination at actual depth")
	print("LOCOMOTION_TEST_PASS path=",route.size()," waypoints=",points.size()," lift=",lift_count)
	quit(0)

