extends SceneTree
const W = preload("res://scripts/world_model.gd")
const S = preload("res://scripts/room_stations.gd")
const L = preload("res://scripts/life.gd")
func _initialize() -> void:
	var w = W.new()
	w.save_path="user://test_room_station_v07.json"
	w.seed_world()
	var station = S.new()
	var cell: Dictionary = w.get_room(-2,0)
	var group: Dictionary = w.merged_group(-1,0)
	assert(group["width"]==3 and group["cells"].size()==3)
	assert(station.capacity(cell)==10)
	assert(station.layout(cell).size()==10)
	var positions: Dictionary = {}
	# Synthetic guests are test-only; NO live/dormant resident is activated.
	for ix in range(30):
		var a_id: String="TEST_GUEST_%02d" % ix
		var actor: Dictionary={"id":a_id,"active":true,"phase":"travel",
			"room_id":w.get_room(-5,0)["id"],"station_slot":-1}
		w.residents[a_id]=actor
		var destination: Dictionary=group["cells"][int(ix/10)]
		var claim: Dictionary=station.single(w,actor,destination)
		assert(not claim.is_empty(),"30 positions must fit in R3 Common")
		station.commit_claim(actor,claim)
		var offset: Vector2=claim["offset"]
		assert(absf(offset.x)<2.05 and offset.y>-0.90 and offset.y<0.9)
		var absolute: String="%.3f:%0.3f:%s" % [
			float(destination["x"])*w.MODULE_W+offset.x,offset.y,str(destination["level"])]
		assert(not positions.has(absolute),"All 30 seats must be geometrically unique")
		positions[absolute]=true
	for room in group["cells"]:
		assert(station.available_count(w,room)==0)
		assert(not station.can_reserve(w,room))
		var overflow: Dictionary={"id":"TEST_GUEST_31","active":true,"phase":"travel"}
		assert(station.single(w,overflow,room).is_empty(),
			"Never assign a duplicate when all 30 places are reserved")
	assert(positions.size()==30)
	# Release exactly one slot, then the same room becomes bookable.
	var freed:Dictionary=w.residents["TEST_GUEST_09"]
	var origin: String=str(freed["station_room_id"])
	station.release(freed)
	assert(station.available_count(w,w.room_by_id(origin))==1)
	var replacement: Dictionary={"id":"TEST_GUEST_31","active":true,"phase":"travel"}
	w.residents[replacement["id"]]=replacement
	var replacement_claim:Dictionary=station.single(w,replacement,w.room_by_id(origin))
	assert(not replacement_claim.is_empty())
	station.commit_claim(replacement,replacement_claim)
	assert(station.available_count(w,w.room_by_id(origin))==0)
	# Private door is public transit but never a public station destination.
	var private_room:Dictionary=w.get_room(3,1)
	assert(private_room["public_frontage"])
	assert(station.available_count(w,private_room)==0)
	assert(not station.can_reserve(w,private_room))
	# A social pair reserves *adjacent* same-row stations, never identical.
	var pair_cell:Dictionary=w.get_room(4,1)
	var pair_a:Dictionary=w.residents["RES_01"]
	var pair_b:Dictionary=w.residents["RES_02"]
	var social:Dictionary=station.pair(w,pair_a,pair_b,pair_cell)
	assert(not social.is_empty())
	var left:Vector2=social["actor"]["offset"]
	var right:Vector2=social["partner"]["offset"]
	assert(absf(left.x-right.x)>0.05 and absf(left.x-right.x)<1.3)
	assert(is_equal_approx(left.y,right.y))
	station.commit_claim(pair_a,social["actor"])
	station.commit_claim(pair_b,social["partner"])
	pair_a["phase"]="travel"
	pair_b["phase"]="travel"
	assert(station.used_slots(w,str(pair_cell["id"])).size()==2)
	# Stale duplicate in a snapshot is reconciled deterministically.
	pair_b["station_slot"]=pair_a["station_slot"]
	pair_b["waypoints"]=[{"kind":"outdated"}]
	w.sim_clock=65
	assert(station.reconcile(w)==1)
	var expected_to_release:Dictionary = pair_a if str(pair_a.get("station_room_id",""))=="" else pair_b
	assert(not expected_to_release.has("station_slot"))
	assert(expected_to_release.get("phase","")=="idle")
	assert(expected_to_release.get("waypoints",[]).is_empty())
	# Real life scheduler uses claims for both people, not independent hash spots.
	var pair_actor:Dictionary=w.residents["RES_03"]
	var life=L.new()
	life.setup(w)
	# Preseeded dummy 30 people are outside the chosen upper room.
	life._assign(pair_actor,{"intent":"TALK_PAIR","room":w.get_room(1,0)})
	var partner_id:String=str(pair_actor.get("partner_id",""))
	assert(partner_id!="","Must book reciprocal physical positions")
	var other:Dictionary=w.residents[partner_id]
	assert(pair_actor["station_room_id"] == other["station_room_id"])
	assert(int(pair_actor["station_slot"])!=int(other["station_slot"]))
	var target_a:Array=pair_actor["waypoints"][-1]["position"]
	var target_b:Array=other["waypoints"][-1]["position"]
	assert(absf(float(target_a[0])-float(target_b[0]))<1.30)
	assert(not is_equal_approx(float(target_a[0]),float(target_b[0])))
	assert(is_equal_approx(float(target_a[2]),float(target_b[2])))
	# All actor-owned claims are saved as primitive types, never Vector2 JSON.
	assert(w.save_world())
	var loaded=W.new()
	loaded.save_path=w.save_path
	loaded.load_or_seed()
	assert(loaded.residents["RES_03"].has("station_point"))
	assert(typeof(loaded.residents["RES_03"]["station_point"]) == TYPE_ARRAY)
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+suffix))
	print("STATION_RESERVATIONS_V07_PASS common_R3=30 unique, private=0, pair=adjacent, snapshot=stable")
	quit(0)

