extends "res://tests/audit_i96_owner_decor.gd"
const NAV=preload("res://scripts/teea008_navigation.gd")
const SHELF=DESIGN.SHELF
func _preserve(nav,room:Dictionary,row:Dictionary)->bool:
 var trial=NAV.new();trial.configure({row.variant_id:row})
 var half:float=float(room.size_modules)*2.4
 var ends:Array=[Vector2(-half+.08,1.5),Vector2(half-.08,1.5)]
 for s in nav.candidate_spots(room):
  if not s.get("offset",Vector2.INF).is_finite():continue
  for start in ends:
   if not nav.path(room,start,s.offset).is_empty() and trial.path(room,start,s.offset).is_empty():return false
 return trial.book_slots(room).size()==nav.book_slots(room).size() and trial.cup_slots(room).size()==nav.cup_slots(room).size()
func _run()->void:
 if not review.initialize():quit(1);return
 var w=WORLD.new();w.canonical_house_seed=true;w.seed_world()
 var runtime=RUNTIME.new();var layouts:Dictionary={}
 if not runtime.install(w,layouts,true):quit(2);return
 var manifest:Dictionary=DESIGN.read_manifest()
 if manifest.is_empty():quit(3);return
 for rid in runtime.by_room:
  var entry:Dictionary=runtime.by_room[rid]
  var room:Dictionary=entry.compiled
  if room.key not in ["L2_library","L0_reading"]:continue
  var live:Dictionary=w.room_by_id(rid)
  var k:String=entry.variant
  var original:Dictionary=layouts[k]
  var nav=NAV.new();nav.configure({k:original})
  var candidates:Array=[]
  var half:float=float(room.width)*.5
  # Bookcase face points into the room. Keep the front and inter-room
  # passage bands open; add only genuinely free wall bays.
  for x in range(-12,13,2):candidates.append([0.0,float(x)*.5,-7.9])
  for side in [-1,1]:
   for z in [-7.35,-5.57,-2.67,-.1]:
    candidates.append([-90.0*float(side),float(side)*(half-.08),z])
  var shelves:Array=[]
  var props:Array=[]
  var occupied:Array=[]
  for p in room.placements:
   if p.get("fits",false) and p.has("bounds_min"):occupied.append({"id":p.id,"box":_box(p)})
  for spec in candidates:
   var yaw:float=spec[0]
   var measure:Dictionary=review.measured_bounds(SHELF,yaw)
   if measure.is_empty():continue
   var b:AABB=measure.bounds
   var scale:float=.86 if yaw==0 else 1.0
   var size:=b.size*scale
   var center:=Vector3(spec[1],.025+size.y*.5,spec[2])
   if yaw==0:center.z=-8.0+size.z*.5
   else:center.x=signf(center.x)*(half-.08-size.x*.5)
   var bb:=AABB(center-size*.5,size)
   if bb.position.z< -8.04 or bb.end.z>1.65 or bb.position.x< -half or bb.end.x>half or bb.end.y>3.0:continue
   if yaw!=0:
    var band:int=NAV.DEPTH7.band(center.z)
    if band not in [2,4,6,7] or NAV.DEPTH7.band(bb.position.z+.001)!=band or NAV.DEPTH7.band(bb.end.z-.001)!=band:continue
   if occupied.any(func(o):return bb.grow(.04).intersects(o.box)):continue
   var pivot:=center-b.get_center()*scale
   var p:Dictionary={"id":room.key+"_I96_WALL_SHELF_%02d"%(shelves.size()+1),"asset":"wooden_bookshelf_worn","path":SHELF,"role":"floor","fits":true,"scale":scale,"yaw":yaw,"pivot":_a(pivot),"bounds_min":_a(bb.position),"bounds_max":_a(bb.end),"station_candidates":[],"support_slots":[],"evidence":"DECORATIVE_LIBRARY_BOOKCASE_MEASURED"}
   room.placements.append(p)
   var row:Dictionary=review.navigation_row(room,"library",3)
   for field in ["service_sources","service_cups","measured_book_slots"]:
    if original.has(field):row[field]=original[field]
   if not _preserve(nav,live,row):
    room.placements.pop_back();continue
   shelves.append(p);occupied.append({"id":p.id,"box":bb})
   for i in range(8):
    var book:=_place(room,p,"book_encyclopedia_set_01",LIB+"book_encyclopedia_set_01/model.gltf",occupied,100+props.size())
    if book.is_empty():break
    book.id=room.key+"_I96_SHELF_BOOK_%03d"%(props.size()+1)
    props.append(book);occupied.append({"id":book.id,"box":_box(book)})
  manifest.rooms[room.key]={"floor_additions":shelves,"placements":props}
  print("I96_LIBRARY_WALLS ",room.key," new_cases=",shelves.size()," decorative_book_sets=",props.size()," walls=",shelves.map(func(p):return [p.yaw,p.pivot]))
 var f:=FileAccess.open("user://owner_design_qa.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(manifest," "));f.close()
 print("I96_LIBRARY_AUDIT_PASS")
 quit(0)
