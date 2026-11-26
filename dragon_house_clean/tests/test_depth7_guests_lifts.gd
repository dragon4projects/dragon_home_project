extends SceneTree
const D=preload("res://scripts/depth7_space.gd")
const L=preload("res://scripts/depth7_layout.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const W=preload("res://scripts/world_model.gd")
const Lift=preload("res://scripts/canonical_lift_capacity.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 for key in L.GUEST_KEYS:
  var row:Dictionary=L.convert(b.layouts[key],key)
  assert(not row.is_empty(),key)
  var modules:int=int(key.get_slice("/R",1));var hw:float=modules*2.4
  var room={"id":"qa","type":"guest","interior_variant":key.get_slice("/",0),"size_modules":modules,"depth7":true}
  var n=N.new();n.configure({key:row})
  for i in row.instances:
   assert(float(i.bounds_min_m[0])>=-hw-.02 and float(i.bounds_max_m[0])<=hw+.02,str([key,i.instance_id]))
   assert(float(i.bounds_min_m[2])>=-8.3 and float(i.bounds_max_m[2])<=1.66)
  for band in [1,3,5]:assert(n.segment_clear(room,Vector2(-hw+.08,D.center(band)),Vector2(hw-.08,D.center(band))))
  for spot in n.candidate_spots(room):
   for x in [-hw+.08,hw-.08]:assert(not n.path(room,Vector2(x,1.5),spot.offset).is_empty(),str([key,spot.id]))
  print("GUEST_DEPTH7_PASS ",key," items=",row.instances.size()," stations=",n.candidate_spots(room).size())
 var world=W.new();world.canonical_house_seed=true;world.seed_world()
 var room:Dictionary=world.get_room(0,0);room["depth7"]=true
 var lifts=Lift.new();lifts.setup(world)
 var center:Vector3=world.room_center_pos(room);var top:Vector3=center+Vector3.UP*world.FLOOR_H
 var lanes:Dictionary={}
 for i in range(7):
  var a={"id":"QA_%d"%i,"room_id":room.id,"active":true,"phase":"travel","visual_y":center.y,"waypoint_index":0,"waypoints":[{"kind":"lift"}]}
  var result:Dictionary=lifts.target(a,center,top)
  if i==6:assert(result.get("wait",false));continue
  var at:Vector3=result.target;assert(D.passage(at.z))
  lanes[at.z]=int(lanes.get(at.z,0))+1
  assert(lifts.target(a,at,top).target==Vector3(at.x,top.y,at.z))
  a.visual_y=center.y+1.;world.residents[a.id]=a
 assert(lanes.size()==3)
 for c in lanes.values():assert(c==2)
 var restored=Lift.new();restored.setup(world)
 assert(restored.occupied["0"].size()==6)
 # Existing allocated old lane keeps its revision through a save/restart.
 var legacy:Dictionary=world.residents["QA_0"];legacy.canonical_lift_slot.depth_revision=0
 restored.sync()
 assert(restored.target(legacy,center,top).target.z==-.75)
 print("DEPTH7_LIFT_PASS slots=6 lanes=",lanes," reload=true legacy_slot=true")
 quit()
