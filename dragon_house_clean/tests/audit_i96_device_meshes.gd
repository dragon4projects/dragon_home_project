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
   if mat!=null and mat.resource_name in ["Lowpoly_Screen","classic_laptop_screen"]:
    var points:Array=[]
    for v in vs:
     var q:Vector3=t*v
     if not points.has(q):points.append(q)
    print("SCREEN_POINTS ",points.slice(0,40))
 for child in n.get_children():visit(child,t)
func run()->void:
 for p in ["res://assets/teea008_review/decor_bank/classic_laptop/model.gltf","res://assets/decor_bank/owner_hp_notebook_lowpoly/model.gltf","res://assets/teea008_review/decor_bank/portable_cassette_player/model.gltf"]:
  print("I96_MESH ",p)
  var scene:PackedScene=load(p)
  var n:=scene.instantiate()
  visit(n,Transform3D.IDENTITY);n.free()
 quit(0)
