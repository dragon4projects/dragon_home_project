extends SceneTree
const BANK=preload("res://scripts/teea008_review_bank.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var bank=BANK.new()
 var result:Dictionary={}
 for id in ["sofa_03","blendkit_sofa_repaired","ArmChair_01","gothic_coffee_table","wooden_table_02"]:
  var node:Node3D=load(bank._asset_path(id)).instantiate()
  root.add_child(node)
  var tris:Array[PackedVector3Array]=[]
  var bounds:=AABB();var first:=true
  for mesh in node.find_children("*","MeshInstance3D",true,false):
   var m:MeshInstance3D=mesh
   var b:AABB=m.global_transform*m.get_aabb()
   bounds=b if first else bounds.merge(b);first=false
   for i in range(m.mesh.get_surface_count()):
    var a:Array=m.mesh.surface_get_arrays(i)
    var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX]
    if ix.is_empty():
     for j in range(v.size()):ix.append(j)
    for k in range(0,ix.size(),3):
     tris.append(PackedVector3Array([m.to_global(v[ix[k]]),m.to_global(v[ix[k+1]]),m.to_global(v[ix[k+2]])]))
  var samples:Array=[]
  for x in [-.45,0.0,.45]:
   for z in [-.30,-.20,-.10,0.0,.10,.15,.20,.30]:
    var h:float=-1
    for t in tris:
     var hit=Geometry3D.ray_intersects_triangle(Vector3(x,3,z),Vector3.DOWN,t[0],t[1],t[2])
     if hit==null:hit=Geometry3D.ray_intersects_triangle(Vector3(x,3,z),Vector3.DOWN,t[2],t[1],t[0])
     if hit!=null:h=maxf(h,hit.y)
    samples.append([x,z,h])
  result[id]={"bounds":[bounds.position,bounds.size],"samples":samples,"triangles":tris.size()}
  node.free()
 var f=FileAccess.open("/home/user/dragon_qa/iter58_measure.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(result,"  "));f.close()
 print("HEARTH_MEASURE_PASS ",result.size())
 quit()
