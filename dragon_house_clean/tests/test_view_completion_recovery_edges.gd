extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const Gate=preload("res://scripts/world_event_gate.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 OS.set_environment("DRAGON_OBJECT_EVENT_BACKEND","json")
 var w=W.new()
 w.save_path="user://view_recovery_edges.json"
 assert(w.load_or_seed())
 var room:Dictionary=w.get_room(1,-1)
 assert(w.register_physical_object("QA_ART","QA Art","",room.id,false,true,false,false,false,{"display_mode":"wall","interaction_station_id":"QA_VIEW","interaction_point":[0.0,0.2],"display_anchor":[0.0,1.4,-1.8]}))
 var a:Dictionary=w.residents.RES_01
 var l=L.new()
 l.world=w
 var old:Dictionary=a.duplicate(true)
 a["intent"]="REST"
 a["phase"]="perform"
 a["until"]=35.0
 a["habits"]={}
 a["solo_habit_commitment"]={"intent":"REST","started_at":5.0,"ends_at":35.0,"room_id":a.room_id,"station_id":"REST_STATION"}
 w.sim_clock=10.0
 assert(w.save_world())
 var claim:Dictionary=l.stations.display_claim(w,a,room,w.objects.QA_ART)
 assert(not claim.is_empty())
 var pos:Vector3=w.room_local_to_world(room,claim.offset)
 a.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":room.level,"x":pos.x,"z":pos.z,"visual_y":pos.y,"phase":"perform","intent":"VIEW_ART","viewing_object_id":"QA_ART","until":50.0},true)
 l.stations.commit_claim(a,claim)
 l.clock=40.0
 w.sim_clock=40.0
 l._begin_solo_habit_commitment(a)
 var marker:Dictionary=a.solo_habit_commitment.duplicate(true)
 marker.erase("view_subject_id") # compatible pre-upgrade snapshot form
 a["solo_habit_commitment"]=marker
 var event_id:String=Gate.view_completion_id(a,"QA_ART")
 l.clock=50.0
 w.sim_clock=50.0
 assert(l._finish_solo_habit_commitment(a))
 assert(w.object_event_revision()==2)
 var r=W.new()
 r.save_path=w.save_path
 assert(r.load_or_seed())
 var b:Dictionary=r.residents.RES_01
 assert(r.sim_clock==10.0 and b.habit_success.VIEW_ART.count==1)
 assert(b.habit_success.VIEW_ART.last_event_id==event_id)
 assert(b.habit_success.VIEW_ART.last_room_id==room.id and b.habit_success.VIEW_ART.last_station_id=="QA_VIEW")
 assert(b.intent=="REST" and b.until==35.0 and b.solo_habit_commitment.intent=="REST")
 assert(not b.has("recovered_view_completion"))
 # Simulate replaying the same later commitment after the rollback.
 b.merge({"active":true,"autonomy_enabled":true,"room_id":room.id,"level":room.level,"x":pos.x,"z":pos.z,"visual_y":pos.y,"phase":"perform","intent":"VIEW_ART","viewing_object_id":"QA_ART","until":50.0},true)
 l=L.new()
 l.world=r
 l.stations.commit_claim(b,claim)
 b["solo_habit_commitment"]=marker.duplicate(true)
 l.clock=50.0
 r.sim_clock=50.0
 assert(Gate.view_completion_id(b,"QA_ART")==event_id)
 assert(not l._finish_solo_habit_commitment(b))
 assert(r.object_event_revision()==2 and b.habit_success.VIEW_ART.count==1)
 # Repair previously mis-stamped journal rows on load using canonical event time.
 for row in r.journal:
  if row.event=="OBJECT_VIEWED":row["sim_clock"]=3.0
 assert(r.save_world())
 var again=W.new()
 again.save_path=r.save_path
 assert(again.load_or_seed())
 for row in again.journal:
  if row.event=="OBJECT_VIEWED":assert(row.sim_clock==50.0)
 assert(again.residents.RES_01.habit_success.VIEW_ART.count==1)
 print("VIEW_RECOVERY_EDGES_PASS post_checkpoint_credit=true unrelated_commitment_preserved=true legacy_marker=true duplicate_refused=true timestamp_repaired=true")
 quit(0)
