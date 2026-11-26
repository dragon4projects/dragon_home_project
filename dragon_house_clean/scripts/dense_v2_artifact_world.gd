extends RefCounted
## QA world adapter. The event projection is the only occupancy authority.
## No separate mutable save or reservation journal.
const REG=preload("res://scripts/dense_v2_artifact_grid_registry.gd")
const CELL=preload("res://scripts/artifact_cell_grid.gd")
const PREFIX="DG:"
var registry=REG.new()
var room_id:String=""
var slots:Dictionary={}
var error:String=""

func initialize(id:String)->bool:
 if id=="" or not registry.initialize():return false
 room_id=id
 slots.clear()
 for grid_id in registry.supports:
  var row:Dictionary=registry.supports[grid_id]
  var grid=registry.grids[grid_id]
  for size in ["S","M","L"]:
   for turn in ([false,true] if size=="L" else [false]):
    for z in range(grid.rows):
     for x in range(grid.columns):
      var at:=Vector2i(x,z)
      if not registry._fits(grid_id,size,at,turn):continue
      var shape:Vector2i=CELL.SHAPES[size]
      if turn:shape=Vector2i(shape.y,shape.x)
      var sid:String=PREFIX+grid_id+":"+size+":"+str(x)+":"+str(z)+":"+str(int(turn))
      var origin:Array=row.origin
      var pitch:float=float(row.pitch)
      var xyz:Array=[float(origin[0])+(x+shape.x*.5)*pitch,float(origin[1]),float(origin[2])+(z+shape.y*.5)*pitch]
      var dims:Vector3=registry.sizes[size]
      slots[sid]={"id":sid,"grid_id":grid_id,"size":size,"at":at,"turn":turn,"xyz":xyz,"dimensions":[dims.x,dims.y,dims.z],"unscaled_dimensions":[dims.x,dims.y,dims.z],"instance_xyz":xyz,"furniture_id":row.host,"approach":row.approach,"physical_grid":true,"cells":grid.cells_for(size,at,turn)}
 return not slots.is_empty()

func size_for(obj:Dictionary)->String:return str(obj.get("artifact_size","S"))

func choices()->Array:
 var out:Array=slots.values()
 out.sort_custom(func(a,b):return str(a.id)<str(b.id))
 return out

func validate_projection(projection:Dictionary)->bool:
 error=""
 var used:Dictionary={}
 for id in projection:
  var obj:Dictionary=projection[id]
  if obj.has("artifact_size") and (not registry.sizes.has(size_for(obj)) or (size_for(obj)!="S" and (obj.get("object_class","")=="small_artifact" or bool(obj.get("ambient_pickup_allowed",false))))):
   error="Invalid artifact size or carry policy: "+str(id);return false
  for prefix in ["home","current"]:
   var sid:String=str(obj.get(prefix+"_support_id",""))
   if not sid.begins_with(PREFIX):continue
   var slot:Dictionary=slots.get(sid,{})
   if slot.is_empty() or str(obj.get(prefix+"_room_id",""))!=room_id or obj.get("viewer_category","")!="artifacts" or obj.get("display_mode","")=="wall" or size_for(obj)!=slot.size:
    error="Invalid artifact grid support or size: "+str(id);return false
   if prefix=="current" and (obj.get("current_holder_id","")!="" or obj.get("state","")!="PLACED"):
    error="Held/hidden artifact has grid support: "+str(id);return false
   if slot.size!="S" and (obj.get("object_class","")=="small_artifact" or bool(obj.get("ambient_pickup_allowed",false))):
    error="Only S artifacts may be ambient-carried";return false
   var anchor:Array=obj.get(prefix+"_anchor",[])
   if anchor.size()!=2 or Vector2(float(anchor[0]),float(anchor[1])).distance_to(Vector2(float(slot.xyz[0]),float(slot.xyz[2])))>.0001:
    error="Artifact grid anchor mismatch: "+str(id);return false
   for cell in slot.cells:
    var key:String=str(slot.grid_id)+":"+str(cell)
    # Same object can reserve its home and occupy exactly that same slot.
    if used.has(key) and used[key]!=[id,sid]:
     error="Artifact grid cell conflict: "+str(id);return false
    used[key]=[id,sid]
 return true

func available(projection:Dictionary,id:String,sid:String)->bool:
 var slot:Dictionary=slots.get(sid,{})
 if slot.is_empty():return false
 var candidate:Dictionary=projection.duplicate(true)
 var obj:Dictionary=candidate.get(id,{"viewer_category":"artifacts"})
 obj["home_room_id"]=room_id
 obj["current_room_id"]=room_id
 obj["home_support_id"]=sid
 obj["current_support_id"]=sid
 obj["home_anchor"]=[slot.xyz[0],slot.xyz[2]]
 obj["current_anchor"]=obj.home_anchor.duplicate()
 obj["current_holder_id"]=""
 obj["state"]="PLACED"
 candidate[id]=obj
 return validate_projection(candidate)

func free_visual_slots(projection:Dictionary)->Array:
 # Occupied or reserved cells are never covered by empty visual holders.
 var occupied:Dictionary={}
 for obj in projection.values():
  for prefix in ["home","current"]:
   var slot:Dictionary=slots.get(str(obj.get(prefix+"_support_id","")),{})
   if slot.is_empty():continue
   for cell in slot.cells:occupied[str(slot.grid_id)+":"+str(cell)]=true
 var result:Array=[]
 # Show a mixed empty layout only in fully unused grids. A partially used
 # grid shows small empty holders on individual remaining cells.
 for grid_id in registry.supports:
  var grid=registry.grids[grid_id]
  var empty:=true
  for z in range(grid.rows):
   for x in range(grid.columns):
    if occupied.has(str(grid_id)+":"+str(Vector2i(x,z))):empty=false
  var pattern:Array=[]
  if empty and registry.supports.keys().find(grid_id)%2==0:
   pattern=[["L",0,0,grid.rows==3]]
  elif empty:
   pattern=[["M",0,0,false],["S",0,2,false],["S",1,2,false]] if grid.rows==3 else [["M",0,0,false],["S",2,0,false],["S",2,1,false]]
  else:
   for z in range(grid.rows):
    for x in range(grid.columns):
     if not occupied.has(str(grid_id)+":"+str(Vector2i(x,z))):pattern.append(["S",x,z,false])
  for a in pattern:
   var sid:String=PREFIX+grid_id+":"+str(a[0])+":"+str(a[1])+":"+str(a[2])+":"+str(int(a[3]))
   if slots.has(sid):result.append(slots[sid])
 return result
