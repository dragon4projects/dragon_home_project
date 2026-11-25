extends SceneTree
const W=preload("res://scripts/world_model.gd")

func _initialize()->void:
	var world=W.new()
	world.canonical_house_seed=true
	world.seed_world()
	# Every indexed geometric neighbor list must match the original scan,
	# including tie-breaking order. Check actual room IDs, not just degree.
	var index:Dictionary=world.route_geometry_index()
	var edges:=0
	for room in world.rooms:
		var expected:Array=[]
		for other in world.rooms:
			if not world.connection_between(room,other).is_empty():
				expected.append(str(other["id"]))
		var actual:Array=[]
		for other in world.indexed_geometry_neighbors(room,index):
			actual.append(str(other["id"]))
		assert(expected==actual,str([room["id"],expected,actual]))
		edges+=actual.size()
	assert(edges==148)
	var samples:Array=[]
	for x in [-7,0,7]:
		for level in [-2,0,3]:
			samples.append(world.get_room(x,level))
	samples.append(world.get_room(-3,1))
	samples.append(world.get_room(4,2))
	var cases:=0
	for start in samples:
		for target in world.rooms:
			var owner:String=str(target.get("owner_id",""))
			for actor in ["MANJKA",owner if owner!="" else "RES_01"]:
				var a:Array=world.find_route(str(start["id"]),str(target["id"]),actor)
				world.canonical_house_seed=false
				var b:Array=world.find_route(str(start["id"]),str(target["id"]),actor)
				world.canonical_house_seed=true
				assert(a==b,str([start["id"],target["id"],actor,a,b]))
				cases+=1
	# Live access changes must not be hidden by a geometry cache.
	var guest:Dictionary=world.get_room(-6,-2)
	guest["owner_id"]="NPC_CENTAUR"
	guest["guest_access_state"]="closed"
	var from:Dictionary=world.get_room(-7,3)
	assert(world.find_route(str(from["id"]),str(guest["id"]),"RES_01").is_empty())
	assert(not world.find_route(str(from["id"]),str(guest["id"]),"NPC_CENTAUR").is_empty())
	guest["guest_access_state"]="open"
	assert(not world.find_route(str(from["id"]),str(guest["id"]),"RES_01").is_empty())
	# Expansion after the first route must participate without stale indices.
	var extra:Dictionary=world.make_room(8,0,"rest",1)
	assert(not world.find_route(str(from["id"]),str(extra["id"]),"RES_01").is_empty())
	print("CANONICAL_ROUTE_INDEX_PASS directed_edges=",edges," exact_route_parity_cases=",cases," live_access=true expansion=true")
	quit(0)
