extends SceneTree
## Regression for two bodies occupying one sofa in v0.6 screenshots.
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const S=preload("res://scripts/room_stations.gd")
const M=preload("res://scripts/main.gd")
const R=preload("res://scripts/room_locomotion.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world=W.new()
	world.save_path="user://test_seat_anchors_v09.json"
	world.seed_world()
	var life=L.new()
	life.setup(world)
	var lounge:Dictionary=world.get_room(-1,0)
	var body_a:Dictionary=world.residents["RES_01"]
	var body_b:Dictionary=world.residents["RES_02"]
	var body_c:Dictionary=world.residents["RES_03"]
	for actor in [body_a,body_b,body_c]:
		life._assign(actor,{"intent":"REST","room":lounge})
	assert(body_a["station_room_id"]==lounge["id"])
	assert(body_b["station_room_id"]==lounge["id"])
	assert(body_a.get("station_kind","")=="seat")
	assert(body_b.get("station_kind","")=="seat")
	assert(body_c.get("station_kind","")!="seat",
		"A third guest cannot be shown sitting on a two-seat sofa")
	assert(body_a["station_furniture_id"]=="SOFA_COMMON_MIDDLE")
	assert(body_b["station_furniture_id"]=="SOFA_COMMON_MIDDLE")
	assert(body_a["station_slot"] != body_b["station_slot"])
	var loc_a: Array=body_a["station_point"]
	var loc_b: Array=body_b["station_point"]
	assert(absf(float(loc_a[0])-float(loc_b[0]))>1.0)
	assert(is_equal_approx(float(loc_a[1]),float(loc_b[1])))
	for p in [loc_a,loc_b]:
		# Actual sofa is centered (x=0,z=-1.06), width=2.6, depth=0.9.
		assert(absf(float(p[0]))<1.05)
		assert(absf(float(p[1])-(-1.06))<0.52)
	for actor in [body_a,body_b,body_c]:
		var final:Array=actor["waypoints"][-1]["position"]
		var spot:Array=actor["station_point"]
		assert(is_equal_approx(float(final[0]),float(lounge["x"])*world.MODULE_W+float(spot[0])))
		assert(is_equal_approx(float(final[2]),float(spot[1])))
		if actor["station_kind"]=="seat":
			var approach:Dictionary=actor["waypoints"][-2]
			assert(approach["kind"]=="station_approach",
				"Travel to couch via frontage, not through the sofa")
			assert(is_equal_approx(float(approach["position"][0]),float(final[0])))
			assert(float(approach["position"][2])>float(final[2]))
	var stage=M.new()
	stage.world.save_path="user://test_seating_visual_v09.json"
	root.add_child(stage)
	current_scene=stage
	stage.zoom_current=12.0
	assert(stage.effective_camera_yaw()>0.10,
		"Close view needs shallow physical obliqueness to reveal depth")
	stage.zoom_current=86.0
	assert(absf(stage.effective_camera_yaw())<0.001,
		"House overview must remain almost elevation-like")
	stage.zoom_current=12.0
	body_a["phase"]="perform"
	body_b["phase"]="perform"
	body_c["phase"]="perform"
	assert(stage.desired_actor_animation(body_a)=="RELAXED_SIT")
	assert(stage.desired_actor_animation(body_b)=="RELAXED_SIT")
	assert(stage.desired_actor_animation(body_c)=="IDLE_S",
		"Standing near sofa cannot use sit pose")
	var visual_group:Dictionary=stage.world.merged_group(-1,0)
	var visual:Node3D=stage.room_root.get_node(visual_group["primary_id"])
	var depth:Node3D=visual.get_node("Layer_Structure/Stage_CutawayDepth")
	assert(depth.get_child_count()==3,"R3 public room needs 3 physically modeled depth bays")
	var private_room:Dictionary=stage.world.get_room(3,1)
	var private_group:Node3D=stage.room_root.get_node(private_room["id"])
	assert(private_group.get_node_or_null("Layer_Structure/Stage_CutawayDepth")==null)
	private_room["owner_id"]="RES_01"
	assert(S.new().single(stage.world,stage.world.residents["RES_01"],private_room,"REST").is_empty(),
		"Even owned door stays closed to public visualization")
	# v0.6 legacy save: three performing occupants at *exact same spot*.
	var legacy=W.new()
	legacy.save_path=world.save_path
	legacy.seed_world()
	for id in ["RES_01","RES_02","RES_03"]:
		var guest:Dictionary=legacy.residents[id]
		guest["room_id"]=lounge["id"]
		guest["x"]=-1.0*legacy.MODULE_W
		guest["z"]=-0.57
		guest["intent"]="REST"
		guest["phase"]="perform"
		guest["until"]=100.0
		guest.erase("station_slot")
		guest.erase("station_room_id")
	assert(legacy.save_world())
	var recovered=W.new()
	recovered.save_path=legacy.save_path
	recovered.load_or_seed()
	var new_life=L.new()
	new_life.setup(recovered)
	var assigned:Dictionary={}
	for id in ["RES_01","RES_02","RES_03"]:
		var resident:Dictionary=recovered.residents[id]
		assert(resident.has("station_slot"),"Legacy seated overlap must be migrated at load")
		var xz:String="%.4f:%.4f" % [float(resident["x"]),float(resident["z"])]
		assert(not assigned.has(xz),"Old overlapping actors must be separated immediately")
		assigned[xz]=true
	assert(recovered.residents["RES_01"]["station_kind"]=="seat")
	assert(recovered.residents["RES_02"]["station_kind"]=="seat")
	assert(recovered.residents["RES_03"]["station_kind"]!="seat")
	assert(recovered.save_world())
	var reloaded=W.new()
	reloaded.save_path=recovered.save_path
	reloaded.load_or_seed()
	var again=L.new()
	again.setup(reloaded)
	assert(reloaded.residents["RES_01"]["station_furniture_id"]=="SOFA_COMMON_MIDDLE")
	assert(reloaded.residents["RES_01"]["station_kind"]=="seat")
	# Actor still en route in old save gets endpoint repaired too.
	var walker:Dictionary=reloaded.residents["RES_04"]
	var locomotion=R.new()
	var route:Array=reloaded.find_route(walker["room_id"],reloaded.get_room(1,0)["id"],"RES_04")
	walker["waypoints"]=locomotion.build_waypoints(reloaded,walker,route,"REST")
	walker["waypoint_index"]=0
	walker["intent"]="REST"
	walker["phase"]="travel"
	var old_last: Array=walker["waypoints"][-1]["position"].duplicate()
	assert(S.new().migrate_legacy_positions(reloaded)>=1)
	assert(walker.has("station_slot"))
	var new_last: Array=walker["waypoints"][-1]["position"]
	assert(old_last!=new_last,"Old walking route must be rebased to a unique station")
	for path in [world.save_path,stage.world.save_path]:
		for ext in ["",".bak",".tmp"]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path+ext))
	print("SOFA_SEATING_V09_PASS 2_seats=unique 3rd=standing private=blocked v06_save=migrated 3D_depth=R3")
	quit(0)

