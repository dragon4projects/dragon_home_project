extends SceneTree
const WorldScript = preload("res://scripts/world_model.gd")
const LifeScript = preload("res://scripts/life.gd")

func _initialize() -> void:
	var model = WorldScript.new()
	model.save_path = "user://test_model_world_only.json"
	model.seed_world()
	assert(model.rooms.size() == 21, "Initial cutaway map must be 21 cells")
	assert(model.residents.size() == 25, "24 canonical slots + Manjka")
	assert(model.residents["RES_24"]["active"] == false, "Never invent unavailable identity")
	var core: Dictionary = model.get_room(-2, 0)
	assert(model.merged_run_length(-2, 0) == 3, "Three-wide common room")
	var upper: Dictionary = model.get_room(4, 1)
	var route: Array = model.find_route(core["id"], upper["id"], "MANJKA")
	assert(route.size() > 3, "Navigation must reach upper band through lift")
	var priv: Dictionary = model.get_room(3, 1)
	assert(model.find_route(core["id"], priv["id"], "MANJKA").is_empty(),
		"Private room must not leak to Manka")
	assert(not model.build(3, 1, "library"), "Cannot overwrite private room")
	assert(not model.build(10, 5, "music"), "Cannot create isolated room")
	assert(model.build(6, 0, "workshop"), "Expansion should attach to lift")
	assert(model.get_room(6, 0)["type"] == "workshop")
	var life = LifeScript.new()
	life.setup(model)
	for i in range(180):
		life.tick(1.0)
	assert(life.steps > 1, "Autonomous plan scheduler must make choices")
	assert(life.log.size() > 0, "Human-readable house log must exist")
	assert(model.media["films"].is_empty(), "Do not fabricate film catalog")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(model.save_path))
	print("DRAGON_HOUSE_MODEL_TEST_PASS room=22 slot=24+Manka route=", route.size(),
		" autonomy_actions=", life.steps)
	quit(0)

