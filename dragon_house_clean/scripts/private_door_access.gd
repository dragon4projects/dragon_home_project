extends RefCounted
## Local simulation protocol. Caller must be an explicitly authorized local
## owner-control adapter. IDs here are simulation identities, not credentials
## or evidence of a real person's consent. No default grants, no text parsing.
const KEY="private_door_access_v1"
const FRONTAGE_Z=1.54
const MIN_FRONTAGE_Z=1.35

static func state(world,room:Dictionary)->Dictionary:
 var all=world.runtime_state.get(KEY,{})
 if typeof(all)!=TYPE_DICTIONARY:return {}
 var row=all.get(str(room.get("id","")),{})
 if typeof(row)!=TYPE_DICTIONARY or str(row.get("owner",""))!=str(room.get("owner_id","")):return {}
 return row

static func valid_room(room:Dictionary)->bool:
 return room.get("type","")=="private" and room.get("privacy","")!="public" and str(room.get("owner_id",""))!=""

static func valid_visitor(world,room:Dictionary,visitor:String)->bool:
 if not valid_room(room) or visitor=="" or visitor==room.get("owner_id",""):return false
 var a:Dictionary=world.residents.get(visitor,{})
 return bool(a.get("active",false)) and bool(a.get("autonomy_enabled",true)) and not world.creatures.has(visitor) and visitor!="MANJKA"

static func at_frontage(world,room:Dictionary,visitor:String)->bool:
 var a:Dictionary=world.residents.get(visitor,{})
 if str(a.get("room_id",""))!=str(room.get("id","")):return false
 var at:=Vector3(float(a.get("x",INF)),float(a.get("visual_y",INF)),float(a.get("z",INF)))
 if not at.is_finite() or absf(at.y-float(room.level)*world.FLOOR_H)>.05:return false
 var local:Vector2=world.room_world_to_local(room,at)
 return local.y>=MIN_FRONTAGE_Z and local.y<=1.65 and absf(local.x)<=0.8

static func permitted(world,room:Dictionary,visitor:String)->bool:
 if not valid_visitor(world,room,visitor):return false
 var row:=state(world,room)
 return row.get("open",false)==true and row.get("quiet",false)==false and row.get("tickets",{}).get(visitor,"")=="admitted"

static func validate_snapshot(raw,rooms:Array,residents:Dictionary)->bool:
 if typeof(raw)!=TYPE_DICTIONARY:return false
 var by_id:Dictionary={}
 for room in rooms:by_id[str(room.get("id",""))]=room
 for rid in raw:
  var room:Dictionary=by_id.get(str(rid),{})
  var row=raw[rid]
  if not valid_room(room) or typeof(row)!=TYPE_DICTIONARY or str(row.get("owner",""))!=str(room.get("owner_id","")) or not residents.has(row.owner):return false
  if typeof(row.get("open"))!=TYPE_BOOL or typeof(row.get("quiet"))!=TYPE_BOOL or typeof(row.get("standing"))!=TYPE_DICTIONARY or typeof(row.get("tickets"))!=TYPE_DICTIONARY:return false
  if row.quiet and row.open:return false
  for visitor in row.standing:
   if visitor==row.owner or not residents.has(visitor) or row.standing[visitor]!=true:return false
  for visitor in row.tickets:
   if visitor==row.owner or not residents.has(visitor) or row.tickets[visitor] not in ["knocked","admitted"]:return false
  if row.quiet and not row.tickets.is_empty():return false
 # Visits must be attributable to one actual private threshold. A snapshot
 # with no current ticket can still contain a visitor completing safe exit.
 var occupied:Dictionary={}
 for id in residents:
  var a:Dictionary=residents[id]
  if not a.has("private_visit_room") and not a.has("private_visit_stage"):continue
  var rid:String=str(a.get("private_visit_room",""))
  var room:Dictionary=by_id.get(rid,{})
  var stage:String=str(a.get("private_visit_stage",""))
  if not valid_room(room) or occupied.has(rid) or id==room.get("owner_id","") or id=="MANJKA" or stage not in ["enter","inside","exit"]:return false
  if a.get("room_id","")!=rid or a.get("intent","")!="VISIT_PRIVATE" or a.get("phase","")!=("perform" if stage=="inside" else "travel"):return false
  for field in ["x","visual_y","z"]:
   if typeof(a.get(field)) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(a[field])):return false
  var center_x:float=(float(room.x)+(float(room.get("size_modules",1))-1.0)*.5)*4.8
  if absf(float(a.x)-center_x)>.801 or absf(float(a.visual_y)-float(room.level)*4.6)>.05 or float(a.z)<.799 or float(a.z)>1.651:return false
  occupied[rid]=true
 return true

static func mutate(world,rid:String,actor_id:String,operation:String,visitor:String="",flag:bool=false)->bool:
 if world.recovery_blocked:return false
 var room:Dictionary=world.room_by_id(rid)
 if not valid_room(room):return false
 var owner:String=room.owner_id
 var old:Dictionary=world.runtime_state.get(KEY,{}).duplicate(true)
 var row:Dictionary=state(world,room).duplicate(true)
 if row.is_empty():row={"owner":owner,"open":false,"quiet":false,"standing":{},"tickets":{}}
 var affected:Array=[]
 if operation=="knock":
  if actor_id!=visitor or not valid_visitor(world,room,visitor) or not at_frontage(world,room,visitor) or row.quiet:return false
  if row.tickets.get(visitor,"")=="admitted":return true
  row.tickets[visitor]="admitted" if row.open and row.standing.has(visitor) else "knocked"
  affected.append(visitor)
 elif operation=="leave":
  if actor_id!=visitor or not row.tickets.has(visitor) or not at_frontage(world,room,visitor):return false
  row.tickets.erase(visitor)
  affected.append(visitor)
 else:
  if actor_id!=owner or not world.residents.has(owner):return false
  match operation:
   "open":
    if flag and row.quiet:return false
    row.open=flag
    if not flag:
     affected.append_array(row.tickets.keys())
     row.tickets.clear()
   "quiet":
    row.quiet=flag
    if flag:
     row.open=false
     affected.append_array(row.tickets.keys())
     row.tickets.clear()
   "standing":
    if not valid_visitor(world,room,visitor):return false
    row.standing[visitor]=true
   "answer":
    if not valid_visitor(world,room,visitor) or row.quiet or row.tickets.get(visitor,"")!="knocked":return false
    if flag:row.tickets[visitor]="admitted"
    else:row.tickets.erase(visitor)
    affected.append(visitor)
   "revoke":
    if visitor=="" or visitor==owner:return false
    row.standing.erase(visitor)
    row.tickets.erase(visitor)
    affected.append(visitor)
   _:return false
 if state(world,room)==row:return true
 var next:Dictionary=old.duplicate(true)
 next[rid]=row
 world.runtime_state[KEY]=next
 # Private details are deliberately never present in the public projection.
 var previous_journal:Array=world.journal.duplicate(true)
 world._append_journal("PRIVATE_DOOR_CONTROL",actor_id,rid,rid,rid,{"visibility":"private","operation":operation,"visitor_id":visitor})
 if not world.save_world():
  world.runtime_state[KEY]=old
  world.journal=previous_journal
  return false
 for id in affected:world.private_access_changed.emit(rid,str(id))
 return true
