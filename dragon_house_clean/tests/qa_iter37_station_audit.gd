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
 for room in w.matching_rooms(["common","rest","kitchen","library","artifact","cinema","music","study","workshop"]):
  var seats:=0
  var spots:Array=s.layout_for_world(w,room)
  for p in spots:
   if p.kind=="seat":seats+=1
  var reads:Array=[]
  var rests:Array=[]
  var films:Array=[]
  var works:Array=[]
  for i in range(1,25):
   var id:String="RES_%02d"%i
   var a:Dictionary=w.residents[id]
   if not s.single(w,a,room,"READ_BOOK").is_empty():reads.append(id)
   if not s.single(w,a,room,"REST").is_empty():rests.append(id)
   if not s.single(w,a,room,"WATCH_FILM").is_empty():films.append(id)
   if not s.single(w,a,room,"WORK_CREATE").is_empty():works.append(id)
  print("ROOM ",room.id," ",n.key(room)," spots=",spots.size()," seats=",seats," read=",reads," rest=",rests.size()," film=",films.size()," work=",works.size())
 quit(0)
