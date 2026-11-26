extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const Gate=preload("res://scripts/world_event_gate.gd")
const SAVE="user://view_completion_crash.json"
const OBJECT="QA_ART"
func _initialize()->void:call_deferred("run")
func start_view(w,l,a,room,at:float,end:float)->void:
 var claim:Dictionary=l.stations.display_claim(w,a,room,w.objects[OBJECT])
 assert(not claim.is_empty())
 var pos:Vector3=w.room_local_to_world(room,claim.offset)
 a.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":room.level,"x":pos.x,"z":pos.z,"visual_y":pos.y,"phase":"perform","intent":"VIEW_ART","viewing_object_id":OBJECT,"until":end},true)
 l.stations.commit_claim(a,claim)
 l.clock=at
 w.sim_clock=at
 l._begin_solo_habit_commitment(a)
 assert(a.has("solo_habit_commitment"))
func run()->void:
 var mode:=OS.get_environment("DRAGON_QA_CRASH_MODE")
 assert(mode in ["write","verify_primary","verify_backup"])
 var w=W.new()
 w.save_path=SAVE
 assert(w.load_or_seed())
 var room:Dictionary=w.get_room(1,-1)
 var a:Dictionary=w.residents.RES_01
 var l=L.new()
 l.world=w
 if mode=="write":
  assert(w.load_status=="SEEDED")
  assert(w.register_physical_object(OBJECT,"QA Art","",room.id,false,true,false,false,false,{"display_mode":"wall","interaction_station_id":"QA_VIEW","interaction_point":[0.0,0.2],"display_anchor":[0.0,1.4,-1.8]}))
  a["habits"]={}
  start_view(w,l,a,room,10.123456,50.123456)
  # A different resident commitment must not be aged or cancelled on replay.
  var other:Dictionary=w.residents.RES_02
  other["until"]=90.0
  other["phase"]="perform"
  other["intent"]="REST"
  w.sim_clock=20.0
  assert(w.save_world())
  w.sim_clock=40.0
  assert(w.save_world())
  assert(not w.record_object_view(OBJECT,"RES_01","day"))
  assert(w.object_event_revision()==1)
  l.clock=50.123456
  w.sim_clock=50.123456
  var orig_x:float=a.x
  a.x=orig_x+0.5
  assert(not w.record_object_view(OBJECT,"RES_01","day"))
  assert(w.object_event_revision()==1)
  a.x=orig_x
  var saved_marker:Dictionary=a.solo_habit_commitment.duplicate(true)
  var completion_id:String=Gate.view_completion_id(a,OBJECT)
  assert(l._finish_solo_habit_commitment(a))
  assert(a.habit_success.VIEW_ART.count==1 and a.habit_success.VIEW_ART.last_event_id==completion_id)
  assert(w.object_event_revision()==2)
  # A repeat of the identical commitment must not create a new event.
  a["solo_habit_commitment"]=saved_marker
  assert(not l._finish_solo_habit_commitment(a))
  assert(w.object_event_revision()==2 and a.habit_success.VIEW_ART.count==1)
  print("CRASH_FIXTURE_READY backend=",w.runtime_state.object_event_backend," clock=",w.sim_clock)
  return
 var expected:float=40.0 if mode=="verify_primary" else 20.0
 assert(w.sim_clock==expected and w.object_event_revision()==2)
 assert(a.habit_success.VIEW_ART.count==1 and a.last_view_credit_seq==2)
 assert(absf(float(a.habit_success.VIEW_ART.last_event_sim_clock)-50.123456)<0.000001)
 assert(a.habit_success.VIEW_ART.last_success_at==expected)
 assert(a.habit_success.VIEW_ART.last_station_id=="QA_VIEW")
 assert(not a.has("solo_habit_commitment") and a.has("recovered_view_completion"))
 assert(w.residents.RES_02.until==90.0)
 var count:=0
 for row in w.journal:
  if row.event=="OBJECT_VIEWED" and row.subject_id==OBJECT:
   count+=1
   assert(absf(float(row.sim_clock)-50.123456)<0.000001)
 assert(count==1)
 assert(absf(float(w.objects[OBJECT].last_interaction_at)-50.123456)<0.000001)
 # Prove recovery in Life.setup, not just the raw object projection.
 l.setup(w)
 assert(a.phase=="idle" and a.until==expected and not a.has("station_anchor_id") and not a.has("viewing_object_id"))
 assert(not a.has("recovered_view_completion") and not a.has("view_recovery_wake"))
 assert(not l._finish_solo_habit_commitment(a))
 assert(w.save_world())
 if w.object_events.store.has_method("close"):w.object_events.store.close()
 var again=W.new()
 again.save_path=SAVE
 assert(again.load_or_seed())
 var b:Dictionary=again.residents.RES_01
 assert(b.habit_success.VIEW_ART.count==1 and again.object_event_revision()==2)
 assert(again.sim_clock==expected)
 # A genuinely later view must remain possible.
 l=L.new()
 l.world=again
 start_view(again,l,b,again.get_room(1,-1),60.0,80.0)
 l.clock=80.0
 again.sim_clock=80.0
 assert(l._finish_solo_habit_commitment(b))
 assert(b.habit_success.VIEW_ART.count==2 and again.object_event_revision()==3)
 assert(not l._finish_solo_habit_commitment(b))
 print("CRASH_RECOVERY_PASS mode=",mode," backend=",again.runtime_state.object_event_backend," restored=",expected," durable_view_time=50 credits=1 then 2 journal_once=true")
 quit(0)
