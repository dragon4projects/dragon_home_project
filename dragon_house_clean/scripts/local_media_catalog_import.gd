extends RefCounted
## Owner-selected local catalog; no media playback, no network and no mutable
## simulation state accepted from the external manifest.
const ROOT="user://imported_media_v1/masters/"
const MAX_MANIFEST=4*1024*1024
const MAX_IMAGE=32*1024*1024
const MAX_TEXT=512*1024
const MAX_SIDE=8192
const MAX_ROWS=2000
const MAX_BATCH_BYTES=128*1024*1024
const CATEGORIES=["books","films","tracks"]
const OBJECT_CATEGORIES=["artifacts","paintings","posters","cups"]
var error:String=""

func _fail(reason:String)->Dictionary:
 error=reason
 return {"ok":false,"error":reason,"added":0}

func read_manifest(path:String):
 var f:=FileAccess.open(path,FileAccess.READ)
 if f==null or f.get_length()<=0 or f.get_length()>MAX_MANIFEST:return null
 return JSON.parse_string(f.get_as_text())

func _safe_id(s:String)->bool:
 if s.length()<1 or s.length()>100:return false
 for c in s:
  if not c in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-":return false
 return true

func _number(v)->bool:
 return typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and float(v)>=0

func _integer(v)->bool:
 return _number(v) and float(v)==floorf(float(v)) and float(v)<=100000

func _digest(bytes:PackedByteArray)->String:
 var h:=HashingContext.new()
 h.start(HashingContext.HASH_SHA256);h.update(bytes)
 return h.finish().hex_encode()

func _store_exact(path:String,bytes:PackedByteArray,sha:String)->bool:
 if FileAccess.file_exists(path):return FileAccess.get_sha256(path)==sha
 var f:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if f==null:return false
 f.store_buffer(bytes);f.flush();f.close()
 if FileAccess.get_sha256(path+".tmp")!=sha:return false
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

func _source(manifest_path:String,raw,extensions:Array,limit:int)->Dictionary:
 if typeof(raw)!=TYPE_STRING:return {}
 var name:String=raw
 # A selected manifest authorizes its explicitly named sibling files only.
 if not name.is_valid_filename() or name.contains("..") or name.contains("/") or name.contains("\\"):return {}
 var ext:String=name.get_extension().to_lower()
 if not ext in extensions:return {}
 var f:=FileAccess.open(manifest_path.get_base_dir().path_join(name),FileAccess.READ)
 if f==null or f.get_length()<=0 or f.get_length()>limit:return {}
 var bytes:=f.get_buffer(f.get_length())
 f.close()
 var sha:String=_digest(bytes)
 return {"bytes":bytes,"sha":sha,"path":ROOT+sha+"."+ext,"ext":ext}

