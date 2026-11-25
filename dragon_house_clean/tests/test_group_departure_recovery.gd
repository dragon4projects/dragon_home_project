extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

func _member(world,room:Dictionary,id:String,p:Vector2)->Dictionary:
	var at:Vector3=world.room_local_to_world(room,p)
	return {"id":id,"active":true,"intent":"TALK_GROUP","phase":"perform","room_id":room["id"],"station_room_id":room["id"],"station_anchor_id":"spot_"+id,"station_point":[p.x,p.y],"x":at.x,"visual_y":at.y,"z":at.z,"until":0.0,"habits":{}}

func _initialize()->void:
	var w=W.new()
	var room:Dictionary=w.make_room(0,0,"common",3)
	var life=Life.new()
	life.world=w
	life.clock=10.0
	var members:Array=[]
	var positions:Array=[Vector2(-1,0),Vector2(0,-1),Vector2(1,0),Vector2(0,1)]
	for i in range(4):
		var id:String="a%d"%i
		var actor:Dictionary=_member(w,room,id,positions[i])
		w.residents[id]=actor
		members.append(actor)
	var sid:String=life._create_group_record(members,room,500.0)
	life._update_pair(w.residents["a0"])
	assert(life._pair_sessions()[sid]["phase"]=="active")
	var start:float=float(life._pair_sessions()[sid]["started_at"])
	var end:float=float(life._pair_sessions()[sid]["ends_at"])
	life.clock=30.0
	assert(life.leave_social_session("a3"))
	assert(life._pair_sessions()[sid]["members"]==["a0","a1","a2"])
	assert(life._pair_sessions()[sid]["started_at"]==start)
	assert(life._pair_sessions()[sid]["ends_at"]==end)
	assert(not w.residents["a3"].has("station_room_id"))
	assert(not w.residents["a3"].has("social_session_id"))
	assert(w.residents["a3"]["habits"].is_empty())
	assert(not life.leave_social_session("a3"))
	# An orphan backlink is not membership and cannot cancel this group.
	var orphan:Dictionary=_member(w,room,"orphan",Vector2(0,1))
	orphan["social_session_id"]=sid
	w.residents["orphan"]=orphan
	life.reconcile_pair_sessions()
	assert(not orphan.has("social_session_id"))
	assert(life._pair_sessions().has(sid))
	assert(life._pair_sessions()[sid]["members"].size()==3)
	# Surviving membership and time are retained across JSON roundtrip.
	w.runtime_state=JSON.parse_string(JSON.stringify(w.runtime_state))
	w.residents=JSON.parse_string(JSON.stringify(w.residents))
	life.reconcile_pair_sessions()
	assert(life._pair_sessions()[sid]["ends_at"]==end)
	life.clock=end
	life._update_pair(w.residents["a0"])
	for i in range(3):
		assert(is_equal_approx(float(w.residents["a%d"%i]["habits"]["TALK_GROUP"]),0.012))
	assert(w.residents["a3"]["habits"].is_empty())
	assert(life._pair_sessions().is_empty())
	# Recover a group whose fourth member lost a station, without crediting them.
	members.clear()
	for i in range(4):
		var id:String="b%d"%i
		var actor:Dictionary=_member(w,room,id,positions[i])
		w.residents[id]=actor
		members.append(actor)
	sid=life._create_group_record(members,room,end+500.0)
	life._update_pair(w.residents["b0"])
	var retained_end:float=float(life._pair_sessions()[sid]["ends_at"])
	w.residents["b3"].erase("station_anchor_id")
	life.reconcile_pair_sessions()
	assert(life._pair_sessions()[sid]["members"]==["b0","b1","b2"])
	assert(life._pair_sessions()[sid]["ends_at"]==retained_end)
	assert(w.residents["b3"]["habits"].is_empty())
	# A further departure would reduce the group below the minimum.
	assert(life.leave_social_session("b2"))
	assert(life._pair_sessions().is_empty())
	for i in range(4):
		var actor:Dictionary=w.residents["b%d"%i]
		assert(not actor.has("social_session_id"))
		assert(not actor.has("station_room_id"))
		assert(actor["habits"].is_empty())
	print("GROUP_DEPARTURE_RECOVERY_TEST_PASS")
	quit(0)
