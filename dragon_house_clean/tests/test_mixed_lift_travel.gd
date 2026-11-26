extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.canonical_house_seed=true
	w.save_path="user://mixed_lift_"+str(Time.get_ticks_usec())+".json"
	w.seed_world()
	for a in w.residents.values():a.active=false
	for a in w.creatures.values():a.active=false
	var life=L.new()
	life.setup(w)
	var ids:Array=[]
	var destinations:Dictionary={}
	for i in range(8):
		var start_floor:int=-2 if i%2==0 else 3
		var end_floor:int=3 if i%2==0 else -2
		var room:Dictionary=w.get_room(0,start_floor)
		var target:Dictionary=w.get_room(0,end_floor)
		var id:String="RES_%02d"%(i+1) if i<4 else "QA_LIFT_CREATURE_%d"%i
		var a:Dictionary={}
		if i<4:a=w.residents[id]
		else:
			assert(w.register_creature(id,id,room.id))
			a=w.creatures[id]
		var c:Vector3=w.room_center_pos(room)
		a.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":start_floor,"x":c.x,"visual_y":c.y,"z":0.0,"phase":"travel","intent":"PURPOSEFUL_EXPLORE","until":10000.0,"waypoint_index":0,"next_decision_at":10000.0},true)
		var offset:=Vector2.ZERO
		# RES_01 intentionally retains a stationless legacy lift destination;
		# the other residents travel to real reserved public stations.
		if i>0 and i<4:
			var options:Array=w.matching_rooms(["common","rest","library","study","music","cinema","artifact","workshop","kitchen"],id).filter(func(r):return int(r.level)==(2 if end_floor==3 else 0))
			options.sort_custom(func(a,b):return absf(w.room_center_pos(a).x)<absf(w.room_center_pos(b).x))
			var claim:Dictionary={}
			for candidate in options:
				claim=life.stations.single(w,a,candidate,"PURPOSEFUL_EXPLORE")
				if not claim.is_empty():target=candidate;break
			assert(not claim.is_empty())
			life.stations.commit_claim(a,claim)
			offset=claim.offset
		var route:Array=w.find_route(room.id,target.id,id)
		a["waypoints"]=life.locomotion.build_waypoints(w,a,route,"PURPOSEFUL_EXPLORE",offset)
		assert(not a.waypoints.is_empty())
		a["route_target_room_id"]=target.id
		ids.append(id)
		destinations[id]=target.id
	var saw_mixed:=false
	var saw_wait:=false
	var reload_done:=false
	var finished:Dictionary={}
	for step in range(1000):
		life.canonical_lifts.sync()
		for id in ids:
			var a:Dictionary=w.residents.get(id,w.creatures.get(id,{}))
			if a.phase!="travel":continue
			var at:=Vector3(a.x,a.visual_y,a.z)
			if w.residents.has(id):life._move(a,0.125)
			else:life.creature_runtime.advance_travel(id,0.125)
			assert(Vector3(a.x,a.visual_y,a.z).distance_to(at)<=0.34)
			if a.phase!="travel":
				if id=="RES_01":
					assert(reload_done and a.phase=="idle" and int(a.level)==-1 and absf(float(a.visual_y)+w.FLOOR_H)<0.035)
				else:assert(a.room_id==destinations[id])
				finished[id]=true
		var holders:Dictionary=life.canonical_lifts.occupied.get("0",{})
		assert(holders.size()<=6)
		if holders.size()==6 and holders.values().any(func(id):return w.creatures.has(id)) and holders.values().any(func(id):return w.residents.has(id)):saw_mixed=true
		if life.canonical_lifts.waiting>0:saw_wait=true
		if step==24:
			assert(saw_mixed and saw_wait)
			assert(w.save_world())
			var copy=W.new()
			copy.canonical_house_seed=true
			copy.save_path=w.save_path
			assert(copy.load_or_seed())
			var old_holders:Dictionary=holders.duplicate()
			w=copy
			life=L.new()
			life.setup(w)
			assert(life.canonical_lifts.occupied.get("0",{})==old_holders)
			assert(w.residents.RES_01.has("station_replan_lift_pending"))
			reload_done=true
		if finished.size()==ids.size():break
	assert(finished.size()==8 and saw_mixed and saw_wait and reload_done)
	life.canonical_lifts.sync()
	assert(life.canonical_lifts.occupied.get("0",{}).is_empty())
	print("MIXED_LIFT_TRAVEL_PASS finished=8 shared_peak=6 opposite_directions=true wait=true reload=true legacy_safe_landing=true")
	quit(0)
