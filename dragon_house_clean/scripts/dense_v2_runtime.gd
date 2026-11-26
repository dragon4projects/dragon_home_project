extends RefCounted
## Explicit isolated QA mode. Does not migrate, overwrite, or reinterpret
## an owner's existing house save. Physical and visual records share one
## measured transform; rejected source placements remain in the QA report.
const NAV=preload("res://scripts/teea008_navigation.gd")
const REVIEW=preload("res://scripts/dense_v2_review.gd")
const COMPILED="res://data/interior_v2/dense_v2_compiled_%d.zip"
const ROOMS={
 "L2_library":[4,2,"library",3],
 "L0_reading":[-6,0,"library",3],
 "L1_gallery":[1,1,"artifact",3],
 "L2_cinema":[-6,2,"cinema",3],
 "L0_cinema":[1,0,"cinema",3],
 "L2_music":[1,2,"music",3],
 "L1_study":[4,1,"study",3],
 "L0_workshop":[-3,0,"workshop",3],
 "L0_kitchen":[4,0,"kitchen",3],
 "L2_lounge":[-3,2,"rest",3],
 "L1_lounge":[-6,1,"rest",3],
 "Lm2_centaur":[-6,-2,"guest",2],
 "Lm2_vampire":[1,-2,"guest",1],
 "Lm2_miu":[6,-2,"guest",1]
}
var by_room:Dictionary={}
var report:Dictionary={}
var route_repairs:Array=[]
var withheld_stations:Array=[]
var review=REVIEW.new()

func install(world,layouts:Dictionary)->bool:
 var data:Dictionary={}
 var rooms:Dictionary={}
 var expected_source:String=FileAccess.get_sha256(REVIEW.SOURCE)
 for i in range(3):
  var archive:=ZIPReader.new()
  if archive.open(COMPILED%i)!=OK:return false
  var part=JSON.parse_string(archive.read_file("compiled.json").get_string_from_utf8())
  archive.close()
  if typeof(part)!=TYPE_DICTIONARY or int(part.get("schema",0))!=1:return false
  if part.get("source_sha256")!=expected_source or int(part.get("totals",{}).get("issues",-1))!=0:return false
  if i==0:data=part.duplicate(true)
  elif data.get("totals")!=part.get("totals"):return false
  for k in part.get("rooms",{}):
   if rooms.has(k):return false
   rooms[k]=part["rooms"][k]
 if rooms.size()!=19:return false
 data["rooms"]=rooms
 var prospective:Dictionary={}
 var planned_layouts:Dictionary={}
 for k in ROOMS:
  var spec:Array=ROOMS[k]
  var room:Dictionary=world.get_room(spec[0],spec[1])
  if room.is_empty() or room.get("type")!=spec[2] or int(room.get("size_modules",0))!=int(spec[3]):return false
  if not world.public_cutaway_allowed(room):continue
  var compiled:Dictionary=data.get("rooms",{}).get(k,{})
  if compiled.is_empty() or not compiled.get("issues",[]).is_empty():return false
  var row:Dictionary=review.navigation_row(compiled,spec[2],spec[3])
  prospective[str(room.id)]={"compiled":compiled,"variant":row.variant_id}
  planned_layouts[row.variant_id]=row
 if prospective.is_empty():return false
 # Commit only after verifying the entire room-to-plan mapping.
 for id in prospective:
  var room:Dictionary=world.room_by_id(id)
  room["dense_v2_layout"]=prospective[id].variant
  room["depth7"]=true
 for key in planned_layouts:layouts[key]=planned_layouts[key]
 by_room=prospective
 report=data
 qualify_approaches(world,layouts)
 return true

func has_room(id:String)->bool:return by_room.has(id)

func mount(parent:Node3D,id:String,overview:bool)->int:
 if not by_room.has(id):return 0
 var row:Dictionary=by_room[id].compiled
 if overview:
  row={"placements":row.placements.filter(func(p):return p.get("role","") in REVIEW.FLOOR_ROLES)}
 return review.mount_review(parent,row)

# Qualify the precise approach, not the actual seat/pelvis coordinates.
# A seat without a near and reachable approach remains visual-only.
func qualify_approaches(world,layouts:Dictionary)->void:
 var nav=NAV.new()
 nav.configure(layouts)
 for id in by_room:
  var room:Dictionary=world.room_by_id(id)
  var row:Dictionary=layouts[by_room[id].variant]
  var half:float=float(room.size_modules)*2.4
  var ends:Array=[Vector2(-half+.08,1.5),Vector2(half-.08,1.5)]
  var points:Array=nav.candidate_spots(room)
  var failed:Dictionary={}
  for spot in points:
   if str(spot.get("furniture_id",""))=="" or not spot.has("candidate_kind"):continue
   if ends.all(func(e):return not nav.path(room,e,spot.offset).is_empty()):continue
   failed[spot.id]=spot
  for item in row.instances:
   var keep:Array=[]
   for station in item.station_candidates:
    var sid:String=str(station.station_candidate_id)
    if not failed.has(sid):
     keep.append(station);continue
    var at:Vector2=failed[sid].offset
    var lo:=Vector2(item.bounds_min_m[0],item.bounds_min_m[2])
    var hi:=Vector2(item.bounds_max_m[0],item.bounds_max_m[2])
    var options:Array=[]
    for radius in [.10,.20,.30,.40,.50]:
     for i in range(16):
      var p:Vector2=at+Vector2.from_angle(TAU*float(i)/16.0)*radius
      if not nav.clear(room,p):continue
      # Keep the approach near the same piece and original contact.
      if p.distance_to(p.clamp(lo,hi))>.70:continue
      options.append(p)
    var chosen:=Vector2.INF
    for p in options:
     if ends.all(func(e):return not nav.path(room,e,p).is_empty()):
      chosen=p;break
    if chosen.is_finite():
     station["room_approach_xz"]=[chosen.x,chosen.y]
     route_repairs.append({"room":id,"station":sid,"old":[at.x,at.y],"new":[chosen.x,chosen.y]})
     keep.append(station)
    else:
     withheld_stations.append({"room":id,"station":sid,"reason":"UNREACHABLE_NEAR_CONTACT"})
   item["station_candidates"]=keep
 print("DENSE_V2_APPROACH_QUALIFICATION repaired=",route_repairs," withheld=",withheld_stations)
