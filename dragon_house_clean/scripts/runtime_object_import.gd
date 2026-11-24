extends RefCounted
## Explicit local owner import. No new store: registration is event-backed.
const CATEGORIES := ["artifacts","paintings","posters","cups"]
const LIMIT_BYTES := 16777216
const LIMIT_IMAGE := 4096

func _fail(reason:String, added:int=0)->Dictionary:
	return {"ok":false,"error":reason,"added":added}

func import_file(world,path:String)->Dictionary:
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>LIMIT_BYTES:
		return _fail("unreadable/oversized manifest")
	var parsed=JSON.parse_string(file.get_as_text())
	if typeof(parsed)!=TYPE_DICTIONARY:
		return _fail("manifest must be a JSON object")
	var seen:Dictionary={}
	var pending:Array=[]
	var has_media:bool=parsed.has("books") or parsed.has("films") or parsed.has("tracks") or parsed.has("audio")
	var has_objects:=false
	for category in CATEGORIES:
		if not parsed.has(category):
			continue
		has_objects=true
		var records=parsed[category]
		if typeof(records)!=TYPE_ARRAY:
			return _fail(category+" must be an array")
		for raw in records:
			if typeof(raw)!=TYPE_DICTIONARY:
				return _fail("object entry must be a dictionary")
			var row:Dictionary=raw
			var id:String=str(row.get("id",""))
			var title:String=str(row.get("title",row.get("display_name",""))).strip_edges()
			if id=="" or id.length()>100 or not id.is_valid_filename() or id.contains(" ") or title=="" or seen.has(id) or not world.physical_object(id).is_empty():
				return _fail("empty/invalid/duplicate object id: "+id)
			seen[id]=true
			var room_id:String=str(row.get("home_room_id",""))
			var room:Dictionary=world.room_by_id(room_id)
			if not world.public_cutaway_allowed(room) or str(room.get("type",""))=="lift":
				return _fail("public non-lift room required: "+id)
			var wall:bool=category in ["paintings","posters"]
			var anchor=row.get("home_anchor",[])
			if typeof(anchor)!=TYPE_ARRAY or anchor.size()!=(3 if wall else 2):
				return _fail("home_anchor requires [x,y,z] for wall, [x,z] otherwise: "+id)
			for v in anchor:
				if typeof(v) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(v)):
					return _fail("invalid anchor: "+id)
			var x:float=float(anchor[0])
			var z:float=float(anchor[2] if wall else anchor[1])
			if not world.room_contains_local(room,Vector2(x,z),0.16):
				return _fail("anchor outside room: "+id)
			if wall and (absf(z+1.52)>0.01 or float(anchor[1])<0.65 or float(anchor[1])>2.8 or absf(x)>world.room_space.half_width(room)-0.60):
				return _fail("wall must use z=-1.52, y=0.65..2.8, edge margin 0.60: "+id)
			var preview:String=str(row.get("preview_path",""))
			# Only explicitly named project/user resources or a sibling image
			# of the selected manifest. Never follow arbitrary absolute paths.
			var image:Image=null
			if preview.begins_with("res://") or preview.begins_with("user://"):
				if preview.contains(".."):
					return _fail("unsafe preview path: "+id)
				if preview.begins_with("res://") and ResourceLoader.exists(preview,"Texture2D"):
					var texture:=ResourceLoader.load(preview,"Texture2D") as Texture2D
					if texture!=null:
						image=texture.get_image()
			elif preview.is_valid_filename() and not preview.contains(".."):
				preview=path.get_base_dir().path_join(preview)
			else:
				return _fail("preview must be a sibling image or project/user resource: "+id)
			if image==null:
				var source:=FileAccess.open(preview,FileAccess.READ)
				if source==null or source.get_length()>LIMIT_BYTES or preview.get_extension().to_lower() not in ["png","jpg","jpeg","webp"]:
					return _fail("unreadable/unsupported preview: "+id)
				image=Image.load_from_file(preview)
			if image==null or image.is_empty() or image.get_width()>LIMIT_IMAGE or image.get_height()>LIMIT_IMAGE:
				return _fail("invalid/oversized image: "+id)
			var height:float=float(row.get("display_world_height",0.8 if wall else 0.3))
			if not is_finite(height) or height<0.05 or height>2.5:
				return _fail("invalid display height: "+id)
			var small:bool=category=="artifacts" and str(row.get("object_class","display_object"))=="small_artifact"
			var metadata:Dictionary={"description":str(row.get("description","")),"viewer_category":category,"object_class":"small_artifact" if small else "display_object","home_anchor":anchor.duplicate(),"display_mode":"wall" if wall else "","display_world_height":height,"reset_eligible":not wall}
			if wall:
				metadata["display_anchor"]=anchor.duplicate()
				metadata["interaction_point"]=[x,z+0.3]
				metadata["interaction_station_id"]="WALL_"+id
			pending.append({"id":id,"title":title,"room":room_id,"image":image,"metadata":metadata,"wall":wall,"small":small})
	if not has_objects and not has_media:
		return _fail("no recognized content categories")
	var added:=0
	if not pending.is_empty() and DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://imported_content"))!=OK:
		return _fail("cannot create imported_content")
	for entry in pending:
		var id:String=entry["id"]
		var target:String="user://imported_content/"+id.sha256_text()+".png"
		var image:Image=entry["image"]
		if image.save_png(target)!=OK:
			return _fail("could not persist preview: "+id,added)
		var metadata:Dictionary=entry["metadata"]
		metadata["preview_path"]=target
		var wall:bool=entry["wall"]
		var small:bool=entry["small"]
		if not world.register_physical_object(id,entry["title"],"",entry["room"],not wall,not wall,small,small,not small,metadata):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
			return _fail("event gate rejected registration: "+id,added)
		added+=1
	if added>0 and not world.save_world():
		return _fail("objects registered; snapshot save failed",added)
	return {"ok":true,"added":added,"has_media":has_media}
