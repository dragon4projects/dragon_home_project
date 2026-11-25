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
	var st=life.stations
	var nav=life.candidate_navigation
	var actors:Array=[]
	for i in range(1,7):actors.append(w.residents["RES_%02d"%i])
	for a in w.residents.values():st.release(a)
	var result:Dictionary={}
	var checked:=0
	for room in w.matching_rooms(["common","rest","kitchen"]):
		var spots:Array=st.layout_for_world(w,room)
		assert(spots.size()<=st.capacity(room))
		var max_group:=0
		assert(not st.pair(w,actors[0],actors[1],room).is_empty())
		for n in range(3,7):
			var claims:Dictionary=st.group_claims(w,actors.slice(0,n),room)
			if claims.is_empty():continue
			assert(claims.size()==n)
			var pos:Array=[]
			for id in claims:
				var claim:Dictionary=claims[id]
				var p:Vector2=claim.offset
				assert(nav.clear(room,p) and p.y<=0.75)
				for side in [-1,1]:
					var start:=Vector2(float(side)*(float(room.size_modules)*2.4-0.08),1.50)
					var path:Array=nav.path(room,start,p)
					assert(not path.is_empty())
					for step in path:
						assert(nav.sampled_segment_clear(room,start,step))
						start=step
				pos.append(p)
				checked+=1
			assert(st.group_geometry(room,pos))
			max_group=n
		assert(st.can_reserve_group(w,room)==(max_group>=3))
		result[room.id]=max_group
	assert(result=={"ROOM_0020":4,"ROOM_0026":5,"ROOM_0027":0,"ROOM_0036":6},str(result))
	# Occupied stations cannot be offered to another group.
	var kitchen:Dictionary=w.room_by_id("ROOM_0036")
	var claims:Dictionary=st.group_claims(w,actors,kitchen)
	for a in actors:
		st.commit_claim(a,claims[a.id])
		a.phase="perform"
	var extra:Array=[]
	for i in range(7,10):extra.append(w.residents["RES_%02d"%i])
	var others:Dictionary=st.group_claims(w,extra,kitchen)
	for claim in others.values():
		for existing in claims.values():assert(claim.slot!=existing.slot)
	print("CANONICAL_GROUP_GEOMETRY_PASS max_groups=",result," reachable_claims=",checked)
	quit(0)
