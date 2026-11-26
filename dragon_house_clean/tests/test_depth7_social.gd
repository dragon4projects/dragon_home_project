extends SceneTree
const D=preload("res://scripts/depth7_space.gd")
const L=preload("res://scripts/depth7_layout.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var bank=B.new()
 if not bank.initialize(true):push_error(bank.error);quit(1);return
 bank.apply_architecture_layouts()
 for key in L.SOCIAL_KEYS:
  var original:Dictionary=bank.layouts[key]
  var row:Dictionary=L.convert(original,key)
  assert(not row.is_empty())
  assert(row.instances.size()==original.instances.size())
  var by_id:Dictionary={}
  for item in row.instances:by_id[item.instance_id]=item
  for item in row.instances:
   var lo:Array=item.bounds_min_m;var hi:Array=item.bounds_max_m
   assert(float(lo[0])>=-7.21 and float(hi[0])<=7.21,str([key,item.instance_id,lo,hi]))
   assert(float(lo[2])>=-8.30 and float(hi[2])<=1.66,str([key,item.instance_id,lo,hi]))
   var h:String=L.host_id(item)
   if h!="":
    assert(by_id.has(h))
    var host:Dictionary=by_id[h]
    assert(absf(float(item.bounds_min_m[1])-float(host.bounds_max_m[1]))<.035,str([key,item.instance_id]))
  var n=N.new();n.configure({key:row})
  var room={"id":"test","type":"kitchen" if key.begins_with("kitchen") else "rest","interior_variant":key.get_slice("/",0),"size_modules":3,"depth7":true}
  var spots:Array=n.candidate_spots(room)
  for i in [1,3,5]:assert(n.segment_clear(room,Vector2(-7.12,D.center(i)),Vector2(7.12,D.center(i))))
  for spot in spots:
   for x in [-7.12,7.12]:assert(not n.path(room,Vector2(x,1.5),spot.offset).is_empty(),str([key,spot.id,x]))
  print("DEPTH7_SOCIAL_ROOM_PASS ",key," instances=",row.instances.size()," stations=",spots.size()," cup_slots=",n.cup_slots(room).size())
 print("DEPTH7_SOCIAL_PASS 3")
 quit(0)
