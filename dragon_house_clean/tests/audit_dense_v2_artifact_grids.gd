extends "res://tests/audit_dense_v2_support_surfaces.gd"
## Physical grid candidates on real gallery furniture. No world mutation.
const NAV=preload("res://scripts/teea008_navigation.gd")
const GRID=preload("res://scripts/artifact_cell_grid.gd")
const PITCH:=.26
const GAP:=.012
const MODELS={"S":"res://assets/decor_bank/artifact_glass_cube_s/model.gltf","M":"res://assets/decor_bank/artifact_glass_cube_m/model.gltf","L":"res://assets/decor_bank/artifact_glass_cube_l/model.gltf"}
const SERVICE_OR_ORB=["L1_gallery_F20","L1_gallery_F24","L1_gallery_F29"]
var cube_bounds:Dictionary={}
var candidates:Array=[]
var mount_count:=0
var nav=NAV.new()
var nav_room:Dictionary={}
var withheld:Array=[]

func _cube_box(size:String,at:Vector3)->AABB:
 var b:AABB=cube_bounds[size]
 return AABB(at-Vector3(b.size.x*.5,0,b.size.z*.5),b.size)

func _physical_clear(host:Dictionary,geom:Dictionary,box:AABB,occupied:Array)->bool:
 if box.end.y>2.98:return false
 var pivot:=_v(host.pivot)
 if occupied.any(func(o):return o.id!=host.id and box.grow(GAP).intersects(o.box)):return false
 var center:=box.get_center()
 center.y=box.position.y
 return _probe(geom,center-pivot,box.size) and _host_clear(geom,AABB(box.position-pivot,box.size))

func _layout_boxes(origin:Vector3,layout:Array,turn:bool)->Array:
 var boxes:Array=[]
 for a in layout:
  var at:Vector2i=a.at
  var shape:Vector2i=GRID.SHAPES[a.size]
  if a.get("turn",false):shape=Vector2i(shape.y,shape.x)
  var center:=origin+Vector3((at.x+shape.x*.5)*PITCH,0,(at.y+shape.y*.5)*PITCH)
  boxes.append({"id":a.id,"size":a.size,"box":_cube_box(a.size,center),"center":center})
 return boxes

func _try_grid(host:Dictionary,geom:Dictionary,origin:Vector3,turn:bool,occupied:Array)->Dictionary:
 var w:=2 if turn else 3
 var d:=3 if turn else 2
 var size:=Vector3(w*PITCH,.54+GAP,d*PITCH)
 var region:=AABB(origin,size)
 # The complete logical cell region must be one physical plane with
 # unobstructed clearance. This forbids bridging between shelf bays.
 if not _physical_clear(host,geom,region,occupied):return {}
 var grid=GRID.new(w,d)
 if not grid.reserve("large","L",Vector2i.ZERO,turn):return {}
 var large:Array=[{"id":"large","size":"L","at":Vector2i.ZERO,"turn":turn}]
 var replacement:Array=[{"id":"medium","size":"M","at":Vector2i.ZERO},{"id":"small_1","size":"S","at":Vector2i(0,2) if turn else Vector2i(2,0)},{"id":"small_2","size":"S","at":Vector2i(1,2) if turn else Vector2i(2,1)}]
 if not grid.replace("large",replacement) or grid.free_cells()!=0:return {}
 var large_boxes:=_layout_boxes(origin,large,turn)
 var small_boxes:=_layout_boxes(origin,replacement,turn)
 for layout in [large_boxes,small_boxes]:
  for i in range(layout.size()):
   var a:Dictionary=layout[i]
   if not region.encloses(a.box) or not _physical_clear(host,geom,a.box,occupied):return {}
   for j in range(i):
    if a.box.grow(GAP).intersects(layout[j].box):return {}
 var id:String="%s.grid.%d.%d.%d.%s"%[host.id,roundi(origin.x*1000),roundi(origin.y*1000),roundi(origin.z*1000),"T" if turn else "N"]
 var approach:=_approach(host,region)
 if not approach.is_finite():
  withheld.append(id)
  return {}
 return {"id":id,"host":host.id,"origin":_a(origin),"columns":w,"rows":d,"pitch":PITCH,"approach":[approach.x,approach.y],"bounds_min":_a(region.position),"bounds_max":_a(region.end),"large":_serialize(large_boxes),"replacement":_serialize(small_boxes),"status":"MEASURED_QA_CANDIDATE"}

# Front-face approach only; this does not certify a resident-specific
# reach animation or shelf opening orientation.
func _approach(host:Dictionary,region:AABB)->Vector2:
 var b:=_box(host)
 var c:=region.get_center()
 for dz in [.35,.45,.55,.65]:
  for dx in [0.0,-.1,.1,-.2,.2,-.3,.3]:
   var p:=Vector2(c.x+dx,b.end.z+dz)
   if p.distance_to(Vector2(c.x,c.z))>1.2:continue
   if nav.clear(nav_room,p) and not nav.path(nav_room,Vector2(-7.12,1.5),p).is_empty() and not nav.path(nav_room,Vector2(7.12,1.5),p).is_empty():return p
 return Vector2.INF

func _serialize(boxes:Array)->Array:
 var result:Array=[]
 for b in boxes:result.append({"id":b.id,"size":b.size,"center":_a(b.center),"bounds_min":_a(b.box.position),"bounds_max":_a(b.box.end)})
 return result

