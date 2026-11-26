extends RefCounted
const D=preload("res://scripts/depth7_space.gd")
## Relocate only a proven, preserved support. Never infer a new home or move
## a carried, stashed or lost object; unmatched cup positions remain explicit.
static func cup_match(nav,room:Dictionary,anchor:Array)->Dictionary:
 if anchor.size()!=2:return {}
 var at:=Vector2(float(anchor[0]),float(anchor[1]))
 var found:Dictionary={}
 for slot in nav.cup_slots(room):
  var p:Array=slot["xyz"]
  if at.distance_to(Vector2(float(p[0]),float(p[2])))<.06:
   if not found.is_empty():return {}
   found=slot
 return found

static func run(world,old_nav,new_nav)->Dictionary:
 var result={"rebased":0,"unmatched":0,"failed":0}
 world.housekeeping_navigation=new_nav
 if not world._ensure_object_events():result.failed+=1;return result
 for id in world.objects.keys():
  var obj:Dictionary=world.objects[id]
  var category:String=str(obj.get("viewer_category",""))
  if not category in ["artifacts","cups"]:continue
  var changes:Dictionary={}
  for prefix in ["home","current"]:
   if prefix=="current" and (obj.get("state")!="PLACED" or str(obj.get("current_holder_id",""))!=""):continue
   var room:Dictionary=world.room_by_id(str(obj.get(prefix+"_room_id","")))
   if not D.enabled_for(room) or not world.public_cutaway_allowed(room):continue
   var field:String=prefix+"_anchor"
   var at:Array=obj.get(field,[])
   if at.size()!=2:continue
   var slot:Dictionary={}
   if category=="artifacts":
    var sid:String=str(obj.get(prefix+"_support_id",""))
    if sid=="":continue
    slot=new_nav.artifact_support(room,sid)
   else:
    # Already at a new slot: no second migration after restart.
    if not cup_match(new_nav,room,at).is_empty():continue
    var old_room:Dictionary=room.duplicate(true);old_room["depth7"]=false
    var old:Dictionary=cup_match(old_nav,old_room,at)
    if old.is_empty():result.unmatched+=1;continue
    for candidate in new_nav.cup_slots(room):
     if str(candidate["id"])==str(old["id"]):slot=candidate;break
   if slot.is_empty():result.unmatched+=1;continue
   var p:Array=slot["xyz"];var to:Array=[p[0],p[2]]
   if Vector2(float(at[0]),float(at[1])).distance_to(Vector2(float(to[0]),float(to[1])))<.0001:continue
   changes[field]={"from":at.duplicate(true),"to":to,"slot_id":slot["id"]}
  if not changes.is_empty():
   if world.object_events.rebase_support_geometry(str(id),changes):result.rebased+=1
   else:result.failed+=1
 return result
