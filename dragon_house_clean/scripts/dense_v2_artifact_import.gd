extends RefCounted
## Explicit local image assignment in isolated QA. Original bytes remain
## content-addressed and unchanged; thumbnails are disposable derivatives.
const ROOT="user://dense_artifact_qa_v1/masters/"
const MAX_BYTES:=32*1024*1024
const MAX_SIDE:=8192
var error:String=""

func _fail(reason:String)->String:
 error=reason
 return ""

func _store_exact(path:String,bytes:PackedByteArray,sha:String)->bool:
 if FileAccess.file_exists(path):return FileAccess.get_sha256(path)==sha
 var tmp:String=path+".tmp"
 var f:=FileAccess.open(tmp,FileAccess.WRITE)
 if f==null:return false
 f.store_buffer(bytes);f.flush();f.close()
 if FileAccess.get_sha256(tmp)!=sha:return false
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp),ProjectSettings.globalize_path(path))==OK

func assign(world,sid:String,path:String)->String:
 error=""
 var adapter=world.dense_artifact_world
 if adapter==null:return _fail("Реестр ячеек недоступен")
 var slot:Dictionary=adapter.slots.get(sid,{})
 if slot.is_empty():return _fail("Ячейка не существует")
 if not world.public_cutaway_allowed(world.room_by_id(adapter.room_id)):return _fail("Комната закрыта")
 if not adapter.free_visual_slots(world.objects).any(func(s):return s.id==sid):return _fail("Ячейка больше не свободна")
 var ext:String=path.get_extension().to_lower()
 if not ext in ["png","jpg","jpeg","webp"]:return _fail("Неподдерживаемый формат")
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()<=0 or file.get_length()>MAX_BYTES:return _fail("Файл недоступен или слишком большой")
 var bytes:=file.get_buffer(file.get_length())
 file.close()
 var image:=Image.new()
 var decode:int=ERR_INVALID_DATA
 match ext:
  "png":decode=image.load_png_from_buffer(bytes)
  "jpg","jpeg":decode=image.load_jpg_from_buffer(bytes)
  "webp":decode=image.load_webp_from_buffer(bytes)
 if decode!=OK or image.is_empty() or image.get_width()>MAX_SIDE or image.get_height()>MAX_SIDE:return _fail("Невозможно прочитать изображение")
 var hash:=HashingContext.new()
 hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
 var sha:String=hash.finish().hex_encode()
 var id:String="LOCAL_GRID_"+sha
 if not world.physical_object(id).is_empty():return _fail("Это изображение уже назначено; переместите существующий куб")
 var prospective:Dictionary=world.objects.duplicate(true)
 prospective[id]={"viewer_category":"artifacts","artifact_size":slot.size}
 if not adapter.available(prospective,id,sid):return _fail("Ячейка пересекается с занятой областью")
 if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))!=OK:return _fail("Не удалось создать папку артефактов")
 var master:String=ROOT+sha+"."+ext
 if not _store_exact(master,bytes,sha):return _fail("Не удалось сохранить оригинал")
 var thumb:String=ROOT+sha+"_preview.png"
 var longest:int=maxi(image.get_width(),image.get_height())
 if longest>512:
  var scale:float=512.0/longest
  image.resize(maxi(1,roundi(image.get_width()*scale)),maxi(1,roundi(image.get_height()*scale)),Image.INTERPOLATE_LANCZOS)
 # The derivative has no authority over master identity.
 var thumb_bytes:=image.save_png_to_buffer()
 var h:=HashingContext.new()
 h.start(HashingContext.HASH_SHA256);h.update(thumb_bytes)
 if not _store_exact(thumb,thumb_bytes,h.finish().hex_encode()):return _fail("Не удалось сохранить превью")
 var small:bool=slot.size=="S"
 var title:String=path.get_file().get_basename().left(120)
 if title.strip_edges()=="":title="Артефакт"
 var meta:Dictionary={"viewer_category":"artifacts","display_mode":"cube","artifact_size":slot.size,"object_class":"small_artifact" if small else "display_object","home_anchor":[slot.xyz[0],slot.xyz[2]],"home_support_id":sid,"display_world_height":float(slot.dimensions[1]),"preview_path":thumb,"full_image_path":master,"artifact_source_sha256":sha,"description":"Локально назначенный оригинал"}
 if not world.register_physical_object(id,title,"",adapter.room_id,true,true,small,small,not small,meta):return _fail("Событие назначения отклонено; исходный файл сохранён")
 return id
