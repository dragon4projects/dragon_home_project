extends SceneTree
const W = preload("res://scripts/world_model.gd")
const S = preload("res://scripts/room_stations.gd")

func _initialize() -> void:
	var w = W.new()
	w.save_path="user://test_room_station_v07.json"
	w.seed_world()
	var station = S.new()
	var common: Dictionary = w.get_room(-2,0)
	assert(common["id"]==w.get_room(0,0)["id"])
	assert(w.room_size_modules(common)==3)
	assert(station.capacity(common)==16)
	var layout:Array=station.layout_for_world(w,common)
	assert(layout.size()==16)
	var max_abs_x: float = 0.0
	for spot in layout:
		var local:Vector2=spot["offset"]
		max_abs_x=maxf(max_abs_x,absf(local.x))
		assert(w.room_contains_local(common,local,0.05))
	assert(max_abs_x>2.20,"R3 stations must occupy the physical width, not one R1 cell")
	var positions:Dictionary={}
	for ix in range(16):
		var a_id: String="TEST_GUEST_%02d" % ix
		var actor: Dictionary={"id":a_id,"active":true,"phase":"perform",
			"room_id":w.get_room(-5,0)["id"],"station_slot":-1}
		w.residents[a_id]=actor
		var claim: Dictionary=station.single(w,actor,common)
		assert(not claim.is_empty(),"16 positions must fit in physical R3")
		station.commit_claim(actor,claim)
		var offset:Vector2=claim["offset"]
		var world_pos:Vector3=w.room_local_to_world(common,offset)
		var absolute:String="%.3f:%0.3f" % [world_pos.x,world_pos.z]
		assert(not positions.has(absolute),"All R3 stations must be geometrically unique")
		positions[absolute]=true
	assert(positions.size()==16)
	assert(station.available_count(w,common)==0)
	var overflow:Dictionary={"id":"TEST_GUEST_17","active":true,"phase":"travel"}
	assert(station.single(w,overflow,common).is_empty(),
		"Capacity is R3=16; movement space is not extra station capacity")
	var freed:Dictionary=w.residents["TEST_GUEST_09"]
	station.release(freed)
	assert(station.available_count(w,common)==1)
	w.residents[overflow["id"]]=overflow
	var replacement: Dictionary = station.single(w,overflow,common)
	assert(not replacement.is_empty())
	station.commit_claim(overflow,replacement)
	assert(station.available_count(w,common)==0)
	var private_room:Dictionary=w.get_room(3,1)
	assert(station.capacity(private_room)==0)
	assert(not station.can_reserve(w,private_room))
	var rest:Dictionary=w.get_room(1,0)
	assert(station.capacity(rest)==4)
	var pair_a:Dictionary=w.residents["RES_01"]
	var pair_b:Dictionary=w.residents["RES_02"]
	var social:Dictionary=station.pair(w,pair_a,pair_b,rest)
	assert(not social.is_empty())
	var left:Vector2=social["actor"]["offset"]
	var right:Vector2=social["partner"]["offset"]
	assert(absf(left.x-right.x)>0.05 and absf(left.x-right.x)<1.35)
	assert(is_equal_approx(left.y,right.y))
	station.commit_claim(pair_a,social["actor"])
	station.commit_claim(pair_b,social["partner"])
	pair_a["phase"]="perform"
	pair_b["phase"]="travel"
	assert(station.used_slots(w,str(rest["id"])).size()==2)
	assert(w.save_world())
	var loaded=W.new()
	loaded.save_path=w.save_path
	loaded.load_or_seed()
	assert(loaded.room_size_modules(loaded.get_room(-2,0))==3)
	assert(loaded.residents["RES_01"].has("station_point"))
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(w.save_path+suffix))
	print("STATION_RESERVATIONS_V08_PASS R1=4 R2=8 R3=16 continuous_XZ=true")
	quit(0)
