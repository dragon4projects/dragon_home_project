extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const L=preload("res://scripts/depth7_layout.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const D=preload("res://scripts/depth7_space.gd")
const W=preload("res://scripts/world_model.gd")
const M=preload("res://scripts/media_runtime.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var row:Dictionary=L.convert(b.layouts["library/R3"],"library/R3")
 var n=N.new();n.configure({"library/R3":row})
 var room={"id":"QA","type":"library","size_modules":3,"depth7":true}
 var by_id:Dictionary={};var floor_items:Array=[];var new_floor:Array=[];var added:=0
 for it in row.instances:
  assert(not by_id.has(it.instance_id))
  by_id[it.instance_id]=it
  var is_new:bool=str(it.instance_id).begins_with("library_island_")
  if it.placement_policy=="floor_fixed":
   floor_items.append(it)
   if is_new:new_floor.append(it)
  if is_new:added+=1
 assert(added==10 and new_floor.size()==4)
 for item in new_floor:
  var a:=Rect2(Vector2(item.bounds_min_m[0],item.bounds_min_m[2]),Vector2(item.bounds_max_m[0]-item.bounds_min_m[0],item.bounds_max_m[2]-item.bounds_min_m[2]))
  for other in floor_items:
   if item==other:continue
   var r:=Rect2(Vector2(other.bounds_min_m[0],other.bounds_min_m[2]),Vector2(other.bounds_max_m[0]-other.bounds_min_m[0],other.bounds_max_m[2]-other.bounds_min_m[2]))
   assert(not a.intersects(r),str([item.instance_id,other.instance_id]))
 for it in row.instances:
  if not str(it.instance_id).begins_with("library_island_") or it.placement_policy!="supported":continue
  var host:Dictionary=by_id[L.host_id(it)]
  assert(absf(float(host.bounds_max_m[1])-float(it.bounds_min_m[1]))<.001)
 var seats:=0
 for spot in n.candidate_spots(room):
  if not str(spot.furniture_id).begins_with("library_island_"):continue
  for x in [-7.12,7.12]:assert(not n.path(room,Vector2(x,1.5),spot.offset).is_empty(),str(spot.id))
  seats+=1
 assert(seats==2)
 for band in [1,3,5]:assert(n.segment_clear(room,Vector2(-7.12,D.center(band)),Vector2(7.12,D.center(band))))
 # Actual 76 source-backed catalog entries must fit in the 100 real slots.
 var w=W.new();w.canonical_house_seed=true;w.seed_world()
 for r in w.matching_rooms(["library"]):r["depth7"]=true
 var media=M.new();media.candidate_navigation=n;media.setup(w)
 var result:Dictionary=media.install_canonical_book_catalog()
 var assignments:Dictionary=w.runtime_state.get("teea008_book_slot_assignments",{})
 var seen:Dictionary={}
 for book in w.media.books:
  if not book.get("physical",false):continue
  var slot:Dictionary=media.book_slot(str(book.id))
  assert(not slot.is_empty(),str(book.id))
  var key:String=str(slot.room_id)+"|"+str(slot.id)
  assert(not seen.has(key));seen[key]=true
 assert(w.media.books.size()==76 and seen.size()==76,str([w.media.books.size(),seen.size(),result]))
 assert(media.install_canonical_book_catalog().physical==0)
 assert(media.reconcile_book_slots()==76)
 assert(w.runtime_state["teea008_book_slot_assignments"]==assignments)
 print("DEPTH7_READING_ISLAND_PASS added=10 seats=2 catalog=76 physical=76 unique_slots=true")
 quit()
