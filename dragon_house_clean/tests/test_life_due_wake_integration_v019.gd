extends SceneTree
const World = preload("res://scripts/world_model.gd")
const Life = preload("res://scripts/life.gd")

func _initialize() -> void:
	call_deferred("run")

func _cleanup(path: String) -> void:
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))

func run() -> void:
	var path := "user://life_due_wake_v019.json"
	_cleanup(path)
	var world := World.new()
	world.save_path = path
	world.seed_world()
	var life := Life.new()
	life.setup(world)

	var active_ids: Array = []
	for id in world.residents:
		if bool(world.residents[id].get("active",false)):
			active_ids.append(str(id))
	assert(life.life_scheduler.due_at.size()==active_ids.size())
	assert(life.planner_calls==0)

	for _i in range(5):
		life.tick(0.01)
	assert(life.planner_calls < active_ids.size())
	assert(int(world.runtime_state["life_scheduler_metrics"]["planner_calls"])==life.planner_calls)

	var target := ""
	for id in active_ids:
		if life.life_scheduler.peek_due_at(id) > life.clock + 0.1:
			target = id
			break
	assert(target!="")
	var actor: Dictionary = world.residents[target]
	actor["phase"]="idle"
	actor["until"]=0.0
	var before := life.planner_calls
	life.wake_actor(target,"QA_WAKE")
	life.tick(0.01)
	assert(life.planner_calls==before+1)
	assert(life.life_scheduler.peek_due_at(target)>life.clock)

	assert(world.save_world())
	var loaded := World.new()
	loaded.save_path = path
	loaded.load_or_seed()
	assert(typeof(loaded.runtime_state.get("life_scheduler",null))==TYPE_DICTIONARY)
	var life2 := Life.new()
	life2.setup(loaded)
	assert(life2.life_scheduler.due_at.size()>0)
	assert(int(life2.life_scheduler.sequence)>=int(world.runtime_state["life_scheduler"]["sequence"]))

	_cleanup(path)
	print("LIFE_DUE_WAKE_INTEGRATION_V019_PASS planner_due_only=yes explicit_wake=yes snapshot_restore=yes")
	quit(0)
