extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const SAVE="user://combined_checkpoint_crash.json"
func _initialize()->void:call_deferred("run")
func place(w,l,a:Dictionary,room:Dictionary,claim:Dictionary,intent:String)->void:
 assert(not claim.is_empty(),intent)
 var at:Vector3=w.room_local_to_world(room,claim.offset)
 a.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":room.level,"x":at.x,"visual_y":at.y,"z":at.z,"phase":"perform","intent":intent,"habits":{}},true)
 l.stations.commit_claim(a,claim)
func run()->void:
 var mode:String=OS.get_environment("DRAGON_QA_CRASH_MODE")
 assert(mode in ["write","verify_primary","verify_backup"])
 var w=W.new()
 w.canonical_house_seed=true
 w.save_path=SAVE
 assert(w.load_or_seed())
 var bank=B.new()
 assert(bank.initialize(true))
 bank.apply_architecture_layouts()
 var nav=N.new()
 nav.configure(bank.layouts)
 var l=L.new()
 l.candidate_navigation=nav
 var social:Dictionary=w.room_by_id("ROOM_0027")
 var cinema:Dictionary=w.matching_rooms(["cinema"])[0]
 var library:Dictionary=w.matching_rooms(["library"])[0]
 var reader:Dictionary=w.residents.RES_05
 var watcher:Dictionary=w.residents.RES_04
 var drinker:Dictionary=w.residents.RES_06
 var rider:Dictionary=w.residents.RES_07
 var lower:Dictionary=w.get_room(0,0)
 var upper:Dictionary=w.get_room(0,1)
 var mid:Vector3=w.room_center_pos(lower)+Vector3(-0.52,1.0,-0.75)
 var up:Vector3=w.room_center_pos(upper)
 if mode=="write":
  assert(w.load_status=="SEEDED")
  for a in w.residents.values():
   a.active=false
   a["teea008_pose_wardrobe"]=str(nav.pose_profiles.get(a.id,{}).get("wardrobe",""))
  for a in w.creatures.values():a.active=false
  w.media["books"]=[{"id":"QA_BOOK","work_id":"QA_BOOK","title":"QA book","physical":true,"holder_id":"","location_room_id":library.id,"home_room_id":library.id,"reading_seconds":1500.0}]
  w.media["films"]=[{"id":"QA_FILM","title":"QA film","simulation_only":true,"media_type":"film","runtime_seconds":7200}]
  w.media["tracks"]=[]
  w.sim_clock=100.0
  l.setup(w)
  var group:Array=[w.residents.RES_01,w.residents.RES_02,w.residents.RES_03]
  for a in group:a.active=true
  var claims:Dictionary=l.stations.group_claims(w,group,social)
  assert(claims.size()==3)
  for a in group:place(w,l,a,social,claims[a.id],"TALK_GROUP")
  var sid:String=l._create_group_record(group,social,500.0)
  l._update_pair(group[0])
  assert(l._pair_sessions()[sid].phase=="active")
  watcher.active=true
  place(w,l,watcher,cinema,l.stations.single(w,watcher,cinema,"WATCH_FILM"),"WATCH_FILM")
  watcher["activity_media_id"]="QA_FILM"
  watcher["activity_media_category"]="films"
  assert(l.media_runtime.begin_watch(watcher,100.0))
  reader.active=true
  assert(l.media_runtime.borrow(reader.id,"QA_BOOK",100))
  var reading_room:Dictionary=library
  place(w,l,reader,reading_room,l.stations.single(w,reader,reading_room,"READ_BOOK"),"READ_BOOK")
  reader.merge({"held_book":"QA_BOOK","book_task_id":"QA_BOOK","book_task_stage":"read","activity_media_id":"QA_BOOK","activity_media_category":"books"},true)
  assert(l.media_runtime.begin_reading(reader,100.0,500.0))
  var p:Vector3=w.room_center_pos(social)
  drinker.merge({"active":true,"autonomy_enabled":true,"room_id":social.id,"level":social.level,"x":p.x,"visual_y":p.y,"z":1.5,"phase":"idle","intent":"GET_COFFEE","until":800.0},true)
  assert(w.register_physical_object("QA_CUP","QA cup","",social.id,true,true,false,false,false,{"viewer_category":"cups"}))
  assert(w.pickup_physical_object("QA_CUP",drinker.id))
  drinker.merge({"cup_task_id":"QA_CUP","cup_task_stage":"hold","cup_task_room":social.id,"drink_sips_left":2},true)
  var drinks=l.candidate_cups.beverages
  assert(drinks.fill_or_resume("QA_CUP",drinker.id,"GENERIC","day",["BAR","COFFEE_NOOK"],"CAPPUCCINO"))
  assert(drinks.sip("QA_CUP",drinker.id))
  rider.merge({"active":true,"autonomy_enabled":true,"room_id":lower.id,"level":lower.level,"x":mid.x,"visual_y":mid.y,"z":mid.z,"phase":"travel","intent":"PURPOSEFUL_EXPLORE","waypoint_index":0,"waypoints":[{"kind":"lift","room_id":upper.id,"position":[up.x,up.y,0.0]}],"canonical_lift_slot":{"shaft":"0","index":0},"canonical_lift_boarded":true,"until":800.0},true)
  l.canonical_lifts.sync()
  assert(l.canonical_lifts.occupied["0"][0]==rider.id)
  for id in ["RES_04","RES_05","RES_06","RES_07"]:l._schedule_actor(w.residents[id],"QA_COMBINED")
  w.runtime_state["life_scheduler"]=l.life_scheduler.snapshot()
  # Both retained snapshots contain simultaneous live commitments.
  w.sim_clock=120.0
  l.clock=120.0
  assert(w.save_world())
  for domain in W.RNG_STREAM_SEEDS:w.decision_rng(domain).randi()
  w.sim_clock=140.0
  l.clock=140.0
  assert(w.save_world())
  # An actual durable event after the checkpoint, plus unsaved RNG draws.
  assert(w.set_object_ambient_protection("QA_CUP",true))
  for domain in W.RNG_STREAM_SEEDS:
   for i in range(10):w.decision_rng(domain).randi()
  print("CRASH_FIXTURE_READY backend=",w.runtime_state.object_event_backend," clock=",w.sim_clock)
  return
 var expected:float=140.0 if mode=="verify_primary" else 120.0
 assert(w.sim_clock==expected)
 var saved_rng:Dictionary=w.runtime_state.decision_rng_v1.duplicate(true)
 l.setup(w)
 assert(l.clock==expected)
 for domain in W.RNG_STREAM_SEEDS:assert(str(w.decision_rng(domain).state)==saved_rng[domain])
 assert(l._pair_sessions().size()==1)
 var row:Dictionary=l._pair_sessions().values()[0]
 assert(row.phase=="active" and row.members.size()==3 and l._pair_members_valid(row.id,row))
 for id in row.members:assert(w.residents[id].until==row.ends_at)
 assert(l.media_runtime.timed_session_valid(watcher,expected) and watcher.until==7300.0)
 assert(l.media_runtime.reading_session_valid(reader,expected) and reader.until==600.0)
 assert(l.media_runtime._lookup("books","QA_BOOK").holder_id==reader.id)
 var drinks=l.candidate_cups.beverages
 assert(w.objects.QA_CUP.current_holder_id==drinker.id and w.objects.QA_CUP.ambient_protected)
 assert(w.object_event_revision()==3)
 assert(drinker.cup_task_stage=="hold" and drinker.drink_sips_left==2)
 assert(drinks.content("QA_CUP").remaining_ml>0.0 and drinks.content("QA_CUP").remaining_ml<drinks.content("QA_CUP").get("serving_ml",0.0) and drinks.history(drinker.id).total_choices==1)
 assert(l.canonical_lifts.occupied["0"][0]==rider.id and rider.phase=="travel" and is_equal_approx(float(rider.visual_y),mid.y))
 # Movement resumes from the physical mid-lift coordinate, not a floor snap.
 l._move(rider,0.1)
 assert(float(rider.visual_y)>mid.y and float(rider.visual_y)<up.y)
 # Both independent timed activities still have their original deadlines.
 assert(not l.media_runtime.finish_watch(watcher,expected))
 assert(l.media_runtime.reading_session_valid(reader,expected))
 assert(w.save_world())
 print("CRASH_RECOVERY_PASS mode=",mode," backend=",w.runtime_state.object_event_backend," clock=",expected," group=3 film=true book=true sip=true lift=true rng=3")
 quit(0)