func _mount_verify(grid:Dictionary,mode:String)->bool:
 var parent:=Node3D.new()
 root.add_child(parent)
 var records:Array=[]
 for b in grid[mode]:
  var mesh_bounds:AABB=cube_bounds[b.size]
  var at:=_v(b.center)
  var center:=mesh_bounds.get_center()
  var pos:=at-Vector3(center.x,mesh_bounds.position.y,center.z)
  records.append({"id":b.id,"asset":"artifact_glass_cube_"+str(b.size).to_lower(),"path":MODELS[b.size],"role":"supported_decor","pivot":_a(pos),"scale":1.0,"yaw":0.0,"fits":true})
 var ok:bool=review.mount_review(parent,{"placements":records})==records.size()
 for record in records:
  var node:Node3D=parent.get_node_or_null(record.id)
  if node==null or node.find_children("*","MeshInstance3D",true,false).is_empty():ok=false
  else:mount_count+=1
 parent.free()
 return ok

func _run()->void:
 if not _self_test():quit(1);return
 for size in MODELS:
  var m:Dictionary=review.measured_bounds(MODELS[size],0.0)
  if m.is_empty():quit(2);return
  cube_bounds[size]=m.bounds
 var gallery:Dictionary={}
 var expected:=FileAccess.get_sha256(REVIEW.SOURCE)
 for i in range(3):
  var archive:=ZIPReader.new()
  if archive.open("res://data/interior_v2/dense_v2_compiled_%d.zip"%i)!=OK:quit(3);return
  var data=JSON.parse_string(archive.read_file("compiled.json").get_string_from_utf8())
  archive.close()
  if typeof(data)!=TYPE_DICTIONARY or data.source_sha256!=expected:quit(4);return
  if data.rooms.has("L1_gallery"):gallery=data.rooms.L1_gallery
 if gallery.is_empty():quit(5);return
 var row:=review.navigation_row(gallery,"artifact",3)
 nav_room={"type":"artifact","size_modules":3,"depth7":true,"dense_v2_layout":row.variant_id}
 nav.configure({row.variant_id:row})
 var occupied:Array=[]
 for p in gallery.placements:
  if p.get("fits",false) and p.has("bounds_min"):occupied.append({"id":p.id,"box":_box(p)})
  # Never use a reserved functional slot without explicit migration.
  for slot in p.get("support_slots",[]):
   if slot.get("room_xyz",[]).size()!=3 or slot.get("max_dimensions_m",[]).size()!=3:continue
   var s:=_v(slot.max_dimensions_m)
   if absf(fposmod(float(p.yaw),180.0)-90.0)<.01:s=Vector3(s.z,s.y,s.x)
   if minf(s.x,minf(s.y,s.z))<=0:continue
   var at:=_v(slot.room_xyz)
   occupied.append({"id":str(slot.room_slot_id),"box":AABB(at-Vector3(s.x*.5,0,s.z*.5),s)})
 for host in gallery.placements:
  if host.get("role","")!="floor" or host.id in SERVICE_OR_ORB:continue
  var asset:String=host.asset.to_lower()
  if not ["table","shelf","shelv","rack","cabinet"].any(func(x):return asset.contains(x)):continue
  var geom:=_geometry(host)
  if geom.is_empty():continue
  var box:=_box(host)
  var pivot:=_v(host.pivot)
  for turn in [false,true]:
   var w:=2 if turn else 3
   var d:=3 if turn else 2
   var nx:=floori((box.size.x-w*PITCH)/.10)
   var nz:=floori((box.size.z-d*PITCH)/.10)
   for ix in range(nx+1):
    for iz in range(nz+1):
     var x:float=box.position.x+.01+ix*.10
     var z:float=box.position.z+.01+iz*.10
     var q:=Vector2(x+w*PITCH*.5-pivot.x,z+d*PITCH*.5-pivot.z)
     var last:float=-INF
     for hit in _hits(geom,q):
      var y:float=float(hit.y)+pivot.y
      if not hit.flat or y<.18 or y-last<PLANE_TOL:continue
      last=y
      var grid:=_try_grid(host,geom,Vector3(x,y,z),turn,occupied)
      if grid.is_empty():continue
      if not _mount_verify(grid,"large") or not _mount_verify(grid,"replacement"):quit(6);return
      candidates.append(grid)
      occupied.append({"id":grid.id,"box":AABB(_v(grid.bounds_min),_v(grid.bounds_max)-_v(grid.bounds_min))})
 var dims:Dictionary={}
 for k in cube_bounds:dims[k]=_a(cube_bounds[k].size)
 var f:=FileAccess.open("user://dense_v2_artifact_grids.json",FileAccess.WRITE)
 if f==null:quit(7);return
 f.store_string(JSON.stringify({"schema":1,"source_sha256":expected,"room_key":"L1_gallery","model_dimensions_m":dims,"status":"MEASURED_QA_CANDIDATES_ONLY","grids":candidates,"withheld_approaches":withheld},"  "))
 f.close()
 print("ARTIFACT_GRID_GEOMETRY grids=",candidates.size()," cells=",candidates.size()*6," withheld_approaches=",withheld.size()," mounted_models=",mount_count," dims=",dims)
 quit(0 if not candidates.is_empty() else 8)
