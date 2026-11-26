extends RefCounted
## Owner rule: a large holder consumes 6 cells, medium 4, small 1.
## A cell is an occupancy unit on one continuous, measured support.
## Never merge cells across shelf dividers or across different tables.
const COST={"S":1,"M":4,"L":6}
const SHAPES={"S":Vector2i(1,1),"M":Vector2i(2,2),"L":Vector2i(3,2)}
var columns:int
var rows:int
var occupied:Dictionary={}
var allocations:Dictionary={}

func _init(w:int=3,d:int=2)->void:
 columns=maxi(0,w)
 rows=maxi(0,d)

func cells_for(size:String,at:Vector2i,turn:bool=false)->Array:
 if not SHAPES.has(size):return []
 var shape:Vector2i=SHAPES[size]
 if turn:shape=Vector2i(shape.y,shape.x)
 if at.x<0 or at.y<0 or at.x+shape.x>columns or at.y+shape.y>rows:return []
 var out:Array=[]
 for z in range(at.y,at.y+shape.y):
  for x in range(at.x,at.x+shape.x):out.append(Vector2i(x,z))
 return out

func reserve(id:String,size:String,at:Vector2i,turn:bool=false)->bool:
 if id=="" or allocations.has(id):return false
 var cells:Array=cells_for(size,at,turn)
 if cells.is_empty():return false
 for p in cells:
  if occupied.has(p):return false
 for p in cells:occupied[p]=id
 allocations[id]={"size":size,"at":at,"turn":turn,"cells":cells}
 return true

func release(id:String)->bool:
 if not allocations.has(id):return false
 for p in allocations[id].cells:occupied.erase(p)
 allocations.erase(id)
 return true

func replace(old_id:String,replacements:Array)->bool:
 # Atomic replacement: no destructive partial operation.
 if not allocations.has(old_id):return false
 var previous:Dictionary=allocations.duplicate(true)
 var occupied_before:Dictionary=occupied.duplicate(true)
 var allowed:Array=allocations[old_id].cells.duplicate()
 release(old_id)
 for entry in replacements:
  var cells:Array=cells_for(str(entry.get("size","")),entry.get("at",Vector2i(-1,-1)),bool(entry.get("turn",false)))
  if cells.is_empty() or not cells.all(func(p):return allowed.has(p)) or not reserve(str(entry.get("id","")),str(entry.get("size","")),entry.get("at",Vector2i(-1,-1)),bool(entry.get("turn",false))):
   allocations=previous;occupied=occupied_before;return false
 return true

func free_cells()->int:return columns*rows-occupied.size()

func snapshot()->Dictionary:
 var records:Array=[]
 for id in allocations:
  var a:Dictionary=allocations[id]
  records.append({"id":id,"size":a.size,"at":[a.at.x,a.at.y],"turn":a.turn})
 return {"columns":columns,"rows":rows,"allocations":records}

func restore(doc:Dictionary)->bool:
 if int(doc.get("columns",-1))!=columns or int(doc.get("rows",-1))!=rows:return false
 var old_a:Dictionary=allocations.duplicate(true);var old_o:Dictionary=occupied.duplicate(true)
 allocations.clear();occupied.clear()
 for row in doc.get("allocations",[]):
  var at:Array=row.get("at",[])
  if at.size()!=2 or not reserve(str(row.get("id","")),str(row.get("size","")),Vector2i(int(at[0]),int(at[1])),bool(row.get("turn",false))):
   allocations=old_a;occupied=old_o;return false
 return true
