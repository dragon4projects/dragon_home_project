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
	var series:Dictionary={"id":"QA_SERIES","title":"QA serial","simulation_only":true,"media_type":"series","latest_season":2,"latest_episode":2,"episode_runtime_seconds":{"1":[2400,2700],"2":[1800,1920]}}
	w.media["films"]=[movie,series,{"id":"QA_UNKNOWN","simulation_only":true,"media_type":"film"}]
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	a["intent"]="WATCH_FILM"
	a["phase"]="perform"
	a["activity_media_id"]="QA_SERIES"
	assert(m.begin_watch(a,100))
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
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	m.setup(copy)
	assert(m.next_watch_unit("RES_01",series)["season"]==2)
	assert(m.next_watch_unit("RES_02",series)["season"]==1)
	print("CINEMA_TIMED_SESSIONS_PASS")
	quit(0)
