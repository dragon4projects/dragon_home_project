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
	var supported:=0
	for key in nav.layouts:
		var items:Array=nav.layouts[key]["instances"]
		var by_id:Dictionary={}
		for item in items:
			by_id[str(item["instance_id"])]=item
		for item in items:
			var host_id:String=scene.teea008_review._support_host_id(item)
			if host_id=="":continue
			assert(by_id.has(host_id),str([key,item["instance_id"],host_id]))
			var host:Dictionary=by_id[host_id]
			var hp:Array=host["room_local_xyz"]
			var p:Array=item["room_local_xyz"]
			var d:float=scene.depth_visual_scale(float(hp[2]))
			var pose:Dictionary=scene.teea008_review._mount_pose(item,scene.depth_visual_scale,by_id)
			var expected_position:=Vector3(float(p[0])*d,float(hp[1])+(float(p[1])-float(hp[1]))*d,float(hp[2])+(float(p[2])-float(hp[2]))*d)
			assert(str(pose["support_host_id"])==host_id)
			assert(is_equal_approx(float(pose["depth"]),d))
			assert((pose["position"] as Vector3).distance_to(expected_position)<0.00001)
			supported+=1
	assert(supported>=100,str(supported))
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
	var dressed:=0
	for key in ["study/R3","workshop/R3","music/R3"]:
		for item in nav.layouts[key]["instances"]:
			if not str(item["instance_id"]).begins_with("lived_"):continue
			assert(str(item.get("support_ref",""))!="")
			assert(item["station_candidates"].is_empty())
			dressed+=1
	assert(dressed==13)
	var sleeve:Dictionary=scene.teea008_review.surfaces.get("music.r3.audio.now_playing",{})
	assert(not sleeve.is_empty() and sleeve.get("binding_alias","")=="music.r3.audio.01")
	assert(not sleeve["holder_instance"].is_empty())
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
			assert(bool(anchor.get_meta("carrier_hit_only",false))==(kind=="music"),id)
			assert(anchor.get_node_or_null("BoundPreview")==null)
			checked[id]=true
		assert(checked.size()==(4 if kind=="music" else 1),str(checked))
		if kind=="cinema":
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://filmix_previews"))
			var image:=Image.create(96,128,false,Image.FORMAT_RGB8)
			image.fill(Color("#6d253b"))
			assert(image.save_webp("user://filmix_previews/QA_CINEMA.webp")==OK)
			var film:Dictionary={"id":"QA_CINEMA","title":"QA","simulation_only":true,"media_type":"film","runtime_seconds":3600,"preview":"user://filmix_previews/QA_CINEMA.webp"}
			world.media["films"].append(film)
			var rid:String=str(room["id"])
			assert(scene.teea008_media_bindings.assign(rid,"cinema.r3.film.screen","films",film["id"]))
			assert(scene.teea008_media_bindings.assign(rid,"cinema.r3.film.tv","films",film["id"]))
			assert(scene.teea008_media_bindings.resolve(rid,"cinema.r3.film.tv")["id"]==film["id"])
			scene._update_teea008_media_previews()
			var found:=0
			for anchor in get_nodes_in_group("teea008_media_surface"):
				if str(anchor.get_meta("room_id",""))!=rid or not str(anchor.get_meta("surface_id","")) in ["cinema.r3.film.screen","cinema.r3.film.tv"]:continue
				assert(anchor.get_node_or_null("BoundPreview")!=null)
				found+=1
			assert(found==2)
			assert(scene.content_viewer.open_record("films",film))
			assert(scene.content_viewer.preview.texture!=null)
			var controls:Array=scene.content_viewer.find_children("*","Button",true,false)
			assert(controls.size()==1 and str(controls[0].text).contains("Закрыть"))
			scene.content_viewer.close_viewer()
	print("CANONICAL_PUBLIC_INTERIORS_PASS rooms=",tested," route_checks=",approaches," physical_media_carriers=5 supported_projection=",supported)
	quit(0)
