extends SceneTree
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:
	var w=W.new()
	var old:Dictionary={"id":"FILMIX_QA","title":"Fixture","media_type":"film","preview":"user://filmix_previews/FILMIX_QA.webp","runtime_seconds":6000,"duration_source":"verified fixture","duration_status":"VERIFIED"}
	var incoming:Dictionary=old.duplicate(true)
	incoming["runtime_seconds"]=0
	incoming["duration_status"]="UNVERIFIED"
	incoming.erase("duration_source")
	assert(w._valid_cinema_record(incoming,false))
	var merged:Dictionary=w._merge_cinema_record(old,incoming)
	assert(merged["runtime_seconds"]==6000 and merged["duration_source"]=="verified fixture")
	var s:Dictionary={"id":"FILMIX_SERIES_QA","title":"Fixture series","media_type":"series","preview":"user://filmix_previews/FILMIX_SERIES_QA.webp","latest_season":2,"latest_episode":2,"episode_runtime_seconds":{"1":[100,200],"2":[300]},"complete_seasons":[1],"duration_status":"PARTIAL"}
	var r:Dictionary=s.duplicate(true)
	r["episode_runtime_seconds"]={"2":[0,400]}
	r["complete_seasons"]=[]
	var result:Dictionary=w._merge_cinema_record(s,r)
	assert(result["episode_runtime_seconds"]["1"]==[100,200])
	assert(result["episode_runtime_seconds"]["2"]==[300,400])
	assert(result["complete_seasons"]==[1])
	assert(w._valid_cinema_record(result,false))
	r["episode_runtime_seconds"]={"2":[-10]}
	assert(not w._valid_cinema_record(r,false))
	r["episode_runtime_seconds"]={"2":[0,400]}
	r["complete_seasons"]=[2]
	assert(not w._valid_cinema_record(r,false))
	r["preview"]="user://unrelated.webp"
	assert(not w._valid_cinema_record(r,false))
	print("PRIVATE_CINEMA_MERGE_PASS")
	quit(0)
