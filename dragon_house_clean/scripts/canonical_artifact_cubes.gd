extends RefCounted
## Explicit source-manifest cube identity; no inferred identities from pictures.
## This first pass uses SMALL only where the historical size is unresolved.
## MEDIUM/LARGE grid packing is deliberately not faked with a single small slot.
const SOURCE="res://assets/manifests/artifact_master_sources_zna004.json"
const LOCAL_ROOT="user://house_content/artifact_masters/"
var world
var nav
var rows:Dictionary={}
var object_to_source:Dictionary={}
var provisional_size_m:=0.20

func setup(model,navigation)->void:
	world=model
	nav=navigation
	rows.clear()
	object_to_source.clear()
	var file:=FileAccess.open(SOURCE,FileAccess.READ)
	if file==null:return
	var doc=JSON.parse_string(file.get_as_text())
	if typeof(doc)!=TYPE_DICTIONARY:return
	for row in doc.get("entries",[]):
		var normalized:String=str(row["normalized_id"])
		rows[normalized]=row
		var chosen:String=normalized
		var legacy=row.get("current_media_content_id")
		if legacy!=null and str(legacy)!="":
			chosen=str(legacy)
		# Older local save may already have the normalized ID. Prefer the
		# existing record rather than creating a duplicate of it.
		if not world.physical_object(normalized).is_empty():chosen=normalized
		if normalized=="ARTEFACT_006_CUBE_LETTERS_BEFORE_SLEEP" and not world.physical_object("CUBE_LETTERS").is_empty():
			chosen="CUBE_LETTERS"
		if world.physical_object(chosen).is_empty():
			for obj in world.objects.values():
				if str(obj.get("display_name",""))==str(row.get("title","")):
					chosen=str(obj["id"])
					break
		object_to_source[chosen]=normalized

func is_cube(id:String)->bool:
	return object_to_source.has(id)

func row_for(id:String)->Dictionary:
	return rows.get(str(object_to_source.get(id,"")),{})

func master_path(id:String)->String:
	var row:=row_for(id)
	if row.is_empty():return ""
	var local:String=LOCAL_ROOT+str(row["normalized_id"])+".png"
	var packaged:String="res://"+str(row.get("repo_source_target",""))
	for path in [local,packaged]:
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path)==str(row["source_sha256"]):
			return path
	return ""

func title(id:String)->String:
	var row:=row_for(id)
	return str(row.get("title","Артефакт"))

func slot_available(room:Dictionary,slot:Dictionary,id:String)->bool:
	var dims:Array=slot.get("unscaled_dimensions",slot.get("dimensions",[]))
	if dims.size()!=3:return false
	for axis in range(3):
		if float(dims[axis])+0.00001<provisional_size_m:return false
	var xyz:Array=slot["xyz"]
	for other in world.objects.values():
		if str(other.get("id",""))==id:continue
		if str(other.get("home_room_id",""))==str(room["id"]) and str(other.get("home_support_id",""))==str(slot["id"]):return false
		if str(other.get("current_room_id",""))==str(room["id"]) and str(other.get("current_support_id",""))==str(slot["id"]):return false
		# A home from a legacy save may not yet have a slot ID. Do not
		# overwrite another visible object's position in that same opening.
		if str(other.get("current_room_id",""))==str(room["id"]) and str(other.get("current_holder_id",""))=="" and str(other.get("display_mode",""))!="wall" and str(other.get("current_support_id",""))=="":
			var p:Array=other.get("current_anchor",[])
			if p.size()==2 and Vector2(float(p[0]),float(p[1])).distance_to(Vector2(float(xyz[0]),float(xyz[2])))<0.12:return false
	return true

func pick_slot(room:Dictionary,id:String,near:Vector2=Vector2.INF)->Dictionary:
	var options:Array=[]
	if room.is_empty() or not world.public_cutaway_allowed(room):return {}
	for slot in nav.artifact_slots(room):
		if slot_available(room,slot,id):options.append(slot)
	if options.is_empty():return {}
	if near.is_finite():
		options.sort_custom(func(a,b):
			var p:Array=a["xyz"]
			var q:Array=b["xyz"]
			return near.distance_squared_to(Vector2(p[0],p[2]))<near.distance_squared_to(Vector2(q[0],q[2])))
	return options[0]

func assign_at(id:String,room:Dictionary,slot:Dictionary)->bool:
	if not is_cube(id) or room.is_empty() or slot.is_empty() or not slot_available(room,slot,id):return false
	var p:Array=slot["xyz"]
	return world.assign_physical_object_home(id,str(room["id"]),Vector2(float(p[0]),float(p[2])),true,str(slot["id"]))

func install_initial(room:Dictionary)->int:
	if room.is_empty():return 0
	var placed:=0
	for id in object_to_source:
		var row:Dictionary=row_for(str(id))
		var obj:Dictionary=world.physical_object(str(id))
		# Do not steal an already assigned or actively carried object from
		# its owner's save. Unassigned gallery records may receive a shelf.
		if not obj.is_empty():
			if str(obj.get("current_holder_id",""))!="" or str(obj.get("state",""))=="STASHED":continue
			if str(obj.get("home_support_id",""))!="":continue
			if str(obj.get("home_room_id",""))!=str(room["id"]):continue
		var slot:=pick_slot(room,str(id))
		if slot.is_empty():continue
		var p:Array=slot["xyz"]
		if obj.is_empty():
			var metadata:Dictionary={"asset_id":str(row["normalized_id"]),"viewer_category":"artifacts","object_class":"display_object","display_mode":"cube","home_anchor":[p[0],p[2]],"display_world_height":provisional_size_m,"preview_path":"res://"+str(row["preview_target"]),"reset_eligible":true}
			if not world.register_physical_object(str(id),str(row["title"]),"",str(room["id"]),true,true,false,false,true,metadata):continue
		if assign_at(str(id),room,slot):placed+=1
	return placed
