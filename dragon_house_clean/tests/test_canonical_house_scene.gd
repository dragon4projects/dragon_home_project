extends SceneTree

func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.architecture_review and scene.teea008_live and scene.teea008_review.enabled)
	assert(scene.world.save_path=="user://dragon_house_canonical_architecture_20261125.json")
	assert(scene.room_root.get_child_count()==65)
	assert(scene.teea008_review.sketchfab_common_enabled)
	var overview_count:=0
	for node in scene.room_root.get_children():
		var overview:Node3D=node.get_node_or_null("Layer_OverviewCues")
		if overview!=null and int(overview.get_meta("real_model_count",0))>0:
			overview_count+=1
	assert(overview_count==15,str(overview_count))
	assert(scene.world.guest_room_for("NPC_CENTAUR")["size_id"]=="R2")
	var active:=0
	for profile in scene.world.read_resident_profiles():
		var actor:Dictionary=scene.world.residents[str(profile["id"])]
		assert(not str(actor.get("home_room_id","")).is_empty())
		if bool(actor.get("active",false)) and bool(actor.get("runtime_visual_bound",false)):
			active+=1
	assert(active==24)
	for id in ["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]:
		assert(bool(scene.world.residents[id].get("runtime_visual_bound",false)))
	var room:Dictionary=scene.world.get_room(-3,1)
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var group:Node3D=scene.room_root.get_node(str(room["id"]))
	assert(group.find_child("common_r3_animated_hearth_review",true,false)!=null)
	var dragon:Node3D=group.find_child("canonical_hearth_sleeping_dragon",true,false)
	assert(dragon!=null and dragon.get_child_count()==1)
	var overview:Node3D=group.get_node("Layer_OverviewCues")
	assert(overview.find_child("canonical_hearth_sleeping_dragon",true,false)!=null)
	assert(not overview.visible)
	# The same visual offset applies while stationary or travelling; physical
	# room floor/route/ownership remain untouched.
	assert(scene._creature_hover_height("npc_ai_magic_sphere",0.0)>0.8)
	assert(scene._creature_hover_height("npc_ai_magic_sphere",PI/4.0)>scene._creature_hover_height("npc_ai_magic_sphere",0.0))
	assert(scene._creature_hover_height("npc_rat",PI/4.0)==0.0)
	var nav=scene.life.candidate_navigation
	assert(not nav.clear(room,Vector2(6.45,-1.40)))
	assert(nav.clear(room,Vector2(6.45,1.50)))
	assert(nav.has_layout(scene.world.guest_room_for("NPC_CENTAUR")))
	for mode in ["HOUSE","LEVEL","ROOM","FOLLOW"]:
		scene.set_mode(mode)
		scene.update_render_lod()
		for node in scene.room_root.get_children():
			assert(node.visible)
			var physical:Dictionary=scene.world.room_by_id(str(node.name))
			if str(physical["type"])=="private":
				assert(node.get_node_or_null("LocalFurniture")==null)
	scene.set_mode("HOUSE")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	var bounds:Rect2=scene.camera_world_bounds()
	var view:Vector2=root.get_visible_rect().size
	for point in [Vector3(bounds.position.x,bounds.position.y,1.65),Vector3(bounds.end.x,bounds.end.y,1.65)]:
		var screen:Vector2=scene.camera.unproject_position(point)
		assert(screen.x>=0 and screen.x<=view.x and screen.y>=0 and screen.y<=view.y,str(screen))
	print("CANONICAL_HOUSE_SCENE_PASS rooms=65 all_modes_visible=true sleeping_dragon=true residents=",active)
	quit(0)
