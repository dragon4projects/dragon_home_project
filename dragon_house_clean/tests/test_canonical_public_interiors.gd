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
	print("CANONICAL_PUBLIC_INTERIORS_PASS rooms=",tested," route_checks=",approaches)
	quit(0)
