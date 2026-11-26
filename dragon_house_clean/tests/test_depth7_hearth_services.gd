extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/depth7_layout.gd")
const D=preload("res://scripts/depth7_space.gd")
const W=preload("res://scripts/world_model.gd")
const C=preload("res://scripts/teea008_cup_runtime.gd")
const MIG=preload("res://scripts/depth7_support_migration.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=B.new();assert(b.initialize(true));b.apply_architecture_layouts()
 var original:Dictionary=b.layouts["common/R3"]
 var file:=FileAccess.open("res://data/depth7_hearth_layout.json",FileAccess.READ)
 var row:Dictionary=JSON.parse_string(file.get_as_text())
 L.append_hearth_services(row,original)
 var ids:Dictionary={};var service_floor:Array=[];var floors:Array=[]
 for item in row.instances:
  assert(not ids.has(item.instance_id))
  ids[item.instance_id]=item
  if item.placement_policy=="floor_fixed":
   floors.append(item)
   if item.get("depth7_hearth_service",false):service_floor.append(item)
 assert(service_floor.size()==3)
 for item in service_floor:
  var a:=Rect2(Vector2(item.bounds_min_m[0],item.bounds_min_m[2]),Vector2(item.bounds_max_m[0]-item.bounds_min_m[0],item.bounds_max_m[2]-item.bounds_min_m[2]))
  for other in floors:
   if item==other:continue
   var bnd:=Rect2(Vector2(other.bounds_min_m[0],other.bounds_min_m[2]),Vector2(other.bounds_max_m[0]-other.bounds_min_m[0],other.bounds_max_m[2]-other.bounds_min_m[2]))
   assert(not a.intersects(bnd),str([item.instance_id,other.instance_id]))
 for item in row.instances:
  if not item.get("depth7_hearth_service",false) or item.placement_policy!="supported":continue
  assert(absf(float(item.bounds_min_m[1])-float(ids[L.host_id(item)].bounds_max_m[1]))<.0001)
 var n=N.new();n.configure({"common/R3":row})
 var old=N.new();old.configure({"common/R3":original})
 var w=W.new();w.canonical_house_seed=true;w.seed_world()
 var room:Dictionary=w.get_room(-3,1)
 var cups=C.new();cups.setup(w,old)
 assert(cups.register_review_mugs()==2)
 room["depth7"]=true
 var migration:Dictionary=MIG.run(w,old,n)
 assert(migration.rebased==2 and migration.failed==0,str(migration))
 cups.setup(w,n)
 assert(cups.register_review_mugs()==0)
 var actor:Dictionary=w.residents["RES_07"]
 var sources:Array=cups.service_sources(actor,room)
 var kinds:Dictionary={}
 for source in sources:
  kinds[source.type]=true
  assert(not n.path(room,Vector2(7.12,1.5),source.approach).is_empty())
 assert(kinds.has("BAR") and kinds.has("COFFEE_NOOK"),str(sources))
 assert(cups.candidates(actor,room).size()==2)
 for band in [1,3,5]:assert(n.segment_clear(room,Vector2(-7.12,D.center(band)),Vector2(7.12,D.center(band))))
 print("DEPTH7_HEARTH_SERVICES_PASS sources=2 migrated_mugs=2 passage_lanes=3")
 quit()
