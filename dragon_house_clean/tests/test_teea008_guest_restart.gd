extends SceneTree
const W=preload("res://scripts/world_model.gd")
const C=preload("res://scripts/candidate_content_runtime.gd")
func _initialize()->void:
	var w=W.new()
	w.save_path="user://teea008_guest_restart_qa.json"
	w.seed_world()
	var c=C.new()
	assert(c.initialize())
	assert(c.apply_guest_candidate(w).get("ok",false))
	var id: String="NPC_CENTAUR"
	var home:Dictionary=w.guest_room_for(id)
	var home_id:String=str(home["id"])
	var common:Dictionary=w.get_room(-2,0)
	var actor:Dictionary=w.residents[id]
	actor["room_id"]=common["id"]
	actor["x"]=w.room_center_pos(common).x
	actor["z"]=1.0
	actor["autonomy_enabled"]=true
	assert(w.set_guest_room_open(home_id,false))
	assert(w.save_world())
	var reloaded=W.new()
	reloaded.save_path=w.save_path
	reloaded.load_or_seed()
	assert(c.apply_guest_candidate(reloaded).get("ok",false),c.last_error)
	assert(reloaded.residents[id]["room_id"]==common["id"])
	assert(reloaded.residents[id]["home_room_id"]==home_id)
	assert(bool(reloaded.residents[id]["autonomy_enabled"]))
	assert(reloaded.room_by_id(home_id)["guest_access_state"]=="closed")
	assert(not reloaded.public_cutaway_allowed(reloaded.room_by_id(home_id)))
	assert(reloaded.rooms.size()==22)
	print("TEEA008_GUEST_RESTART_PASS home_preserved=true current_preserved=true closed_preserved=true autonomy_preserved=true")
	quit(0)
