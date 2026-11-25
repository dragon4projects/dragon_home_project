extends RefCounted
## Public private-door metadata only. Never scans private folders.
const DEFAULT_PATH := "res://data/private_doors_v1.json"
const NOTE_ROOT := "res://data/door_notes/"
var doors:Dictionary={}
var last_error:=""

func initialize(path:String=DEFAULT_PATH)->bool:
	doors.clear()
	last_error=""
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:
		last_error="Door registry missing"
		return false
	var parsed=JSON.parse_string(f.get_as_text())
	if typeof(parsed)!=TYPE_DICTIONARY or int(parsed.get("schema",0))!=1:
		last_error="Door registry schema invalid"
		return false
	var raw=parsed.get("doors",{})
	if typeof(raw)!=TYPE_DICTIONARY:
		last_error="Door registry doors must be object"
		return false
	for owner_id in raw:
		if not str(owner_id).begins_with("RES_") or typeof(raw[owner_id])!=TYPE_DICTIONARY:
			last_error="Invalid owner entry: "+str(owner_id)
			return false
		var entry:Dictionary=raw[owner_id]
		var note_path:String=str(entry.get("note_path",""))
		if note_path!="":
			if not bool(entry.get("owner_public_note",false)):
				last_error="Non-public note path forbidden: "+str(owner_id)
				return false
			if not note_path.begins_with(NOTE_ROOT) or note_path.contains("..") or note_path.contains("\\"):
				last_error="Unsafe public note path: "+note_path
				return false
		doors[str(owner_id)]=entry.duplicate(true)
	return true

func entry_for_owner(owner_id:String)->Dictionary:
	return (doors.get(owner_id,{}) as Dictionary).duplicate(true)

func _profile_name(owner_id:String,profiles:Array)->String:
	for p in profiles:
		if str(p.get("id",""))==owner_id:
			return str(p.get("display_name","")).strip_edges()
	return ""

func sign_text(owner_id:String,profiles:Array,debug:bool=false)->String:
	if owner_id=="":
		return "ЛИЧНОЕ"
	var entry:Dictionary=doors.get(owner_id,{})
	for key in ["chosen_name","title","handle","chat_label"]:
		var value:String=str(entry.get(key,"")).strip_edges()
		if value!="":
			return value
	var fallback:=_profile_name(owner_id,profiles)
	if fallback!="":
		return fallback
	return owner_id if debug else "ЛИЧНОЕ"

func _local_note_path(owner_id:String)->String:
	# Read only explicit, locally installed door-note files. Never scan other personal folders.
	if not owner_id in ["RES_03","RES_04","RES_07","RES_08","RES_20"]:return ""
	return "user://house_content/door_notes/"+owner_id+"/00_ДВЕРЬ.md"

func has_public_note(owner_id:String)->bool:
	var local:=_local_note_path(owner_id)
	if local!="" and FileAccess.file_exists(local):return true
	var entry:Dictionary=doors.get(owner_id,{})
	var path:String=str(entry.get("note_path",""))
	return bool(entry.get("owner_public_note",false)) and path.begins_with(NOTE_ROOT) and FileAccess.file_exists(path)

func note_text(owner_id:String)->String:
	if not has_public_note(owner_id):
		return ""
	var local:=_local_note_path(owner_id)
	var path:String=local if local!="" and FileAccess.file_exists(local) else str(doors.get(owner_id,{}).get("note_path",""))
	var f:=FileAccess.open(path,FileAccess.READ)
	return "" if f==null else f.get_as_text()
