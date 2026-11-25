extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")

func _initialize()->void:call_deferred("run")

func _arrive(w,who:String,room:Dictionary,intent:String,item:String)->Dictionary:
	var actor:Dictionary=w.residents[who]
	actor["room_id"]=room["id"]
	actor["station_room_id"]=room["id"]
	actor["phase"]="perform"
	actor["intent"]=intent
	actor["activity_media_id"]=item
	return actor

func run()->void:
	var w=W.new()
	w.save_path="user://shared_media_qa_"+str(Time.get_ticks_usec())+".json"
	w.seed_world()
	var cinema:Dictionary=w.get_room(4,0)
	var music:Dictionary=w.get_room(3,0)
	w.media["films"]=[
		{"id":"SERIES","title":"QA","simulation_only":true,"media_type":"series","latest_season":1,"latest_episode":2,"episode_runtime_seconds":{"1":[1000,1200]},"complete_seasons":[1]},
		{"id":"OTHER","title":"Other","simulation_only":true,"media_type":"film","runtime_seconds":3000}]
	w.media["tracks"]=[{"id":"LONG","title":"Compilation","simulation_only":true,"autonomous_music":true,"runtime_seconds":9409}]
	var m=M.new()
	m.setup(w)
	var a:Dictionary=_arrive(w,"RES_01",cinema,"WATCH_FILM","SERIES")
	var b:Dictionary=_arrive(w,"RES_02",cinema,"WATCH_FILM","SERIES")
	var c:Dictionary=_arrive(w,"RES_03",cinema,"WATCH_FILM","SERIES")
	var d:Dictionary=_arrive(w,"RES_04",cinema,"WATCH_FILM","OTHER")
	w.sim_clock=100.0
	assert(m.begin_watch(a,w.sim_clock))
	assert(m.begin_watch(b,w.sim_clock))
	assert(a["watch_session"]["full_credit"] and b["watch_session"]["full_credit"])
	var sid:String=str(a["watch_session"]["session_id"])
	assert(b["watch_session"]["session_id"]==sid)
	w.sim_clock=400.0
	assert(m.begin_watch(c,w.sim_clock))
	assert(c["watch_session"]["session_id"]==sid and not c["watch_session"]["full_credit"])
	assert(c["until"]==1100.0)
	assert(not m.begin_watch(d,w.sim_clock),"Cannot replace an active program")
	assert(m.begin_watch(c,401.0) and c["until"]==1100.0)
	w.sim_clock=600.0
	m.cancel_timed_media(a,w.sim_clock)
	a["phase"]="idle"
	assert(m.active_device_session("films",cinema["id"])["session_id"]==sid)
	assert(w.runtime_state["media_attendance"]["RES_01"]["films|SERIES"]["attended_seconds"]==500.0)
	assert(w.runtime_state.get("cinema_progress",{}).get("RES_01",{}).is_empty())
	w.sim_clock=700.0
	assert(w.save_world())
	var loaded=W.new()
	loaded.save_path=w.save_path
	loaded.load_or_seed()
	assert(loaded.sim_clock==700.0)
	m.setup(loaded)
	b=loaded.residents["RES_02"]
	c=loaded.residents["RES_03"]
	assert(m.timed_session_valid(b,700.0) and m.timed_session_valid(c,700.0))
	assert(b["watch_session"]["full_credit"] and not c["watch_session"]["full_credit"])
	assert(b["until"]==1100.0 and c["until"]==1100.0)
	loaded.sim_clock=1100.0
	assert(m.finish_watch(b,1100.0))
	assert(m.finish_watch(c,1100.0))
	assert(not m.finish_watch(c,1100.0))
	assert(loaded.runtime_state["cinema_progress"]["RES_02"]["SERIES"]["completed_units"]==1)
	assert(loaded.runtime_state["cinema_progress"].get("RES_03",{}).is_empty())
	assert(loaded.runtime_state["media_attendance"]["RES_03"]["films|SERIES"]["attended_seconds"]==700.0)
	assert(loaded.runtime_state["media_attendance"]["RES_02"]["films|SERIES"]["full_sessions"]==1)
	assert(loaded.runtime_state["media_device_sessions"].is_empty())
	a=_arrive(loaded,"RES_01",cinema,"WATCH_FILM","SERIES")
	loaded.sim_clock=1101.0
	assert(m.begin_watch(a,1101.0))
	assert(a["watch_session"]["episode"]==1 and a["until"]==2101.0)
	m.cancel_timed_media(a,1150.0)
	a["phase"]="idle"
	# Music uses the exact same shared timeline, including long compilations.
	var e:Dictionary=_arrive(loaded,"RES_01",music,"LISTEN_MUSIC","LONG")
	var f:Dictionary=_arrive(loaded,"RES_03",music,"LISTEN_MUSIC","LONG")
	loaded.sim_clock=2000.0
	assert(m.begin_listen(e,2000.0))
	assert(e["until"]==11409.0)
	loaded.sim_clock=2400.0
	assert(m.begin_listen(f,2400.0))
	assert(f["until"]==11409.0 and not f["listen_session"]["full_credit"])
	loaded.sim_clock=11409.0
	assert(m.finish_listen(e,11409.0))
	assert(m.finish_listen(f,11409.0))
	assert(m.listen_history("RES_01","LONG")["total_seconds"]==9409.0)
	assert(m.listen_history("RES_03","LONG").is_empty())
	assert(loaded.runtime_state["media_attendance"]["RES_03"]["tracks|LONG"]["attended_seconds"]==9009.0)
	assert(not m.begin_listen(e,11410.0))
	print("SHARED_MEDIA_ATTENDANCE_PASS start_members=2 late_credit=0 cancelled_credit=0 persisted=yes long_compilation=9409")
	quit(0)
