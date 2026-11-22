extends SceneTree
const R = preload("res://scripts/interaction_anchor_registry.gd")
const S = preload("res://scripts/room_stations.gd")
const W = preload("res://scripts/world_model.gd")

func _initialize() -> void:
	call_deferred("run")

func _write_test_json(path: String, doc: Dictionary) -> void:
	var f:=FileAccess.open(path,FileAccess.WRITE)
	assert(f!=null)
	f.store_string(JSON.stringify(doc))
	f.close()

func run() -> void:
	var reg=R.new()
	assert(reg.initialize(), "Baseline interaction registry MUST load")
	var world=W.new()
	world.save_path="user://test_interaction_contract_v10.json"
	world.seed_world()
	var station=S.new()
	assert(station.furniture.source_path==R.DEFAULT_PATH)
	var rooms_with_props:=0
	for room in world.rooms:
		var spots: Array=reg.for_room(room)
		if room.get("privacy","public")!="public":
			assert(spots.is_empty(),"Private interior cannot have public anchors")
			continue
		var ids: Dictionary={}
		for spot in spots:
			assert(not ids.has(spot["id"]))
			ids[spot["id"]]=true
			assert(absf(float(spot["x"]))<2.0)
			assert(str(spot["pose_hint"])!="")
		if not spots.is_empty():
			rooms_with_props+=1
	assert(rooms_with_props>=9)

	var common=world.get_room(-1,0)
	var sofa: Array=reg.for_room(common)
	assert(sofa.size()==2)
	assert(sofa[0]["furniture_id"]=="SOFA_COMMON_MIDDLE")
	assert(sofa[1]["furniture_id"]=="SOFA_COMMON_MIDDLE")
	var person: Dictionary=world.residents["RES_01"]
	var claim: Dictionary=station.single(world,person,common,"REST")
	assert(claim.get("kind","")=="seat")
	assert(claim["pose_hint"]=="RELAXED_SIT")
	station.commit_claim(person,claim)
	person["room_id"]=common["id"]
	person["phase"]="perform"
	assert(person["station_anchor_id"]!="")
	assert(person["station_pose_hint"]=="RELAXED_SIT")
	assert(is_equal_approx(float(person["station_approach_z"]),0.95))

	# The actual procedural scene must contain the prop names from the JSON,
	# not merely imaginary data positions attached to no visible furniture.
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_scene_furniture_contract_v10.json"
	root.add_child(scene)
	current_scene=scene
	var checked:=0
	for room in scene.world.rooms:
		var anchors: Array=reg.for_room(room)
		if anchors.is_empty():
			continue
		scene.zoom_current=10.0
		scene.smooth_focus=Vector3(float(room["x"])*scene.W,float(room["level"])*scene.H,0)
		scene.update_render_lod()
		var group: Dictionary=scene.world.merged_group(int(room["x"]),int(room["level"]))
		var visual:Node3D=scene.room_root.get_node(group["primary_id"])
		var module:Node3D=visual.get_node("LocalFurniture").get_node(str(room["id"])+"_furniture")
		for a in anchors:
			var expected: String=str(a["furniture_id"])
			assert(module.get_node_or_null(expected)!=null,
				"An advertised seat/workstation must be present as a visible scene object: "+expected)
			checked+=1
	assert(checked>=17)

	# Candidate JSON is VALIDATION ONLY and must never mutate the live source.
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(R.DEFAULT_PATH))
	var candidate_path="user://test_anchor_candidate_v10.json"
	var candidate=original.duplicate(true)
	candidate["room_profiles"]["rest"].reverse()
	_write_test_json(candidate_path,candidate)
	var check: Dictionary=reg.check_candidate_patch(candidate_path)
	assert(check["valid"] and not check["integrated"] and not check["approved"])
	assert(reg.for_room(world.get_room(1,0))==original["room_profiles"]["rest"],
		"Read-only candidate validation must not silently change live physics")

	# On an explicitly reviewed future rearrangement, stable IDs remap saved
	# seats, even if the numeric slot order changes.
	var change_for_test=S.new()
	assert(change_for_test.furniture.initialize(candidate_path))
	var rest_room:Dictionary=world.get_room(1,0)
	var resident:Dictionary=world.residents["RES_02"]
	resident["room_id"]=rest_room["id"]
	resident["phase"]="perform"
	var old_claim=station.single(world,resident,rest_room,"REST")
	assert(not old_claim.is_empty())
	station.commit_claim(resident,old_claim)
	var persisted_id: String=resident["station_anchor_id"]
	var persisted_slot: int=int(resident["station_slot"])
	var prior_x:float=resident["x"]
	assert(change_for_test.reconcile(world)==0)
	assert(resident["station_anchor_id"]==persisted_id)
	assert(int(resident["station_slot"])!=persisted_slot)
	assert(resident["station_kind"]=="seat")
	assert(not is_equal_approx(float(resident["x"]),prior_x))
	# Bad sources cannot enter live data.
	var malformed=original.duplicate(true)
	malformed["room_profiles"]["private"]=[{
		"id":"forbidden","x":0,"z":0,"kind":"seat",
		"furniture_id":"SECRET","pose_hint":"RELAXED_SIT","approach_z":0.95
	}]
	_write_test_json(candidate_path,malformed)
	assert(not reg.check_candidate_patch(candidate_path)["valid"])
	malformed=original.duplicate(true)
	malformed["room_profiles"]["rest"][0]["x"]=3.2
	_write_test_json(candidate_path,malformed)
	assert(not reg.check_candidate_patch(candidate_path)["valid"])
	malformed=original.duplicate(true)
	malformed["room_profiles"]["rest"][1]["id"]=malformed["room_profiles"]["rest"][0]["id"]
	_write_test_json(candidate_path,malformed)
	assert(not reg.check_candidate_patch(candidate_path)["valid"])
	assert(reg.for_room(common).size()==2,"Unapproved malformed proposals cannot affect real anchors")
	for p in [candidate_path,world.save_path,scene.world.save_path]:
		for suffix in ["",".bak",".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p+suffix))
	print("FURNITURE_CONTRACT_V10_PASS scene_objects=%d stable_id_remap=true private=blocked candidate=review_only" % checked)
	quit(0)

