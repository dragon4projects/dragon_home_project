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
	# The cover sleeve and actual boombox share exactly one persistent binding.
	var spec_data:Dictionary=bank.surfaces.get(surface_id,{})
	return room_id+"|"+str(spec_data.get("binding_alias",surface_id))

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
		if obj.is_empty() or str(obj.get("viewer_category",""))!="artifacts" or str(obj.get("state",""))=="STASHED":
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
		if category=="books" and bool(item.get("physical",true)) and (str(item.get("location_room_id",""))!=room_id or str(item.get("holder_id",""))!=""):
			return false
		if _is_screen(surface_id) and not media.playable("films").any(func(r):return str(r.get("id",""))==item_id):
			# A source-backed film may be shown as a static catalog preview.
			# This does not grant WATCH_FILM eligibility or local playback.
			var preview_path:String=str(item.get("preview",item.get("preview_path","")))
			if not preview_path.begins_with("res://assets/media/previews/") or not (ResourceLoader.exists(preview_path,"Texture2D") or FileAccess.file_exists(preview_path)):
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
	if category=="books" and bool(record.get("physical",true)) and (str(record.get("location_room_id",""))!=room_id or str(record.get("holder_id",""))!=""):
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

func active_track(room_id:String,ignore_actor:String="",perform_only:bool=false)->Dictionary:
	var ids:Array=world.residents.keys()
	ids.sort()
	for id in ids:
		if str(id)==ignore_actor:continue
		var actor:Dictionary=world.residents[id]
		if not bool(actor.get("active",false)) or str(actor.get("intent",""))!="LISTEN_MUSIC" or str(actor.get("station_room_id",""))!=room_id:
			continue
		if not str(actor.get("phase","")) in (["perform"] if perform_only else ["travel","perform"]):continue
		if perform_only and str(actor.get("room_id",""))!=room_id:continue
		var item_id:String=str(actor.get("activity_media_id",""))
		if media.can_listen(str(id),item_id,room_id):
			return media._lookup("tracks",item_id)
	return {}

func choose_track(room_id:String,actor_id:String)->Dictionary:
	var active:Dictionary=active_track(room_id,actor_id)
	if not active.is_empty() and media.can_listen(actor_id,str(active["id"]),room_id):
		return active
	var room:Dictionary=world.room_by_id(room_id)
	var surface_id:String="music.r%d.audio.01" % int(room.get("size_modules",1))
	var item:Dictionary=pinned(room_id,surface_id)
	if not item.is_empty() and media.can_listen(actor_id,str(item["id"]),room_id):
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
	if surface_id.ends_with(".audio.01") or surface_id=="music.r3.audio.now_playing":
		var track:Dictionary=active_track(room_id,"",true)
		if not track.is_empty():return track
	return pinned(room_id,surface_id)

func place_artifact(room_id:String,surface_id:String,item_id:String,navigation,width:float,height:float,depth:float)->bool:
	# Explicit owner action, no invented physical size. Caller supplies
	# the actual rendered representation's dimensions, not an inferred real-world object.
	var surface:Dictionary=spec(room_id,surface_id)
	var obj:Dictionary=_record("artifacts",item_id)
	if surface.is_empty() or str(surface.get("legacy_runtime_category",""))!="artifacts" or obj.is_empty() or str(obj.get("current_room_id",""))!=room_id or str(obj.get("current_holder_id",""))!="" or not bool(obj.get("movable",false)) or str(obj.get("display_mode",""))=="wall":
		return false
	if width<=0 or height<=0 or depth<=0 or not is_finite(width+height+depth):return false
	var room:Dictionary=world.room_by_id(room_id)
	var carrier:String=str(surface.get("carrier_instance_id",""))
	for slot in navigation.artifact_slots(room):
		if str(slot["furniture_id"])!=carrier:continue
		var dims:Array=slot["dimensions"]
		if width>float(dims[0]) or height>float(dims[1]) or depth>float(dims[2]):continue
		var pos:Array=slot["xyz"]
		var occupied:=false
		for other in world.objects.values():
			if str(other.get("id",""))==item_id:continue
			if str(other.get("home_room_id",""))==room_id and str(other.get("home_support_id",""))==str(slot["id"]):
				occupied=true
				break
			if str(other.get("current_room_id",""))==room_id and str(other.get("current_holder_id",""))=="" and str(other.get("state",""))=="PLACED" and str(other.get("home_support_id",""))=="":
				var anchor:Array=other.get("current_anchor",[])
				if anchor.size()==2 and Vector2(float(anchor[0]),float(anchor[1])).distance_to(Vector2(float(pos[0]),float(pos[2])))<0.12:
					occupied=true
					break
		if occupied:continue
		if not world.assign_physical_object_home(item_id,room_id,Vector2(float(pos[0]),float(pos[2])),true,str(slot["id"])):
			return false
		return assign(room_id,surface_id,"artifacts",item_id)
	return false
