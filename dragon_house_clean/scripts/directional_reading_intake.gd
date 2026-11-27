extends RefCounted
## Optional exact-frame reading bank. The side sprite contains a visible
## book; the runtime hides the physical volume only when it renders this frame.
const PATH="res://data/asset_proposals/DH_I93_SIDE_READ/frames.json"
const PROOF="res://data/integration_candidates/TEEA008_POSE_EXPORT_PROOF.json"
func install(bank,nav)->int:
 var f:=FileAccess.open(PATH,FileAccess.READ)
 if f==null:return 0
 var d=JSON.parse_string(f.get_as_text())
 if typeof(d)!=TYPE_DICTIONARY or int(d.get("schema",0))!=1 or d.get("status","")!="SIDE_READING_PILOT_CANDIDATE":return -1
 var proof:Dictionary={}
 var pf:=FileAccess.open(PROOF,FileAccess.READ)
 if pf!=null:
  var pd=JSON.parse_string(pf.get_as_text())
  if typeof(pd)==TYPE_DICTIONARY:proof=pd.get("frames",{})
 var pending:Array=[]
 var seen:Dictionary={}
 for r in d.get("frames",[]):
  var id:String=str(r.get("actor_id",""))
  var wardrobe:String=str(r.get("wardrobe",""))
  var state:String=str(r.get("state",""))
  var path:String=str(r.get("path",""))
  if not wardrobe in ["HOME","SHORT","CITY"] or not state in ["READ_E","READ_W","READ_NE","READ_NW","READ_SE","READ_SW","READ_N"] or not bank._safe_frame_path(id,wardrobe,path) or path!=bank._root(id,wardrobe)+state+"/0001.png" or seen.has(path):return -1
  seen[path]=true
  var profile:Dictionary=nav.pose_profiles.get(id,{})
  if profile.get("appearance_profile","")!=r.get("appearance_profile","") or profile.get("wardrobe","")!=wardrobe:return -1
  var states:Dictionary=bank.manifest.get("residents",{}).get(id,{}).get("wardrobes",{}).get(wardrobe,{}).get("states",{})
  if states.is_empty() or not states.get(state,{}).get("frames",[]).is_empty() or profile.states.has(state):return -1
  if str(r.get("source_seat_sha256",""))!=str(profile.states.get("SIT_"+state.trim_prefix("READ_"),{}).get("sha256","")):return -1
  if r.get("canvas",[]).size()!=2 or int(r.canvas[0])!=512 or int(r.canvas[1])!=512 or r.get("alpha_bbox",[]).size()!=4 or r.get("contact_px",[]).size()!=2 or not bool(r.get("book_baked",false)) or float(r.get("contact_span_px",0))<=0 or not nav._pose_source_valid("res://"+path,r):return -1
  var box:Array=r.alpha_bbox
  var point:Array=r.contact_px
  if not Rect2(float(box[0]),float(box[1]),float(box[2])-float(box[0]),float(box[3])-float(box[1])).has_point(Vector2(point[0],point[1])):return -1
  pending.append({"states":states,"profile":profile,"state":state,"frame":path,"record":r})
 if pending.is_empty():return -1
 for row in pending:
  row.states[row.state]={"frames":[row.frame],"frame_count":1,"fps":1,"status":"PASS","runtime_bound":false,"source_confidence":"I93 side-reading art candidate; measured contact gate","evidence":PATH}
  row.profile.states[row.state]=row.record.duplicate(true)
 return pending.size()
