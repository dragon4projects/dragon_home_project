extends SceneTree
const D=preload("res://scripts/depth7_space.gd")
const L=preload("res://scripts/depth7_layout.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=B.new()
 assert(b.initialize(true));b.apply_architecture_layouts()
 for key in L.FUNCTION_KEYS:
  var original:Dictionary=b.layouts[key]
  var row:Dictionary=L.convert(original,key)
  assert(not row.is_empty(),key)
  var room={"id":"qa","type":key.get_slice("/",0),"size_modules":3,"depth7":true}
  var old=N.new();old.configure({key:original})
  var previous_room:Dictionary=room.duplicate();previous_room["depth7"]=false
  var old_books:int=old.book_slots(previous_room).size()
  var old_art:int=old.artifact_slots(previous_room).size()
  var n=N.new();n.configure({key:row})
  var count:=0
  var by_id:Dictionary={}
  for item in row.instances:by_id[item.instance_id]=item
  for item in row.instances:
   var lo:Array=item.bounds_min_m;var hi:Array=item.bounds_max_m
   assert(float(lo[0])>=-7.21 and float(hi[0])<=7.21,str([key,item.instance_id,lo,hi]))
   assert(float(lo[2])>=-8.30 and float(hi[2])<=1.66,str([key,item.instance_id,lo,hi]))
   var h:String=L.host_id(item)
   if h!="":assert(by_id.has(h),str([key,item.instance_id,h]))
  if key=="cinema/R3":
   for j in [1,2]:
    var seat:Dictionary=by_id["owner_cinema_row_%d"%j]
    var base:Dictionary=by_id["owner_cinema_row_%d_plinth"%j]
    assert(absf(float(seat.bounds_min_m[1])-float(base.bounds_max_m[1]))<.0001)
    assert(absf(float(seat.room_local_xyz[2])-float(base.room_local_xyz[2]))<.0001)
   assert(n.candidate_spots(room).filter(func(s):return s.get("candidate_asset_id","")=="owner_theatre_seat_pair").size()==6)
  for spot in n.candidate_spots(room):
   for x in [-7.12,7.12]:
    assert(not n.path(room,Vector2(x,1.5),spot.offset).is_empty(),str([key,spot.id,x]))
    count+=1
  for i in [1,3,5]:assert(n.segment_clear(room,Vector2(-7.12,D.center(i)),Vector2(7.12,D.center(i))))
  var books:int=n.book_slots(room).size();var art:int=n.artifact_slots(room).size()
  print("DEPTH7_FUNCTION ",key," items=",row.instances.size()," routes=",count," book_slots=",old_books,"->",books," artifact_slots=",old_art,"->",art)
  assert(books>=old_books and art>=old_art)
  b.layouts[key]=row
 L.move_media(b.surfaces,L.FUNCTION_KEYS)
 for key in L.FUNCTION_KEYS:
  var parent:=Node3D.new();root.add_child(parent)
  var count:int=b.populate(parent,key.get_slice("/",0),3,func(_z):return 1.0)
  assert(count==b.layouts[key].instances.size(),str([key,count]))
  var wanted:=0
  for id in b.surfaces:
   if b.surfaces[id].room_variant==key:wanted+=1
  var actual:=parent.find_children("Aperture_*","Node3D",true,false).size()
  assert(actual==wanted,str([key,actual,wanted]))
  print("DEPTH7_MOUNT ",key," models=",count," apertures=",actual)
  parent.free()
 print("DEPTH7_FUNCTION_PASS")
 quit()
