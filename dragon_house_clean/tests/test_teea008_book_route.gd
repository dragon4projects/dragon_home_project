extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const N=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func arrive(life,actor:Dictionary)->void:
	for i in range(2400):
		life.clock+=0.125
		life.world.sim_clock=life.clock
		life._move(actor,0.125)
		if str(actor["phase"])!="travel" or int(actor["waypoint_index"])==0:break
func run()->void:
	var w=W.new()
	w.save_path="user://teea008_book_route.json"
	w.seed_world()
	var library:Dictionary=w.get_room(2,0)
	var rest:Dictionary=w.get_room(1,0)
	var book:Dictionary={"id":"QA_PHYSICAL_BOOK","title":"QA book","physical":true,"location_room_id":library["id"],"home_room_id":library["id"],"holder_id":""}
	w.media["books"]=[book,{"id":"QA_REFERENCE","title":"Reference only","physical":false,"location_room_id":library["id"]}]
	var nav=N.new()
	var rows:Dictionary={}
	var f:=FileAccess.open("res://data/teea008_review/room_layouts_xz.json",FileAccess.READ)
	for row in JSON.parse_string(f.get_as_text())["items"]:rows[row["variant_id"]]=row
	nav.configure(rows)
	var life=L.new()
	life.candidate_navigation=nav
	life.daypart_override="day"
	for id in ["RES_01","RES_02"]:
		w.residents[id]["teea008_pose_wardrobe"]=nav.pose_profiles[id]["wardrobe"]
	life.setup(w)
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	life._assign(a,{"intent":"READ_BOOK","room":rest})
	assert(a["intent"]=="FETCH_BOOK" and a["phase"]=="travel")
	assert(book["holder_id"]=="" and book["location_room_id"]==library["id"])
	life._assign(b,{"intent":"READ_BOOK","room":rest})
	assert(not b.has("book_task_id"),"double reservation")
	assert(not life.media_runtime.borrow_at_shelf("RES_01",book["id"],library["id"]),"remote pickup")
	assert(w.save_world())
	var restored=W.new()
	restored.save_path=w.save_path
	restored.load_or_seed()
	var recovered=L.new()
	recovered.candidate_navigation=nav
	recovered.setup(restored)
	life=recovered
	w=restored
	a=w.residents["RES_01"]
	book=w.media["books"][0]
	assert(a["book_task_stage"]=="fetch" and book["holder_id"]=="")
	arrive(life,a)
	assert(a["book_task_stage"]=="read" and a["held_book"]==book["id"] and book["holder_id"]=="RES_01")
	assert(a["room_id"]==library["id"])
	arrive(life,a)
	assert(a["phase"]=="perform" and a["room_id"]==rest["id"] and a["intent"]=="READ_BOOK")
	assert(life.status(a)=="читает «QA book»")
	life.clock+=40.0
	assert(life._continue_book_task(a))
	assert(a["book_task_stage"]=="return" and book["holder_id"]=="RES_01")
	arrive(life,a)
	assert(book["holder_id"]=="" and book["location_room_id"]==library["id"] and not a.has("held_book"))
	assert(float(book["progress_by_actor"]["RES_01"])>=40.0)
	assert(w.journal.any(func(e):return e.get("event")=="BOOK_PICKED_UP_AT_SHELF"))
	assert(w.journal.any(func(e):return e.get("event")=="BOOK_RETURNED_AT_SHELF"))
	print("TEEA008_BOOK_ROUTE_PASS reserve_pickup_read_return restart=true duplicate_denied=true remote_denied=true")
	quit(0)
