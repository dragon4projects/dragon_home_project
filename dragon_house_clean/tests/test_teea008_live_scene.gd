extends SceneTree
func _initialize()->void:
	call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	OS.set_environment("DRAGON_TEEA008_LIVE","1")
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.teea008_live and scene.teea008_review.enabled)
	assert(scene.world.save_path=="user://dragon_house_teea008_live_review.json")
	var bound:=0
	var active:=0
	for profile in scene.world.read_resident_profiles():
		var id:String=str(profile["id"])
		var actor:Dictionary=scene.world.residents[id]
		if bool(actor.get("active",false)):active+=1
		if bool(actor.get("runtime_visual_bound",false)):bound+=1
	assert(active==24 and bound==24,str([active,bound]))
	var guests:Array=["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]
	for id in guests:
		assert(bool(scene.world.residents[id]["runtime_visual_bound"]),id)
		assert(bool(scene.world.residents[id]["autonomy_enabled"]),id)
	var contacts:Dictionary={}
	var seen:Dictionary={}
	var phases:Dictionary={}
	var samples:=0
	var nav=scene.life.candidate_navigation
	scene.life.daypart_override="night"
	for tick in range(4800):
		scene.life.tick(0.125)
		for id in scene.world.residents:
			var actor:Dictionary=scene.world.residents[id]
			if not bool(actor.get("active",false)):continue
			var room:Dictionary=scene.world.room_by_id(str(actor.get("room_id","")))
			if room.is_empty():continue
			if not seen.has(id):seen[id]={};phases[id]={}
			phases[id][str(actor.get("phase","idle"))]=true
			seen[id][str(room["id"])]=true
			if not nav.has_layout(room):continue
			var center:Vector3=scene.world.room_center_pos(room)
			var at:=Vector2(float(actor["x"])-center.x,float(actor["z"]))
			if absf(at.x)>float(room["size_modules"])*2.4:continue
			assert(nav.clear(room,at),str([tick,id,room["id"],at]))
			samples+=1
			if str(actor.get("phase",""))=="perform" and not actor.get("station_contact",{}).is_empty():
				var contact:Dictionary=actor["station_contact"]
				contacts[str(contact["state"])]=int(contacts.get(str(contact["state"]),0))+1
				assert(str(contact["state"])!="RELAXED_SIT" or id!="NPC_CENTAUR")
				assert(str(contact["state"])!="RELAXED_SIT" or id!="NPC_GINGER_CAT_GUEST")
	assert(contacts.get("RELAXED_SIT",0)>0)
	assert(contacts.get("LIE_SIDE_CURLED",0)>0)
	for id in guests:
		print("GUEST ",id," rooms=",seen[id].size()," phases=",phases[id].keys()," final=",scene.world.residents[id].get("intent","")," phase=",scene.world.residents[id].get("phase",""))
		assert(phases[id].has("perform"),id+" no actual activity")
	# A guest may choose to stay home naturally. Force one permitted exploration
	# task separately to demonstrate route availability without misreporting autonomy.
	for id in guests:
		var a:Dictionary=scene.world.residents[id]
		var destination:Dictionary=scene.world.get_room(-3,0)
		if str(a["room_id"])==str(destination["id"]):
			destination=scene.world.get_room(2,0)
		if a.has("held_book"):
			scene.life.media_runtime.return_book(id,str(a["held_book"]))
			a.erase("held_book")
		scene.life._assign(a,{"room":destination,"intent":"PURPOSEFUL_EXPLORE"})
		assert(str(a.get("phase",""))=="travel",id+" explicit route unavailable")
		for step in range(1200):
			scene.life._move(a,0.125)
			if str(a.get("phase",""))!="travel":break
		assert(str(a["room_id"])==str(destination["id"]) and str(a["phase"])=="perform",id+" travel failed")
	print("TEEA008_PLANNER_METRICS ",scene.life.candidate_planner_percentiles())
	print("TEEA008_LIVE_SCENE_PASS active_sisters=",active," bound_sisters=",bound," guests=3 samples=",samples," contact_ticks=",contacts," paths=",nav.path_calls," failed=",nav.path_failures," cache_hits=",nav.path_cache_hits," max_planner_us=",scene.life.planner_usec_max)
	quit(0)
