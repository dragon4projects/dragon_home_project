extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/canonical_lift_capacity.gd")
const R=preload("res://scripts/room_locomotion.gd")
func _initialize()->void:
	var world=W.new()
	world.canonical_house_seed=true
	world.seed_world()
	var lifts=L.new()
	lifts.setup(world)
	var room:Dictionary=world.get_room(0,0)
	var destination:Dictionary=world.get_room(0,1)
	var center:Vector3=world.room_center_pos(room)
	var top:Vector3=world.room_center_pos(destination)
	var actors:Array=[]
	var slots:Dictionary={}
	var lanes:Dictionary={}
	for i in range(7):
		var actor:Dictionary={"id":"QA_LIFT_%d"%i,"room_id":room["id"],"active":true,"phase":"travel","visual_y":center.y,"waypoint_index":0,"waypoints":[{"kind":"lift"}]}
		actors.append(actor)
		var result:Dictionary=lifts.target(actor,center,top)
		if i==6:
			assert(bool(result.get("wait",false)))
			continue
		assert(bool(result.get("boarding",false)))
		var pos:Vector3=result["target"]
		assert(world.room_contains_local(room,Vector2(pos.x-center.x,pos.z)))
		assert(not slots.has(pos))
		slots[pos]=true
		lanes[pos.z]=int(lanes.get(pos.z,0))+1
		var up:Dictionary=lifts.target(actor,pos,top)
		assert(not bool(up.get("boarding",false)))
		assert(up["target"]==Vector3(pos.x,top.y,pos.z))
		# Persist both rider metadata and actual vertical coordinate.
		actor["visual_y"]=center.y+1.0
		world.residents[actor["id"]]=actor
	assert(slots.size()==6 and lanes.size()==3)
	for count in lanes.values():assert(count==2)
	assert(lifts.peak==6)
	var restored=L.new()
	restored.setup(world)
	assert(restored.occupied["0"].size()==6)
	assert(bool(restored.target(actors[6],center,top).get("wait",false)))
	restored.release(actors[0])
	assert(not bool(restored.target(actors[6],center,top).get("wait",false)))
	assert(restored.occupied["0"].size()==6)
	# An existing pre-upgrade rider between floors completes its old leg
	# unchanged; a new rider cannot enter until that old leg drains.
	var legacy_room:Dictionary=world.get_room(-7,0)
	var legacy_center:Vector3=world.room_center_pos(legacy_room)
	var legacy_actor:Dictionary={"id":"LEGACY","room_id":legacy_room["id"],"active":true,"phase":"travel","visual_y":legacy_center.y+1.0,"waypoint_index":0,"waypoints":[{"kind":"lift"}]}
	world.creatures["LEGACY"]=legacy_actor
	restored.sync()
	var legacy_target:Vector3=legacy_center+Vector3(0,world.FLOOR_H,0)
	assert(restored.target(legacy_actor,legacy_center+Vector3.UP,legacy_target)["target"]==legacy_target)
	var newcomer:Dictionary={"id":"NEW","room_id":legacy_room["id"]}
	assert(bool(restored.target(newcomer,legacy_center,legacy_target).get("wait",false)))
	legacy_actor["phase"]="idle"
	restored.sync()
	assert(not bool(restored.target(newcomer,legacy_center,legacy_target).get("wait",false)))
	print("CANONICAL_LIFT_CAPACITY_PASS slots=6 lanes=3 riders_per_lane=2 seventh_waits=true reload=true legacy_drain=true")
	quit(0)
