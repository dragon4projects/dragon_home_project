extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.save_path="user://timed_media_reload_qa.json"
	w.seed_world()
	var room:Dictionary=w.get_room(3,0)
	assert(str(room.get("type",""))=="music")
	w.media["tracks"]=[{"id":"QA_TRACK","title":"QA","simulation_only":true,"autonomous_music":true,"runtime_seconds":195}]
	var life=L.new()
	life.setup(w)
	var a:Dictionary=w.residents["RES_01"]
	life._assign(a,{"intent":"LISTEN_MUSIC","room":room})
	assert(a.get("activity_media_id","")=="QA_TRACK")
	a["room_id"]=room["id"]
	a["phase"]="perform"
	a["waypoint_index"]=a.get("waypoints",[]).size()
	life.clock=100.0
	w.sim_clock=100.0
	assert(life.media_runtime.begin_listen(a,100.0))
	assert(life.media_runtime.timed_session_valid(a,100.0))
	a["until"]=101.0
	life._process_due_actor("RES_01","QA_EARLY_WAKE")
	assert(a["until"]==295.0)
	assert(life.media_runtime.listen_history("RES_01","QA_TRACK").is_empty())
	life.clock=180.0
	w.sim_clock=180.0
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	var resumed=L.new()
	resumed.setup(copy)
	var restored:Dictionary=copy.residents["RES_01"]
	assert(restored["listen_session"]["started_at"]==100.0)
	assert(restored["until"]==295.0)
	assert(resumed.life_scheduler.peek_due_at("RES_01")==295.0)
	resumed.clock=295.0
	copy.sim_clock=295.0
	resumed._process_due_actor("RES_01","QA_COMPLETION")
	assert(resumed.media_runtime.listen_history("RES_01","QA_TRACK")["completed_count"]==1)
	assert(not restored.has("listen_session"))
	resumed._process_due_actor("RES_01","QA_DUPLICATE_WAKE")
	assert(resumed.media_runtime.listen_history("RES_01","QA_TRACK")["completed_count"]==1)
	print("TIMED_MEDIA_RELOAD_PASS")
	quit(0)
