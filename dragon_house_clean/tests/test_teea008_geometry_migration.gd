extends SceneTree
const W=preload("res://scripts/world_model.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const L=preload("res://scripts/life.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_TEEA008_REVIEW","1")
	var w=W.new()
	w.save_path="user://geometry_migration_qa.json"
	w.seed_world()
	var bank=B.new()
	assert(bank.initialize() and bank.sketchfab_common_enabled)
	var nav=N.new()
	nav.configure(bank.layouts)
	var room:Dictionary=w.get_room(-2,0)
	var c:Vector3=w.room_center_pos(room)
	var a:Dictionary=w.residents["RES_01"]
	var b:Dictionary=w.residents["RES_02"]
	a["room_id"]=room["id"]
	a["x"]=c.x-6.4
	a["z"]=-0.48
	a["visual_y"]=c.y
	a["level"]=room["level"]
	a["phase"]="perform"
	a["active"]=true
	var old_pos:=Vector2(float(a["x"]),float(a["z"]))
	assert(not nav.clear(room,Vector2(old_pos.x-c.x,old_pos.y)))
	assert(w.register_physical_object("QA_CUP","QA cup","RES_01",str(room["id"]),true,true,false,false,true,{"viewer_category":"cups","home_anchor":[0.0,0.9]}))
	assert(w.pickup_physical_object("QA_CUP","RES_01"))
	a["cup_task_stage"]="hold"
	a["cup_task_id"]="QA_CUP"
	a["cup_task_room"]=room["id"]
	var unaffected:Dictionary=w.get_room(2,0)
	var bc:Vector3=w.room_center_pos(unaffected)
	b["room_id"]=unaffected["id"]
	b["x"]=bc.x
	b["z"]=1.5
	b["visual_y"]=bc.y
	b["level"]=unaffected["level"]
	b["phase"]="idle"
	b["active"]=true
	var unchanged:Array=[b["x"],b["z"],b["visual_y"]]
	w.runtime_state["teea008_navigation_initialized"]=true
	var topology:Array=[]
	for rr in w.rooms:topology.append([str(rr["id"]),int(rr["x"]),int(rr["level"]),int(rr.get("size_modules",1)),str(rr["type"])])
	assert(w.save_world())
	var loaded=W.new()
	loaded.save_path=w.save_path
	loaded.load_or_seed()
	var life=L.new()
	life.candidate_navigation=nav
	life.setup(loaded)
	a=loaded.residents["RES_01"]
	b=loaded.residents["RES_02"]
	assert(nav.clear(room,Vector2(float(a["x"])-c.x,float(a["z"]))))
	assert(a["phase"]=="idle" and a["cup_task_stage"]=="hold")
	assert(loaded.physical_object("QA_CUP")["current_holder_id"]=="RES_01")
	assert(loaded.physical_object("QA_CUP")["canonical_owner_id"]=="RES_01")
	assert(Vector3(float(unchanged[0]),float(unchanged[1]),float(unchanged[2])).is_equal_approx(Vector3(float(b["x"]),float(b["z"]),float(b["visual_y"]))),str([unchanged,b["x"],b["z"],b["visual_y"]]))
	var restored_topology:Array=[]
	for rr in loaded.rooms:restored_topology.append([str(rr["id"]),int(rr["x"]),int(rr["level"]),int(rr.get("size_modules",1)),str(rr["type"])])
	assert(topology==restored_topology)
	var events:=0
	for event in loaded.journal:
		if event["event"]=="TEEA008_REVIEW_GEOMETRY_MIGRATED" and event["actor_id"]=="RES_01":events+=1
	assert(events==1)
	assert(life._migrate_review_geometry(true)==0)
	assert(loaded.save_world())
	var again=W.new()
	again.save_path=w.save_path
	again.load_or_seed()
	assert(again.runtime_state["teea008_geometry_revision"]=="SKETCHFAB_COMMON_R3_20261125_V1")
	assert(again.physical_object("QA_CUP")["current_holder_id"]=="RES_01")
	print("TEEA008_GEOMETRY_MIGRATION_PASS hold_preserved=true unaffected_unchanged=true topology_unchanged=true idempotent=true")
	quit(0)
