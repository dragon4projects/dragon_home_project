extends SceneTree
const D=preload("res://scripts/depth7_space.gd")
const N=preload("res://scripts/teea008_navigation.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var f=FileAccess.open("res://data/depth7_hearth_layout.json",FileAccess.READ)
 var row:Dictionary=JSON.parse_string(f.get_as_text())
 var n=N.new();n.configure({"common/R3":row})
 var room={"id":"test","type":"common","size_modules":3,"depth7":true}
 var seats:=0
 for s in n.candidate_spots(room):
  if s.get("candidate_kind","")!="seat":continue
  seats+=1
  for x in [-7.12,7.12]:
   var start:=Vector2(x,1.5)
   var path:Array=n.path(room,start,s.offset)
   if path.is_empty():
    push_error("FAILED "+str([s.id,s.offset,x,n.clear(room,s.offset)]));quit(1);return
   for p in path:
    if not n.segment_clear(room,start,p):
     push_error("BAD SEGMENT "+str([s.id,start,p]));quit(1);return
    start=p
 assert(seats==19)
 for i in [1,3,5]:
  assert(n.segment_clear(room,Vector2(-7.12,D.center(i)),Vector2(7.12,D.center(i))),str(i))
 print("DEPTH7_NAVIGATION_PASS seats=",seats," routes=",2*seats)
 quit(0)
