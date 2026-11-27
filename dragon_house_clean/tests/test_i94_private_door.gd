extends SceneTree
const W=preload("res://scripts/world_model.gd")
const L=preload("res://scripts/life.gd")
const ACCESS=preload("res://scripts/private_door_access.gd")
func _initialize()->void:call_deferred("run")
func must(v:bool,msg:String)->bool:
 if not v:push_error(msg);quit(2)
 return v
func move(life,actor:Dictionary)->void:
 for i in range(40):
  if actor.get("phase","")!="travel":break
  life._move(actor,.125)
func restore(path:String):
 var w=W.new();w.canonical_house_seed=true;w.save_path=path
 if not w.load_or_seed():return null
 var life=L.new();life.setup(w)
 return [w,life]
func run()->void:
 var path:="user://i94_private_door_fixture.json"
 var pair=restore(path)
 if not must(pair!=null,"seed"):return
 var w=pair[0];var life=pair[1]
 var owner:Dictionary=w.residents["RES_01"]
 var actor:Dictionary=w.residents["RES_02"]
 var rid:String=owner.home_room_id
 var room:Dictionary=w.room_by_id(rid)
 var id:String=actor.id
 var p:Vector3=w.room_center_pos(room)
 # Synthetic QA arrival at public threshold, no real owner instruction.
 life.stations.release(actor)
 actor.merge({"room_id":rid,"level":room.level,"x":p.x,"visual_y":p.y,"z":1.54,"phase":"idle","intent":"REST","waypoints":[],"waypoint_index":0},true)
 if not must(not w.private_visit_allowed(room,id) and not w.is_accessible(room,id) and not w.public_cutaway_allowed(room),"default closed"):return
 if not must(not w.control_private_door(rid,id,"open","",true) and not w.control_private_door(rid,id,"standing",id,true),"wrong authority"):return
 if not must(w.control_private_door(rid,owner.id,"open","",true),"explicit open"):return
 if not must(not w.private_visit_allowed(room,id) and not life.begin_private_visit(id,rid),"open not invitation"):return
 if not must(w.control_private_door(rid,id,"knock",id) and not w.private_visit_allowed(room,id),"knock pending"):return
 if not must(w.control_private_door(rid,owner.id,"answer",id,true),"explicit acceptance"):return
 if not must(w.private_visit_allowed(room,id) and not w.is_accessible(room,id) and not w.public_cutaway_allowed(room),"entry separate from object/visibility rights"):return
 if not must(life.stations.single(w,actor,room,"REST").is_empty(),"no private furniture claim"):return
 if not must(life.begin_private_visit(id,rid),"visit start"):return
 move(life,actor)
 if not must(actor.get("private_visit_stage")=="inside" and is_equal_approx(float(actor.z),.8),"actual entry movement"):return
 if not must(w.save_world(),"save inside"):return
 pair=restore(path)
 if not must(pair!=null,"load inside"):return
 w=pair[0];life=pair[1];actor=w.residents[id];room=w.room_by_id(rid)
 if not must(actor.get("private_visit_stage")=="inside" and w.private_visit_allowed(room,id),"persist active visit"):return
 if not must(w.control_private_door(rid,owner.id,"revoke",id),"revoke"):return
 if not must(not w.private_visit_allowed(room,id) and actor.get("private_visit_stage")=="exit","revoke starts physical exit"):return
 move(life,actor)
 if not must(not actor.has("private_visit_room") and is_equal_approx(float(actor.z),1.54) and not w.private_visit_allowed(room,id),"safe exit"):return
 if not must(w.control_private_door(rid,owner.id,"standing",id,true) and w.control_private_door(rid,id,"knock",id),"standing plus knock"):return
 if not must(w.private_visit_allowed(room,id),"standing admission"):return
 if not must(w.control_private_door(rid,owner.id,"quiet","",true) and not w.private_visit_allowed(room,id) and not w.control_private_door(rid,id,"knock",id),"quiet revokes admission without inference"):return
 if not must(w.control_private_door(rid,owner.id,"quiet","",false) and w.control_private_door(rid,owner.id,"open","",true) and w.control_private_door(rid,id,"knock",id),"standing persists through quiet"):return
 if not must(life.begin_private_visit(id,rid),"second visit"):return
 life._move(actor,.125)
 if not must(w.control_private_door(rid,owner.id,"open","",false),"close in transit"):return
 move(life,actor)
 if not must(not actor.has("private_visit_room") and is_equal_approx(float(actor.z),1.54),"mid-entry reversal"):return
 for e in w.journal:
  if e.event=="PRIVATE_DOOR_CONTROL" and not must(not e.public_projection_allowed,"private journal leaked"):return
 if not must(w.control_private_door(rid,owner.id,"open","",true) and w.control_private_door(rid,id,"knock",id),"prepare backup permission fixture"):return
 if not must(w.save_world() and w.control_private_door(rid,owner.id,"revoke",id),"commit revocation"):return
 var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string("torn primary");f.close()
 pair=restore(path)
 if not must(pair!=null,"recover backup"):return
 w=pair[0];room=w.room_by_id(rid)
 if not must(w.load_status=="RECOVERED_BACKUP" and not w.private_visit_allowed(room,id) and not w.runtime_state.has(ACCESS.KEY),"backup fail closed"):return
 print("I94_PRIVATE_DOOR_PASS owner_authority=true knock=true explicit=true standing=true quiet=true persisted=true physical_exit=true mid_entry_reversal=true backup_fail_closed=true private_journal=true")
 quit(0)
