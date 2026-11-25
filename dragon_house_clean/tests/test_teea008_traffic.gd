extends SceneTree
const W=preload("res://scripts/world_model.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const T=preload("res://scripts/teea008_traffic.gd")
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var w=W.new()
	w.seed_world()
	var nav=N.new()
	# A real R3 volume; isolate a clear strip inside it rather than fake a room.
	var room:Dictionary=w.get_room(-2,0)
	var rows:Dictionary={}
	var file:=FileAccess.open("res://data/teea008_review/room_layouts_xz.json",FileAccess.READ)
	for row in JSON.parse_string(file.get_as_text())["items"]:rows[row["variant_id"]]=row
	nav.configure(rows)
	var center:Vector3=w.room_center_pos(room)
	var t=T.new()
	for id in w.residents:w.residents[id]["active"]=false
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	for actor in [a,b]:
		actor["active"]=true
		actor["room_id"]=room["id"]
		actor["visual_y"]=center.y
		actor["z"]=1.40
	a["x"]=center.x-2.0
	b["x"]=center.x+2.0
	var targets:Dictionary={"RES_01":Vector3(center.x+2.0,center.y,1.40),"RES_02":Vector3(center.x-2.0,center.y,1.40)}
	var finished:=false
	for i in range(320):
		t.begin(w,nav)
		for actor in [a,b]:
			var at:Vector3=t.positions[actor["id"]]
			var target:Vector3=targets[actor["id"]]
			var n:Vector3=t.step(actor,at,target,at.move_toward(target,0.12),0.12,"candidate_path")
			t.publish(actor["id"],n)
			actor["x"]=n.x
			actor["z"]=n.z
			assert(nav.sampled_segment_clear(room,w.room_space.world_to_local(room,at),w.room_space.world_to_local(room,n)),str([i,actor["id"],at,n]))
			assert(Vector2(float(a["x"])-float(b["x"]),float(a["z"])-float(b["z"])).length()>=0.6498,str([i,a["x"],b["x"],a["z"],b["z"]]))
		t.finish()
		if absf(float(a["x"])-targets["RES_01"].x)<0.05 and absf(float(b["x"])-targets["RES_02"].x)<0.05 and absf(float(a["z"])-1.4)<0.05 and absf(float(b["z"])-1.4)<0.05:
			finished=true
			break
	assert(finished,str([a["x"],a["z"],b["x"],b["z"],t.metrics()]))
	assert(t.detours>0)
	print("TEEA008_TRAFFIC_PASS ",t.metrics())
	quit(0)
