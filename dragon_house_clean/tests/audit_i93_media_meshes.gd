extends SceneTree
func _initialize()->void:call_deferred("run")
func visit(n:Node,xf:Transform3D)->void:
 var t:=xf
 if n is Node3D:t=xf*n.transform
 if n is MeshInstance3D and n.mesh!=null:
  for i in range(n.mesh.get_surface_count()):
   var arrays:Array=n.mesh.surface_get_arrays(i)
   if arrays.is_empty():continue
   var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
   var ns=arrays[Mesh.ARRAY_NORMAL]
   var box:=AABB(t*vs[0],Vector3.ZERO)
   for v in vs:box=box.expand(t*v)
   var mat:Material=n.mesh.surface_get_material(i)
   var normal:Vector3=(t.basis*ns[0]).normalized() if ns!=null and ns.size()>0 else Vector3.ZERO
   print(n.name," surface ",i," mat=",mat.resource_name if mat!=null else "none"," bounds=",box," normal=",normal)
 for child in n.get_children():visit(child,t)
func run()->void:
 for p in ["res://assets/decor_bank/owner_theatre_screen/model.gltf","res://assets/teea008_review/decor_bank/media_holder_audio/model.gltf","res://assets/teea008_review/decor_bank/cassette_player/model.gltf"]:
  print("I93_MESH ",p)
  var scene:PackedScene=load(p)
  var n:=scene.instantiate()
  visit(n,Transform3D.IDENTITY);n.free()
 quit(0)
