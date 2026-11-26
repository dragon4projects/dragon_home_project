extends SceneTree
const REVIEW=preload("res://scripts/dense_v2_review.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
 var review=REVIEW.new()
 var expected:=FileAccess.get_sha256(REVIEW.SOURCE)
 var total:=0
 var rooms:=0
 var ids:Dictionary={}
 for i in range(3):
  var archive:=ZIPReader.new()
  assert(archive.open("res://data/interior_v2/dense_v2_compiled_%d.zip"%i)==OK)
  var part=JSON.parse_string(archive.read_file("compiled.json").get_string_from_utf8())
  archive.close()
  assert(part.source_sha256==expected)
  assert(int(part.totals.supported)==103 and int(part.totals.pending)==538)
  for room in part.rooms.values():
   var records:Array=room.placements.filter(func(p):return p.get("review_status","")=="I85_TRIANGLE_PREFLIGHT_STATIC_DECOR")
   if records.is_empty():continue
   rooms+=1
   var parent:=Node3D.new()
   root.add_child(parent)
   assert(review.mount_review(parent,{"placements":records})==records.size())
   var by_id:Dictionary={}
   for p in room.placements:by_id[p.id]=p
   for p in records:
    assert(not ids.has(p.id) and by_id.has(p.support_host))
    ids[p.id]=true
    assert(not room.pending.any(func(x):return x.id==p.id))
    assert(p.asset!="potted_plant_04")
    var node:Node3D=parent.get_node_or_null(p.id)
    assert(node!=null and node.get_child_count()>0)
    assert(node.position.is_equal_approx(Vector3(float(p.pivot[0]),float(p.pivot[1]),float(p.pivot[2]))))
    assert(node.find_children("*","MeshInstance3D",true,false).size()>0)
    var measurement:Dictionary=review.measured_bounds(p.path,float(p.yaw))
    assert(not measurement.is_empty())
    var b:AABB=measurement.bounds
    var lo:=node.position+b.position*float(p.scale)
    var hi:=lo+b.size*float(p.scale)
    assert(lo.distance_to(Vector3(float(p.bounds_min[0]),float(p.bounds_min[1]),float(p.bounds_min[2])))<.001)
    assert(hi.distance_to(Vector3(float(p.bounds_max[0]),float(p.bounds_max[1]),float(p.bounds_max[2])))<.001)
    total+=1
   parent.free()
 assert(total==24 and rooms==5)
 print("DENSE_V2_STATIC_DECOR_PASS mounted=",total," rooms=",rooms," bounds_verified=true")
 quit(0)
