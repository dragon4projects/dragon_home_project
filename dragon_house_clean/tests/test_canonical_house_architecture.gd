extends SceneTree
const W=preload("res://scripts/world_model.gd")
const V=preload("res://scripts/semantic_view_v019.gd")
const C=preload("res://scripts/candidate_content_runtime.gd")

func _initialize()->void:
	var world=W.new()
	world.canonical_house_seed=true
	world.save_path="user://test_canonical_house_20261125.json"
	world.seed_world()
	assert(world.rooms.size()==65)
	var counts:Dictionary={}
	var occupied:Dictionary={}
	var public_rooms:Array=[]
	var homes:Array=[]
	for room in world.rooms:
		assert(bool(room["immutable_topology"]))
		assert(not world.can_reconfigure_room(str(room["id"])))
		var key:String=str(room["type"])+"/"+str(room["size_id"])
		counts[key]=int(counts.get(key,0))+1
		for x in range(int(room["x"]),int(room["x"])+int(room["size_modules"])):
			var cell:String=world.cell_key(x,int(room["level"]))
			assert(not occupied.has(cell))
			occupied[cell]=true
		if world.public_cutaway_allowed(room):
			public_rooms.append(room)
		if str(room["type"])=="private" and str(room["owner_id"])!="":
			homes.append(room)
	assert(occupied.size()==90)
	assert(counts["lift/R1"]==18)
	assert(counts["private/R1"]==32 and counts["guest/R1"]==2 and counts["guest/R2"]==1)
	assert(homes.size()==24)
	assert(world.get_room(-6,-2)["id"]==world.get_room(-5,-2)["id"])
	assert(world.get_room(-6,-2)["size_id"]=="R2")
	assert(world.get_room(-3,1)["type"]=="common")
	for level in range(-2,4):
		for x in range(-7,8):
			assert(not world.get_room(x,level).is_empty())
		for x in [-7,0,7]:
			var lift:Dictionary=world.get_room(x,level)
			assert(lift["type"]=="lift")
			if level<3:
				assert(world.connection_between(lift,world.get_room(x,level+1))["kind"]=="lift")
	for room in homes:
		var owner:String=str(room["owner_id"])
		assert(world.residents[owner]["home_room_id"]==room["id"])
		assert(not world.public_cutaway_allowed(room))
		assert(world.is_accessible(room,owner))
		assert(not world.is_accessible(room,"MANJKA"))
		assert(not world.find_route(str(public_rooms[0]["id"]),str(room["id"]),owner).is_empty())
		assert(world.find_route(str(public_rooms[0]["id"]),str(room["id"]),"MANJKA").is_empty())
	for a in public_rooms:
		for b in public_rooms:
			assert(not world.find_route(str(a["id"]),str(b["id"]),"MANJKA").is_empty())
	var view=V.new()
	view.install(world)
	view.all_levels_visible=true
	for mode in ["HOUSE","LEVEL","ROOM","FOLLOW"]:
		view.set_view(world,mode,str(public_rooms[0]["id"]),3)
		for group in world.visual_groups():
			assert(view.group_visible(group))
	var candidate=C.new()
	assert(candidate.initialize())
	var preflight:Dictionary=candidate.guest_preflight(world)
	assert(preflight["ok"] and preflight["plans"].size()==3)
	assert(candidate.apply_guest_candidate(world)["ok"])
	assert(candidate.apply_guest_candidate(world)["ok"])
	assert(world.rooms.size()==65)
	assert(world.guest_room_for("NPC_CENTAUR")["size_id"]=="R2")
	var loaded=W.new()
	loaded.canonical_house_seed=true
	loaded.save_path=world.save_path
	loaded.load_or_seed()
	assert(loaded.rooms.size()==65)
	assert(loaded.guest_room_for("NPC_CENTAUR")["size_id"]=="R2")
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path+suffix))
	print("CANONICAL_HOUSE_TOPOLOGY_PASS floors=6 cells=90 rooms=47 lift_cells=18 shafts=3 homes=24")
	quit(0)
