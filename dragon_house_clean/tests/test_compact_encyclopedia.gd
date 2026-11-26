extends SceneTree
const Bank=preload("res://scripts/teea008_review_bank.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var b=Bank.new()
 var packed:PackedScene=load("res://assets/teea008_review/decor_bank/book_encyclopedia_set_01/model.gltf")
 assert(packed!=null)
 var source:Node=packed.instantiate()
 var groups:Dictionary={}
 assert(b._collect_encyclopedia_surfaces(source,Transform3D.IDENTITY,groups))
 assert(groups.size()==3)
 var count:=0
 var triangle_count:=0
 var bounds:=AABB()
 var first:=true
 for records in groups.values():
  for row in records:
   count+=1
   var mesh:ArrayMesh=row.mesh
   var i:int=row.surface
   var n:int=mesh.surface_get_array_index_len(i)
   triangle_count+=(n if n>0 else mesh.surface_get_array_len(i))/3
   var arr:Array=mesh.surface_get_arrays(i)
   var xf:Transform3D=row.transform
   for vertex in arr[Mesh.ARRAY_VERTEX]:
    var at:Vector3=xf*vertex
    if first:bounds=AABB(at,Vector3.ZERO);first=false
    else:bounds=bounds.expand(at)
 assert(count==40)
 var merged:ArrayMesh=b._compact_encyclopedia(packed)
 assert(merged!=null and merged.get_surface_count()==3)
 assert(merged.get_aabb().position.distance_to(bounds.position)<0.00001 and merged.get_aabb().size.distance_to(bounds.size)<0.00001)
 var merged_triangles:=0
 for i in range(merged.get_surface_count()):
  var n:int=merged.surface_get_array_index_len(i)
  merged_triangles+=(n if n>0 else merged.surface_get_array_len(i))/3
 assert(merged_triangles==triangle_count)
 assert(b._compact_encyclopedia(packed)==merged)
 source.free()
 print("COMPACT_ENCYCLOPEDIA_PASS surfaces=40->3 triangles=",triangle_count," bounds=true cache=true")
 quit(0)
