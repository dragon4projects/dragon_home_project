extends SceneTree
const W=preload("res://scripts/world_model.gd")
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const C=preload("res://scripts/teea008_cup_runtime.gd")
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
 var original:Dictionary={}
 var raw:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/canonical_social_interiors_20261125.json"))
 for row in raw.variants:original[row.variant_id]=row
 var old=N.new()
 old.configure(original)
 var cups=C.new()
 cups.setup(w,n)
 var s=S.new()
 s.candidate_navigation=n
 for a in w.residents.values():
  a.active=false
  a["teea008_pose_wardrobe"]=str(n.pose_profiles.get(a.id,{}).get("wardrobe",""))
 var tested:=0
 for room in w.matching_rooms(["kitchen","rest"]):
  var key:String=n.key(room)
  var row:Dictionary=b.layouts[key]
  assert(row.social_zone_revision=="SOCIAL_ZONES_V3")
  var left:=Vector2(-7.12,1.5)
  var right:=Vector2(7.12,1.5)
  assert(n.segment_clear(room,left,right))
  var original_slots:Array=old.cup_slots(room)
  var current_slots:Array=n.cup_slots(room)
  for slot in original_slots:
   var matches:Array=current_slots.filter(func(p):return p.id==slot.id)
   assert(matches.size()==1 and matches[0].xyz==slot.xyz,str([key,slot.id,matches]))
  var solids:Array=[]
  var seats:=0
  for item in row.instances:
   if item.placement_policy=="floor_fixed":solids.append(item)
   for station in item.get("station_candidates",[]):
    var pt:Array=station.get("room_approach_xz",[])
    if pt.size()!=2:continue
    var at:=Vector2(pt[0],pt[1])
    assert(n.clear(room,at),str([key,item.instance_id,at]))
    for entry in [left,right]:
     assert(not n.path(room,entry,at).is_empty(),str([key,item.instance_id,entry]))
    if station.kind=="seat":seats+=1
  for i in range(solids.size()):
   var a:Dictionary=solids[i]
   for j in range(i+1,solids.size()):
    var c:Dictionary=solids[j]
    var lo:Array=a.bounds_min_m
    var hi:Array=a.bounds_max_m
    var cl:Array=c.bounds_min_m
    var ch:Array=c.bounds_max_m
    assert(minf(hi[0],ch[0])-maxf(lo[0],cl[0])<=0.001 or minf(hi[2],ch[2])-maxf(lo[2],cl[2])<=0.001,str([key,a.instance_id,c.instance_id]))
  var sources:Array=cups.service_sources(w.residents.RES_01,room)
  var kinds:Dictionary={}
  for source in sources:
   kinds[source.type]=true
   for entry in [left,right]:assert(not n.path(room,entry,source.approach).is_empty())
  assert(kinds.has("BAR") and kinds.has("COFFEE_NOOK"))
  assert(seats==(2 if key=="kitchen/R3" else 6))
  print("SOCIAL_ZONE ",key," seats=",seats," cup_homes=",original_slots.size()," service=",sources.size())
  tested+=1
 assert(tested==3)
 print("SOCIAL_ZONES_V3_PASS rooms=3 seats=14 support_homes_preserved=true no_floor_overlap=true both_entries=true")
 quit(0)
