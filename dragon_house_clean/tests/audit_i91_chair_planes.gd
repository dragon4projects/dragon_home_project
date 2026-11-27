extends "res://tests/audit_dense_v2_support_surfaces.gd"
const TARGETS={
 "mid_century_lounge_chair":"res://assets/teea008_review/decor_bank/mid_century_lounge_chair/model.gltf",
 "modern_arm_chair_01":"res://assets/teea008_review/decor_bank/modern_arm_chair_01/model.gltf",
 "gallinera_chair":"res://assets/teea008_review/decor_bank/gallinera_chair/model.gltf",
 "painted_wooden_chair_02":"res://assets/teea008_review/decor_bank/painted_wooden_chair_02/model.gltf",
 "blendkit_sofa":"res://assets/decor_bank/blendkit_sofa/model.gltf"
}
func _run()->void:
 for asset in TARGETS:
  var p:Dictionary={"path":TARGETS[asset],"scale":1.0,"yaw":0.0}
  var bounds:Dictionary=review.measured_bounds(p.path,0)
  var b:AABB=bounds.bounds
  var g:=_geometry(p)
  print("I91_CHAIR ",asset," bbox=",b," triangles=",g.get("triangles",[]).size()/3)
  if g.is_empty():continue
  for iz in range(11):
   var row:Array=[]
   for ix in range(11):
    var x:float=b.position.x+b.size.x*(.05+.09*ix)
    var z:float=b.position.z+b.size.z*(.05+.09*iz)
    var hits:=_hits(g,Vector2(x,z))
    var top:float=float(hits[-1].y)-b.position.y if not hits.is_empty() else -1.0
    row.append("%5.2f"%top)
   print("z=","%.3f"%(b.position.z+b.size.z*(.05+.09*iz))," "," ".join(row))
 print("I91_CHAIR_PLANE_PROBE_COMPLETE")
 quit(0)
