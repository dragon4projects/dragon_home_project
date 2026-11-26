extends RefCounted
## Physical QA registry. Identity/occupancy independent of visual nodes.
## Not yet a durable WorldModel event adapter; do not use on owner saves.
const GRID=preload("res://scripts/artifact_cell_grid.gd")
const SOURCE="res://data/interior_v2/dense_v2_source.zip"
const MANIFEST="res://data/interior_v2/artifact_grids_qa.json"
const MODELS={"S":"res://assets/decor_bank/artifact_glass_cube_s/model.gltf","M":"res://assets/decor_bank/artifact_glass_cube_m/model.gltf","L":"res://assets/decor_bank/artifact_glass_cube_l/model.gltf"}
var supports:Dictionary={}
var grids:Dictionary={}
var sizes:Dictionary={}
var homes:Dictionary={}
var revision:String=""

func _vec(a:Array)->Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
func _arr(v:Vector3)->Array:return [v.x,v.y,v.z]

func initialize()->bool:
 var file:=FileAccess.open(MANIFEST,FileAccess.READ)
 if file==null:return false
 var doc=JSON.parse_string(file.get_as_text())
 if typeof(doc)!=TYPE_DICTIONARY or int(doc.get("schema",0))!=1 or doc.get("room_key","")!="L1_gallery":return false
 if doc.get("source_sha256","")!=FileAccess.get_sha256(SOURCE):return false
 for i in range(3):
  if doc.get("compiled_sha256",{}).get(str(i),"")!=FileAccess.get_sha256("res://data/interior_v2/dense_v2_compiled_%d.zip"%i):return false
 var staged:Dictionary={}
 var dimensions:Dictionary={}
 var boxes:Array=[]
 for size in MODELS:
  var a:Array=doc.get("model_dimensions_m",{}).get(size,[])
  if a.size()!=3:return false
  var v:=_vec(a)
  if not v.is_finite() or minf(v.x,minf(v.y,v.z))<=0:return false
  dimensions[size]=v
 for row in doc.get("grids",[]):
  var id:String=str(row.get("id",""))
  var cols:int=int(row.get("columns",0))
  var rows:int=int(row.get("rows",0))
  var pitch:float=float(row.get("pitch",0))
  if id=="" or staged.has(id) or not ((cols==3 and rows==2) or (cols==2 and rows==3)) or pitch<=0:return false
  if row.get("origin",[]).size()!=3 or row.get("bounds_min",[]).size()!=3 or row.get("bounds_max",[]).size()!=3 or row.get("approach",[]).size()!=2:return false
  var origin:=_vec(row.origin)
  var lo:=_vec(row.bounds_min)
  var hi:=_vec(row.bounds_max)
  if not origin.is_finite() or not lo.is_finite() or not hi.is_finite():return false
  var b:=AABB(lo,hi-lo)
  if not origin.is_equal_approx(lo) or absf(b.size.x-cols*pitch)>.001 or absf(b.size.z-rows*pitch)>.001 or b.size.y<dimensions.L.y:return false
  if boxes.any(func(other):return b.intersects(other)):return false
  boxes.append(b)
  staged[id]=row.duplicate(true)
 if staged.is_empty():return false
 supports=staged
 sizes=dimensions
 grids.clear()
 homes.clear()
 for id in supports:grids[id]=GRID.new(int(supports[id].columns),int(supports[id].rows))
 revision=FileAccess.get_sha256(MANIFEST)
 return true

func _fits(grid_id:String,size:String,at:Vector2i,turn:bool)->bool:
 if not grids.has(grid_id) or not sizes.has(size):return false
 var cells:Array=grids[grid_id].cells_for(size,at,turn)
 if cells.is_empty():return false
 var shape:Vector2i=GRID.SHAPES[size]
 if turn:shape=Vector2i(shape.y,shape.x)
 var row:Dictionary=supports[grid_id]
 var dims:Vector3=sizes[size]
 var height:float=float(row.bounds_max[1])-float(row.bounds_min[1])
 return dims.x+.012<=shape.x*float(row.pitch)+.00001 and dims.z+.012<=shape.y*float(row.pitch)+.00001 and dims.y<=height+.00001

func reserve(id:String,grid_id:String,size:String,at:Vector2i,turn:bool=false)->bool:
 if id=="" or homes.has(id) or not _fits(grid_id,size,at,turn):return false
 if not grids[grid_id].reserve(id,size,at,turn):return false
 homes[id]=grid_id
 return true

func release(id:String)->bool:
 if not homes.has(id):return false
 if not grids[homes[id]].release(id):return false
 homes.erase(id)
 return true

func move(id:String,target:String,at:Vector2i,turn:bool=false)->bool:
 if not homes.has(id):return false
 var old:String=homes[id]
 var record:Dictionary=grids[old].allocations[id].duplicate(true)
 if not _fits(target,record.size,at,turn):return false
 release(id)
 if reserve(id,target,record.size,at,turn):return true
 assert(reserve(id,old,record.size,record.at,record.turn))
 return false

func replace(id:String,replacements:Array)->bool:
 if not homes.has(id):return false
 var host:String=homes[id]
 var ids:Dictionary={}
 for entry in replacements:
  var next:String=str(entry.get("id",""))
  if next=="" or ids.has(next) or (homes.has(next) and next!=id):return false
  if not _fits(host,str(entry.get("size","")),entry.get("at",Vector2i(-1,-1)),bool(entry.get("turn",false))):return false
  ids[next]=true
 if not grids[host].replace(id,replacements):return false
 homes.erase(id)
 for next in ids:homes[next]=host
 return true

func placement(id:String)->Dictionary:
 if not homes.has(id):return {}
 var host:String=homes[id]
 var row:Dictionary=supports[host]
 var a:Dictionary=grids[host].allocations[id]
 var shape:Vector2i=GRID.SHAPES[a.size]
 if a.turn:shape=Vector2i(shape.y,shape.x)
 var at:Vector2i=a.at
 var pitch:float=float(row.pitch)
 var center:=_vec(row.origin)+Vector3((at.x+shape.x*.5)*pitch,0,(at.y+shape.y*.5)*pitch)
 var dims:Vector3=sizes[a.size]
 return {"id":id,"grid_id":host,"size":a.size,"path":MODELS[a.size],"center":_arr(center),"dimensions":_arr(dims),"approach":row.approach.duplicate(),"host":row.host}

func snapshot()->Dictionary:
 var records:Dictionary={}
 for id in grids:records[id]=grids[id].snapshot()
 return {"revision":revision,"grids":records}

func restore(doc:Dictionary)->bool:
 if revision=="" or doc.get("revision","")!=revision:return false
 var raw=doc.get("grids",{})
 if typeof(raw)!=TYPE_DICTIONARY or raw.size()!=supports.size():return false
 var staged:Dictionary={}
 var owners:Dictionary={}
 for id in supports:
  if not raw.has(id):return false
  var grid=GRID.new(int(supports[id].columns),int(supports[id].rows))
  if not grid.restore(raw[id]):return false
  for object_id in grid.allocations:
   var a:Dictionary=grid.allocations[object_id]
   if owners.has(object_id) or not _fits(id,a.size,a.at,a.turn):return false
   owners[object_id]=id
  staged[id]=grid
 grids=staged
 homes=owners
 return true
