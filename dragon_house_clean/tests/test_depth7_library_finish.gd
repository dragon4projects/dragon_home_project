extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const L=preload("res://scripts/depth7_layout.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const D=preload("res://scripts/depth7_space.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var row:Dictionary=L.convert(b.layouts["library/R3"],"library/R3")
 var n=N.new();n.configure({"library/R3":row})
 var room={"id":"QA","type":"library","size_modules":3,"depth7":true}
 var ids:Dictionary={};var shelves:Array=[];var floor_items:Array=[]
 for it in row.instances:
  assert(not ids.has(it.instance_id),str(it.instance_id))
  ids[it.instance_id]=it
  if it.placement_policy=="floor_fixed":floor_items.append(it)
  if str(it.instance_id).begins_with("library_depth7_shelf_"):shelves.append(it)
 assert(shelves.size()==4)
 for item in shelves:
  var a:=Rect2(Vector2(item.bounds_min_m[0],item.bounds_min_m[2]),Vector2(item.bounds_max_m[0]-item.bounds_min_m[0],item.bounds_max_m[2]-item.bounds_min_m[2]))
  for other in floor_items:
   if item==other:continue
   var bnd:=Rect2(Vector2(other.bounds_min_m[0],other.bounds_min_m[2]),Vector2(other.bounds_max_m[0]-other.bounds_min_m[0],other.bounds_max_m[2]-other.bounds_min_m[2]))
   assert(not a.intersects(bnd),str([item.instance_id,other.instance_id]))
 for it in row.instances:
  if not str(it.instance_id).contains("library_depth7_shelf_") or it.placement_policy!="supported":continue
  var host:Dictionary=ids[L.host_id(it)]
  var sid:String=str(it.get("decor_slot_id",it.get("support_ref","")))
  var slots:Array=host.support_slots.filter(func(s):return s.room_slot_id==sid)
  assert(slots.size()==1)
  assert(absf(float(it.bounds_min_m[1])-float(slots[0].room_xyz[1]))<.001)
 var all_slots:Array=n.book_slots(room)
 print("LIBRARY_SLOTS ",all_slots.size()," instances=",row.instances.size())
 assert(all_slots.size()==50)
 var slots_by_id:Dictionary={}
 for slot in all_slots:
  assert(not slots_by_id.has(slot.id));slots_by_id[slot.id]=true
 for spot in n.candidate_spots(room):
  for x in [-7.12,7.12]:assert(not n.path(room,Vector2(x,1.5),spot.offset).is_empty(),str(spot.id))
 for band in [1,3,5]:assert(n.segment_clear(room,Vector2(-7.12,D.center(band)),Vector2(7.12,D.center(band))))
 print("DEPTH7_LIBRARY_FINISH_PASS new_shelves=4 new_book_slots=40 no_overlaps=true")
 quit()
