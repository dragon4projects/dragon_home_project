extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/life.gd")
const M=preload("res://scripts/media_runtime.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.canonical_house_seed=true
	w.save_path="user://reading_station_upgrade_"+str(Time.get_ticks_usec())+".json"
	w.seed_world()
	var bank=B.new()
	assert(bank.initialize(true))
	bank.apply_architecture_layouts()
	var nav=N.new()
	nav.configure(bank.layouts)
	var room:Dictionary=w.room_by_id("ROOM_0027")
	var library:Dictionary=w.matching_rooms(["library"])[0]
	for a in w.residents.values():a.active=false
	w.media["books"]=[]
	var m=M.new()
	m.setup(w)
	w.sim_clock=1000.0
	for i in range(1,3):
		var id:String="RES_%02d"%i
		var bid:String="QA_BOOK_%d"%i
		w.media.books.append({"id":bid,"title":bid,"physical":true,"holder_id":"","location_room_id":library.id,"home_room_id":library.id,"reading_seconds":500.0})
		w.residents[id].active=true
		assert(m.borrow(id,bid,1000))
		var actor:Dictionary=w.residents[id]
		var old:=Vector2(-2.6,0.632194) if i==1 else Vector2(1.5,0.962194)
		var pos:Vector3=w.room_local_to_world(room,old)
		actor.merge({"active":true,"room_id":room.id,"level":room.level,"x":pos.x if i==1 else pos.x+1.0,"visual_y":pos.y,"z":pos.z,"phase":"perform","intent":"READ_BOOK","station_room_id":room.id,"station_slot":i,"station_anchor_id":"common_r3_p3_chair_center.seat_1" if i==1 else "canonical_hearth_extra_chair.seat_1","station_point":[old.x,old.y],"held_book":bid,"book_task_id":bid,"book_task_stage":"read"},true)
		assert(m.begin_reading(actor,1000.0,200.0))
	w.sim_clock=1067.0
	w.runtime_state["teea008_navigation_initialized"]=true
	w.runtime_state["teea008_geometry_revision"]="CANONICAL_SOCIAL_INTERIOR_20261125_V1|LIBRARY_GALLERY_V1|MEDIA_WORK_V1|GUEST_DISPLAY_V1"
	assert(w.save_world())
	var restored=W.new()
	restored.canonical_house_seed=true
	restored.save_path=w.save_path
	assert(restored.load_or_seed())
	var life=L.new()
	life.candidate_navigation=nav
	life.setup(restored)
	var a:Dictionary=restored.residents.RES_01
	var b:Dictionary=restored.residents.RES_02
	assert(life.media_runtime.book_history(a.id,life.media_runtime._lookup("books","QA_BOOK_1")).progress==67.0)
	assert(life.media_runtime.book_history(b.id,life.media_runtime._lookup("books","QA_BOOK_2")).progress==0.0)
	assert(a.held_book=="QA_BOOK_1" and a.book_task_stage=="return_wait" and not a.has("reading_session"))
	assert(life.media_runtime._lookup("books","QA_BOOK_1").holder_id==a.id)
	assert(restored.save_world())
	var again=W.new()
	again.canonical_house_seed=true
	again.save_path=w.save_path
	assert(again.load_or_seed())
	var second=L.new()
	second.candidate_navigation=nav
	second.setup(again)
	assert(second.media_runtime.book_history(a.id,second.media_runtime._lookup("books","QA_BOOK_1")).progress==67.0)
	assert(again.sim_clock==1067.0)
	print("READING_STATION_UPGRADE_PASS credited=67 wrong_position=0 retained_copy=true reload_idempotent=true")
	quit(0)
