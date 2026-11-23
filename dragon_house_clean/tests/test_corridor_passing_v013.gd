extends SceneTree
const World=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

func _initialize()->void:
	call_deferred("run")

func _travel(actor:Dictionary, room_id:String, from_x:float, to_x:float)->void:
	actor["x"]=from_x
	actor["visual_y"]=0.0
	actor["level"]=0
	actor["z"]=0.95
	actor["room_id"]=room_id
	actor["phase"]="travel"
	actor["waypoint_index"]=0
	actor["waypoints"]=[{
		"position":[to_x,0.0,0.95],
		"room_id":room_id,
		"kind":"room_center"
	}]

func run()->void:
	var world=World.new()
	world.save_path="user://v013_passing_test.json"
	world.seed_world()
	var life=Life.new()
	life.setup(world)
	var room:Dictionary=world.get_room(-1,0)
	var a:Dictionary=world.residents["RES_01"]
	var b:Dictionary=world.residents["RES_02"]
	life.stations.release(a)
	life.stations.release(b)

	# Opposing residents must form two transient depth lanes instead of
	# occupying the same point while crossing.
	_travel(a,room["id"],-1.6,1.6)
	_travel(b,room["id"],1.6,-1.6)
	var minimum_distance:=999.0
	var maximum_lane_separation:=0.0
	for i in range(80):
		life._move(a,0.05)
		life._move(b,0.05)
		var pa:=Vector3(float(a["x"]),float(a["visual_y"]),float(a["z"]))
		var pb:=Vector3(float(b["x"]),float(b["visual_y"]),float(b["z"]))
		minimum_distance=minf(minimum_distance,pa.distance_to(pb))
		maximum_lane_separation=maxf(maximum_lane_separation,absf(pa.z-pb.z))
	assert(maximum_lane_separation>=0.22,
		"Opposing walkers never formed visible passing lanes")
	assert(minimum_distance>=0.18,
		"Opposing walkers still occupied effectively the same point")
	assert(str(a["phase"])=="perform" and str(b["phase"])=="perform")
	assert(absf(float(a["z"])-0.95)<0.03 and absf(float(b["z"])-0.95)<0.03,
		"Transient lanes must converge back to authored aisle")

	# Same-direction following: the rear resident yields for one tick rather
	# than stepping through the resident immediately ahead.
	_travel(a,room["id"],0.0,2.6)
	_travel(b,room["id"],0.34,2.6)
	var before_x:float=float(a["x"])
	life._move(a,0.10)
	assert(is_equal_approx(float(a["x"]),before_x))
	assert(str(a.get("moving_axis",""))=="wait")
	life._move(b,0.10)
	life._move(b,0.10)
	life._move(a,0.10)
	assert(float(a["x"])>before_x,
		"Rear resident must resume once the following gap reopens")

	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path+suffix))
	print("CORRIDOR_PASSING_V013_PASS min_distance=%.3f lane_sep=%.3f following=yield_resume" % [
		minimum_distance,maximum_lane_separation])
	quit(0)
