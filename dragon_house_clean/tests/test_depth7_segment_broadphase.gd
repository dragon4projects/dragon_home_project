extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const D=preload("res://scripts/depth7_layout.gd")
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func slow(n,room:Dictionary,a:Vector2,b:Vector2)->bool:
 var steps:=maxi(1,ceili(a.distance_to(b)/.025))
 for i in range(steps+1):
  if not n.clear(room,a.lerp(b,float(i)/float(steps))):return false
 return true
func run()->void:
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var rows:Dictionary=b.layouts.duplicate(true)
 for key in D.SOCIAL_KEYS+D.FUNCTION_KEYS+D.GUEST_KEYS:rows[key]=D.convert(rows[key],key)
 var hearth:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/depth7_hearth_layout.json"))
 D.append_hearth_services(hearth,b.layouts["common/R3"]);rows["common/R3"]=hearth
 var n=N.new();n.configure(rows)
 var rng:=RandomNumberGenerator.new();rng.seed=827311
 var queries:Array=[]
 for key in D.SOCIAL_KEYS+D.FUNCTION_KEYS+D.GUEST_KEYS:
  var room:Dictionary={"type":key.get_slice("/",0),"size_modules":int(key.get_slice("/",1).trim_prefix("R")),"depth7":true}
  var hw:float=room.size_modules*2.4
  for i in range(110):
   var a:=Vector2(rng.randf_range(-hw-.01,hw+.01),rng.randf_range(-8.1,1.7))
   var z:float=[1.15,-1.3,-4.0][i%3]
   var target:=Vector2(rng.randf_range(-hw-.01,hw+.01),z if i%2==0 else rng.randf_range(-8.1,1.7))
   queries.append([room,a,target])
  for z in [1.65,0.65,-.85,-1.75,-3.6,-4.5,-6.65,-7.726]:
   queries.append([room,Vector2(-hw,z),Vector2(hw,z)])
 var expected:Array=[]
 var t:=Time.get_ticks_usec()
 for q in queries:expected.append(slow(n,q[0],q[1],q[2]))
 var baseline:int=Time.get_ticks_usec()-t
 t=Time.get_ticks_usec()
 var actual:Array=[]
 for q in queries:actual.append(n.sampled_segment_clear(q[0],q[1],q[2]))
 var fast:int=Time.get_ticks_usec()-t
 for i in range(queries.size()):assert(actual[i]==expected[i],str(queries[i]))
 print("DEPTH7_SEGMENT_BROADPHASE_PASS queries=",queries.size()," original_us=",baseline," new_us=",fast," equivalent=true")
 quit()
