extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var w=scene.world
	var life=scene.life
	var room:Dictionary=w.get_room(-3,1)
	var actor:Dictionary=w.residents["RES_01"]
	var spot:Dictionary={}
	for candidate in life.candidate_navigation.candidate_spots(room):
		if candidate.get("furniture_id","")=="common_r3_p3_sofa_center":
			spot=candidate
			break
	var contact:Dictionary=life.candidate_navigation.pose_contact(actor,spot,"READ_BOOK")
	assert(contact.get("state","")=="READ" and not contact["book_baked"])
	var c:Vector3=w.room_center_pos(room)
	actor["room_id"]=room.id
	actor["level"]=room.level
	actor["station_room_id"]=room.id
	actor["station_contact"]=contact
	actor["phase"]="perform"
	actor["intent"]="READ_BOOK"
	actor["x"]=c.x+spot.offset.x
	actor["z"]=spot.offset.y
	actor["visual_y"]=c.y
	var book:Dictionary=w.media.books[0]
	var bid:String=str(book.id)
	book["holder_id"]=actor.id
	book["location_room_id"]=""
	actor["held_book"]=bid
	scene.selected_room=room.id
	scene.set_mode("ROOM")
	scene.zoom=6.0
	scene.zoom_current=6.0
	scene.desired_focus=c+Vector3(-4.65,1.0,-0.5)
	scene.smooth_focus=scene.desired_focus
	var physical:Array=[actor.x,actor.z,actor.visual_y]
	for yaw in [-0.42,0.0,0.42]:
		scene.yaw=yaw
		scene.apply_camera(1.0)
		scene.update_render_lod()
		scene.update_residents()
		scene._update_physical_books()
		assert(scene.book_nodes.has(bid))
		var node:Node3D=scene.book_nodes[bid]
		assert(node.get_meta("hand_contact_status")=="READ_FRAME_MARKED")
		assert(node.to_global(Vector3(0,0.09,0)).distance_to(node.get_meta("hand_contact_target"))<0.0001)
		var anchor:Node3D=scene.actor_sprites[actor.id]
		var sprite:Sprite3D=anchor.get_node("Body")
		assert(scene._sprite_pixel_world(anchor,sprite,contact.contact_px).distance_to(anchor.global_position)<0.0001)
		assert(physical==[actor.x,actor.z,actor.visual_y])
	if DisplayServer.get_name()!="headless":
		for id in scene.actor_sprites:
			if id!=actor.id:scene.actor_sprites[id].visible=false
		for i in range(6):await process_frame
		assert(root.get_texture().get_image().save_png("res://private_review/iter26_read_seat.png")==OK)
	# A missing calibration must never suppress a real book.
	actor.erase("station_contact")
	scene.update_residents()
	scene._update_physical_books()
	assert(scene.book_nodes.has(bid))
	assert(scene.book_nodes[bid].get_meta("hand_contact_status")=="IDLE_FRAME_MARKED")
	# Change wardrobe with the same idle animation; texture must refresh.
	actor["visual_wardrobe"]="CITY"
	scene.update_residents()
	scene._update_physical_books()
	assert(scene.actor_animations[actor.id].wardrobe=="CITY")
	assert(scene.actor_sprites[actor.id].get_node("Body").texture==scene.asset_banks.texture_for(actor.id,"CITY","IDLE_S",0))
	assert(scene.book_nodes[bid].get_meta("hand_contact_status")=="UNCALIBRATED")
	print("VERIFIED_BOOK_CONTACT_PASS yaw_samples=3 wardrobe_refresh=true book_visible=true")
	quit(0)
