extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var expected:Dictionary={"blendkit_sofa_set/chair.gltf":Vector3(.816706,.635204,.852862),"blendkit_beaker_flask/model.gltf":Vector3(.099607,.0994,.099607),"blendkit_decorational_glass_cover_storage/model.gltf":Vector3(.26,.393966,.26)}
 for id in expected:
  var node=load("res://assets/decor_bank/"+id).instantiate()
  root.add_child(node)
  var bounds:=AABB()
  var hit_y:float=-1.0
  var count:=0
  for mesh in node.find_children("*","MeshInstance3D",true,false):
   var m:MeshInstance3D=mesh
   bounds=bounds.merge(m.global_transform*m.get_aabb())
   for i in range(m.mesh.get_surface_count()):
    var a:Array=m.mesh.surface_get_arrays(i)
    var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX]
    var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX]
    count+=ix.size()/3
    if not id.begins_with("blendkit_sofa_set/"):continue
    for k in range(0,ix.size(),3):
     var x:Vector3=m.to_global(v[ix[k]])
     var y:Vector3=m.to_global(v[ix[k+1]])
     var z:Vector3=m.to_global(v[ix[k+2]])
     var h=Geometry3D.ray_intersects_triangle(Vector3(0,3,0),Vector3.DOWN,x,y,z)
     if h==null:h=Geometry3D.ray_intersects_triangle(Vector3(0,3,0),Vector3.DOWN,z,y,x)
     if h!=null:hit_y=maxf(hit_y,h.y)
  assert(bounds.size.distance_to(expected[id])<.005,str([id,bounds]))
  assert(absf(bounds.position.y)<.005,str([id,bounds]))
  if id.begins_with("blendkit_sofa_set/"):
   assert(count==304 and absf(hit_y-.385)<.005,str([count,hit_y]))
  print("MEASURED ",id," bounds=",bounds," tris=",count," seat_y=",hit_y)
  node.free()
 print("OWNER_CHAIR_MESH_PASS meshes=3")
 quit()
