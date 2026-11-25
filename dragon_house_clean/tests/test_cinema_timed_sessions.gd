extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.save_path="user://cinema_timed_qa.json"
	w.seed_world()
	var m=M.new()
	m.setup(w)
	var movie:Dictionary={"id":"QA_MOVIE","title":"QA","simulation_only":true,"media_type":"film","runtime_seconds":6000}
	var series:Dictionary={"id":"QA_SERIES","title":"QA serial","simulation_only":true,"media_type":"series","latest_season":2,"latest_episode":2,"episode_runtime_seconds":{"1":[2400,2700],"2":[1800,1920]},"complete_seasons":[1,2]}
	w.media["films"]=[movie,series,{"id":"QA_UNKNOWN","simulation_only":true,"media_type":"film"}]
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	a["intent"]="WATCH_FILM"
	a["room_id"]=w.get_room(4,0)["id"]
	a["station_room_id"]=a["room_id"]
	a["phase"]="perform"
	a["activity_media_id"]="QA_SERIES"
	a["phase"]="travel"
	assert(not m.begin_watch(a,100))
	assert(not a.has("watch_session"))
	a["phase"]="perform"
	a["station_room_id"]="WRONG_ROOM"
	assert(not m.begin_watch(a,100))
	a["station_room_id"]=a["room_id"]
	assert(m.begin_watch(a,100))
	a["until"]=102
	assert(m.begin_watch(a,101))
	assert(a["until"]==2500)
	assert(a["watch_session"]["started_at"]==100)
	assert(a["watch_session"]["ends_at"]==2500)
	var valid_session:Dictionary=a["watch_session"].duplicate(true)
	a["watch_session"]["ends_at"]=102
	assert(not m.finish_watch(a,102))
	a["watch_session"]=valid_session
	a["station_room_id"]="WRONG_ROOM"
	assert(not m.finish_watch(a,2500))
	a["station_room_id"]=a["room_id"]
	assert(a["until"]==2500)
	assert(not m.finish_watch(a,2499))
	assert(m.finish_watch(a,2500))
	assert(not m.finish_watch(a,2500))
	assert(m.next_watch_unit("RES_01",series)["episode"]==2)
	assert(m.next_watch_unit("RES_02",series)["episode"]==1)
	assert(m.begin_watch(a,2600))
	assert(a["until"]==5300)
	assert(m.finish_watch(a,5300))
	assert(m.next_watch_unit("RES_01",series)["season"]==2)
	assert(m.next_watch_unit("RES_01",series)["episode"]==1)
	a["activity_media_id"]="QA_MOVIE"
	assert(m.begin_watch(a,6000))
	assert(a["until"]==12000)
	assert(m.finish_watch(a,12000))
	assert(m.next_watch_unit("RES_01",movie).is_empty())
	assert(m.watch_candidates("RES_01").size()==1)
	w.sim_clock=12000+w.GAME_DAY_SECONDS
	assert(m.next_watch_unit("RES_01",movie)["seconds"]==6000)
	assert(m.begin_watch(a,w.sim_clock))
	assert(m.finish_watch(a,w.sim_clock+6000))
	assert(w.runtime_state["cinema_progress"]["RES_01"]["QA_MOVIE"]["completed_count"]==2)
	var partial:Dictionary={"id":"QA_PARTIAL","title":"Partial","simulation_only":true,"media_type":"series","latest_season":2,"latest_episode":1,"episode_runtime_seconds":{"1":[1200],"2":[1300]},"complete_seasons":[]}
	w.media["films"].append(partial)
	a["activity_media_id"]="QA_PARTIAL"
	assert(m.begin_watch(a,200000))
	assert(m.finish_watch(a,201200))
	assert(m.next_watch_unit("RES_01",partial).is_empty())
	partial["complete_seasons"]=[1]
	assert(m.next_watch_unit("RES_01",partial)["season"]==2)
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	m.setup(copy)
	assert(m.next_watch_unit("RES_01",series)["season"]==2)
	assert(m.next_watch_unit("RES_02",series)["season"]==1)
	var restored:Dictionary=copy.residents["RES_01"]
	restored["activity_media_id"]="QA_SERIES"
	var start:float=210000.0
	assert(m.begin_watch(restored,start))
	assert(m.finish_watch(restored,start+1800.0))
	assert(m.begin_watch(restored,start+1801.0))
	var finale:float=start+1801.0+1920.0
	assert(m.finish_watch(restored,finale))
	var row:Dictionary=copy.runtime_state["cinema_progress"]["RES_01"]["QA_SERIES"]
	assert(row["complete"] and row["completed_count"]==1)
	var saved_series:Dictionary=m._lookup("films","QA_SERIES")
	assert(m.next_watch_unit("RES_01",saved_series,finale+W.GAME_DAY_SECONDS-0.01).is_empty())
	assert(m.next_watch_unit("RES_01",saved_series,finale+W.GAME_DAY_SECONDS)["episode"]==1)
	assert(not m.begin_watch(restored,finale+1.0))
	# An authored extension is new material, not a replay.
	saved_series["latest_episode"]=3
	saved_series["episode_runtime_seconds"]["2"].append(2000)
	assert(m.next_watch_unit("RES_01",saved_series,finale+1.0)["episode"]==3)
	assert(m.begin_watch(restored,finale+1.0))
	assert(m.finish_watch(restored,finale+2001.0))
	var repeat_at:float=finale+2001.0+W.GAME_DAY_SECONDS
	assert(m.begin_watch(restored,repeat_at))
	assert(restored["watch_session"]["season"]==1 and restored["watch_session"]["episode"]==1)
	assert(m.finish_watch(restored,repeat_at+2400.0))
	row=copy.runtime_state["cinema_progress"]["RES_01"]["QA_SERIES"]
	assert(row["repeat_cycle"]==1 and not row["complete"])
	assert(m.next_watch_unit("RES_01",saved_series,repeat_at+2400.0)["episode"]==2)
	print("CINEMA_TIMED_SESSIONS_PASS")
	quit(0)
