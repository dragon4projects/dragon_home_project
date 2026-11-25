extends SceneTree
func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var nav=scene.life.candidate_navigation
	var tested:=0
	var approaches:=0
	for room in world.matching_rooms(["common","rest","kitchen","library","artifact","cinema","music","study","workshop"]):
		var key:String=nav.key(room)
		assert(nav.has_layout(room),key)
		var row:Dictionary=nav.layouts[key]
		if str(room["type"]) in ["library","artifact","cinema","music","study","workshop"]:
			assert(str(row.get("canonical_dressing_revision",""))!="",key)
		assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)),key)
		for item in row["instances"]:
			for station in item.get("station_candidates",[]):
				var p:Array=station.get("room_approach_xz",[])
				if p.is_empty() and station.has("room_local_xyz"):
					var xyz:Array=station["room_local_xyz"]
					p=[xyz[0],xyz[2]]
				if p.size()!=2:continue
				var at:=Vector2(float(p[0]),float(p[1]))
				for entry in [Vector2(-7.12,1.5),Vector2(7.12,1.5)]:
					var points:Array=nav.path(room,entry,at)
					assert(not points.is_empty(),str([key,item["instance_id"],at]))
					var previous:Vector2=entry
					for point in points:
						assert(nav.segment_clear(room,previous,point),str([key,item["instance_id"]]))
						previous=point
					approaches+=1
		tested+=1
	assert(tested==12,str(tested))
	# Saved surface IDs now resolve to actual devices, not separate wall props.
	var expected:Dictionary={
		"music.r3.audio.01":"music_r3_p2_boombox",
		"music.r3.audio.02":"music_r3_p2_cassette",
		"music.r3.audio.03":"music_cassette_deck",
		"music.r3.audio.04":"music_shelf_cassette_player",
		"cinema.r3.film.tv":"cinema_r3_p2_tv"
	}
	for kind in ["music","cinema"]:
		var rooms:Array=world.matching_rooms([kind])
		assert(not rooms.is_empty())
		var room:Dictionary=rooms[0]
		scene.selected_room=room["id"]
		scene.set_mode("ROOM")
		scene.zoom_current=scene.zoom
		scene.smooth_focus=scene.desired_focus
		scene.apply_camera(1.0)
		scene.update_render_lod()
		var checked:Dictionary={}
		for anchor in get_nodes_in_group("teea008_media_surface"):
			if str(anchor.get_meta("room_id",""))!=str(room["id"]):continue
			var id:String=str(anchor.get_meta("surface_id",""))
			if not expected.has(id):continue
			assert(str(anchor.get_parent().name)==str(expected[id]),id)
			assert(bool(anchor.get_meta("carrier_hit_only",false)),id)
			assert(anchor.get_node_or_null("BoundPreview")==null)
			checked[id]=true
		assert(checked.size()==(4 if kind=="music" else 1),str(checked))
	print("CANONICAL_PUBLIC_INTERIORS_PASS rooms=",tested," route_checks=",approaches," physical_media_carriers=5")
	quit(0)
