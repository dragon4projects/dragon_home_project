extends SceneTree
func _initialize()->void:
	call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	assert(scene.teea008_review.enabled,scene.teea008_review.error)
	assert(scene.world.save_path=="user://dragon_house_teea008_review.json")
	assert(scene.world.rooms.size()==22)
	var checked:int=0
	for room in scene.world.rooms:
		if not scene.world.public_cutaway_allowed(room):continue
		var id:String=str(room["id"])
		var group:Dictionary=scene.visual_room_groups[id]
		if not bool(group.get("teea008_review",false)):continue
		var group_node:Node3D=scene.room_root.get_node(id)
		scene.current_mode="ROOM"
		scene.semantic_view.set_view(scene.world,"ROOM",id)
		scene.smooth_focus=scene.world.room_center_pos(room)+Vector3(0,1.5,0)
		scene.desired_focus=scene.smooth_focus
		scene.zoom=12.0
		scene.zoom_current=12.0
		scene.apply_camera(0.1)
		scene.update_render_lod()
		var furn:Node3D=group_node.get_node_or_null("LocalFurniture/PhysicalFurniture/TEEA008CandidateFurniture")
		assert(furn!=null,id)
		assert(furn.get_child_count()>0,id)
		assert(group_node.get_node_or_null("Layer_ApprovedArt/Art_furniture_back")==null,id)
		if str(room["type"])=="common":
			assert(group_node.get_node_or_null("LocalFurniture/PhysicalDressing/Dressing_Fireplace")!=null)
		checked+=1
	assert(checked>=12)
	# New rooms are actual immutable-width volumes. No seed room is replaced.
	var original:Dictionary=scene.world.get_room(-2,0).duplicate(true)
	assert(scene.world.build_room(7,0,"cinema",3))
	assert(scene.world.get_room(-2,0)==original)
	scene.make_rooms()
	var built:Dictionary=scene.world.get_room(7,0)
	var built_id:String=str(built["id"])
	scene.semantic_view.set_view(scene.world,"ROOM",built_id)
	scene.smooth_focus=scene.world.room_center_pos(built)+Vector3(0,1.5,0)
	scene.desired_focus=scene.smooth_focus
	scene.apply_camera(0.1)
	scene.update_render_lod()
	var node:Node3D=scene.room_root.get_node(built_id)
	assert(node.get_node_or_null("LocalFurniture/PhysicalFurniture/TEEA008CandidateFurniture")!=null)
	assert(scene.life.stations.capacity(built)==16)
	var screen:Node3D=null
	for anchor in get_nodes_in_group("teea008_media_surface"):
		if str(anchor.get_meta("room_id",""))==built_id and str(anchor.get_meta("surface_id",""))=="cinema.r3.film.screen":screen=anchor
	assert(screen!=null)
	var hit:Dictionary=scene.teea008_review.aperture_hit(scene.camera,scene.camera.unproject_position(screen.global_position))
	assert(str(hit.get("item_id",""))=="cinema.r3.film.screen")
	assert(scene.open_content_hotspot(hit))
	assert(scene.media_panel.visible)
	var guest:Dictionary={}
	for room in scene.world.rooms:
		if str(room.get("type",""))=="guest":guest=room;break
	assert(not guest.is_empty())
	var guest_id:String=str(guest["id"])
	assert(scene.world.set_guest_room_open(guest_id,false))
	scene.make_rooms()
	assert(scene.room_root.get_node(guest_id).get_node_or_null("LocalFurniture")==null)
	scene.update_residents()
	var owner:String=str(guest.get("owner_id",""))
	assert(owner!="" and not scene.actor_sprites[owner].visible,"Closed guest interior must not expose its actor")
	print("TEEA008_INTEGRATED_SCENE_PASS existing_rooms=",checked," new_R3=true cinema_aperture=true hearth=true closed_guest_facade=true")
	quit(0)
