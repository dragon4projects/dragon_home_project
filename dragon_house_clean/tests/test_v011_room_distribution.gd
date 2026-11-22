extends SceneTree
const World=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

func _initialize()->void:
	call_deferred("run")

func _reserve(life,world,actor:Dictionary,room:Dictionary,intent:String)->void:
	var claim:Dictionary=life.stations.single(world,actor,room,intent)
	assert(not claim.is_empty())
	life.stations.commit_claim(actor,claim)
	actor["phase"]="perform"
	actor["intent"]=intent
	actor["room_id"]=room["id"]

func run()->void:
	var world=World.new()
	world.save_path="user://v011_distribution_test.json"
	world.seed_world()
	var life=Life.new()
	life.setup(world)

	var rest0:Dictionary=world.get_room(1,0)
	var rest1:Dictionary=world.get_room(1,1)
	var ids:Array=[]
	for id in world.residents:
		if id!="MANJKA" and world.residents[id].get("active",false):
			ids.append(id)
	ids.sort()
	for i in range(4):
		_reserve(life,world,world.residents[ids[i]],rest0,"REST")
	var chooser:Dictionary=world.residents[ids[4]]
	var pick:Dictionary=life.best_destination(chooser,[rest0,rest1])
	assert(not pick.is_empty())
	assert(str(pick["room"]["id"])==str(rest1["id"]),
		"less occupied rest room should beat crowded nearest room")

	# In one merged Common R3, cell pressure must spread subsequent choices.
	for id in ids:
		life.stations.release(world.residents[id])
		world.residents[id]["phase"]="idle"
	var common:Array=[world.get_room(-2,0),world.get_room(-1,0),world.get_room(0,0)]
	var chosen:Array=[]
	for i in range(6):
		var actor:Dictionary=world.residents[ids[i]]
		var option:Dictionary=life.best_destination(actor,common)
		assert(not option.is_empty())
		var room:Dictionary=option["room"]
		chosen.append(int(room["x"]))
		_reserve(life,world,actor,room,"GET_COFFEE")
	var counts:Dictionary={-2:0,-1:0,0:0}
	for x in chosen:
		counts[x]=int(counts[x])+1
	var values:Array=counts.values()
	values.sort()
	assert(int(values[-1])-int(values[0])<=1,
		"merged R3 should distribute reservations across cells")
	print("DRAGON_V011_ROOM_DISTRIBUTION_PASS rest_spread=true common_R3_counts=",counts)
	quit(0)
