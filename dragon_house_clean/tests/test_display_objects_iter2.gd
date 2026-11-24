extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame

	var artifact:Dictionary={}
	for room in scene.world.rooms:
		if str(room.get("type",""))=="artifact" and str(room.get("privacy","public"))=="public":
			artifact=room
			break
	assert(not artifact.is_empty())

	for object_id in ["POSTER_SHURSHUN","PHOTO_MOON","PORTRAIT_SHURS"]:
		var object:Dictionary=scene.world.physical_object(object_id)
		assert(not object.is_empty())
		assert(not bool(object.get("movable",true)))
		assert(not bool(object.get("recoverable",true)))
		assert(bool(object.get("ambient_protected",false)))
		assert(str(object.get("display_mode",""))=="wall")
		assert(str(object.get("viewer_category",""))=="artifacts")
		assert(str(object.get("current_room_id",""))==str(artifact["id"]))
		var anchor=object.get("home_anchor",[])
		assert(typeof(anchor)==TYPE_ARRAY and anchor.size()==3)
		assert(str(object.get("preview_path","")).begins_with("res://assets/props/artifacts/"))
		assert(scene.object_nodes.has(object_id))
		var object_node:Node3D=scene.object_nodes[object_id]
		var visual:Sprite3D=object_node.get_node_or_null("Visual")
		var frame:Node3D=object_node.get_node_or_null("WallFrame")
		assert(visual!=null and visual.texture!=null)
		assert(frame!=null and frame.get_child_count()==5)
		assert(float(object.get("display_world_height",0.0))>=1.15)

	var layout:Array=scene.life.stations.layout_for_world(scene.world,artifact)
	var station_ids:Array=[]
	for spot in layout:
		station_ids.append(str(spot.get("id","")))
	assert(station_ids.has("WALL_GALLERY_LEFT"))
	assert(station_ids.has("WALL_GALLERY_RIGHT"))
	assert(layout.size()==scene.life.stations.capacity(artifact))

	var start_room:Dictionary=scene.world.get_room(-2,0)
	var actor:Dictionary={
		"id":"TEST_WALL_VIEW","active":true,
		"room_id":str(start_room["id"]),
		"x":scene.world.room_center_pos(start_room).x,
		"level":0,"visual_y":0.0,"z":1.30
	}
	var photo:Dictionary=scene.world.physical_object("PHOTO_MOON")
	var claim:Dictionary=scene.life.stations.display_claim(scene.world,actor,artifact,photo)
	assert(not claim.is_empty())
	assert(str(claim.get("anchor_id",""))=="WALL_GALLERY_RIGHT")
	var route:Array=scene.world.find_route(str(actor["room_id"]),str(artifact["id"]),str(actor["id"]))
	assert(not route.is_empty())
	var waypoints:Array=scene.life.locomotion.build_waypoints(
		scene.world,actor,route,"VIEW_ART",claim["offset"],float(claim.get("approach_z",0.95)))
	assert(not waypoints.is_empty())
	var final:Array=waypoints[-1]["position"]
	assert(absf(float(final[2])-float(claim["offset"].y))<0.01)
	assert(float(final[2]) < -1.0)

	var hotspot:Dictionary={}
	for entry in scene.content_hotspots:
		if str(entry.get("item_id",""))=="PHOTO_MOON":
			hotspot=entry
			break
	assert(not hotspot.is_empty())
	assert(scene.open_content_hotspot(hotspot))
	assert(scene.content_viewer.visible)
	scene.content_viewer.close_viewer()

	print("ITER2_DISPLAY_OBJECTS_PASS event_truth=3 wall_station=true rear_view=true hotspot_viewer=true")
	quit(0)
