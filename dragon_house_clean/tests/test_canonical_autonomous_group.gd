extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/life.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var w=W.new()
	w.canonical_house_seed=true
	w.seed_world()
	var bank=B.new()
	assert(bank.initialize(true))
	bank.apply_architecture_layouts()
	var nav=N.new()
	nav.configure(bank.layouts)
	for a in w.residents.values():a.active=false
	for a in w.creatures.values():a.active=false
	w.media["books"]=[]
	w.media["films"]=[]
	w.media["tracks"]=[]
	w.sim_clock=1000.0
	var room:Dictionary=w.room_by_id("ROOM_0027")
	var c:Vector3=w.room_center_pos(room)
	var ids:Array=[]
	for i in range(1,5):
		var id:String="RES_%02d"%i
		ids.append(id)
		var actor:Dictionary=w.residents[id]
		var p:=Vector2(-5.0+float(i-1)*2.5,1.5)
		assert(nav.clear(room,p))
		actor.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":room.level,"x":c.x+p.x,"z":p.y,"visual_y":c.y,"phase":"idle","intent":"REST","until":1000.0,"needs":{"rest":0.0,"curiosity":0.0,"social":1.0},"traits":{"reading":0.0,"music":0.0},"social_fatigue":0.0,"habits":{}},true)
	w.runtime_state["teea008_navigation_initialized"]=true
	var life=L.new()
	life.candidate_navigation=nav
	life.daypart_override="evening"
	life.setup(w)
	# Idle scheduling delay is not a commitment. Expired simple solo work
	# is recruitable, while a live activity or held item remains protected.
	var probe:Dictionary=w.residents.RES_01.duplicate(true)
	assert(life._group_recruitable(probe))
	probe["phase"]="perform"
	probe["intent"]="WATCH_FIRE"
	probe["until"]=life.clock+10.0
	assert(not life._group_recruitable(probe))
	probe["until"]=life.clock
	assert(life._group_recruitable(probe))
	probe["held_book"]="protected"
	assert(not life._group_recruitable(probe))
	probe.erase("held_book")
	probe["social_rest_until"]=life.clock+10.0
	assert(not life._group_recruitable(probe))
	probe.erase("social_rest_until")
	probe["phase"]="travel"
	assert(not life._group_recruitable(probe))
	# Use the real utility planner and due scheduler, not _assign,
	# _begin_group_session, direct claims or manually positioned performers.
	var observed:Dictionary={}
	var previous:Dictionary={}
	for id in ids:
		var a:Dictionary=w.residents[id]
		previous[id]=Vector3(a.x,a.visual_y,a.z)
	for step in range(3000):
		life.tick(0.15)
		for id in ids:
			var a:Dictionary=w.residents[id]
			var at:=Vector3(float(a.x),float(a.visual_y),float(a.z))
			assert(at.distance_to(previous[id])<=0.35,"movement jump "+id)
			previous[id]=at
		for row in life._pair_sessions().values():
			if row.kind=="group" and row.phase=="active":observed=row.duplicate(true);break
		if not observed.is_empty():break
	if observed.is_empty():
		print("NO_GROUP clock=",life.clock," planner=",life.planner_calls," actors=",ids.map(func(id):return [id,w.residents[id].intent,w.residents[id].phase,w.residents[id].until]))
		for event in w.journal:
			if str(event.event).begins_with("GROUP"):print(event)
		quit(1)
		return
	assert(life._pair_members_valid(observed.id,observed))
	assert(observed.members.size()>=3)
	assert(observed.started_at>1000.0)
	var reserved:=false
	var started:=false
	for event in w.journal:
		if event.event=="GROUP_RESERVED":reserved=true
		if event.event=="GROUP_STARTED":started=true
	assert(reserved and started)
	print("CANONICAL_AUTONOMOUS_GROUP_PASS members=",observed.members.size()," room=",observed.room_id," elapsed=",life.clock-1000.0," planner_calls=",life.planner_calls)
	quit(0)
