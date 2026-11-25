extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")
func _member(world,room:Dictionary,id:String,p:Vector2,phase:String)->Dictionary:
	var at:Vector3=world.room_local_to_world(room,p)
	return {"id":id,"active":true,"intent":"TALK_GROUP","phase":phase,"room_id":room["id"],"station_room_id":room["id"],"station_anchor_id":"spot_"+id,"station_point":[p.x,p.y],"x":at.x,"visual_y":at.y,"z":at.z,"until":0.0,"habits":{}}

func _initialize()->void:
	var w=W.new()
	var room:Dictionary=w.make_room(0,0,"common",3)
	var second:Dictionary=w.make_room(3,0,"rest",3)
	var life=Life.new()
	life.world=w
	life.clock=10.0
	var positions:Array=[Vector2(-0.8,-0.5),Vector2(0.8,-0.5),Vector2(0.0,0.9)]
	assert(life.stations.group_geometry(room,positions))
	assert(not life.stations.group_geometry(room,[Vector2(-1,0),Vector2(0,0),Vector2(1,0)]))
	assert(not life.stations.group_geometry(room,[Vector2(0,0),Vector2(0.1,0),Vector2(0,1)]))
	var six:Array=[]
	for i in range(6):six.append(Vector2.from_angle(TAU*float(i)/6.0)*1.0)
	assert(life.stations.group_geometry(room,six))
	var groups:Array=[]
	for k in range(2):
		var members:Array=[]
		var target:Dictionary=room if k==0 else second
		for i in range(3):
			var id:String="%d_%d"%[k,i]
			var member:Dictionary=_member(w,target,id,positions[i],"travel" if i==2 else "perform")
			w.residents[id]=member
			members.append(member)
		groups.append(life._create_group_record(members,target,500.0))
	assert(groups[0]!=groups[1])
	assert(life._pair_sessions().size()==2)
	life._update_pair(w.residents["0_0"])
	assert(life._pair_sessions()[groups[0]]["phase"]=="assembling")
	life.clock=30.0
	w.residents["0_2"]["phase"]="perform"
	life._update_pair(w.residents["0_2"])
	var row:Dictionary=life._pair_sessions()[groups[0]]
	assert(row["phase"]=="active" and row["started_at"]==30.0)
	assert(row["duration_seconds"]>=3600.0 and row["duration_seconds"]<=14400.0)
	var end:float=float(row["ends_at"])
	assert(w.residents["0_0"]["until"]==end)
	assert(w.residents["0_0"]["social_facing_xz"].size()==2)
	assert(life._pair_sessions()[groups[1]]["phase"]=="assembling")
	w.runtime_state=JSON.parse_string(JSON.stringify(w.runtime_state))
	w.residents=JSON.parse_string(JSON.stringify(w.residents))
	life.clock=60.0
	life.reconcile_pair_sessions()
	assert(life._pair_sessions()[groups[0]]["ends_at"]==end)
	assert(life._pair_sessions().size()==2)
	w.residents["1_2"].erase("station_anchor_id")
	life.reconcile_pair_sessions()
	assert(life._pair_sessions().size()==1)
	for i in range(3):
		assert(not w.residents["1_%d"%i].has("social_session_id"))
		assert(w.residents["1_%d"%i]["habits"].is_empty())
	life.clock=end
	life._update_pair(w.residents["0_1"])
	assert(life._pair_sessions().is_empty())
	for i in range(3):
		var a:Dictionary=w.residents["0_%d"%i]
		assert(not a.has("social_session_id") and not a.has("social_facing_xz"))
		assert(is_equal_approx(float(a["habits"]["TALK_GROUP"]),0.012))
	life.reconcile_pair_sessions()
	assert(is_equal_approx(float(w.residents["0_0"]["habits"]["TALK_GROUP"]),0.012))
	print("GROUP_SESSION_RECOVERY_TEST_PASS")
	quit(0)
