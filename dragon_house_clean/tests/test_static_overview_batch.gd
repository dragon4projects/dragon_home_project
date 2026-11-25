extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.architecture_review and scene.teea008_live)
	var saved:=0
	var sources:=0
	var batches:=0
	for room in scene.room_root.get_children():
		var cue:Node3D=room.get_node_or_null("Layer_OverviewCues")
		if bool(room.get_meta("facade_only",false)):
			assert(cue==null)
			continue
		if cue==null or not cue.has_meta("static_overview_batch"):continue
		var stats:Dictionary=cue.get_meta("static_overview_batch")
		var originals:=0
		var actual_batches:=0
		for mesh in cue.find_children("*","MeshInstance3D",true,false):
			if mesh.has_meta("overview_batched"):
				assert(not mesh.visible)
				originals+=1
		for child in cue.get_children():
			if str(child.name).begins_with("OverviewStaticBatch_") or str(child.name).begins_with("OverviewInstanceBatch_"):
				assert(child.visible)
				actual_batches+=1
		assert(originals==int(stats["sources"]) and actual_batches==int(stats["batches"]))
		saved+=int(stats["saved"])
		sources+=originals
		batches+=actual_batches
	assert(saved>50 and sources-batches==saved)
	var w=scene.world
	var snapshot:Dictionary=w.residents.duplicate(true)
	var room:Dictionary=w.get_room(-3,1)
	scene.selected_room=str(room["id"])
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var group:Node3D=scene.room_root.get_node(str(room["id"]))
	assert(not group.get_node("Layer_OverviewCues").visible)
	assert(group.get_node("LocalFurniture").visible)
	scene.set_mode("HOUSE")
	assert(group.get_node("Layer_OverviewCues").visible)
	assert(not group.get_node("LocalFurniture").visible)
	var guest:Dictionary=w.guest_room_for("NPC_CENTAUR")
	var gid:String=str(guest["id"])
	assert(w.set_guest_room_open(gid,false))
	scene.update_render_lod()
	assert(scene.room_root.get_node(gid).get_node_or_null("Layer_OverviewCues")==null)
	assert(w.set_guest_room_open(gid,true))
	scene.update_render_lod()
	assert(scene.room_root.get_node(gid).get_node_or_null("Layer_OverviewCues")!=null)
	assert(w.residents==snapshot)
	print("STATIC_OVERVIEW_BATCH_PASS sources=",sources," batches=",batches," saved=",saved," room_visibility=true privacy_roundtrip=true")
	quit(0)
