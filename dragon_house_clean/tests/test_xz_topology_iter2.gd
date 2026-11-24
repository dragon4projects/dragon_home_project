extends SceneTree
const W = preload("res://scripts/world_model.gd")
const S = preload("res://scripts/room_stations.gd")
const L = preload("res://scripts/room_locomotion.gd")

func _initialize() -> void:
	var w=W.new()
	w.save_path="user://test_iter2_xz_topology.json"
	w.seed_world()
	assert(w.rooms.size()==19)
	var common:Dictionary=w.get_room(-2,0)
	assert(common["id"]==w.get_room(-1,0)["id"] and common["id"]==w.get_room(0,0)["id"])
	assert(common["size_id"]=="R3" and bool(common["immutable_topology"]))
	var group:Dictionary=w.merged_group(-1,0)
	assert(group["width"]==3 and group["cells"].size()==3)
	assert(str(group["primary_id"])==str(common["id"]))
	var back_local: Vector2 = Vector2(0.0,float(w.room_space.BACK_Z)+0.08)
	assert(w.room_contains_local(common,back_local))
	var back_world: Vector3 = w.room_local_to_world(common,back_local)
	assert(is_equal_approx(back_world.z,back_local.y))
	var cinema:Dictionary=w.get_room(4,0)
	var lift0:Dictionary=w.get_room(5,0)
	var horizontal:Dictionary=w.connection_between(cinema,lift0)
	assert(horizontal.get("kind","")=="horizontal")
	assert(absf(float((horizontal["from"] as Vector3).z)-w.room_space.SIDE_CONNECTOR_Z)<0.01)
	var lift1:Dictionary=w.get_room(5,1)
	var vertical:Dictionary=w.connection_between(lift0,lift1)
	assert(vertical.get("kind","")=="lift")
	assert(is_equal_approx(float((vertical["from"] as Vector3).z),w.room_space.LIFT_CORE_Z))
	assert(is_equal_approx(float((vertical["to"] as Vector3).z),w.room_space.LIFT_CORE_Z))
	var route:Array=w.find_route(common["id"],w.get_room(4,1)["id"],"MANJKA")
	assert(route.has(lift0["id"]) and route.has(lift1["id"]))
	var locomotion=L.new()
	var actor:Dictionary={"id":"TEST_XZ","room_id":common["id"],
		"x":w.room_center_pos(common).x,"level":0,"z":1.35}
	var wall_station: Vector2 = Vector2(-5.2,-1.84)
	assert(w.room_contains_local(common,wall_station,0.05))
	var local_route:Array=[common["id"]]
	var waypoints:Array=locomotion.build_waypoints(
		w,actor,local_route,"VIEW_ART",wall_station,-1.35)
	assert(not waypoints.is_empty())
	var kinds:Array=[]
	for point in waypoints:
		kinds.append(str(point.get("kind","")))
		assert(str(point.get("room_id",""))==str(common["id"]))
	assert(kinds.has("local_aisle_entry"))
	assert(kinds.has("local_aisle"))
	assert(kinds.has("station_approach"))
	var aisle_index:int=kinds.find("local_aisle")
	var approach_index:int=kinds.find("station_approach")
	var station_index:int=kinds.find("station")
	assert(aisle_index>=0 and approach_index>aisle_index and station_index>approach_index,
		"Rear-wall interaction must route front aisle -> authored approach -> station")
	var final:Array=waypoints[-1]["position"]
	assert(absf(float(final[0])-(w.room_center_pos(common).x+wall_station.x))<0.01)
	assert(absf(float(final[2])-wall_station.y)<0.01,
		"Actor must be able to walk to a station directly at the rear wall")
	var stations=S.new()
	assert(stations.capacity(w.get_room(1,0))==4)
	assert(w.build_room(6,0,"workshop",2))
	var r2:Dictionary=w.get_room(6,0)
	assert(stations.capacity(r2)==8)
	assert(w.build_room(8,0,"artifact",1))
	assert(w.get_room(6,0)["id"]==r2["id"] and w.room_size_modules(r2)==2)
	assert(w.get_room(8,0)["id"]!=r2["id"])
	assert(w.room_space.perspective_scale(w.room_space.BACK_Z) <
		w.room_space.perspective_scale(0.0))
	assert(w.room_space.perspective_scale(0.0) <
		w.room_space.perspective_scale(w.room_space.FRONT_Z))
	assert(absf(w.room_space.perspective_scale(w.room_space.BACK_Z)-0.62)<0.001)
	assert(absf(w.room_space.perspective_scale(w.room_space.FRONT_Z)-1.0)<0.001)
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+suffix))
	print("ITER2_XZ_TOPOLOGY_PASS R1/R2/R3 immutable_seed connectors lift rear_wall_station scale_62_100")
	quit(0)
