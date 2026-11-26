extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var nav=scene.life.candidate_navigation
	assert(world.rooms.size()==65)
	assert(world.matching_rooms(["music"]).size()==1)
	assert(world.matching_rooms(["kitchen"]).size()==1)
	var kitchen:Dictionary=world.get_room(4,0)
	assert(str(kitchen["type"])=="kitchen" and int(kitchen["size_modules"])==3)
	var tested:=0
	var cups:=0
	for room in world.matching_rooms(["common","rest","kitchen"]):
		var row:Dictionary=nav.layouts.get(nav.key(room),{})
		assert(not row.is_empty(),str(room["id"]))
		var machine:=0
		var bar:=0
		var ids:Dictionary={}
		for item in row["instances"]:
			var asset:String=str(item["asset_id"])
			if asset=="sketchfab_steampunk_coffee_machine":machine+=1
			if asset in ["wine_bottles_01","blendkit_jack_daniel_s_whiskey"]:bar+=1
			assert(not ids.has(item["instance_id"]))
			ids[item["instance_id"]]=true
		assert(machine>=1 and bar>=1,str(room["id"]))
		assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
		var slots:Array=nav.cup_slots(room)
		assert(not slots.is_empty(),str(room["id"]))
		for slot in slots:
			assert(not nav.path(room,Vector2(-7.12,1.5),slot["approach"]).is_empty())
		var placed:=0
		for obj in world.objects.values():
			if str(obj.get("viewer_category",""))=="cups" and str(obj.get("current_room_id",""))==str(room["id"]):
				placed+=1
		assert(placed>=2,str(room["id"]))
		cups+=placed
		tested+=1
	assert(tested==4 and cups>=10)
	print("CANONICAL_SOCIAL_INTERIORS_PASS rooms=",tested," registered_cups=",cups," kitchen=true music=1")
	quit(0)
