extends SceneTree
const W = preload("res://scripts/world_model.gd")
const LOC = preload("res://scripts/room_locomotion.gd")

func _initialize() -> void:
	var w = W.new()
	w.save_path = "user://test_cutaway_groups_only.json"
	w.seed_world()
	var group: Dictionary = w.merged_group(-1,0)
	assert(group["width"] == 3 and group["x_start"] == -2 and group["x_end"] == 0)
	var groups: Array = w.visual_groups()
	assert(groups.size() == 19, "21 modules with one 3-wide Common = 19 visible shells")
	assert(groups.filter(func(g): return g["type"] == "common").size() == 1)
	assert(w.find_route(w.get_room(4,1)["id"], w.get_room(1,1)["id"], "RES_01").size() == 4,
		"Private door facades must allow PUBLIC corridor traversal")
	assert(w.find_route(w.get_room(4,1)["id"], w.get_room(3,1)["id"], "RES_01").is_empty(),
		"Corridor transit is NOT entry into private room")
	var route: Array = w.find_route(w.get_room(4,1)["id"], w.get_room(1,1)["id"], "RES_01")
	var actor: Dictionary = w.residents["RES_01"]
	actor["room_id"] = w.get_room(4,1)["id"]
	actor["x"] = 4.0*w.MODULE_W
	actor["level"] = 1
	actor["visual_y"] = w.FLOOR_H
	var loc = LOC.new()
	var points: Array = loc.build_waypoints(w, actor, route, "REST")
	var frontage_seen := 0
	for waypoint in points:
		var cell: Dictionary = w.room_by_id(waypoint["room_id"])
		if cell["type"] == "private":
			frontage_seen += 1
			assert(float(waypoint["position"][2]) >= loc.PUBLIC_FRONTAGE_Z - 0.005,
				"Actor must remain in public foreground while passing a private door")
	assert(frontage_seen > 0, "Trace must contain private-frontage walking")
	assert(w.build(0,1,"rest"), "Build second merged rest module on upper floor")
	assert(w.build(-1,1,"rest"), "Build third merged rest module on upper floor")
	assert(w.merged_group(0,1)["width"] == 3)
	assert(not w.can_build(-2,1,"rest"), "R4 must be rejected; width limit is R3")
	assert(w.can_build(-2,1,"library"), "Different type may be adjacent without merging")
	assert(w.get_room(0,1)["id"] != w.get_room(1,1)["id"],
		"Merge must preserve stable cell IDs")
	assert(w.visual_groups().size() == groups.size(),
		"Two new cells merged into one existing group must not add shells")
	var room_ids: Dictionary = {}
	for g in w.visual_groups():
		for cell in g["cells"]:
			assert(not room_ids.has(cell["id"]), "Cell cannot belong to two visual groups")
			room_ids[cell["id"]] = true
	assert(room_ids.size() == w.rooms.size(), "No cell lost in visual grouping")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+".bak"))
	print("CUTAWAY_GROUP_TEST_PASS old=19 merged_rest=3 private_frontage=",frontage_seen)
	quit(0)

