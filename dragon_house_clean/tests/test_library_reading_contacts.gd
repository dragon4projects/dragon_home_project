extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const S=preload("res://scripts/room_stations.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var w=W.new()
 w.canonical_house_seed=true
 w.seed_world()
 var b=B.new()
 assert(b.initialize(true))
 b.apply_architecture_layouts()
 var n=N.new()
 n.configure(b.layouts)
 var s=S.new()
 s.candidate_navigation=n
 for a in w.residents.values():
  a.active=false
  a["teea008_pose_wardrobe"]=str(n.pose_profiles.get(a.id,{}).get("wardrobe",""))
 var rooms:Array=w.matching_rooms(["library"])
 assert(rooms.size()==2)
 for room in rooms:
  assert(n.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
  var seats:=0
  var ids:Array=[]
  for spot in s.layout_for_world(w,room):
   if str(spot.id).begins_with("library_r3_reading_chair"):
    assert(spot.kind=="seat")
    assert(n.clear(room,spot.offset))
    for start in [Vector2(-7.12,1.5),Vector2(7.12,1.5)]:
     assert(not n.path(room,start,spot.offset).is_empty())
    seats+=1
  assert(seats==2)
  for i in range(1,25):
   var id:String="RES_%02d"%i
   var claim:Dictionary=s.single(w,w.residents[id],room,"READ_BOOK")
   if not claim.is_empty():
    assert(claim.contact.state=="READ")
    ids.append(id)
  print("LIBRARY ",room.id," seats=",seats," read=",ids.size()," excluded=",24-ids.size())
  assert(ids.size()==23 and not ids.has("RES_07"))
 print("LIBRARY_READING_CONTACTS_PASS rooms=2 seats=4 compatible_residents=23 aisle=true both_entries=true")
 quit(0)
