extends SceneTree
const N=preload("res://scripts/teea008_navigation.gd")
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const C=preload("res://scripts/candidate_content_runtime.gd")
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var file:=FileAccess.open("res://data/teea008_review/room_layouts_xz.json",FileAccess.READ)
	var doc:Dictionary=JSON.parse_string(file.get_as_text())
	var rows:Dictionary={}
	for row in doc["items"]:rows[row["variant_id"]]=row
	var nav=N.new()
	nav.configure(rows)
	var checked:=0
	var slots:=0
	for key in rows:
		var parts:PackedStringArray=str(key).split("/")
		var room:Dictionary={"size_modules":int(parts[1].trim_prefix("R")),"type":parts[0]}
		if parts[0].begins_with("guest_"):
			room["type"]="guest"
			room["candidate_room_id"]=parts[0]+"_01"
		var spots:Array=nav.candidate_spots(room)
		assert(not spots.is_empty(),str(key))
		for spot in spots:
			var dest:Vector2=spot["offset"]
			for side in [-1,1]:
				var start:=Vector2(float(side)*(float(room["size_modules"])*2.4-0.08),1.50)
				var path:Array=nav.path(room,start,dest)
				assert(not path.is_empty(),str([key,spot["id"],side,start,dest]))
				for p in path:
					assert(nav.segment_clear(room,start,p),str([key,spot["id"],start,p]))
					start=p
				checked+=1
			slots+=1
	print("TEEA008_NAV_GRID_PASS rooms=",rows.size()," slots=",slots," routes=",checked)
	var w=W.new()
	w.save_path="user://teea008_nav_qa.json"
	w.seed_world()
	var c=C.new()
	assert(c.initialize())
	assert(c.apply_guest_candidate(w).get("ok",false))
	for a in w.residents.values():
		if str(a.get("entity_type",""))=="guest":a["autonomy_enabled"]=true
	var life=L.new()
	life.candidate_navigation=nav
	life.setup(w)
	var visited:Dictionary={}
	var movements:=0
	var phases:Dictionary={}
	for tick in range(4800):
		life.tick(0.125)
		for collection in [w.residents,w.creatures]:
			for id in collection:
				var a:Dictionary=collection[id]
				if not bool(a.get("active",false)):continue
				var room:Dictionary=w.room_by_id(str(a.get("room_id","")))
				if room.is_empty():continue
				if not visited.has(id):visited[id]={};phases[id]={}
				visited[id][str(room["id"])]=true
				phases[id][str(a.get("phase","idle"))]=true
				if not nav.has_layout(room):continue
				var center:Vector3=w.room_center_pos(room)
				var p:=Vector2(float(a.get("x",center.x))-center.x,float(a.get("z",0)))
				# During horizontal connector crossing room_id changes only on arrival.
				if absf(p.x)>float(room["size_modules"])*2.4:continue
				assert(nav.clear(room,p),str([tick,id,room["id"],p,a.get("phase"),a.get("intent")]))
				movements+=1
	for id in ["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]:
		print("GUEST ",id," rooms=",visited.get(id,{}).size()," phases=",phases.get(id,{}).keys())
		assert(visited.get(id,{}).size()>1)
		assert(phases[id].has("travel") and phases[id].has("perform"))
	print("TEEA008_NAV_LIVE_PASS samples=",movements," path_calls=",nav.path_calls," path_failures=",nav.path_failures)
	quit(0)
