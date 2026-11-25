extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

# Synthetic measured-station fixture; this is a lifecycle regression,
# not evidence of feasibility in the delivered canonical interiors.
class FixtureStations extends "res://scripts/room_stations.gd":
	func layout_for_world(_world, _room:Dictionary)->Array:
		var result:Array=[]
		var points:Array=[Vector2(-1,0),Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(0.9,0.9)]
		for i in range(points.size()):
			result.append({"id":"spot_%d"%i,"offset":points[i],"kind":"standing","furniture_id":"","pose_hint":"IDLE_S","approach_z":points[i].y})
		return result

func _actor(world,room:Dictionary,id:String,p:Vector2)->Dictionary:
	var at:Vector3=world.room_local_to_world(room,p)
	return {"id":id,"active":true,"intent":"REST","phase":"idle","room_id":room["id"],"x":at.x,"visual_y":at.y,"z":at.z,"level":room["level"],"until":0.0,"habits":{},"needs":{"social":0.8}}

func _initialize()->void:
	var w=W.new()
	var room:Dictionary=w.make_room(0,0,"common",3)
	var life=Life.new()
	life.world=w
	life.stations=FixtureStations.new()
	life.clock=10.0
	var spots:Array=life.stations.layout_for_world(w,room)
	var members:Array=[]
	for i in range(3):
		var id:String="a%d"%i
		var actor:Dictionary=_actor(w,room,id,spots[i]["offset"])
		life.stations.commit_claim(actor,life.stations._claim(room,i,spots[i]))
		actor["intent"]="TALK_GROUP"
		actor["phase"]="perform"
		w.residents[id]=actor
		members.append(actor)
	var sid:String=life._create_group_record(members,room,500.0)
	life._update_pair(w.residents["a0"])
	assert(life._pair_sessions()[sid]["phase"]=="active")
	var original_start:float=float(life._pair_sessions()[sid]["started_at"])
	var original_end:float=float(life._pair_sessions()[sid]["ends_at"])
	var newcomer:Dictionary=_actor(w,room,"new",Vector2(0,1.4))
	w.residents["new"]=newcomer
	var busy:Dictionary=_actor(w,room,"busy",Vector2(1,1.4))
	busy["held_book"]="BOOK"
	w.residents["busy"]=busy
	life.clock=30.0
	assert(not life.request_group_join("busy",sid))
	assert(life.request_group_join("new",sid))
	assert(newcomer["social_join_session_id"]==sid and not newcomer.has("social_session_id"))
	assert(life._pair_sessions()[sid]["members"].size()==3)
	assert(life._pair_sessions()[sid]["ends_at"]==original_end)
	assert(not life.request_group_join("new",sid))
	# Restore a pending approach, without creating active attendance.
	w.runtime_state=JSON.parse_string(JSON.stringify(w.runtime_state))
	w.residents=JSON.parse_string(JSON.stringify(w.residents))
	newcomer=w.residents["new"]
	life.clock=35.0
	life.reconcile_pair_sessions()
	assert(newcomer["social_join_session_id"]==sid)
	assert(life._pair_sessions()[sid]["members"].size()==3)
	var point:Array=newcomer["station_point"]
	var at:Vector3=w.room_local_to_world(room,Vector2(float(point[0]),float(point[1])))
	newcomer["x"]=at.x
	newcomer["visual_y"]=at.y
	newcomer["z"]=at.z
	newcomer["phase"]="perform"
	life.clock=40.0
	life._update_pending_join(newcomer)
	assert(not newcomer.has("social_join_session_id"))
	assert(newcomer["social_session_id"]==sid)
	assert(life._pair_sessions()[sid]["members"].size()==4)
	assert(life._pair_sessions()[sid]["late_members"]["new"]==40.0)
	assert(life._pair_sessions()[sid]["started_at"]==original_start)
	assert(life._pair_sessions()[sid]["ends_at"]==original_end)
	# A second approach times out, leaving the existing group unchanged.
	var other:Dictionary=_actor(w,room,"other",Vector2(0.9,1.4))
	w.residents["other"]=other
	assert(life.request_group_join("other",sid))
	life.clock=101.0
	life._update_pair(w.residents["a0"])
	assert(not other.has("social_join_session_id"))
	assert(not other.has("station_room_id"))
	assert(life._pair_sessions()[sid]["members"].size()==4)
	assert(life._pair_sessions()[sid]["ends_at"]==original_end)
	life.clock=original_end
	life._update_pair(w.residents["a0"])
	assert(life._pair_sessions().is_empty())
	assert(newcomer["habits"].is_empty())
	assert(is_equal_approx(float(w.residents["a0"]["habits"]["TALK_GROUP"]),0.012))
	var partials:Array=[]
	for event in w.journal:
		if event.get("event","")=="GROUP_PARTIAL_ATTENDANCE":partials.append(event)
	assert(partials.size()==1 and partials[0]["actor_id"]=="new")
	assert(is_equal_approx(float(partials[0]["details"]["seconds"]),original_end-40.0))
	life.reconcile_pair_sessions()
	assert(newcomer["habits"].is_empty())
	print("GROUP_LATE_JOIN_TEST_PASS")
	quit(0)
