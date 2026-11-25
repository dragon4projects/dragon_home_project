extends SceneTree
# Focused renderer test: real bank and hash-verified frame, no full roster.
class Fixture extends "res://scripts/main.gd":
	func _ready()->void:pass
	func _process(_delta:float)->void:pass
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=Fixture.new()
	root.add_child(scene)
	current_scene=scene
	var w=scene.world
	var room:Dictionary=w.make_room(0,0,"common",3)
	var id:String="RES_01"
	var actor:Dictionary={"id":id,"appearance_profile":"HELGA_01","visual_wardrobe":"SHORT","teea008_pose_wardrobe":"SHORT","runtime_visual_bound":true,"active":true,"room_id":room.id,"station_room_id":room.id,"level":0,"x":0.0,"z":0.0,"visual_y":0.0,"phase":"perform","intent":"READ_BOOK"}
	w.residents[id]=actor
	assert(scene.asset_banks.initialize())
	var nav=scene.TEEA008NavigationScript.new()
	var file:=FileAccess.open("res://data/teea008_pose_contacts_review.json",FileAccess.READ)
	var doc:Dictionary=JSON.parse_string(file.get_as_text())
	var profile:Dictionary=doc.profiles[id]
	for state in profile.states:
		var entry:Dictionary=profile.states[state]
		assert(nav._pose_source_valid("res://"+str(entry.path),entry))
	nav.pose_profiles[id]=profile
	var hand_file:=FileAccess.open("res://data/teea008_hand_contacts_review.json",FileAccess.READ)
	var hand:Dictionary=JSON.parse_string(hand_file.get_as_text()).profiles[id]
	assert(hand.sha256==profile.states.IDLE_S.sha256 and hand.path==profile.states.IDLE_S.path)
	nav.hand_profiles[id]=hand
	scene.life.world=w
	scene.life.candidate_navigation=nav
	scene.life.media_runtime.world=w
	scene.teea008_live=true
	scene.camera=Camera3D.new()
	scene.add_child(scene.camera)
	scene.camera.current=true
	var anchor:=Node3D.new()
	scene.add_child(anchor)
	var sprite:=Sprite3D.new()
	sprite.name="Body"
	sprite.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
	anchor.add_child(sprite)
	scene.actor_sprites[id]=anchor
	var label:=Label3D.new()
	anchor.add_child(label)
	scene.actor_labels[id]=label
	scene.book_root=Node3D.new()
	scene.add_child(scene.book_root)
	w.media["books"]=[{"id":"book","title":"QA physical book","physical":true,"holder_id":id,"location_room_id":""}]
	var contact:Dictionary={"state":"READ","local_xyz":[0,0.42,-0.5],"instance_xyz":[0,0,-0.5],"contact_px":profile.states.READ.contact_px,"canvas":profile.states.READ.canvas,"book_baked":false,"seat_front_z":-0.1}
	actor.station_contact=contact
	for angle in [-0.42,0.0,0.42]:
		scene.camera.position=Vector3(sin(angle)*6,2.1,cos(angle)*6)
		scene.camera.look_at(Vector3(0,1,0))
		scene.update_residents()
		scene._update_physical_books()
		assert(scene.book_nodes.has("book"))
		var book:Node3D=scene.book_nodes["book"]
		assert(book.get_meta("hand_contact_status")=="READ_FRAME_MARKED")
		assert(book.get_meta("book_open") and book.get_node("OpenBook").visible)
		assert(not book.get_child(0).visible)
		assert(book.to_global(Vector3(0,0.09,0)).distance_to(book.get_meta("hand_contact_target"))<0.0001)
		assert(scene._sprite_pixel_world(anchor,sprite,contact.contact_px).distance_to(anchor.global_position)<0.0001)
	actor.erase("station_contact")
	scene.update_residents()
	scene._update_physical_books()
	assert(scene.book_nodes["book"].get_meta("hand_contact_status")=="IDLE_FRAME_MARKED")
	assert(not scene.book_nodes["book"].get_meta("book_open"))
	assert(not scene.book_nodes["book"].get_node("OpenBook").visible)
	assert(scene.book_nodes["book"].get_child(0).visible)
	assert(w.media.books.size()==1 and w.media.books[0].holder_id==id)
	actor.visual_wardrobe="CITY"
	scene.update_residents()
	scene._update_physical_books()
	assert(scene.actor_animations[id].wardrobe=="CITY")
	assert(sprite.texture==scene.asset_banks.texture_for(id,"CITY","IDLE_S",0))
	assert(scene.book_nodes["book"].get_meta("hand_contact_status")=="UNCALIBRATED")
	print("POSE_CONTACT_PROJECTION_FIXTURE_PASS real_frame=true yaw_samples=3 wardrobe_refresh=true book_visible=true")
	quit(0)
