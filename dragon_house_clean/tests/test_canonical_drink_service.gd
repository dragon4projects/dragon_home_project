extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var life=scene.life
	var beverage=life.candidate_cups.beverages
	assert(beverage.enabled)
	var actor:Dictionary=world.residents["RES_01"]
	var checked:=0
	for room in world.matching_rooms(["common","rest","kitchen"]):
		var sources:Array=life.candidate_cups.service_sources(actor,room)
		var kinds:Dictionary={}
		for source in sources:
			kinds[source["type"]]=true
			assert(not life.candidate_navigation.path(room,Vector2(-7.12,1.5),source["approach"]).is_empty(),str([room["id"],source]))
		assert(kinds.has("BAR") and kinds.has("COFFEE_NOOK"),str([room["id"],sources]))
		checked+=1
	assert(checked==4)
	var room:Dictionary=world.get_room(-3,1)
	var center:Vector3=world.room_center_pos(room)
	life.stations.release(actor)
	actor["room_id"]=room["id"]
	actor["level"]=room["level"]
	actor["x"]=center.x
	actor["visual_y"]=center.y
	actor["z"]=1.5
	actor["phase"]="idle"
	beverage.forced_drinks["RES_01"]="RED_WINE"
	life._assign(actor,{"room":room,"intent":"GET_COFFEE"})
	assert(actor.get("cup_task_stage","")=="fetch")
	var cup_id:String=str(actor["cup_task_id"])
	var passed_service:=false
	for i in range(1200):
		life.clock+=0.125
		world.sim_clock=life.clock
		life._move(actor,0.125)
		if str(actor.get("cup_task_stage",""))=="serve":
			passed_service=true
			assert(float(beverage.content(cup_id).get("remaining_ml",0))==0.0)
		if str(actor.get("cup_task_stage",""))=="hold":break
	assert(passed_service and str(actor["cup_task_stage"])=="hold")
	assert(str(beverage.content(cup_id)["content_id"])=="RED_WINE")
	assert(str(actor["drink_service_id"]).ends_with("_bar_counter"))
	assert(not life.candidate_cups.put_back(actor))
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_residents()
	scene.update_physical_objects()
	var anchor:Node3D=scene.object_nodes[cup_id]
	var label:Label3D=anchor.get_node("BeverageContent")
	assert(label.visible and label.text=="Красное вино" and anchor.visible)
	assert(beverage.sip(cup_id,"RES_01"))
	assert(int(beverage.history("RES_01")["total_choices"])==1)
	actor["drink_sips_left"]=0
	actor.erase("drink_service_id")
	assert(life._route_cup_return(actor))
	for i in range(1200):
		life.clock+=0.125
		world.sim_clock=life.clock
		life._move(actor,0.125)
		if str(actor["phase"])!="travel":break
	assert(life.candidate_cups.put_back(actor))
	life._clear_cup_task(actor)
	scene.update_physical_objects()
	assert(anchor.visible and label.visible and label.text=="Красное вино")
	assert(world.save_world())
	var W=load("res://scripts/world_model.gd")
	var copy=W.new()
	copy.canonical_house_seed=true
	copy.save_path=world.save_path
	copy.load_or_seed()
	var B=load("res://scripts/canonical_beverage_runtime.gd")
	var restored=B.new()
	restored.setup(copy)
	assert(float(restored.content(cup_id)["remaining_ml"])==112.5)
	assert(int(restored.history("RES_01")["total_choices"])==1)
	beverage.empty_cup(cup_id)
	scene.update_physical_objects()
	assert(not label.visible)
	print("CANONICAL_DRINK_SERVICE_PASS rooms=",checked," bar_route=true physical_return=true partial_reload=true labels=true")
	quit(0)
