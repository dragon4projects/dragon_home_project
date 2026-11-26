extends SceneTree
const B=preload("res://scripts/teea008_review_bank.gd")
func _initialize()->void:call_deferred("run")
func read(path:String)->Dictionary:
 return JSON.parse_string(FileAccess.get_file_as_string("res://"+path))
func run()->void:
 var doc:Dictionary=read("data/asset_proposals/OWNER_NORMALIZED_INTAKE_20261126/asset_index.json")
 var count:=0
 for item in doc.items:
  var scene:PackedScene=load(item.runtime_path)
  assert(scene!=null,item.asset_id)
  var node=scene.instantiate()
  assert(node.find_children("*","MeshInstance3D",true,false).size()>0,item.asset_id)
  node.free()
  count+=1
 assert(count==21)
 var bank=B.new()
 assert(bank.initialize(true))
 bank.apply_architecture_layouts()
 var accepted:=0
 var rooms:Dictionary={}
 for key in bank.layouts:
  var row:Dictionary=bank.layouts[key]
  for item in row.instances:
   if item.get("decor_refresh_revision","")!="OWNER_DECOR_V1":continue
   assert(item.get("station_candidates",[]).is_empty() and item.get("support_slots",[]).is_empty())
   rooms[key]=true
   accepted+=1
   print("DECOR_ACCEPTED ",key," ",item.instance_id," ",item.asset_id)
 assert(accepted>=8)
 print("OWNER_DECOR_INTAKE_PASS imports=",count," replacements=",accepted," variants=",rooms.size())
 quit(0)
