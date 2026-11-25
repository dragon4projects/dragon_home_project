extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const N=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.save_path="user://teea008_cup_route_qa.json"
	w.seed_world()
	var nav=N.new()
	var rows:Dictionary={}
	var f:=FileAccess.open("res://data/teea008_review/room_layouts_xz.json",FileAccess.READ)
	for row in JSON.parse_string(f.get_as_text())["items"]:rows[row["variant_id"]]=row
	nav.configure(rows)
	var life=L.new()
	life.candidate_navigation=nav
	life.setup(w)
	assert(life.candidate_cups.register_review_mugs()==2)
	assert(life.candidate_cups.register_review_mugs()==0)
	var room:Dictionary=w.get_room(-2,0)
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	life._assign(a,{"intent":"GET_COFFEE","room":room})
	assert(a.get("cup_task_stage","")=="fetch",str(nav.cup_slots(room)))
	var id:String=str(a["cup_task_id"])
	assert(w.physical_object(id)["current_holder_id"]=="")
	assert(not life.candidate_cups.pickup(a))
	life._assign(b,{"intent":"GET_COFFEE","room":room})
	assert(str(b.get("cup_task_id",""))!=id)
	for tick in range(1200):
		life.clock+=0.125
		w.sim_clock=life.clock
		life._move(a,0.125)
		if a["phase"]!="travel":break
	assert(a.get("cup_task_stage","")=="hold")
	assert(w.physical_object(id)["current_holder_id"]=="RES_01")
	assert(w.physical_object(id)["canonical_owner_id"]=="")
	assert(not w.can_ambient_pickup_object(id))
	assert(w.save_world())
	var copy=W.new()
	copy.save_path=w.save_path
	copy.load_or_seed()
	var resumed=L.new()
	resumed.candidate_navigation=nav
	resumed.setup(copy)
	a=copy.residents["RES_01"]
	assert(copy.physical_object(id)["current_holder_id"]=="RES_01")
	assert(resumed.candidate_cups.put_back(a))
	var obj:Dictionary=copy.physical_object(id)
	assert(obj["current_holder_id"]=="" and obj["current_room_id"]==room["id"])
	assert(obj["current_anchor"]==obj["home_anchor"])
	assert(obj["canonical_owner_id"]=="")
	print("TEEA008_CUP_ROUTE_PASS pickup_at_station=true no_duplicate=true owner_unchanged=true replay=true")
	quit(0)
