extends RefCounted
## Concrete room-instance media binding. Variant IDs are templates, never
## globally shared mutable selection. No fake media or automatic UI playback.
var world
var bank
var media

func setup(model,review,media_runtime)->void:
	world=model
	bank=review
	media=media_runtime

func _key(room_id:String,surface_id:String)->String:
	return room_id+"|"+surface_id

func spec(room_id:String,surface_id:String)->Dictionary:
	var room:Dictionary=world.room_by_id(room_id)
	if not world.public_cutaway_allowed(room):
		return {}
	var kind:String=str(room.get("type",""))
	var variant:String="%s/R%d" % [kind,int(room.get("size_modules",1))]
	var surface:Dictionary=bank.surfaces.get(surface_id,{})
	return surface if str(surface.get("room_variant",""))==variant else {}

func _record(category:String,id:String)->Dictionary:
	if category=="artifacts":
		var obj:Dictionary=world.physical_object(id)
		if obj.is_empty() or str(obj.get("state",""))=="STASHED":
			return {}
		return obj
	return media._lookup(category,id)

func _is_screen(surface_id:String)->bool:
	return surface_id.ends_with(".film.screen")

func assign(room_id:String,surface_id:String,category:String,item_id:String)->bool:
	var surface:Dictionary=spec(room_id,surface_id)
	if surface.is_empty() or str(surface.get("legacy_runtime_category",""))!=category:
		return false
	if item_id!="":
		var item:Dictionary=_record(category,item_id)
		if item.is_empty():
			return false
		if category=="artifacts" and (str(item.get("current_room_id",""))!=room_id or str(item.get("current_holder_id",""))!=""):
			return false
		if _is_screen(surface_id) and not media.playable("films").any(func(r):return str(r.get("id",""))==item_id):
			return false
	var bindings:Dictionary=world.runtime_state.get("teea008_room_media_bindings",{})
	var key:String=_key(room_id,surface_id)
	var previous:String=str(bindings.get(key,{}).get("item_id",""))
	if item_id=="":
		bindings.erase(key)
	else:
		bindings[key]={"room_id":room_id,"surface_id":surface_id,"category":category,"item_id":item_id}
	world.runtime_state["teea008_room_media_bindings"]=bindings
	world._append_journal("MEDIA_SURFACE_BINDING_CHANGED","LOCAL_DRAGON",surface_id,previous,item_id,{"room_id":room_id,"category":category})
	return true

func pinned(room_id:String,surface_id:String)->Dictionary:
	var surface:Dictionary=spec(room_id,surface_id)
	if surface.is_empty():
		return {}
	var bindings:Dictionary=world.runtime_state.get("teea008_room_media_bindings",{})
	var binding:Dictionary=bindings.get(_key(room_id,surface_id),{})
	var category:String=str(surface.get("legacy_runtime_category",""))
	if str(binding.get("category",""))!=category:
		return {}
	var record:Dictionary=_record(category,str(binding.get("item_id","")))
	if category=="artifacts" and (str(record.get("current_room_id",""))!=room_id or str(record.get("current_holder_id",""))!=""):
		return {}
	return record

func active_film(room_id:String,ignore_actor:String="",perform_only:bool=false)->Dictionary:
	var ids:Array=world.residents.keys()
	ids.sort()
	for id in ids:
		if str(id)==ignore_actor:
			continue
		var actor:Dictionary=world.residents[id]
		if not bool(actor.get("active",false)) or str(actor.get("intent",""))!="WATCH_FILM" or str(actor.get("station_room_id",""))!=room_id:
			continue
		if not str(actor.get("phase","")) in (["perform"] if perform_only else ["travel","perform"]):
			continue
		var item_id:String=str(actor.get("activity_media_id",""))
		if media.can_watch(str(id),item_id,room_id):
			return media._lookup("films",item_id)
	return {}

func choose_film(room_id:String,actor_id:String)->Dictionary:
	var active:Dictionary=active_film(room_id,actor_id)
	if not active.is_empty():
		return active
	var room:Dictionary=world.room_by_id(room_id)
	var surface_id:String="cinema.r%d.film.screen" % int(room.get("size_modules",1))
	var item:Dictionary=pinned(room_id,surface_id)
	if not item.is_empty() and media.can_watch(actor_id,str(item["id"]),room_id):
		return item
	return {}

func resolve(room_id:String,surface_id:String)->Dictionary:
	var surface:Dictionary=spec(room_id,surface_id)
	if surface.is_empty():
		return {}
	if _is_screen(surface_id):
		var active:Dictionary=active_film(room_id,"",true)
		if not active.is_empty():
			return active
	return pinned(room_id,surface_id)
