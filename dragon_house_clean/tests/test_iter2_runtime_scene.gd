extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(FileAccess.file_exists("res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"))
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	var common:Dictionary=scene.world.get_room(-2,0)
	assert(not common.is_empty() and scene.world.room_size_modules(common)==3)
	assert(common["id"]==scene.world.get_room(0,0)["id"])
	assert(bool(common["immutable_topology"]))
	assert(scene.world.rooms.size()>=19)
	scene.update_render_lod()
	assert(scene.art_loaded_groups.size()>0)
	var actor:Dictionary=scene.world.residents["RES_01"]
	actor["room_id"]=common["id"]
	actor["level"]=0
	actor["visual_y"]=0.0
	actor["x"]=scene.world.room_center_pos(common).x
	actor["z"]=scene.world.room_space.BACK_Z
	scene.update_residents()
	var back_scale:float=scene.actor_sprites["RES_01"].scale.x
	actor["z"]=scene.world.room_space.FRONT_Z
	scene.update_residents()
	var front_scale:float=scene.actor_sprites["RES_01"].scale.x
	assert(absf(back_scale-0.62)<0.01)
	assert(absf(front_scale-1.0)<0.01)
	assert(back_scale<front_scale)
	var route:Array=scene.world.find_route(common["id"],scene.world.get_room(4,1)["id"],"RES_01")
	assert(not route.is_empty())
	var waypoints:Array=scene.life.locomotion.build_waypoints(
		scene.world,actor,route,"PURPOSEFUL_EXPLORE",Vector2(0.0,-1.82),-1.30)
	assert(not waypoints.is_empty())
	var has_horizontal:=false
	var has_lift:=false
	for point in waypoints:
		if str(point.get("kind","")) in ["connector_out","connector_in"]:
			has_horizontal=true
		if str(point.get("kind",""))=="lift":
			has_lift=true
	assert(has_horizontal and has_lift)
	print("ITER2_RUNTIME_SCENE_PASS common=R3 back_scale=%.2f front_scale=%.2f connectors=true lift=true" % [
		back_scale,front_scale])
	quit(0)
