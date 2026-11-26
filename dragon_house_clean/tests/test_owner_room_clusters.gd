extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var w=W.new();w.canonical_house_seed=true;w.seed_world()
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var nav=N.new();nav.configure(b.layouts)
 var count:=0
 for room in w.matching_rooms(["library","music","study","workshop"]):
  var key:String=nav.key(room)
  var row:Dictionary=b.layouts[key]
  assert(row.owner_cluster_revision=="OWNER_ROOM_CLUSTERS_V1")
  var fixed:Array=row.instances.filter(func(i):return i.placement_policy=="floor_fixed")
  assert(nav.segment_clear(room,Vector2(-7.12,1.5),Vector2(7.12,1.5)))
  for i in range(fixed.size()):
   var a:Dictionary=fixed[i]
   for j in range(i+1,fixed.size()):
    var c:Dictionary=fixed[j]
    var lo:Array=a.bounds_min_m
    var hi:Array=a.bounds_max_m
    var cl:Array=c.bounds_min_m
    var ch:Array=c.bounds_max_m
    assert(minf(hi[0],ch[0])-maxf(lo[0],cl[0])<=.001 or minf(hi[2],ch[2])-maxf(lo[2],cl[2])<=.001,str([key,a.instance_id,c.instance_id]))
   for st in a.get("station_candidates",[]):
    var xy:Array=st.get("room_approach_xz",[])
    if xy.size()!=2:continue
    var target:=Vector2(xy[0],xy[1])
    assert(nav.clear(room,target),str([key,a.instance_id,target]))
    for entry in [Vector2(-7.12,1.5),Vector2(7.12,1.5)]:
     assert(not nav.path(room,entry,target).is_empty(),str([key,a.instance_id,entry]))
  print("ROOM_CLUSTER ",key," clear=true stations=",nav.candidate_spots(room).size())
  count+=1
 assert(count>=4)
 print("OWNER_ROOM_CLUSTERS_PASS rooms=",count)
 quit()
