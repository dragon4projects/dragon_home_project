extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
func _initialize()->void:call_deferred("run")
func _book(id:String,room:String,seconds:float,sid:String="",index:int=0)->Dictionary:
	var b:Dictionary={"id":id,"work_id":id,"title":id,"physical":true,"location_room_id":room,"home_room_id":room,"holder_id":"","reading_seconds":seconds}
	if sid!="":
		b["series_id"]=sid
		b["series_index"]=index
		b["series_catalog_last_index"]=2
	return b
func _start(w,m,id:String,book:String,room:String,now:float,duration:float)->Dictionary:
	w.sim_clock=now
	assert(m.borrow(id,book,int(now)))
	var actor:Dictionary=w.residents[id]
	actor["held_book"]=book
	actor["room_id"]=room
	actor["station_room_id"]=room
	actor["phase"]="perform"
	actor["intent"]="READ_BOOK"
	assert(m.begin_reading(actor,now,duration))
	return actor
func _pause(w,m,actor:Dictionary,now:float)->void:
	w.sim_clock=now
	assert(m.pause_reading(actor,now))
	assert(m.return_book(str(actor["id"]),str(actor["held_book"])))
	actor.erase("held_book")
	actor["phase"]="idle"
func run()->void:
	var w=W.new()
	w.save_path="user://reading_lifecycle_qa_"+str(Time.get_ticks_usec())+".json"
	w.seed_world()
	var room:String=str(w.get_room(2,0)["id"])
	w.media["books"]=[_book("V1",room,100.0,"S",1),_book("V2",room,120.0,"S",2),_book("DETOUR",room,60.0)]
	var m=M.new()
	m.setup(w)
	var rng=RandomNumberGenerator.new()
	rng.seed=42
	assert(not m.book_eligible("RES_01",m._lookup("books","V2"),0))
	var a:Dictionary=_start(w,m,"RES_01","V1",room,100.0,100.0)
	assert(not m.borrow("RES_02","V1",101))
	_pause(w,m,a,140.0)
	assert(m.book_history("RES_01",m._lookup("books","V1"))["progress"]==40.0)
	assert(m.borrow("RES_02","V1",140))
	var choices:Array=m.choose_book_options("RES_01",rng,140.0)
	assert(choices.size()==1 and choices[0]["id"]=="DETOUR")
	assert(m._reading_state("RES_01")["wait_work_id"]=="V1")
	a=_start(w,m,"RES_01","DETOUR",room,150.0,60.0)
	_pause(w,m,a,180.0)
	assert(m.return_book("RES_02","V1"))
	assert(m.choose_book_options("RES_01",rng,180.0)[0]["id"]=="V1")
	a=_start(w,m,"RES_01","V1",room,200.0,120.0)
	assert(a["reading_session"]["ends_at"]==260.0)
	assert(m._reading_state("RES_01")["wait_work_id"]=="")
	w.sim_clock=220.0
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	m.setup(copy)
	a=copy.residents["RES_01"]
	assert(m.reading_session_valid(a,220.0))
	assert(a["reading_session"]["progress_at_start"]==40.0)
	assert(a["reading_session"]["ends_at"]==260.0)
	_pause(copy,m,a,260.0)
	assert(m.book_history("RES_01",m._lookup("books","V1"))["completed_count"]==1)
	assert(m.book_history("RES_02",m._lookup("books","V1"))["completed_count"]==0)
	assert(not m.book_eligible("RES_01",m._lookup("books","V1"),261.0))
	assert(m.book_eligible("RES_01",m._lookup("books","V2"),261.0))
	# Complete the second volume; the entire cycle now has a replay delay.
	a=_start(copy,m,"RES_01","V2",room,300.0,120.0)
	_pause(copy,m,a,420.0)
	var state:Dictionary=m._reading_state("RES_01")
	assert(state["series"]["S"]["complete"])
	assert(state["series"]["S"]["completed_cycles"]==1)
	assert(not m.book_eligible("RES_01",m._lookup("books","V1"),420.0+W.GAME_DAY_SECONDS-0.01))
	var repeat_at:float=420.0+W.GAME_DAY_SECONDS
	assert(m.book_eligible("RES_01",m._lookup("books","V1"),repeat_at))
	a=_start(copy,m,"RES_01","V1",room,repeat_at,100.0)
	assert(state["series"]["S"]["cycle"]==1)
	_pause(copy,m,a,repeat_at+100.0)
	assert(m.book_history("RES_01",m._lookup("books","V1"))["completed_count"]==2)
	assert(m.book_eligible("RES_01",m._lookup("books","V2"),repeat_at+100.0))
	print("READING_LIFECYCLE_PASS wait_detour=true progress_reload=true series_replay=true independent=true")
	quit(0)
