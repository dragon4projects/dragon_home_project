extends RefCounted
## Owner-selected frame art. Each slot has a small atomic reference; original
## bytes are immutable and shared with the local media master store.
const Local=preload("res://scripts/local_media_catalog_import.gd")
const ROOT="user://dense_v2_qa/wall_holders/"
var error:String=""
static func record_path(slot:String)->String:
 return ROOT+slot.validate_filename()+".json"
static func load_record(slot:String)->Dictionary:
 var path:String=record_path(slot)
 if not FileAccess.file_exists(path):return {}
 var f:=FileAccess.open(path,FileAccess.READ)
 if f==null or f.get_length()>16384:return {}
 var raw=JSON.parse_string(f.get_as_text())
 if typeof(raw)!=TYPE_DICTIONARY or raw.get("id","")!=slot or raw.get("category","") not in ["paintings","posters"] or not bool(raw.get("local_import_v1",false)):return {}
 return raw
static func display_path(slot:String)->String:
 var r:=load_record(slot)
 if not r.is_empty():
  var preview:String=str(r.get("preview",""))
  if preview.begins_with(Local.ROOT) and FileAccess.file_exists(preview) and FileAccess.get_sha256(preview)==str(r.get("preview_sha256","")):return preview
  return ""
 # No inferred master metadata for legacy assignments.
 return ROOT+slot.validate_filename()+".png"
func assign(slot:String,path:String,category:String,title:String="")->Dictionary:
 error=""
 if slot=="" or slot.validate_filename()!=slot or not category in ["paintings","posters"]:
  error="Недопустимая рамка или тип изображения";return {}
 var helper=Local.new()
 var pair:Dictionary=helper._preview(path,path.get_file())
 if pair.is_empty():
  error="Изображение недоступно, повреждено или слишком велико";return {}
 if title.strip_edges()=="":title=path.get_file().get_basename()
 title=title.strip_edges().left(300)
 if title=="":
  error="Требуется название";return {}
 var r:Dictionary={"id":slot,"title":title,"category":category,"local_import_v1":true,"dense_v2_assignable":true,"dense_wall_frame":true,"preview":pair.thumb.path,"preview_sha256":pair.thumb.sha,"full_image_path":pair.master.path,"master_sha256":pair.master.sha}
 var prior:Dictionary=load_record(slot)
 if prior==r and Local.verified_import_preview(prior):return prior
 for dir in [Local.ROOT,ROOT]:
  if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))!=OK:
   error="Не удалось создать локальное хранилище";return {}
 for source in [pair.master,pair.thumb]:
  if not helper._store_exact(source.path,source.bytes,source.sha):
   error="Не удалось сохранить оригинал и превью";return {}
 var dest:String=record_path(slot)
 var f:=FileAccess.open(dest+".tmp",FileAccess.WRITE)
 if f==null:
  error="Не удалось записать назначение рамки";return {}
 f.store_string(JSON.stringify(r,"",true));f.flush();f.close()
 if DirAccess.rename_absolute(ProjectSettings.globalize_path(dest+".tmp"),ProjectSettings.globalize_path(dest))!=OK:
  error="Не удалось сохранить назначение рамки";return {}
 return r