func _preview(manifest_path:String,raw)->Dictionary:
 var source:Dictionary=_source(manifest_path,raw,["png","jpg","jpeg","webp"],MAX_IMAGE)
 if source.is_empty():return {}
 var image:=Image.new()
 var status:int=ERR_INVALID_DATA
 match source.ext:
  "png":status=image.load_png_from_buffer(source.bytes)
  "jpg","jpeg":status=image.load_jpg_from_buffer(source.bytes)
  "webp":status=image.load_webp_from_buffer(source.bytes)
 if status!=OK or image.is_empty() or image.get_width()>MAX_SIDE or image.get_height()>MAX_SIDE:return {}
 var largest:int=maxi(image.get_width(),image.get_height())
 if largest>512:
  var scale:float=512.0/float(largest)
  image.resize(maxi(1,roundi(image.get_width()*scale)),maxi(1,roundi(image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
 var bytes:=image.save_png_to_buffer()
 var sha:String=_digest(bytes)
 return {"master":source,"thumb":{"bytes":bytes,"sha":sha,"path":ROOT+source.sha+"_preview.png"}}

static func verified_import_preview(record:Dictionary)->bool:
 var p:String=str(record.get("preview",""))
 var sha:String=str(record.get("preview_sha256",""))
 var original:String=str(record.get("full_image_path",""))
 var original_sha:String=str(record.get("master_sha256",""))
 if sha.length()!=64 or original_sha.length()!=64:return false
 if p!=ROOT+original_sha+"_preview.png":return false
 if original!=ROOT+original_sha+"."+original.get_extension().to_lower() or not original.get_extension().to_lower() in ["png","jpg","jpeg","webp"]:return false
 return FileAccess.file_exists(p) and FileAccess.get_sha256(p)==sha and FileAccess.file_exists(original) and FileAccess.get_sha256(original)==original_sha

func _series(raw:Dictionary,out:Dictionary)->bool:
 var latest_s=raw.get("latest_season",0)
 var latest_e=raw.get("latest_episode",0)
 if not _integer(latest_s) or not _integer(latest_e) or int(latest_s)<1 or int(latest_e)<1:return false
 var table=raw.get("episode_runtime_seconds",{})
 var complete=raw.get("complete_seasons",[])
 if typeof(table)!=TYPE_DICTIONARY or typeof(complete)!=TYPE_ARRAY:return false
 var seasons:Dictionary={}
 for k in table:
  if not str(k).is_valid_int() or int(k)<1 or int(k)>int(latest_s):return false
  var values=table[k]
  if typeof(values)!=TYPE_ARRAY or values.size()>10000 or (int(k)==int(latest_s) and values.size()>int(latest_e)):return false
  for v in values:
   if not _number(v):return false
  seasons[str(int(k))]=values.duplicate()
 var known:Array=[]
 for s in complete:
  if not _integer(s) or int(s)<1 or int(s)>int(latest_s) or known.has(int(s)) or not seasons.has(str(int(s))) or seasons[str(int(s))].is_empty():return false
  if int(s)==int(latest_s) and seasons[str(int(s))].size()!=int(latest_e):return false
  known.append(int(s))
 out.merge({"latest_season":int(latest_s),"latest_episode":int(latest_e),"episode_runtime_seconds":seasons,"complete_seasons":known},true)
 return true

func _stage_record(category:String,raw:Dictionary,manifest_path:String,files:Dictionary)->Dictionary:
 var id:String=str(raw.get("id",""))
 var title:String=str(raw.get("title","")).strip_edges()
 if typeof(raw.get("id"))!=TYPE_STRING or typeof(raw.get("title"))!=TYPE_STRING or not _safe_id(id) or title=="" or title.length()>300:
  error="Invalid stable ID or title";return {}
 var out:Dictionary={"id":id,"title":title,"local_import_v1":true}
 for key in ["author","artist","description","source","provenance","duration_source","duration_status","series_name","publication_year"]:
  if raw.has(key):
   if typeof(raw[key]) not in [TYPE_STRING,TYPE_INT,TYPE_FLOAT] or str(raw[key]).length()>4000:error="Invalid metadata "+key;return {}
   out[key]=raw[key]
 var preview=raw.get("preview",raw.get("preview_path",""))
 if preview!="":
  var pair:Dictionary=_preview(manifest_path,preview)
  if pair.is_empty():error="Invalid or missing sibling preview for "+id;return {}
  for source in [pair.master,pair.thumb]:files[source.path]=source
  out["preview"]=pair.thumb.path
  out["preview_sha256"]=pair.thumb.sha
  out["full_image_path"]=pair.master.path
  out["master_sha256"]=pair.master.sha
 else:out["preview"]=""
 match category:
  "books":
   out["work_id"]=str(raw.get("work_id",id))
   if not _safe_id(out.work_id):error="Invalid work_id";return {}
   for key in ["reading_seconds","series_index","series_catalog_last_index"]:
    if raw.has(key):
     if not (_number(raw[key]) if key=="reading_seconds" else _integer(raw[key])):error="Invalid "+key;return {}
     out[key]=raw[key]
   if raw.has("series_id"):
    if not _safe_id(str(raw.series_id)) or int(out.get("series_index",0))<1 or (int(out.get("series_catalog_last_index",0))>0 and int(out.series_index)>int(out.series_catalog_last_index)):
     error="Invalid book series position";return {}
    out["series_id"]=str(raw.series_id)
   var content=raw.get("content_path",raw.get("text_path",""))
   if content!="":
    var source:Dictionary=_source(manifest_path,content,["txt","md"],MAX_TEXT)
    if source.is_empty():error="Invalid or missing sibling book text";return {}
    files[source.path]=source
    out["content_path"]=source.path
    out["content_sha256"]=source.sha
  "films":
   out["simulation_only"]=true
   out["media_type"]=str(raw.get("media_type","film"))
   if out.media_type=="film":
    if not _number(raw.get("runtime_seconds",0)):error="Invalid film duration";return {}
    out["runtime_seconds"]=float(raw.get("runtime_seconds",0))
   elif out.media_type=="series":
    if not _series(raw,out):error="Invalid series episode table";return {}
   else:error="Invalid film type";return {}
  "tracks":
   if not _number(raw.get("runtime_seconds",0)) or typeof(raw.get("autonomous_music",true))!=TYPE_BOOL:error="Invalid track duration or eligibility";return {}
   out.merge({"simulation_only":true,"autonomous_music":raw.get("autonomous_music",true),"runtime_seconds":float(raw.get("runtime_seconds",0))},true)
 # A content identity is independent of owner-controlled location/progress.
 # Stringify sort_keys=true; repeated import of identical sources is a no-op.
 out["local_import_signature"]=JSON.stringify(out,"",true).sha256_text()
 return out

func import_file(world,media_runtime,path:String)->Dictionary:
 error=""
 var parsed=read_manifest(path)
 if typeof(parsed)!=TYPE_DICTIONARY:return _fail("Invalid/oversized JSON catalog")
 if parsed.has("tracks") and parsed.has("audio"):return _fail("Use either tracks or audio, not both")
 for key in OBJECT_CATEGORIES:
  if parsed.has(key):return _fail("Import media and physical display objects in separate manifests")
 var next:Dictionary=world.media.duplicate(true)
 var assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{}).duplicate(true)
 var occupied:Dictionary={}
 for row in assignments.values():occupied[str(row.get("room_id",""))+"|"+str(row.get("slot_id",""))]=true
 var files:Dictionary={}
 var added:=0
 var duplicates:=0
 var placed:=0
 var total:=0
 for category in CATEGORIES:
  var raw_items=parsed.get(category,parsed.get("audio",[]) if category=="tracks" else [])
  if typeof(raw_items)!=TYPE_ARRAY:return _fail("Invalid "+category+" array")
  total+=raw_items.size()
  if total>MAX_ROWS:return _fail("Too many catalog records")
  var records:Array=next.get(category,[])
  var ids:Dictionary={}
  for old in records:ids[str(old.get("id",""))]=old
  var seen:Dictionary={}
  for raw in raw_items:
   if typeof(raw)!=TYPE_DICTIONARY:return _fail("Invalid catalog row")
   var out:Dictionary=_stage_record(category,raw,path,files)
   if out.is_empty():return _fail(error)
   var byte_count:int=0
   for staged in files.values():byte_count+=staged.bytes.size()
   if byte_count>MAX_BATCH_BYTES:return _fail("Catalog attachments exceed 128 MiB; import smaller batches")
   var id:String=out.id
   if seen.has(id):return _fail("Duplicate input ID "+id)
   seen[id]=true
   if ids.has(id):
    if ids[id].get("local_import_signature","")!=out.local_import_signature:return _fail("Existing identity conflict "+id)
    duplicates+=1
    continue
   if category=="books":
    # New works are catalog-only unless an exact physical home is explicitly
    # requested and measured/reachable by the live navigation registry.
    out.merge({"physical":false,"catalog_only":true,"holder_id":"","location_room_id":"","progress_by_actor":{},"owner_id":"","last_interaction_at":world.sim_clock},true)
    var rid:String=str(raw.get("home_room_id",""))
    var sid:String=str(raw.get("home_slot_id",""))
    if rid!="" or sid!="":
     if rid=="" or sid=="" or media_runtime.candidate_navigation==null:return _fail("Both measured book home room and slot required: "+id)
     var room:Dictionary=world.room_by_id(rid)
     if not world.public_cutaway_allowed(room) or room.get("type","")!="library" or occupied.has(rid+"|"+sid):return _fail("Book home unavailable: "+id)
     var match_slot:Dictionary={}
     for slot in media_runtime.candidate_navigation.book_slots(room):
      if str(slot.id)==sid:match_slot=slot;break
     if match_slot.is_empty() or not media_runtime._book_support_free(id,rid,match_slot):return _fail("Book shelf support unavailable: "+id)
     occupied[rid+"|"+sid]=true
     assignments[id]={"room_id":rid,"slot_id":sid}
     out.merge({"physical":true,"catalog_only":false,"physical_item_id":id,"home_room_id":rid,"home_slot_id":sid,"location_room_id":rid},true)
     placed+=1
   records.append(out)
   added+=1
  next[category]=records
 if total==0:return _fail("No media records")
 if added==0:
  for staged in files.values():
   if not FileAccess.file_exists(staged.path) or FileAccess.get_sha256(staged.path)!=staged.sha:return _fail("Existing local master or thumbnail missing/corrupt")
  return {"ok":true,"added":0,"duplicates":duplicates,"placed_books":0}
 # All validation precedes world mutation. Immutable content-addressed
 # assets may remain as unreferenced bytes if the final snapshot fails.
 if not files.is_empty() and DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))!=OK:return _fail("Cannot create media storage")
 for f in files.values():
  if not _store_exact(f.path,f.bytes,f.sha):return _fail("Cannot store immutable media master")
 var previous:Dictionary=world.media
 var had_assignments:bool=world.runtime_state.has("teea008_book_slot_assignments")
 var prior_assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{})
 world.media=next
 world.runtime_state["teea008_book_slot_assignments"]=assignments
 if not world.save_world():
  world.media=previous
  if had_assignments:world.runtime_state["teea008_book_slot_assignments"]=prior_assignments
  else:world.runtime_state.erase("teea008_book_slot_assignments")
  return _fail("Catalog snapshot failed")
 return {"ok":true,"added":added,"duplicates":duplicates,"placed_books":placed}
