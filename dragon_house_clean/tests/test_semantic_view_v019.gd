extends SceneTree
const World = preload("res://scripts/world_model.gd")
const SemanticView = preload("res://scripts/semantic_view_v019.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	world.seed_world()
	var view := SemanticView.new()
	view.install(world,"HOUSE")
	assert(view.available_levels(world)==[-1,0,1])
	assert(view.mode=="HOUSE")
	for group in world.visual_groups():
		assert(view.group_visible(group))

	view.select_level(world,0)
	view.set_view(world,"LEVEL","",0)
	assert(view.mode=="LEVEL" and view.level==0)
	for group in world.visual_groups():
		var level := int(group["level"])
		var kind := str(group["type"])
		var expected: bool = level==0 or (kind=="lift" and absi(level)<=1)
		assert(view.group_visible(group)==expected)

	assert(view.step_level(world,1)==1)
	view.set_view(world,"LEVEL","",1)
	assert(view.level==1)
	assert(view.step_level(world,1)==1)
	assert(view.step_level(world,-1)==0)
	assert(view.step_level(world,-1)==-1)

	var common: Dictionary = world.get_room(-1,0)
	view.set_view(world,"ROOM",str(common["id"]))
	assert(view.mode=="ROOM" and view.level==0 and view.active_room==str(common["id"]))
	view.set_view(world,"FOLLOW",str(common["id"]),1)
	assert(view.mode=="FOLLOW" and view.level==1)

	for mode in view.MODES:
		view.set_view(world,mode,"",0)
		for all_visible in [false,true]:
			view.all_levels_visible=all_visible
			assert(not view.actor_visible({"active":false,"level":0}))
			assert(view.actor_visible({"active":true,"level":0}))
	print("SEMANTIC_VIEW_V019_PASS modes=HOUSE_LEVEL_ROOM_FOLLOW levels=-1_0_1 connector_context=yes")
	quit(0)
