extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.save_path="user://music_timed_qa.json"
	w.seed_world()
	var m=M.new()
	m.setup(w)
	var song:Dictionary={"id":"QA_SONG","title":"QA","simulation_only":true,"autonomous_music":true,"runtime_seconds":195}
	w.media["tracks"]=[song,{"id":"QA_OTHER","simulation_only":true,"autonomous_music":false,"runtime_seconds":300}]
	var a:Dictionary=w.residents["RES_01"]
	a["intent"]="LISTEN_MUSIC"
	a["room_id"]=w.get_room(3,0)["id"]
	a["station_room_id"]=a["room_id"]
	a["phase"]="perform"
	a["activity_media_id"]="QA_SONG"
	assert(m.listen_candidates().size()==1)
	a["phase"]="travel"
	assert(not m.begin_listen(a,100))
	assert(not a.has("listen_session"))
	a["phase"]="perform"
	a["station_room_id"]="WRONG_ROOM"
	assert(not m.begin_listen(a,100))
	a["station_room_id"]=a["room_id"]
	assert(m.begin_listen(a,100))
	a["until"]=102
	assert(m.begin_listen(a,101))
	assert(a["until"]==295)
	assert(a["listen_session"]["started_at"]==100)
	assert(a["listen_session"]["ends_at"]==295)
	var valid_session:Dictionary=a["listen_session"].duplicate(true)
	a["listen_session"]["ends_at"]=102
	assert(not m.finish_listen(a,102))
	a["listen_session"]=valid_session
	a["station_room_id"]="WRONG_ROOM"
	assert(not m.finish_listen(a,295))
	a["station_room_id"]=a["room_id"]
	assert(a["until"]==295)
	assert(not m.finish_listen(a,294.99))
	assert(m.finish_listen(a,295))
	assert(not m.finish_listen(a,295))
	assert(m.listen_history("RES_01","QA_SONG")["completed_count"]==1)
	assert(m.listen_history("RES_02","QA_SONG").is_empty())
	assert(m.begin_listen(a,500))
	assert(m.finish_listen(a,695))
	assert(m.listen_history("RES_01","QA_SONG")["completed_count"]==2)
	assert(m.listen_history("RES_01","QA_SONG")["total_seconds"]==390)
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	m.setup(copy)
	assert(m.listen_history("RES_01","QA_SONG")["completed_count"]==2)
	assert(w._zna_duration_seconds("2:36:49")==9409)
	assert(w._zna_duration_seconds("3:15")==195)
	assert(w._zna_duration_seconds("3:99")==0)
	print("MUSIC_TIMED_SESSIONS_PASS")
	quit(0)
