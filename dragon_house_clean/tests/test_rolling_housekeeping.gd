extends SceneTree
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
class MeasuredSlots:
	extends RefCounted
	func artifact_slots(room:Dictionary)->Array:
		if str(room.get("type",""))!="artifact":return []
		return [{"id":"ALT_A","xyz":[-0.7,0.8,-1.1],"dimensions":[0.3,0.3,0.3]},{"id":"ALT_B","xyz":[0.7,0.8,-1.1],"dimensions":[0.3,0.3,0.3]}]
	func cup_slots(_room:Dictionary)->Array:return []
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
	var w=W.new()
	w.save_path="user://qa_rolling_"+str(Time.get_ticks_usec())+".json"
	w.seed_world()
	var gallery:Dictionary=w.get_room(1,-1)
	var common:Dictionary=w.get_room(-2,0)
	var lib:Dictionary=w.get_room(2,0)
	var a:Dictionary=w.residents["RES_01"]
	var rid:String=str(gallery["id"])
	var cid:String=str(common["id"])
	# Two displaced artifacts whose canonical positions are now occupied;
	# deterministic sequential commits cannot choose the same measured slot.
	for n in range(2):
		var id:String="QA_"+str(n)
		var x:float=-0.2+float(n)*0.4
		assert(w.register_physical_object(id,id,"",rid,true,true,false,false,false,{"home_anchor":[x,0.6],"display_world_height":0.18}))
		a["room_id"]=rid
		assert(w.pickup_physical_object(id,"RES_01"))
		a["room_id"]=cid
		assert(w.place_physical_object(id,"RES_01",cid,"PLACED",[x,0.6]))
		assert(w.register_physical_object("BLOCK_"+str(n),"block","",rid,false,true,false,false,false,{"home_anchor":[x,0.6]}))
	w.housekeeping_navigation=MeasuredSlots.new()
	w.sim_clock=W.GAME_DAY_SECONDS
	assert(w.tick_object_home_reset()==2)
	assert(w.physical_object("QA_0")["current_support_id"]!=w.physical_object("QA_1")["current_support_id"])
	assert(w.physical_object("QA_0")["home_anchor"]!=w.physical_object("QA_0")["current_anchor"])
	assert(w.physical_object("QA_0")["home_room_id"]==rid)
	# Re-use refreshes the timestamp and invalidates the old due boundary.
	a["room_id"]=rid
	assert(w.pickup_physical_object("QA_0","RES_01"))
	a["room_id"]=cid
	assert(w.place_physical_object("QA_0","RES_01",cid,"PLACED",[0.0,0.6]))
	assert(w.tick_object_home_reset()==0)
	# Dirty cup at its own home: cleanup is an event and does not train preferences.
	w.housekeeping_navigation=null
	assert(w.register_physical_object("CUP_QA","cup","",cid,true,true,false,false,true,{"viewer_category":"cups","home_anchor":[1.0,0.8]}))
	w.runtime_state["beverages"]={"cups":{"CUP_QA":{"choice_instance_id":"QA_SERVE_1","remaining_ml":80.0,"pending_choice":{}}}}
	w.sim_clock+=W.GAME_DAY_SECONDS
	w.tick_object_home_reset()
	assert(float(w.runtime_state["beverages"]["cups"]["CUP_QA"]["remaining_ml"])==0.0)
	assert(not w.runtime_state["beverages"]["cups"]["CUP_QA"].has("pending_choice"))
	assert(w.save_world())
	var loaded=W.new()
	loaded.save_path=w.save_path
	loaded.load_or_seed()
	assert(float(loaded.runtime_state["beverages"]["cups"]["CUP_QA"]["remaining_ml"])==0.0)
	# A later serving may reuse a snapshot serial after crash rollback, but
	# the durable pickup event is distinct. A replayed cleanup must not empty it.
	loaded.residents["RES_01"]["room_id"]=cid
	assert(loaded.pickup_physical_object("CUP_QA","RES_01"))
	loaded.runtime_state["beverages"]["cups"]["CUP_QA"]={"choice_instance_id":"QA_SERVE_1","serving_pickup_event_id":str(loaded.physical_object("CUP_QA")["updated_event_id"]),"remaining_ml":55.0}
	assert(loaded.place_physical_object("CUP_QA","RES_01",cid,"PLACED",[1.0,0.8]))
	assert(float(loaded.runtime_state["beverages"]["cups"]["CUP_QA"]["remaining_ml"])==55.0)
	# Held book survives deadline; forgotten dropped book preserves progress.
	var m=M.new()
	m.setup(loaded)
	loaded.media["books"]=[{"id":"BOOK_QA","title":"QA","physical":true,"holder_id":"","location_room_id":str(lib["id"]),"home_room_id":str(lib["id"]),"last_interaction_at":loaded.sim_clock}]
	assert(m.borrow("RES_01","BOOK_QA",int(loaded.sim_clock)))
	assert(m.read("RES_01","BOOK_QA",90.0))
	loaded.sim_clock+=W.GAME_DAY_SECONDS
	assert(m.tick_book_home_reset()==0)
	assert(m.drop_book("RES_01","BOOK_QA",int(loaded.sim_clock)))
	loaded.sim_clock+=W.GAME_DAY_SECONDS-1.0
	assert(m.tick_book_home_reset()==0)
	loaded.sim_clock+=1.0
	assert(m.tick_book_home_reset()==1)
	assert(m._lookup("books","BOOK_QA")["progress_by_actor"]["RES_01"]==90.0)
	print("ROLLING_HOUSEKEEPING_PASS alternate_slots=distinct cup=empty book_progress=preserved")
	quit(0)
