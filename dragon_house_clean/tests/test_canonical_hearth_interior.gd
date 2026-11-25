extends SceneTree
func _initialize()->void:
	call_deferred("run")

func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	assert(scene.architecture_review and scene.teea008_live)
	var room:Dictionary=scene.world.get_room(-3,1)
	var nav=scene.life.candidate_navigation
	var layout:Dictionary=nav.layouts["common/R3"]
	assert(str(layout["runtime_review_geometry_revision"])=="CANONICAL_HEARTH_INTERIOR_20261125_V1")
	assert(layout["interior_zones"].size()==3)
	var by_id:Dictionary={}
	var blockers:Array=[]
	var approaches:=0
	var station_ids:Dictionary={}
	for item in layout["instances"]:
		var id:String=str(item["instance_id"])
		assert(not by_id.has(id))
		by_id[id]=item
		if str(item["placement_policy"])=="floor_fixed":
			var lo:Array=item["bounds_min_m"]
			var hi:Array=item["bounds_max_m"]
			assert(float(lo[0])>=-7.2 and float(hi[0])<=7.2)
			assert(float(lo[2])>=-1.95 and float(hi[2])<=1.65)
			var box:=Rect2(Vector2(float(lo[0]),float(lo[2])),Vector2(float(hi[0])-float(lo[0]),float(hi[2])-float(lo[2])))
			for previous in blockers:
				assert(not box.intersects(previous),id)
			blockers.append(box)
		for station in item.get("station_candidates",[]):
			var sid:String=str(station["station_candidate_id"])
			assert(not station_ids.has(sid),sid)
			station_ids[sid]=true
			var p:Array=station.get("room_approach_xz",[])
			if p.is_empty():
				var xyz:Array=station["room_local_xyz"]
				p=[xyz[0],xyz[2]]
			var at:=Vector2(float(p[0]),float(p[1]))
			assert(nav.clear(room,at),sid)
			for entry in [Vector2(-7.12,1.5),Vector2(7.12,1.5)]:
				var points:Array=nav.path(room,entry,at)
				assert(not points.is_empty(),str([sid,entry,at]))
				var previous:Vector2=entry
				for point in points:
					assert(nav.segment_clear(room,previous,point),sid)
					previous=point
			approaches+=1
	assert(approaches==10,str(approaches))
	assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
	assert(not nav.clear(room,Vector2(6.30,-1.30)))
	assert(by_id["canonical_hearth_sleeping_dragon"]["station_candidates"].is_empty())
	assert(by_id["common_r3_p3_shared_coffee_table"]["room_local_xyz"]==[-4.65,0.025,0.6])
	assert(by_id["common_r3_p3_mug_red"]["room_local_xyz"]==[-4.99,0.49152,0.6])
	assert(by_id["common_r3_p3_mug_blue"]["room_local_xyz"]==[-4.33,0.49152,0.6])
	assert(nav.cup_slots(room).size()>=2)
	var usable:Dictionary={}
	for spot in nav.candidate_spots(room):
		usable[str(spot["id"])]=true
	for sid in station_ids:
		assert(usable.has(sid),sid)
	scene.selected_room=room["id"]
	scene.set_mode("ROOM")
	scene.zoom_current=scene.zoom
	scene.smooth_focus=scene.desired_focus
	scene.apply_camera(1.0)
	scene.update_render_lod()
	var group:Node3D=scene.room_root.get_node(str(room["id"]))
	for id in ["canonical_hearth_sleeping_dragon","canonical_hearth_extra_chair","common_r3_animated_hearth_review"]:
		assert(group.get_node("LocalFurniture").find_child(id,true,false)!=null,id)
		assert(group.get_node("Layer_OverviewCues").find_child(id,true,false)!=null,id)
	print("CANONICAL_HEARTH_INTERIOR_PASS islands=3 measured_approaches=",approaches," entry_paths=",approaches*2," cups=",nav.cup_slots(room).size()," blockers=",blockers.size())
	quit(0)
