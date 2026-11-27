extends RefCounted
## A saved intent bridges snapshot storage and the durable object-event log.
## Both checkpoint generations hold the intent before the first event.
## Recovery rolls forward only exact old/new anchors for the same support.
const KEY="pending_cup_support_edit_v1"

static func plan(world,old_nav,new_nav,room:Dictionary)->Dictionary:
 var changes:Dictionary={}
 var targets:Dictionary={}
 for s in new_nav.cup_slots(room):targets[s.id]=s
 var moved:Dictionary={}
 for s in old_nav.cup_slots(room):
  if not targets.has(s.id):return {"ok":false}
  var t:Dictionary=targets[s.id]
  var p:=Vector2(s.xyz[0],s.xyz[2])
  var q:=Vector2(t.xyz[0],t.xyz[2])
  if p.distance_to(q)>.0001:moved[s.id]={"from":[p.x,p.y],"to":[q.x,q.y],"slot_id":s.id}
 if moved.is_empty():return {"ok":true,"changes":{}}
 # Defer edits during any in-flight drink commitment to this room.
 for a in world.residents.values():
  if a.get("cup_task_room","")==room.id and a.has("cup_task_stage"):return {"ok":false}
 for id in world.objects:
  var o:Dictionary=world.objects[id]
  if o.get("viewer_category","")!="cups":continue
  var fields:Dictionary={}
  for prefix in ["home","current"]:
   if o.get(prefix+"_room_id","")!=room.id:continue
   if prefix=="current" and (o.get("state")!="PLACED" or o.get("current_holder_id","")!=""):continue
   var field:String=prefix+"_anchor"
   var at:Array=o.get(field,[])
   if at.size()!=2:continue
   for sid in moved:
    var item:Dictionary=moved[sid]
    if Vector2(at[0],at[1]).distance_to(Vector2(item.from[0],item.from[1]))>.0001:continue
    if o.get("current_holder_id","")!="":return {"ok":false}
    if fields.has(field):return {"ok":false}
    fields[field]={"from":at.duplicate(true),"to":item.to.duplicate(true),"slot_id":sid}
  if not fields.is_empty():changes[id]=fields
 return {"ok":true,"changes":changes}

static func finish(world,nav)->bool:
 if not world.runtime_state.has(KEY):return true
 var pending=world.runtime_state[KEY]
 if typeof(pending)!=TYPE_DICTIONARY or typeof(pending.get("changes"))!=TYPE_DICTIONARY:return false
 var room:Dictionary=world.room_by_id(str(pending.get("room_id","")))
 if room.is_empty() or not world.public_cutaway_allowed(room):return false
 world.housekeeping_navigation=nav
 if not world._ensure_object_events():return false
 for id in pending.changes:
  var o:Dictionary=world.physical_object(id)
  if o.is_empty() or o.get("viewer_category","")!="cups" or o.get("current_holder_id","")!="":return false
  var updates:Dictionary={}
  for field in pending.changes[id]:
   if field not in ["home_anchor","current_anchor"]:return false
   var c:Dictionary=pending.changes[id][field]
   var prefix:String=field.get_slice("_",0)
   if o.get(prefix+"_room_id","")!=room.id:return false
   if prefix=="current" and o.get("state")!="PLACED":return false
   var match_slot:Dictionary={}
   for s in nav.cup_slots(room):
    if s.id==c.slot_id:match_slot=s;break
   if match_slot.is_empty() or c.to.size()!=2 or c.from.size()!=2:return false
   if Vector2(c.to[0],c.to[1]).distance_to(Vector2(match_slot.xyz[0],match_slot.xyz[2]))>.0001:return false
   var at:Array=o.get(field,[])
   if at.size()!=2:return false
   if Vector2(at[0],at[1]).distance_to(Vector2(c.to[0],c.to[1]))<.0001:continue
   if Vector2(at[0],at[1]).distance_to(Vector2(c.from[0],c.from[1]))>.0001:return false
   updates[field]={"from":at.duplicate(true),"to":c.to,"slot_id":c.slot_id}
  if not updates.is_empty() and not world.object_events.rebase_support_geometry(id,updates):return false
 world.runtime_state.erase(KEY)
 if not world.save_world():
  world.runtime_state[KEY]=pending
  return false
 return true
