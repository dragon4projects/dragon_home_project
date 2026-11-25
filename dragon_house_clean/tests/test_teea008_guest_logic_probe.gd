extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const C=preload("res://scripts/candidate_content_runtime.gd")
func _initialize()->void:
	var w=W.new()
	w.save_path="user://teea008_guest_probe.json"
	w.seed_world()
	var c=C.new()
	assert(c.initialize(),c.last_error)
	var result:Dictionary=c.apply_guest_candidate(w)
	assert(bool(result.get("ok",false)),str(result))
	var ids:Array=["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]
	var phases:Dictionary={}
	var rooms:Dictionary={}
	for id in ids:
		w.residents[id]["autonomy_enabled"]=true
		phases[id]={}
		rooms[id]={}
	var life=L.new()
	life.daypart_override="day"
	life.setup(w)
	for tick in range(4800):
		life.tick(0.125)
		for id in ids:
			var a:Dictionary=w.residents[id]
			phases[id][str(a.get("phase",""))]=true
			rooms[id][str(a.get("room_id",""))]=true
			var room:Dictionary=w.room_by_id(str(a.get("room_id","")))
			if str(a.get("phase",""))=="perform":
				assert(w.is_accessible(room,id),id+" private room access")
	for id in ids:
		print("GUEST ",id," phases=",phases[id].keys()," rooms=",rooms[id].size())
		assert(phases[id].has("travel") and phases[id].has("perform"))
		# Staying in a guest home is a legitimate autonomous choice. Verify
		# actual inter-room travel separately from that choice.
		var actor:Dictionary=w.residents[id]
		var destination:Dictionary={}
		for room in w.matching_rooms(["study","library","arrival","corridor","rest"],id):
			if str(room["id"])!=str(actor["room_id"]) and not life.stations.single(w,actor,room,"PURPOSEFUL_EXPLORE").is_empty() and not w.find_route(actor["room_id"],room["id"],id).is_empty():
				destination=room
				break
		assert(not destination.is_empty(),id+" no allowed route")
		if actor.has("held_book"):
			life.media_runtime.return_book(id,str(actor["held_book"]))
			actor.erase("held_book")
		life._assign(actor,{"room":destination,"intent":"PURPOSEFUL_EXPLORE"})
		assert(str(actor["phase"])=="travel",id)
		for step in range(1600):
			life._move(actor,0.125)
			if str(actor["phase"])!="travel":break
		assert(str(actor["room_id"])==str(destination["id"]) and str(actor["phase"])=="perform",id)
	print("TEEA008_GUEST_LOGIC_PROBE_PASS autonomy_enabled_in_test_only=true species_pose_not_tested")
	quit(0)
