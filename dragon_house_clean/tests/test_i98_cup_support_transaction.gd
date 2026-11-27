extends SceneTree
const W=preload("res://scripts/world_model.gd")
const NAV=preload("res://scripts/teea008_navigation.gd")
const TX=preload("res://scripts/local_cup_support_transaction.gd")
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func nav_for(room:Dictionary,x:float):
 var n=NAV.new()
 var k:String=n.key(room)
 n.configure({k:{"variant_id":k,"depth7_measured":true,"instances":[],"service_cups":[{"id":"QA_SUPPORT","object_id":"QA_CUP","furniture_id":"QA_TABLE","xyz":[x,.8,-2.6],"instance_xyz":[x,0,-2.6],"approach":[x,-1.3]}]}})
 return n
func run()->void:
 var w=W.new();w.canonical_house_seed=true;w.save_path="user://i98_cup.json"
 if not must(w.load_or_seed(),"seed"):return
 var room:Dictionary=w.get_room(4,2)
 room["depth7"]=true
 var rid:String=room.id
 var old=nav_for(room,0.0);var next=nav_for(room,.35)
 if not must(w.register_physical_object("QA_CUP","QA cup","",rid,true,true,false,false,true,{"viewer_category":"cups","home_anchor":[0.0,-2.6]}),"register"):return
 var p:Dictionary=TX.plan(w,old,next,room)
 if not must(p.ok and p.changes.has("QA_CUP") and p.changes.QA_CUP.size()==2,"plan both anchors"):return
 var revision:int=w.object_event_revision()
 w.runtime_state[TX.KEY]={"room_id":rid,"changes":p.changes}
 if not must(w.save_world() and w.save_world(),"persist intent twice"):return
 if not must(TX.finish(w,next),"apply durable event"):return
 if not must(w.object_event_revision()==revision+1,"one event only"):return
 var obj:Dictionary=w.physical_object("QA_CUP")
 if not must(absf(float(obj.home_anchor[0])-.35)<.0001 and absf(float(obj.current_anchor[0])-.35)<.0001,"anchors not moved"):return
 # Corrupt primary snapshot after event; fallback contains pending intent.
 var f:=FileAccess.open(w.save_path,FileAccess.WRITE);f.store_string("torn checkpoint");f.close()
 w.object_events.store.close()
 var restored=W.new();restored.canonical_house_seed=true;restored.save_path=w.save_path
 if not must(restored.load_or_seed() and restored.runtime_state.has(TX.KEY),"recover pending intent from backup"):return
 if not must(TX.finish(restored,next) and restored.object_event_revision()==revision+1 and not restored.runtime_state.has(TX.KEY),"idempotent replay"):return
 print("I98_CUP_SUPPORT_TX_PASS exact_anchor=true backup_recovery=true no_duplicate_event=true")
 quit(0)
