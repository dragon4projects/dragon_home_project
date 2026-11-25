extends SceneTree
const W=preload("res://scripts/world_model.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const T=preload("res://scripts/teea008_traffic.gd")

func _initialize()->void:
	var world=W.new()
	world.canonical_house_seed=true
	world.seed_world()
	var nav=N.new()
	nav.configure({})
	var traffic=T.new()
	var room:Dictionary=world.get_room(-6,3)
	var center:Vector3=world.room_center_pos(room)
	var outsider:Dictionary={"id":"MANJKA","room_id":room["id"]}
	var owner:Dictionary={"id":room["owner_id"],"room_id":room["id"]}
	assert(not world.is_accessible(room,"MANJKA"))
	assert(world.is_accessible(room,str(owner["id"])))
	traffic.begin(world,nav)
	var a:=center+Vector3(0,0,1.50)
	assert(traffic._safe_room(outsider,a,a+Vector3(0.15,0,0)))
	assert(not traffic._safe_room(outsider,a,a+Vector3(0,0,-0.40)))
	assert(not traffic._safe_room(outsider,a,a+Vector3(0,0,0.30)))
	assert(not traffic._safe_room(outsider,a,a+Vector3(2.50,0,0)))
	assert(traffic._safe_room(owner,a,a+Vector3(0,0,-0.40)))
	var inside:=center+Vector3(0,0,0.75)
	assert(traffic._safe_room(outsider,inside,inside+Vector3(0,0,0.20)))
	assert(not traffic._safe_room(outsider,inside,inside+Vector3(0,0,-0.20)))
	assert(not traffic._safe_room(outsider,inside,inside+Vector3(0.20,0,0.10)))
	# Public lift cells without candidate furniture are still physical volumes.
	var lift:Dictionary=world.get_room(-7,3)
	var lift_center:Vector3=world.room_center_pos(lift)
	outsider["room_id"]=lift["id"]
	assert(traffic._safe_room(outsider,lift_center,lift_center+Vector3(0,0,1.50)))
	assert(not traffic._safe_room(outsider,lift_center,lift_center+Vector3(0,0,-2.10)))
	assert(not traffic._safe_room(outsider,lift_center,lift_center+Vector3(2.50,0,0)))
	# Force an opposing pedestrian into the narrow public frontage. A waiting
	# or retreating actor is acceptable here; entry behind the door is not.
	outsider["room_id"]=room["id"]
	traffic.positions={"MANJKA":a,"RES_02":a+Vector3(0.66,0,0)}
	var target:=a+Vector3(2.0,0,0)
	for i in range(20):
		var next:Vector3=traffic.step(outsider,a,target,a.move_toward(target,0.12),0.12,"candidate_path")
		assert(next.z>=1.35-0.0001 and next.z<=1.65)
		assert(absf(next.x-center.x)<=2.4)
		traffic.publish("MANJKA",next)
		a=next
	traffic.finish()
	print("CANONICAL_FRONTAGE_GUARD_PASS private_transit=true bounded_empty_rooms=true monotone_egress=true")
	quit(0)
