extends RefCounted
## I90: no ownership/wardrobe change. Add only missing directional seats.
## Existing I66 action and creature banks are authoritative if byte-identical.
const ROOT="res://data/asset_proposals/DH_SPRITE_20261126_COMPLETE/"
const SEATS=["SIT_SE","SIT_E","SIT_NE","SIT_N","SIT_NW","SIT_W","SIT_SW"]
const HUMAN_WARDROBES=["HOME","SHORT","CITY"]
const PROOF="res://data/integration_candidates/TEEA008_POSE_EXPORT_PROOF.json"
var last_error:String=""
var report:Dictionary={}

func read_json(path:String):
 var f:=FileAccess.open(path,FileAccess.READ)
 if f==null:return null
 return JSON.parse_string(f.get_as_text())

func _fail(reason:String)->bool:
 last_error=reason
 return false

func _safe_group(actor:String,wardrobe,state:String)->bool:
 if wardrobe==null:
  return (actor=="manjka" and state=="CHASE_RIGHT") or (actor=="npc_ai_magic_sphere" and state in ["HOVER_IDLE","HOVER_MOVE_E","HOVER_MOVE_W","HOVER_REST"])
 return str(wardrobe) in HUMAN_WARDROBES and (state in SEATS or (actor=="RES_07" and wardrobe=="HOME" and state in ["READ","DRINK","CARRY_USE","IDLE_NW_CORRECTED"]))

func install(bank)->bool:
 last_error=""
 report={}
 var doc=read_json(ROOT+"registry_delta.json")
 var records=read_json(ROOT+"frames.json")
 if typeof(doc)!=TYPE_DICTIONARY or int(doc.get("schema",0))!=1 or typeof(records)!=TYPE_ARRAY or records.size()!=204:
  return _fail("complete sprite metadata missing or invalid")
 var proof:Dictionary={}
 var raw_proof=read_json(PROOF)
 if typeof(raw_proof)==TYPE_DICTIONARY:proof=raw_proof.get("frames",{})
 var hashes:Dictionary={}
 for rec in records:
  var path:String=str(rec.get("path",""))
  var canvas:Array=rec.get("canvas",[])
  var digest:String=str(rec.get("sha256",""))
  if hashes.has(path) or digest.length()!=64 or canvas.size()!=2 or not path.begins_with("assets/") or not bank._real_image_bytes(path):
   return _fail("invalid or absent frame: "+path)
  if FileAccess.file_exists("res://"+path):
   if FileAccess.get_sha256("res://"+path)!=digest:return _fail("frame hash mismatch: "+path)
  elif proof.get("res://"+path,"")!=digest:return _fail("frame export proof missing: "+path)
  hashes[path]=rec
 var used:Dictionary={}
 var group_keys:Dictionary={}
 var pending:Array=[]
 var preserved:=0
 for u in doc.get("entries",[]):
  var actor:String=str(u.get("actor_id",""))
  var wardrobe=u.get("wardrobe")
  var state:String=str(u.get("state","")).to_upper()
  if not _safe_group(actor,wardrobe,state):return _fail("invalid sprite group")
  var key:String=actor+"|"+str(wardrobe)+"|"+state
  if group_keys.has(key):return _fail("duplicate sprite group "+key)
  group_keys[key]=true
  var states:Dictionary=bank.manifest.get("creatures",{}).get(actor,{}).get("states",{}) if wardrobe==null else bank.manifest.get("residents",{}).get(actor,{}).get("wardrobes",{}).get(str(wardrobe),{}).get("states",{})
  if states.is_empty():return _fail("unknown sprite bank "+key)
  var frames:Array=u.get("frames",[])
  if frames.size()!=(6 if state=="CHASE_RIGHT" else (4 if state.begins_with("HOVER_") or state=="DRINK" else 1)):
   return _fail("unexpected frame count "+key)
  for raw in frames:
   var path:String=bank._normalize_frame(raw)
   var safe:bool=bank._safe_creature_frame_path(actor,path) if wardrobe==null else bank._safe_frame_path(actor,str(wardrobe),path)
   var directory:String="assets/creatures/%s/%s/"%[actor,state.to_lower()] if wardrobe==null else bank._root(actor,str(wardrobe))+state+"/"
   if not safe or not path.begins_with(directory) or not hashes.has(path) or used.has(path):
    return _fail("incorrect bank/path "+path)
   var dims:Array=hashes[path].canvas
   if dims.size()!=2 or int(dims[0])!=(1024 if wardrobe==null else 512) or int(dims[1])!=(640 if wardrobe==null else 512):return _fail("incorrect canvas "+path)
   used[path]=true
  var prior:Dictionary=states.get(state,{})
  if prior.get("status","")=="PASS" and not prior.get("frames",[]).is_empty():
   var paths:Array=[]
   for raw in prior.frames:paths.append(bank._normalize_frame(raw))
   if paths!=frames:return _fail("refusing to replace approved or existing bank "+key)
   preserved+=1
   continue
  # Non-seating action/creature entries must have been handled by the I66
  # reviewed overlay (with its original action/hand evidence).
  if not state in SEATS:return _fail("earlier action/creature overlay unavailable: "+key)
  if not prior.get("frames",[]).is_empty():return _fail("refusing to replace partial nonempty bank "+key)
  var entry:Dictionary={"frames":frames.duplicate(),"frame_count":frames.size(),"fps":2,"status":"PASS","runtime_bound":false,"source_confidence":"I90 verified candidate image; chair fit separately gated","evidence":"data/asset_proposals/DH_SPRITE_20261126_COMPLETE/frames.json"}
  pending.append({"states":states,"state":state,"entry":entry})
 if used.size()!=204 or group_keys.size()!=184:return _fail("incomplete sprite coverage")
 for row in pending:row.states[row.state]=row.entry
 report={"frames":used.size(),"groups":group_keys.size(),"added":pending.size(),"preserved":preserved}
 return true

func install_poses(nav,bank)->int:
 var doc=read_json(ROOT+"pose_contacts.json")
 if typeof(doc)!=TYPE_DICTIONARY or doc.get("status","")!="CANDIDATE_CONTACT_ESTIMATES":return 0
 var count:=0
 for actor in doc.get("profiles",{}):
  var incoming:Dictionary=doc.profiles[actor]
  var existing:Dictionary=nav.pose_profiles.get(actor,{})
  # Retain existing outfit, existing frontal SIT and all prior verified
  # action/pose calibrations. Alternate wardrobe estimates remain archived.
  if existing.get("wardrobe")!=incoming.get("wardrobe") or existing.get("appearance_profile")!=incoming.get("appearance_profile"):continue
  for state in incoming.get("states",{}):
   if not state in SEATS or existing.get("states",{}).has(state):continue
   var p:Dictionary=incoming.states[state]
   var path:String=str(p.get("path",""))
   var frames:Array=bank._entry(actor,incoming.wardrobe,state).get("frames",[])
   var point:Array=p.get("contact_px",[])
   var box:Array=p.get("alpha_bbox",[])
   if frames.size()!=1 or bank._normalize_frame(frames[0])!=path or not nav._pose_source_valid("res://"+path,p) or p.get("canvas",[]).size()!=2 or int(p.canvas[0])!=512 or int(p.canvas[1])!=512 or point.size()!=2 or box.size()!=4 or float(p.get("contact_span_px",0))<=0:continue
   if not Rect2(float(box[0]),float(box[1]),float(box[2])-float(box[0]),float(box[3])-float(box[1])).has_point(Vector2(point[0],point[1])):continue
   existing.states[state]=p.duplicate(true)
   count+=1
 return count
