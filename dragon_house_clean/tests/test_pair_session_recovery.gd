extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

func _actor(id:String,room:Dictionary,x:float,anchor:String,phase:String)->Dictionary:
	return {"id":id,"active":true,"intent":"TALK_PAIR","phase":phase,"room_id":room["id"],"station_room_id":room["id"],"station_anchor_id":anchor,"station_point":[x,0.0],"x":x,"visual_y":0.0,"z":0.0,"until":0.0,"habits":{}}

func _initialize()->void:
	var world=W.new()
	var room:Dictionary=world.make_room(0,0,"common",3)
	var life=Life.new()
	life.world=world
	life.clock=10.0
	var a:Dictionary=_actor("a",room,-0.5,"left","perform")
	var b:Dictionary=_actor("b",room,0.5,"right","travel")
	var ca:Vector3=world.room_local_to_world(room,Vector2(-0.5,0.0))
	var cb:Vector3=world.room_local_to_world(room,Vector2(0.5,0.0))
	a["x"]=ca.x
	a["visual_y"]=ca.y
	a["z"]=ca.z
	b["x"]=cb.x
	b["visual_y"]=cb.y
	b["z"]=cb.z
	world.residents={"a":a,"b":b}
	life._create_pair_session(a,b,room,500.0)
	var sid:String=str(a["social_session_id"])
	var row:Dictionary=life._pair_sessions()[sid]
	life._update_pair(a)
	assert(row["phase"]=="assembling")
	assert(row["started_at"]==-1.0)
	assert(a["habits"].is_empty())
	life.clock=30.0
	b["phase"]="perform"
	life._update_pair(b)
	assert(row["phase"]=="active")
	assert(row["started_at"]==30.0)
	var end:float=float(row["ends_at"])
	assert(end>=3630.0 and end<=10830.0)
	assert(a["until"]==end and b["until"]==end)
	# A snapshot roundtrip does not restart the duration or train.
	world.runtime_state=JSON.parse_string(JSON.stringify(world.runtime_state))
	world.residents=JSON.parse_string(JSON.stringify(world.residents))
	a=world.residents["a"]
	b=world.residents["b"]
	life.clock=50.0
	life.reconcile_pair_sessions()
	assert(life._pair_sessions()[sid]["ends_at"]==end)
	assert(life._pair_sessions()[sid]["started_at"]==30.0)
	assert(a["habits"].is_empty())
	life.clock=end
	life._update_pair(a)
	assert(life._pair_sessions().is_empty())
	assert(not a.has("partner_id") and not b.has("partner_id"))
	assert(not a.has("station_room_id") and not b.has("station_room_id"))
	assert(is_equal_approx(float(a["habits"]["TALK_PAIR"]),0.012))
	life.reconcile_pair_sessions()
	assert(is_equal_approx(float(a["habits"]["TALK_PAIR"]),0.012))
	# Invalid pair releases both without fake completion.
	a=_actor("a",room,-0.5,"left","travel")
	b=_actor("b",room,0.5,"right","travel")
	world.residents={"a":a,"b":b}
	life._create_pair_session(a,b,room,end+500.0)
	b.erase("station_anchor_id")
	life.reconcile_pair_sessions()
	assert(life._pair_sessions().is_empty())
	assert(a["habits"].is_empty() and b["habits"].is_empty())
	assert(not a.has("partner_id") and not b.has("partner_id"))
	print("PAIR_SESSION_RECOVERY_TEST_PASS")
	quit(0)
