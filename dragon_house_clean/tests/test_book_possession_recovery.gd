extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")

class FixtureNavigation extends RefCounted:
	func book_slots(_room:Dictionary)->Array:
		return [{"id":"slot0","station_id":"shelf0","xyz":[0.0,1.0,0.0]},{"id":"slot1","station_id":"shelf1","xyz":[1.0,1.0,0.0]},{"id":"slot2","station_id":"shelf2","xyz":[2.0,1.0,0.0]}]

func _initialize()->void:
	var w=W.new()
	var room:Dictionary=w.make_room(0,0,"library",3)
	var rid:String=str(room["id"])
	var life=Life.new()
	life.world=w
	life.clock=456.0
	w.sim_clock=456.0
	life.candidate_navigation=FixtureNavigation.new()
	life.media_runtime.world=w
	life.media_runtime.candidate_navigation=life.candidate_navigation
	w.residents={
		"a":{"id":"a","active":true,"room_id":rid,"phase":"idle","held_book":"wrong"},
		"b":{"id":"b","active":true,"room_id":rid,"phase":"travel","intent":"FETCH_BOOK","book_task_stage":"fetch","book_task_id":"free","book_source_room":rid,"station_room_id":rid,"station_anchor_id":"shelf1","waypoints":[{"kind":"station","room_id":rid}],"waypoint_index":0},
		"c":{"id":"c","active":true,"room_id":rid,"phase":"travel","intent":"FETCH_BOOK","book_task_stage":"fetch","book_task_id":"free","book_source_room":rid,"station_room_id":rid,"station_anchor_id":"shelf1","waypoints":[{"kind":"station","room_id":rid}],"waypoint_index":0}
	}
	w.media["books"]=[
		{"id":"held","title":"Held","physical":true,"holder_id":"a","location_room_id":"","home_room_id":rid,"progress_by_actor":{"a":300}},
		{"id":"free","title":"Free","physical":true,"holder_id":"","location_room_id":rid,"home_room_id":rid},
		{"id":"orphan","title":"Orphan","physical":true,"holder_id":"absent","location_room_id":"","home_room_id":rid}
	]
	w.runtime_state["teea008_book_slot_assignments"]={"held":{"room_id":rid,"slot_id":"slot0"},"free":{"room_id":rid,"slot_id":"slot1"}}
	assert(life.reconcile_book_possession()>0)
	assert(w.residents["a"]["held_book"]=="held")
	assert(w.residents["a"]["book_task_stage"]=="return_wait")
	assert(w.residents["a"]["until"]==456.0)
	assert(w.residents["b"]["book_task_stage"]=="fetch")
	assert(not w.residents["c"].has("book_task_stage"))
	assert(life.media_runtime._lookup("books","held")["holder_id"]=="a")
	assert(life.media_runtime._lookup("books","held")["progress_by_actor"]["a"]==300)
	assert(life.media_runtime._lookup("books","orphan")["holder_id"]=="absent")
	assert(w.runtime_state["book_recovery_issues"].size()==1)
	assert(not life.media_runtime.borrow("a","free",456))
	assert(life.reconcile_book_possession()==0)
	# A measured shelf reservation must remain unavailable to other books.
	var a:Dictionary=w.residents["a"]
	a["book_task_stage"]="return"
	a["phase"]="travel"
	a["book_return_room"]=rid
	a["book_return_slot"]="slot2"
	a["station_room_id"]=rid
	a["station_anchor_id"]="shelf2"
	a["waypoints"]=[{"kind":"station","room_id":rid}]
	assert(life.media_runtime._book_return_reservations("free").has(rid+"|slot2"))
	assert(life.media_runtime.book_return_claim_valid(a))
	# Actual catalogue truth is not modified by a second held-copy conflict.
	w.media["books"].append({"id":"extra","title":"Extra","physical":true,"holder_id":"a","location_room_id":"","home_room_id":rid})
	life.reconcile_book_possession()
	assert(a["held_book"]=="held")
	assert(life.media_runtime._lookup("books","extra")["holder_id"]=="a")
	assert(w.runtime_state["book_recovery_issues"].size()==2)
	print("BOOK_POSSESSION_RECOVERY_TEST_PASS")
	quit(0)
