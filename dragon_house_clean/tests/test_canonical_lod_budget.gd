extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.architecture_review and scene.teea008_live)
	var count:int=scene.room_root.get_child_count()
	assert(count==65)
	var w=scene.world
	var library:Dictionary=w.get_room(-6,0)
	var rid:String=str(library["id"])
	var center:Vector3=w.room_center_pos(library)+Vector3.UP*1.45
	var before:Dictionary=w.residents.duplicate(true)
	for mode in ["HOUSE","LEVEL"]:
		scene.set_mode(mode)
		for z in [100.0,10.0]:
			scene.zoom_current=z
			scene.smooth_focus=center
			scene.update_render_lod()
			assert(scene.detailed_room_groups.is_empty(),mode)
			for node in scene.room_root.get_children():assert(node.visible)
	var max_detail:=0
	for room in w.matching_rooms(["common","rest","library","cinema","music","study","artifact","workshop","kitchen"]):
		scene.selected_room=str(room["id"])
		scene.set_mode("ROOM")
		scene.zoom_current=scene.zoom
		scene.smooth_focus=scene.desired_focus
		scene.apply_camera(1.0)
		scene.update_render_lod()
		assert(scene.detailed_room_groups.has(str(room["id"])),str(room["id"]))
		var n:int=scene.detailed_room_groups.size()
		assert(n<=2,str(n))
		max_detail=maxi(max_detail,n)
		var created:int=scene.detail_materialization_count
		scene.update_render_lod()
		assert(scene.detail_materialization_count==created,"Identical view churn")
		for node in scene.room_root.get_children():
			assert(node.visible)
			if bool(node.get_meta("facade_only",false)):assert(not scene.detailed_room_groups.has(node.name))
	# Wheel-only inspection switches to FREE without requiring a room click.
	scene.set_mode("HOUSE")
	scene.zoom=45.0
	scene.zoom_current=45.0
	scene.zoom_around_pointer(Vector2(640,360),0.87)
	assert(scene.current_mode=="FREE")
	scene.smooth_focus=center
	scene.zoom_current=12.0
	scene.update_render_lod()
	assert(scene.detailed_room_groups.has(rid))
	assert(scene.detailed_room_groups.size()<=2)
	assert(w.residents==before,"Presentation must not mutate residents")
	scene.set_mode("HOUSE")
	scene.update_render_lod()
	assert(scene.detailed_room_groups.is_empty())
	assert(scene.room_root.get_child_count()==count)
	print("CANONICAL_LOD_BUDGET_PASS rooms=",count," max_rich=",max_detail," all_levels=true free_mode=true stable=true")
	quit(0)
