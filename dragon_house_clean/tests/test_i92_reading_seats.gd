extends SceneTree
func _initialize()->void:call_deferred("run")
func must(ok:bool,msg:String)->bool:
 if not ok:push_error(msg);quit(2)
 return ok
func augment(sid:String,edges:Dictionary,match_actor:Dictionary,seen:Dictionary)->bool:
 for aid in edges[sid]:
  if seen.has(aid):continue
  seen[aid]=true
  if not match_actor.has(aid) or augment(str(match_actor[aid]),edges,match_actor,seen):
   match_actor[aid]=sid;return true
 return false
func run()->void:
 OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
 OS.set_environment("DRAGON_DENSE_V2_QA","1")
 OS.set_environment("DRAGON_DENSE_SERVICES_QA","1")
 var scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene);current_scene=scene;scene.set_process(false)
 await process_frame
 var w=scene.world
 var nav=scene.life.candidate_navigation
 if not must(scene.dense_services_qa and scene.complete_sprite_ready,"scene not ready"):return
 for room in w.matching_rooms(["library"]):
  if not scene.dense_v2.has_room(room.id):continue
  var key:String=scene.dense_v2.by_room[room.id].compiled.key
  var spots:Array=nav.candidate_spots(room).filter(func(s):return s.kind=="seat")
  if not must(spots.size()==16,"seat count "+key+" "+str(spots.size())):return
  var read_edges:Dictionary={}
  var rest_edges:Dictionary={}
  var occupied:Dictionary={}
  for s in spots:
   if not must(not occupied.has(s.id) and not nav.path(room,Vector2(-7.12,1.5),s.offset).is_empty() and not nav.path(room,Vector2(7.12,1.5),s.offset).is_empty(),"seat duplicate or route"):return
   occupied[s.id]=true
   var reads:Array=[]
   var rests:Array=[]
   for a in w.residents.values():
    if not a.get("active",false):continue
    if not nav.pose_contact(a,s,"READ_BOOK").is_empty():reads.append(a.id)
    if not nav.pose_contact(a,s,"REST").is_empty():rests.append(a.id)
   read_edges[s.id]=reads;rest_edges[s.id]=rests
   print("I92_SEAT_FIT ",s.id," rest=",rests.size()," read=",reads.size())
  var read_matching:Dictionary={}
  var rest_matching:Dictionary={}
  for sid in read_edges:augment(sid,read_edges,read_matching,{})
  for sid in rest_edges:augment(sid,rest_edges,rest_matching,{})
  var count:int=nav.book_slots(room).size()
  if not must(count==(60 if key=="L2_library" else 65) and nav.cup_slots(room).size()==2,"book/cup regression "+key):return
  print("I92_ROOM_CAPACITY ",key," geometry=",spots.size()," matched_rest=",rest_matching.size()," matched_read=",read_matching.size()," books=",count," cups=2")
 print("I92_GEOMETRY_AND_ROUTE_PASS pose_compatibility_reported_not_certified")
 quit(0)
