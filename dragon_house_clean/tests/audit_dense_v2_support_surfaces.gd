extends SceneTree
## I85 read-only geometry audit. Run with Godot after imported models exist:
## godot --headless --path . --script tests/audit_dense_v2_support_surfaces.gd
## Does not rewrite compiled partitions or activate any placement.
const REVIEW=preload("res://scripts/dense_v2_review.gd")
const EPS:=0.00001
const PLANE_TOL:=0.012
const STEP:=0.025
const MAX_TRIANGLES:=200000
var cache:Dictionary={}
var audit:Dictionary={}
var probe_error:String=""

func _initialize()->void:
 call_deferred("_run")

func _collect(node:Node,xf:Transform3D,triangles:PackedVector3Array)->bool:
 if node is Node3D:
  if not node.visible:return true
  xf=xf*node.transform
 if node is MeshInstance3D and node.mesh!=null:
  var faces:PackedVector3Array=node.mesh.get_faces()
  if triangles.size()+faces.size()>MAX_TRIANGLES*3:return false
  for v in faces:triangles.append(xf*v)
 for child in node.get_children():
  if not _collect(child,xf,triangles):return false
 return true

func _geometry(p:Dictionary)->PackedVector3Array:
 var key:String=str(p.path)+"|"+str(p.scale)+"|"+str(p.yaw)
 if not cache.has(key):
  var scene:=ResourceLoader.load(str(p.path),"PackedScene") as PackedScene
  var triangles:=PackedVector3Array()
  if scene!=null:
   var root:=scene.instantiate()
   var xf:=Transform3D(Basis(Vector3.UP,deg_to_rad(float(p.yaw))).scaled(Vector3.ONE*float(p.scale)),Vector3.ZERO)
   if not _collect(root,xf,triangles):triangles.clear()
   root.free()
  cache[key]=triangles
 return cache[key]

func _v(a:Array)->Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
func _a(v:Vector3)->Array:return [v.x,v.y,v.z]
func _box(p:Dictionary)->AABB:
 var lo:=_v(p.bounds_min)
 return AABB(lo,_v(p.bounds_max)-lo)

# Each column intersects actual imported triangles, not merged mesh AABBs.
# A projected vertical triangle has no unique intersection with this ray.
# Such triangles are covered conservatively by neighbouring footprint
# probes, but the result is a sampled candidate, never clearance certification.
func _hits(tris:PackedVector3Array,q:Vector2)->Array:
 var hits:Array=[]
 for i in range(0,tris.size()-2,3):
  var a:=tris[i];var b:=tris[i+1];var c:=tris[i+2]
  var u:=Vector2(b.x-a.x,b.z-a.z)
  var v:=Vector2(c.x-a.x,c.z-a.z)
  var w:=q-Vector2(a.x,a.z)
  var det:=u.cross(v)
  if absf(det)<EPS:continue
  var t:=w.cross(v)/det
  var s:=u.cross(w)/det
  if t< -EPS or s< -EPS or t+s>1.0+EPS:continue
  var normal:Vector3=(b-a).cross(c-a).normalized()
  hits.append({"y":a.y+t*(b.y-a.y)+s*(c.y-a.y),"flat":absf(normal.y)>=.995})
 hits.sort_custom(func(a,b):return a.y<b.y)
 return hits

func _column_at(hits:Array,y:float,height:float)->bool:
 var supported:=false
 for hit in hits:
  var d:float=float(hit.y)-y
  if absf(d)<=PLANE_TOL and hit.flat:supported=true
  if d>PLANE_TOL and d<height+PLANE_TOL:return false
 return supported

# Sample the full footprint including edges. Using only the centre lets a
# mug balance on a rail or a large cube bridge a hole between shelf bays.
func _probe(tris:PackedVector3Array,center:Vector3,size:Vector3)->bool:
 if tris.is_empty() or not center.is_finite() or not size.is_finite() or minf(size.x,minf(size.y,size.z))<=0:return false
 var nx:=maxi(2,ceili(size.x/STEP))
 var nz:=maxi(2,ceili(size.z/STEP))
 # Fail closed on oversized or unexpectedly expensive candidates.
 if (nx+1)*(nz+1)>4096:return false
 for x in range(nx+1):
  for z in range(nz+1):
   var q:=Vector2(center.x+size.x*(float(x)/nx-.5),center.z+size.z*(float(z)/nz-.5))
   if not _column_at(_hits(tris,q),center.y,size.y):return false
 return true

func _quad(y:float,half:float)->PackedVector3Array:
 var a:=Vector3(-half,y,-half);var b:=Vector3(half,y,-half)
 var c:=Vector3(half,y,half);var d:=Vector3(-half,y,half)
 return PackedVector3Array([a,b,c,a,c,d])

func _self_test()->bool:
 var shelf:=_quad(0.4,.5)
 shelf.append_array(_quad(.9,.5))
 if not _probe(shelf,Vector3(0,.4,0),Vector3(.2,.3,.2)):return false
 if _probe(shelf,Vector3(0,.4,0),Vector3(.2,.6,.2)):return false
 if _probe(shelf,Vector3(.48,.4,0),Vector3(.2,.3,.2)):return false
 if _probe(shelf,Vector3(0,.5,0),Vector3(.2,.2,.2)):return false
 if not _probe(shelf,Vector3(0,.9,0),Vector3(.2,.3,.2)):return false
 return true

