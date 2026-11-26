extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
const N=preload("res://scripts/teea008_navigation.gd")
const L=preload("res://scripts/depth7_layout.gd")
const W=preload("res://scripts/world_model.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var bank=B.new();assert(bank.initialize(true));bank.apply_architecture_layouts()
 var row:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/depth7_hearth_layout.json"))
 L.append_hearth_services(row,bank.layouts["common/R3"])
 var n=N.new();n.configure({"common/R3":row});n.install_depth7_pose_intake()
 var w=W.new();w.canonical_house_seed=true;w.seed_world()
 var room:Dictionary=w.get_room(-3,1);room["depth7"]=true
 var floor_items:Array=[];var mats:Array=[]
 for item in row.instances:
  if item.placement_policy=="floor_fixed":floor_items.append(item)
  if str(item.instance_id).begins_with("common_r3_p3_fur_"):mats.append(item)
 assert(mats.size()==2)
 for item in mats:
  var a:=Rect2(Vector2(item.bounds_min_m[0],item.bounds_min_m[2]),Vector2(item.bounds_max_m[0]-item.bounds_min_m[0],item.bounds_max_m[2]-item.bounds_min_m[2]))
  for other in floor_items:
   var b:=Rect2(Vector2(other.bounds_min_m[0],other.bounds_min_m[2]),Vector2(other.bounds_max_m[0]-other.bounds_min_m[0],other.bounds_max_m[2]-other.bounds_min_m[2]))
   assert(not a.intersects(b),str([item.instance_id,other.instance_id]))
 var count:=0;var fit:=0
 for spot in n.candidate_spots(room):
  if spot.kind!="floor_rest":continue
  for x in [-7.12,7.12]:assert(not n.path(room,Vector2(x,1.5),spot.offset).is_empty())
  for id in n.pose_profiles:
   var actor:Dictionary=w.residents.get(id,{})
   if actor.is_empty():continue
   actor["teea008_pose_wardrobe"]=n.pose_profiles[id]["wardrobe"]
   var contact:Dictionary=n.pose_contact(actor,spot,"REST")
   if contact.is_empty():continue
   assert(contact.state=="LIE_SIDE_CURLED")
   assert(absf(float(contact.local_xyz[1])-.008)<.05)
   fit+=1
  count+=1
 assert(count==2 and fit>0,str([count,fit]))
 print("DEPTH7_FLOOR_REST_PASS mats=",count," compatible_contacts=",fit)
 quit()
