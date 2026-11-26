extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")
const SAVE="user://checkpoint_process_crash.json"
const CUP="QA_CRASH_CUP"
const ACTOR="RES_01"
func _initialize()->void:call_deferred("run")
func run()->void:
	var mode:String=OS.get_environment("DRAGON_QA_CRASH_MODE")
	assert(mode in ["write","verify_primary","verify_backup"])
	var w=W.new()
	w.canonical_house_seed=true
	w.save_path=SAVE
	assert(w.load_or_seed())
	var a:Dictionary=w.residents[ACTOR]
	if mode=="write":
		assert(w.load_status=="SEEDED")
		var room:String=str(a.room_id)
		assert(w.register_physical_object(CUP,"QA cup","",room,true,true,false,false,false,{"viewer_category":"cups"}))
		a["intent"]="GET_COFFEE"
		a["phase"]="travel"
		a["cup_task_id"]=CUP
		a["cup_task_room"]=room
		a["cup_task_stage"]="fetch"
		w.sim_clock=20.0
		assert(w.checkpoint_if_due())
		w.sim_clock=40.0
		assert(w.checkpoint_if_due())
		w.sim_clock=59.875
		assert(w.pickup_physical_object(CUP,ACTOR))
		assert(w.object_event_revision()==2)
		assert(w.checkpoint_if_due() and w.last_checkpoint_clock==40.0)
		# Parent kills this live process without running shutdown handlers.
		print("CRASH_FIXTURE_READY backend=",w.runtime_state.object_event_backend," clock=",w.sim_clock)
		return
	var expected:float=40.0 if mode=="verify_primary" else 20.0
	assert(w.sim_clock==expected and w.last_checkpoint_clock==expected)
	assert(w.load_status==("LOADED" if mode=="verify_primary" else "RECOVERED_BACKUP"))
	assert(w.object_event_revision()==2)
	var obj:Dictionary=w.physical_object(CUP)
	assert(obj.state=="HELD" and obj.current_holder_id==ACTOR and obj.current_room_id=="")
	assert(a.cup_task_stage=="fetch")
	var life=Life.new()
	life.world=w
	life.clock=w.sim_clock
	assert(life.reconcile_cup_tasks()==[ACTOR])
	assert(a.cup_task_stage=="hold" and a.cup_task_id==CUP and a.drink_sips_left==0)
	assert(a.phase=="idle")
	assert(life.reconcile_cup_tasks().is_empty())
	assert(not w.pickup_physical_object(CUP,ACTOR))
	assert(w.object_event_revision()==2)
	var count:=0
	for row in w.journal:
		if row.event=="OBJECT_PICKED_UP" and row.subject_id==CUP:count+=1
	assert(count==1)
	assert(float(obj.last_interaction_at)==59.875)
	print("CRASH_RECOVERY_PASS mode=",mode," backend=",w.runtime_state.object_event_backend," recovered=",w.sim_clock," snapshot_loss=",59.875-w.sim_clock," event_revision=2 cup_reconciled=true journal_once=true")
	quit(0)
