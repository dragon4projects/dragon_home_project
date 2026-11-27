extends RefCounted
## Only explicit local user authoring. No private data or synthetic consent.
var world
var life
var cubes
func setup(model,simulation,cube_bank)->void:
 world=model
 life=simulation
 cubes=cube_bank

func public_object(id:String)->bool:
 var o:Dictionary=world.physical_object(id)
 return not o.is_empty() and o.get("current_holder_id","")=="" and o.get("state","")=="PLACED" and world.public_cutaway_allowed(world.room_by_id(str(o.get("current_room_id","")))) and world.public_cutaway_allowed(world.room_by_id(str(o.get("home_room_id","")))) and bool(o.get("movable",false))

func artifact_options(id:String)->Array:
 var out:Array=[]
 if not public_object(id) or world.recovery_blocked:return out
 var o:Dictionary=world.physical_object(id)
 if o.get("viewer_category","")!="artifacts" or o.get("display_mode","")=="wall" or (o.get("display_mode","")!="cube" and not o.has("artifact_size") and not cubes.is_cube(id)):return out
 var adapter=world.dense_artifact_world
 if adapter==null:return out
 var room:Dictionary=world.room_by_id(adapter.room_id)
 if not world.public_cutaway_allowed(room):return out
 for slot in adapter.choices():
  if adapter.size_for(o)==slot.size and adapter.available(world.objects,id,slot.id) and slot.id!=o.get("current_support_id",""):out.append({"room_id":room.id,"slot_id":slot.id,"label":str(slot.grid_id)+" · "+str(slot.size)+" · "+str(slot.at)+" · "+("↻" if slot.turn else "0°")})
 return out

func move_artifact(id:String,rid:String,sid:String)->bool:
 if not artifact_options(id).any(func(x):return x.room_id==rid and x.slot_id==sid):return false
 var slot:Dictionary=world.dense_artifact_world.slots[sid]
 var ok:bool=world.assign_physical_object_home(id,rid,Vector2(slot.xyz[0],slot.xyz[2]),true,sid)
 if ok:world.save_world() # object-event log is already durable
 return ok

func book_options(id:String)->Array:
 var out:Array=[]
 if world.recovery_blocked or life.candidate_navigation==null:return out
 var m=life.media_runtime
 var b:Dictionary=m._lookup("books",id)
 if b.is_empty() or not bool(b.get("physical",true)) or b.get("holder_id","")!="" or m.reserved_book_ids().has(id) or not world.public_cutaway_allowed(world.room_by_id(str(b.get("location_room_id","")))) or not world.public_cutaway_allowed(world.room_by_id(str(b.get("home_room_id","")))):return out
 var used:Dictionary=m._book_return_reservations(id)
 for other in world.runtime_state.get("teea008_book_slot_assignments",{}):
  if other==id:continue
  var entry:Dictionary=world.runtime_state["teea008_book_slot_assignments"][other]
  used[str(entry.get("room_id",""))+"|"+str(entry.get("slot_id",""))]=true
 # Canonical home reservations also survive temporary relocation.
 for other in world.media.get("books",[]):
  if other.get("id","")==id:continue
  if str(other.get("home_slot_id",""))!="":used[str(other.get("home_room_id",""))+"|"+str(other.home_slot_id)]=true
 for room in world.matching_rooms(["library"]):
  if not world.public_cutaway_allowed(room):continue
  var rid:String=room.id
  for slot in life.candidate_navigation.book_slots(room):
   var sid:String=slot.id
   if used.has(rid+"|"+sid) or not m._book_support_free(id,rid,slot):continue
   out.append({"room_id":rid,"slot_id":sid,"label":str(room.get("display_name",rid))+" · "+sid})
 return out

func move_book(id:String,rid:String,sid:String)->bool:
 if not book_options(id).any(func(x):return x.room_id==rid and x.slot_id==sid):return false
 var b:Dictionary=life.media_runtime._lookup("books",id)
 var before:Dictionary=b.duplicate(true)
 var assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{}).duplicate(true)
 var journal:Array=world.journal.duplicate(true)
 var pending:Dictionary=world.runtime_state.get("housekeeping_pending_books",{}).duplicate(true)
 b["home_room_id"]=rid
 b["home_slot_id"]=sid
 b["location_room_id"]=rid
 b["last_interaction_at"]=world.sim_clock
 b["idle_since"]=0
 if not world.runtime_state.has("teea008_book_slot_assignments"):world.runtime_state["teea008_book_slot_assignments"]={}
 world.runtime_state["teea008_book_slot_assignments"][id]={"room_id":rid,"slot_id":sid}
 world.runtime_state.get("housekeeping_pending_books",{}).erase(id)
 world._append_journal("BOOK_HOME_ASSIGNED","LOCAL_DRAGON",id,str(before.get("home_room_id","")),rid,{"shelf_slot_id":sid})
 if not world.save_world():
  b.clear();b.merge(before,true)
  world.runtime_state["teea008_book_slot_assignments"]=assignments
  world.runtime_state["housekeeping_pending_books"]=pending
  world.journal=journal
  return false
 return true
