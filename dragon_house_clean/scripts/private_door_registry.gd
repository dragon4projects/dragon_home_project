extends RefCounted
## Public private-door metadata only. Never scans private folders.
const DEFAULT_PATH := "res://data/private_doors_v1.json"
const NOTE_ROOT := "res://data/door_notes/"
const LOCAL_ROOT := "user://house_content/door_notes/"
const LOCAL_MANIFEST := "user://house_content/door_notes_manifest.json"
# Exact hashes of the five previously verified and mapped local originals.
const LEGACY_VERIFIED := {
	"RES_03":"69a4f3f2f2a6f53cb1e7d4354ae223549a742c9249a3b5382379a3a237332b96",
	"RES_04":"7f93317d2220b4ae0fe1f826478accee311f9980b4a6606cd7817b7b893175ba",
	"RES_07":"558f08f43178292332f4d5e00b2b29882f48eadd442d82550b2852cf49bb2991",
	"RES_08":"5dce8370ed017dd3ddd63ff2d6ac6f77277eb469740466c5b78508ed850fe66b",
	"RES_20":"ca5d890a3fa07bc2d892bca1fd49d480a69705ba5547663e63f8bd33cb6b5442"
}
var doors:Dictionary={}
var verified_local:Dictionary={}
var last_error:=""

func initialize(path:String=DEFAULT_PATH)->bool:
	doors.clear()
	verified_local.clear()
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
	var validated:Dictionary={}
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
		validated[str(owner_id)]=entry.duplicate(true)
	doors=validated
	_load_local_manifest()
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

func _valid_resident_id(id:String)->bool:
	if not id.begins_with("RES_"):return false
	var suffix:=id.substr(4)
	return suffix.length()==2 and suffix.is_valid_int() and int(suffix)>0 and suffix==("%02d"%int(suffix))

func _valid_digest(digest:String)->bool:
	if digest.length()!=64:return false
	for c in digest:
		if not c in "0123456789abcdef":return false
	return true

func _load_local_manifest()->void:
	# A local install of previously verified bytes remains backwards compatible.
	# Additional/revised notes require an explicit local owner-approved binding.
	verified_local=LEGACY_VERIFIED.duplicate()
	var file:=FileAccess.open(LOCAL_MANIFEST,FileAccess.READ)
	if file==null:return
	var parsed=JSON.parse_string(file.get_as_text())
	if typeof(parsed)!=TYPE_DICTIONARY or int(parsed.get("schema",0))!=1:return
	var entries=parsed.get("entries",{})
	if typeof(entries)!=TYPE_DICTIONARY:return
	for id in entries:
		if not _valid_resident_id(str(id)) or typeof(entries[id])!=TYPE_DICTIONARY:continue
		var entry:Dictionary=entries[id]
		# Explicit revocation suppresses even a legacy/bundled entry.
		if entry.get("display_authorized",null)==false:
			verified_local[str(id)]=""
			continue
		if entry.get("display_authorized",null)!=true:continue
		var digest:=str(entry.get("sha256","")).to_lower()
		if not _valid_digest(digest) or str(entry.get("provenance","")).strip_edges()=="":continue
		verified_local[str(id)]=digest

func _local_note_path(owner_id:String)->String:
	var digest:String=str(verified_local.get(owner_id,""))
	if not _valid_resident_id(owner_id) or not _valid_digest(digest):return ""
	# Use a fixed per-resident path; never accept a manifest-provided path.
	for filename in ["00_ДВЕРЬ.md","00_дверь.md"]:
		var path:String=LOCAL_ROOT+owner_id+"/"+filename
		if FileAccess.file_exists(path) and FileAccess.get_sha256(path)==digest:return path
	return ""

func _public_note_path(owner_id:String)->String:
	if verified_local.has(owner_id) and str(verified_local[owner_id])=="":return ""
	var local:=_local_note_path(owner_id)
	if local!="":return local
	var entry:Dictionary=doors.get(owner_id,{})
	var path:String=str(entry.get("note_path",""))
	if bool(entry.get("owner_public_note",false)) and path.begins_with(NOTE_ROOT) and FileAccess.file_exists(path):return path
	return ""

func has_public_note(owner_id:String)->bool:
	return _public_note_path(owner_id)!=""

func note_text(owner_id:String)->String:
	var path:=_public_note_path(owner_id)
	if path=="":return ""
	var f:=FileAccess.open(path,FileAccess.READ)
	return "" if f==null else f.get_as_text()