func _audit_room(room:Dictionary,source:Dictionary)->Dictionary:
 var result:Dictionary={"slots":[],"pending_hosts":[]}
 var by_id:Dictionary={}
 var known:Dictionary={}
 for p in room.placements:
  by_id[p.id]=p
 for item in room.pending:
  if item.get("role","")!="supported_decor":continue
  var host_id:String=str(item.get("support","")).get_slice(" | ",0)
  if not known.has(host_id):known[host_id]=[]
  known[host_id].append(item.id)
 for p in room.placements:
  if not p.get("fits",false) or not p.has("path") or not p.has("pivot"):continue
  var slots:Array=p.get("support_slots",[])
  if slots.is_empty() and not known.has(p.id):continue
  var triangles:=_geometry(p)
  var pivot:=_v(p.pivot)
  for slot in slots:
   var entry:Dictionary={"id":slot.get("room_slot_id",""),"host":p.id,"status":"UNMEASURED"}
   if slot.get("room_xyz",[]).size()==3 and slot.get("max_dimensions_m",[]).size()==3 and not triangles.is_empty():
    var size:=_v(slot.max_dimensions_m)
    # Template size follows its original axes; use current host orientation.
    if absf(fposmod(float(p.yaw),180.0)-90.0)<.01:size=Vector3(size.z,size.y,size.x)
    var at:=_v(slot.room_xyz)-pivot
    entry["size"]=_a(size)
    entry["status"]="SAMPLED_PLANE_AND_HEIGHT_PASS" if _probe(triangles,at,size) else "WITHHOLD_UNPROVEN_FOOTPRINT"
   result.slots.append(entry)
  if not known.has(p.id):continue
  var host:Dictionary={"id":p.id,"asset":p.asset,"unresolved_ids":known[p.id],"status":"GEOMETRY_UNAVAILABLE","sampled_surfaces":[]}
  if not triangles.is_empty():
   host.status="CANDIDATES_ONLY"
   var box:=_box(p)
   # Find multiple actual shelf elevations, including lower shelves.
   # This does not infer continuous bays from one AABB.
   for ix in range(1,5):
    for iz in range(1,5):
     var x:float=box.position.x+box.size.x*float(ix)/5.0
     var z:float=box.position.z+box.size.z*float(iz)/5.0
     var q:=Vector2(x-pivot.x,z-pivot.z)
     var last:float=-INF
     for hit in _hits(triangles,q):
      var y:float=float(hit.y)
      if not hit.flat or y-last<PLANE_TOL or y+pivot.y<.18:continue
      last=y
      var at:=Vector3(q.x,y,q.y)
      # A small independently sampled patch is only a seed for subsequent
      # prop-specific fit, wall orientation, occupancy and route checks.
      if _probe(triangles,at,Vector3(.10,.12,.10)):
       host.sampled_surfaces.append(_a(at+pivot))
  result.pending_hosts.append(host)
 for id in known:
  if not by_id.has(id):
   result.pending_hosts.append({"id":id,"unresolved_ids":known[id],"status":"HOST_ABSENT","sampled_surfaces":[]})
 return result

func _run()->void:
 if not _self_test():
  push_error("Synthetic shelf geometry regression failed");quit(1);return
 var rooms:Dictionary={}
 var expected:=FileAccess.get_sha256(REVIEW.SOURCE)
 for i in range(3):
  var zip:=ZIPReader.new()
  if zip.open("res://data/interior_v2/dense_v2_compiled_%d.zip"%i)!=OK:quit(2);return
  var part=JSON.parse_string(zip.read_file("compiled.json").get_string_from_utf8())
  zip.close()
  if typeof(part)!=TYPE_DICTIONARY or part.get("source_sha256","")!=expected:quit(3);return
  for key in part.get("rooms",{}):
   if rooms.has(key):quit(4);return
   rooms[key]=part.rooms[key]
 if rooms.size()!=19:quit(5);return
 var keys:Array=["L1_gallery","L0_workshop","L1_study","L2_library","L0_reading"]
 for key in keys:
  if not rooms.has(key):quit(6);return
  audit[key]=_audit_room(rooms[key],{})
  print("SUPPORT_AUDIT ",key," slots=",audit[key].slots.size()," pending_hosts=",audit[key].pending_hosts.size())
 var f:=FileAccess.open("user://dense_v2_support_surface_audit.json",FileAccess.WRITE)
 if f==null:quit(7);return
 f.store_string(JSON.stringify({"schema":1,"source_sha256":expected,"status":"SAMPLED_GEOMETRY_CANDIDATES_ONLY","rooms":audit},"  "))
 f.close()
 print("SUPPORT_AUDIT_WRITTEN ",ProjectSettings.globalize_path("user://dense_v2_support_surface_audit.json"))
 quit(0)
