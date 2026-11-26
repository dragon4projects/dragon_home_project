extends SceneTree
## Full runtime test on isolated review state, not a benchmark of target Dell.
func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.architecture_review and scene.teea008_live)
	var world=scene.world
	var life=scene.life
	var nav=life.candidate_navigation
	var active_ids:Array=[]
	for id in world.residents:
		if bool(world.residents[id].get("active",false)):
			active_ids.append(id)
	var seen:Dictionary={}
	var phases:Dictionary={}
	var levels:Dictionary={}
	var lift_samples:=0
	var samples:=0
	var private_frontage_samples:=0
	var contacts:Dictionary={}
	var max_tick_usec:=0
	var intents:Dictionary={}
	var waits:Dictionary={}
	var longest_wait:float=0.0
	var max_journal:=0
	var tick_times:Array=[]
	var start_clock:float=life.clock
	var seconds:int=int(OS.get_environment("DRAGON_QA_SOAK_SECONDS"))
	if seconds<=0:seconds=1800
	var checkpoints:=0
	var old_checkpoint:float=world.last_checkpoint_clock
	var checkpoint_usec:Array=[]
	var creature_samples:=0
	for tick in range(seconds*8):
		var start:=Time.get_ticks_usec()
		life.tick(0.125)
		var elapsed:int=Time.get_ticks_usec()-start
		max_tick_usec=maxi(max_tick_usec,elapsed)
		tick_times.append(elapsed)
		var save_start:int=Time.get_ticks_usec()
		assert(world.checkpoint_if_due())
		if world.last_checkpoint_clock!=old_checkpoint:
			old_checkpoint=world.last_checkpoint_clock
			checkpoints+=1
			checkpoint_usec.append(Time.get_ticks_usec()-save_start)
		# Creature travel shares the same physical shafts. Check public
		# frontage and object ownership without inventing a species pose.
		if tick%8==0:
			for creature in world.creatures.values():
				if not bool(creature.get("active",false)):continue
				var cr:Dictionary=world.room_by_id(str(creature.get("room_id","")))
				assert(not cr.is_empty())
				var cy:float=float(creature.get("visual_y",float(cr.level)*world.FLOOR_H))
				if absf(cy-float(cr.level)*world.FLOOR_H)>0.05:assert(cr.type=="lift")
				elif not world.public_cutaway_allowed(cr):assert(float(creature.get("z",0))>=1.35)
				var carried:String=str(creature.get("carried_object_id",""))
				if carried!="":
					assert(str(world.physical_object(carried).get("current_holder_id",""))==str(creature.id))
				creature_samples+=1
		for holders in life.canonical_lifts.occupied.values():assert(holders.size()<=6)
		if tick%240==0:
			max_journal=maxi(max_journal,world.journal.size())
		if tick%2400==0:
			print("SOAK_PROGRESS seconds=",life.clock-start_clock," lifts=",life.canonical_lifts.metrics()," paths=",nav.path_calls," failures=",nav.path_failures)
		for id in active_ids:
			var actor:Dictionary=world.residents[id]
			var intent:String=str(actor.get("intent",""))
			intents[intent]=int(intents.get(intent,0))+1
			var waypoint:int=int(actor.get("waypoint_index",0))
			var points:Array=actor.get("waypoints",[])
			var waiting:bool=actor.get("phase","")=="travel" and waypoint<points.size() and str(points[waypoint].get("kind",""))=="lift" and actor.get("moving_axis","")=="wait"
			waits[id]=float(waits.get(id,0.0))+0.125 if waiting else 0.0
			longest_wait=maxf(longest_wait,waits[id])
			var room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
			assert(not room.is_empty(),str([tick,id,"lost room"]))
			var rid:String=str(room["id"])
			if not seen.has(id):
				seen[id]={}
				phases[id]={}
			seen[id][rid]=true
			phases[id][str(actor.get("phase","idle"))]=true
			var y:float=float(actor.get("visual_y",float(room["level"])*world.FLOOR_H))
			if absf(y-float(room["level"])*world.FLOOR_H)>0.05:
				assert(str(room["type"])=="lift",str([tick,id,"non-lift vertical movement",room["type"]]))
				lift_samples+=1
				continue
			levels[int(room["level"])]=true
			var at:=Vector3(float(actor["x"]),y,float(actor["z"]))
			var local:Vector2=world.room_world_to_local(room,at)
			# A room id is committed at the connector endpoint. During the tiny
			# crossing segment physical X can already be in the adjacent room.
			if absf(local.x)>float(room["size_modules"])*2.4:continue
			if nav.has_layout(room):
				assert(nav.clear(room,local),str([tick,id,rid,local]))
				samples+=1
			if str(room["type"])=="private" and str(room["owner_id"])!=str(id):
				assert(local.y>=1.35,str([tick,id,"private frontage violation",local]))
				private_frontage_samples+=1
			if str(actor.get("phase",""))=="perform" and not actor.get("station_contact",{}).is_empty():
				var contact:Dictionary=actor["station_contact"]
				var state:String=str(contact["state"])
				contacts[state]=int(contacts.get(state,0))+1
				assert(state!="RELAXED_SIT" or str(id) not in ["NPC_CENTAUR","NPC_GINGER_CAT_GUEST"])
	tick_times.sort()
	checkpoint_usec.sort()
	print("SOAK_CHECKPOINTS count=",checkpoints," creature_samples=",creature_samples," save_p95_us=",checkpoint_usec[int((checkpoint_usec.size()-1)*0.95)] if not checkpoint_usec.is_empty() else 0)
	print("SOAK_SUMMARY intents=",intents," max_lift_wait_s=",longest_wait," tick_p50_us=",tick_times[int(tick_times.size()*0.5)]," tick_p95_us=",tick_times[int(tick_times.size()*0.95)]," journal_max=",max_journal)
	assert(samples>0 and not contacts.is_empty())
	assert(lift_samples>0 and levels.size()>1)
	for id in ["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]:
		assert(phases.has(id) and phases[id].has("perform"),str([id,phases.get(id,{})]))
	# Isolated movement through every shaft in both directions, in addition
	# to spontaneous activity. This uses actual mover and authored waypoints,
	# not just graph reachability. It does not claim simultaneous cabin safety.
	var traversals:=0
	print("CANONICAL_LIFT_CAPACITY_METRICS ",life.canonical_lifts.metrics())
	assert(life.canonical_lifts.peak<=6)
	assert(life.candidate_traffic.detours==0)
	life.canonical_lifts.occupied.clear()
	life.canonical_lifts.legacy.clear()
	for shaft in [-7,0,7]:
		for direction in [1,-1]:
			var floor_order:Array=[-2,-1,0,1,2,3] if direction==1 else [3,2,1,0,-1,-2]
			var route:Array=[]
			for level in floor_order:
				route.append(str(world.get_room(shaft,int(level))["id"]))
			var first:Dictionary=world.room_by_id(str(route[0]))
			var center:Vector3=world.room_center_pos(first)
			var actor:Dictionary=world.residents["RES_01"].duplicate(true)
			for key in ["cup_task_stage","book_task_stage","held_book","station_contact","teea008_geometry_replan_pending","canonical_lift_slot","canonical_lift_boarded"]:
				actor.erase(key)
			actor.merge({"room_id":route[0],"level":first["level"],"x":center.x,"visual_y":center.y,"z":0.0,"phase":"travel"},true)
			var waypoints:Array=life.locomotion.build_waypoints(world,actor,route,"PURPOSEFUL_EXPLORE",Vector2.ZERO)
			assert(not waypoints.is_empty())
			actor["waypoints"]=waypoints
			actor["waypoint_index"]=0
			for step in range(500):
				life._move(actor,0.125)
				if str(actor["phase"])!="travel":break
			assert(str(actor["room_id"])==str(route[-1]) and str(actor["phase"])=="perform",str([shaft,direction,actor["room_id"]]))
			traversals+=1
	print("CANONICAL_HOUSE_LIFE_PASS actors=",active_ids.size()," seconds=",seconds," sampled_clear=",samples," natural_levels=",levels.keys()," lift_samples=",lift_samples," private_frontage=",private_frontage_samples," isolated_shaft_traversals=",traversals," contacts=",contacts," path_calls=",nav.path_calls," path_failures=",nav.path_failures," max_tick_us=",max_tick_usec)
	print("CANONICAL_TRAFFIC_METRICS ",life.candidate_traffic.metrics())
	print("CANONICAL_PLANNER_METRICS ",life.candidate_planner_percentiles())
	quit(0)
