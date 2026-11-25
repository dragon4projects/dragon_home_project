extends RefCounted
## Explicit owner authoring only. No per-frame scan or movement of saved homes.
const WALL_Z:=-1.52
const FRAME_PAD:=0.075
const GAP:=0.08

static func extent(height:float,aspect:float)->Vector2:
	return Vector2(height*aspect+FRAME_PAD*2.0,height+FRAME_PAD*2.0)

static func object_extent(object:Dictionary)->Vector2:
	var height:float=float(object.get("display_world_height",0.8))
	var path:String=str(object.get("preview_path",""))
	var aspect:=1.4
	if path.begins_with("res://") and ResourceLoader.exists(path,"Texture2D"):
		var texture:=ResourceLoader.load(path,"Texture2D") as Texture2D
		if texture!=null and texture.get_height()>0:
			aspect=float(texture.get_width())/float(texture.get_height())
	elif path.begins_with("user://") and FileAccess.file_exists(path):
		var image:=Image.load_from_file(path)
		if image!=null and image.get_height()>0:aspect=float(image.get_width())/float(image.get_height())
	return extent(height,aspect)

static func _rect(center:Vector2,size:Vector2)->Rect2:
	return Rect2(center-size*0.5,size)

static func _blocked(rect:Rect2,item:Dictionary)->bool:
	var lo:Array=item.get("bounds_min_m",[])
	var hi:Array=item.get("bounds_max_m",[])
	if lo.size()!=3 or hi.size()!=3:return false
	# Only rear-wall furniture/holders can obstruct a mounted frame.
	if float(lo[2])>-1.20:return false
	var other:=Rect2(Vector2(float(lo[0]),float(lo[1])),Vector2(float(hi[0])-float(lo[0]),float(hi[1])-float(lo[1])))
	return rect.intersects(other.grow(GAP))

static func valid(world,bank,navigation,room:Dictionary,center:Vector2,size:Vector2,ignore_id:String="",pending:Array=[])->bool:
	if not world.public_cutaway_allowed(room) or str(room.get("type",""))=="lift":return false
	if not center.is_finite() or not size.is_finite() or size.x<=0 or size.y<=0:return false
	if center.y<0.65 or center.y>2.8:return false
	var rect:=_rect(center,size)
	var half:float=world.room_space.half_width(room)
	if absf(center.x)>half-0.60 or rect.position.x< -half+0.24 or rect.end.x>half-0.24 or rect.position.y<0.28 or rect.end.y>3.02:return false
	var rid:String=str(room["id"])
	for object in world.objects.values():
		if str(object.get("id",""))==ignore_id or str(object.get("home_room_id",""))!=rid or str(object.get("display_mode",""))!="wall":continue
		var anchor:Array=object.get("display_anchor",[])
		if anchor.size()==3 and rect.intersects(_rect(Vector2(float(anchor[0]),float(anchor[1])),object_extent(object)).grow(GAP)):return false
	for reservation in pending:
		if str(reservation.get("room",""))==rid and rect.intersects((reservation["rect"] as Rect2).grow(GAP)):return false
	if bank!=null and navigation!=null and navigation.has_layout(room):
		var key:String=navigation.key(room)
		var row:Dictionary=navigation.layouts.get(key,{})
		for item in row.get("instances",[]):
			if _blocked(rect,item):return false
		for surface in bank.surfaces.values():
			if str(surface.get("room_variant",""))!=key:continue
			var holder:Dictionary=surface.get("holder_instance",{})
			if _blocked(rect,holder):return false
	return true

static func find_slot(world,bank,navigation,room:Dictionary,size:Vector2,pending:Array=[])->Array:
	# Search readable wall positions; never replace an occupied mount.
	var half:float=world.room_space.half_width(room)
	var columns:int=int(floor((half-0.60)/0.25))
	for y in [2.45,2.10,1.75,1.40,1.05,0.70]:
		for n in range(columns+1):
			for sign_x in ([1] if n==0 else [-1,1]):
				var center:=Vector2(float(n*sign_x)*0.25,float(y))
				if valid(world,bank,navigation,room,center,size,"",pending):
					return [center.x,center.y,WALL_Z]
	return []
