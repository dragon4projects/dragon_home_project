extends RefCounted
## Physical-media lifecycle, independent from camera and autonomous planner.
## Catalogue entries are explicit. No invented titles, playback or ownership.
var world
var candidate_navigation=null

func setup(model) -> void:
	world = model
	_normalize_catalogue()
	if candidate_navigation!=null:
		reconcile_book_slots()

func _normalize_catalogue() -> void:
	for book in world.media.get("books", []):
		if not book.has("holder_id"):
			book["holder_id"] = ""
		if not book.has("location_room_id"):
			if not bool(book.get("physical", true)):
				book["location_room_id"] = ""
			else:
				var rooms: Array = world.matching_rooms(["library"])
				book["location_room_id"] = rooms[0]["id"] if not rooms.is_empty() else ""
		if not book.has("idle_since"):
			book["idle_since"] = 0
		if not book.has("progress_by_actor"):
			book["progress_by_actor"] = {}
		if not book.has("owner_id"):
			book["owner_id"] = ""
		if bool(book.get("physical",true)) and not book.has("home_room_id"):
			var rooms:Array=world.matching_rooms(["library"])
			book["home_room_id"]=str(rooms[0]["id"]) if not rooms.is_empty() else ""

func _lookup(kind: String, id: String) -> Dictionary:
	for entry in world.media.get(kind, []):
		if entry.get("id", "") == id:
			return entry
	return {}

func available_books() -> Array:
	var out: Array = []
	for book in world.media.get("books", []):
		if bool(book.get("physical", true)) and book.get("holder_id", "") == "" and book.get("location_room_id", "") != "":
			out.append(book)
	return out

func borrow(actor_id: String, book_id: String, now: int = 0) -> bool:
	var actor: Dictionary = world.residents.get(actor_id, {})
	var book: Dictionary = _lookup("books", book_id)
	if not actor.get("active", false) or book.is_empty() or not bool(book.get("physical", true)):
		return false
	if book.get("holder_id", "") != "" or book.get("location_room_id", "") == "":
		return false
	book["holder_id"] = actor_id
	book["location_room_id"] = ""
	book["idle_since"] = 0
	book["borrowed_at"] = now
	return true

func read(actor_id: String, book_id: String, seconds: float) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	var progress: Dictionary = book.get("progress_by_actor", {})
	progress[actor_id] = maxf(0.0, float(progress.get(actor_id, 0.0)) + seconds)
	book["progress_by_actor"] = progress
	return true

func drop_book(actor_id: String, book_id: String, now: int) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	book["holder_id"] = ""
	book["idle_since"] = now
	# No shelf location while abandoned. This is not a second copy.
	return true

func return_book(actor_id: String, book_id: String, destination_id: String = "") -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	var target:String=destination_id if destination_id!="" else str(book.get("home_room_id",""))
	var room: Dictionary = world.room_by_id(target)
	if not world.public_cutaway_allowed(room) or not ["library", "rest", "study"].has(room.get("type", "")):
		var rooms: Array = world.matching_rooms(["library", "rest", "study"])
		if rooms.is_empty():
			return false
		room = rooms[0]
	book["holder_id"] = ""
	book["location_room_id"] = room["id"]
	book["idle_since"] = 0
	return true

func cleanup_abandoned(now: int) -> int:
	var count := 0
	for book in world.media.get("books", []):
		if not bool(book.get("physical", true)):
			continue
		if book.get("holder_id", "") != "" or book.get("location_room_id", "") != "":
			continue
		var abandoned_at: int = int(book.get("idle_since", 0))
		if abandoned_at <= 0 or now - abandoned_at < 86400:
			continue
		var rooms: Array = world.matching_rooms(["library", "rest", "study"])
		if rooms.is_empty():
			continue
		book["location_room_id"] = rooms[0]["id"]
		book["idle_since"] = 0
		count += 1
	return count

func tick_book_home_reset() -> int:
	var day:int=world.game_day_index()
	var last:int=int(world.runtime_state.get("book_home_reset_day",day))
	if not world.runtime_state.has("book_home_reset_day"):
		world.runtime_state["book_home_reset_day"]=day
		return 0
	if day<=last:
		return 0
	var count:int=0
	for book in world.media.get("books",[]):
		if not bool(book.get("physical",true)):
			continue
		var home:String=str(book.get("home_room_id",""))
		if not world.public_cutaway_allowed(world.room_by_id(home)):
			continue
		var holder:String=str(book.get("holder_id",""))
		var previous:String=str(book.get("location_room_id",""))
		if holder=="" and previous==home:
			continue
		book["holder_id"]=""
		book["location_room_id"]=home
		book["idle_since"]=0
		book.erase("borrowed_at")
		if holder!="" and world.residents.has(holder):
			var actor:Dictionary=world.residents[holder]
			if str(actor.get("held_book",""))==str(book["id"]):
				actor.erase("held_book")
		world._append_journal("BOOK_RESTORED_HOME","HOUSE_SPIRIT",str(book["id"]),holder if holder!="" else previous,home,{"game_day":day})
		count+=1
	world.runtime_state["book_home_reset_day"]=day
	return count

func playable(kind: String) -> Array:
	var allowed: Array = ["ogg", "mp3", "wav"] if kind == "tracks" else ["ogv"] if kind == "films" else []
	var out: Array = []
	for item in world.media.get(kind, []):
		var path: String = str(item.get("file_path", ""))
		if path == "" or not allowed.has(path.get_extension().to_lower()):
			continue
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			out.append(item)
	return out

func next_watch_unit(actor_id:String,item:Dictionary)->Dictionary:
	if not bool(item.get("simulation_only",false)):return {}
	var id:String=str(item.get("id",""))
	if id=="":return {}
	var progress:Dictionary=world.runtime_state.get("cinema_progress",{}).get(actor_id,{}).get(id,{})
	if bool(progress.get("complete",false)):return {}
	if str(item.get("media_type",""))=="film":
		var duration:float=float(item.get("runtime_seconds",0))
		if duration<=0 or not is_finite(duration):return {}
		return {"item_id":id,"season":0,"episode":0,"seconds":duration}
	if str(item.get("media_type",""))!="series":return {}
	var season:int=int(progress.get("next_season",1))
	var episode:int=int(progress.get("next_episode",1))
	var latest_season:int=int(item.get("latest_season",0))
	var latest_episode:int=int(item.get("latest_episode",0))
	if season>latest_season or (season==latest_season and episode>latest_episode):return {}
	var runtimes:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
	if episode<1 or episode>runtimes.size():return {}
	var duration:float=float(runtimes[episode-1])
	if duration<=0 or not is_finite(duration):return {}
	return {"item_id":id,"season":season,"episode":episode,"seconds":duration}

func watch_candidates(actor_id:String)->Array:
	var result:Array=[]
	for item in world.media.get("films",[]):
		if not next_watch_unit(actor_id,item).is_empty():result.append(item)
	return result

func begin_watch(actor:Dictionary,now:float)->bool:
	var item:Dictionary=_lookup("films",str(actor.get("activity_media_id","")))
	var unit:Dictionary=next_watch_unit(str(actor["id"]),item)
	if unit.is_empty():return false
	unit["started_at"]=now
	unit["ends_at"]=now+float(unit["seconds"])
	unit["room_id"]=str(actor.get("room_id",""))
	actor["watch_session"]=unit
	actor["until"]=unit["ends_at"]
	return true

func finish_watch(actor:Dictionary,now:float)->bool:
	var unit:Dictionary=actor.get("watch_session",{})
	if unit.is_empty() or now<float(unit.get("ends_at",INF)):return false
	if str(actor.get("phase",""))!="perform" or str(actor.get("intent",""))!="WATCH_FILM" or str(actor.get("room_id",""))!=str(unit.get("room_id","")):return false
	var id:String=str(unit["item_id"])
	var item:Dictionary=_lookup("films",id)
	var expected:Dictionary=next_watch_unit(str(actor["id"]),item)
	if expected.is_empty() or int(expected["season"])!=int(unit["season"]) or int(expected["episode"])!=int(unit["episode"]):return false
	var all:Dictionary=world.runtime_state.get("cinema_progress",{})
	var actor_id:String=str(actor["id"])
	var progress:Dictionary=all.get(actor_id,{})
	var season:int=int(unit["season"])
	var episode:int=int(unit["episode"])
	var row:Dictionary={"last_completed_season":season,"last_completed_episode":episode,"last_completed_at":now,"complete":false}
	if season==0:
		row["complete"]=true
	else:
		var latest_season:int=int(item.get("latest_season",0))
		var latest_episode:int=int(item.get("latest_episode",0))
		var runtimes:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
		if season==latest_season and episode>=latest_episode:
			# Caught up to the source snapshot, not necessarily series finale.
			row["next_season"]=season
			row["next_episode"]=episode+1
		elif episode==runtimes.size() and season<latest_season:
			# A season array contains only a verified COMPLETE earlier season.
			row["next_season"]=season+1
			row["next_episode"]=1
		else:
			row["next_season"]=season
			row["next_episode"]=episode+1
	progress[id]=row
	all[actor_id]=progress
	world.runtime_state["cinema_progress"]=all
	actor["last_watch_id"]=id
	actor.erase("watch_session")
	world._append_journal("CINEMA_UNIT_COMPLETED",actor_id,id,"",str(actor.get("room_id","")),{"season":season,"episode":episode,"seconds":unit["seconds"]})
	return true

func can_watch(actor_id: String, item_id: String, room_id: String) -> bool:
	if not world.residents.get(actor_id, {}).get("active", false) or world.room_by_id(room_id).get("type", "")!="cinema":return false
	var item:Dictionary=_lookup("films",item_id)
	return not next_watch_unit(actor_id,item).is_empty()

func track_duration(item:Dictionary)->float:
	if not bool(item.get("simulation_only",false)) or not bool(item.get("autonomous_music",false)):return 0.0
	var seconds:float=float(item.get("runtime_seconds",0))
	return seconds if is_finite(seconds) and seconds>0 else 0.0

func listen_candidates()->Array:
	var out:Array=[]
	for item in world.media.get("tracks",[]):
		if track_duration(item)>0:out.append(item)
	return out

func listen_history(actor_id:String,item_id:String)->Dictionary:
	return world.runtime_state.get("music_progress",{}).get(actor_id,{}).get(item_id,{})

func choose_listen_item(actor_id:String,rng:RandomNumberGenerator,now:float)->Dictionary:
	var options:Array=listen_candidates()
	if options.is_empty():return {}
	# Novelty first, but repeat listening remains possible and has its own
	# count/recency. Keep a small nonzero revisit weight for known songs.
	var weights:=PackedFloat32Array()
	for item in options:
		var history:Dictionary=listen_history(actor_id,str(item["id"]))
		var n:int=int(history.get("completed_count",0))
		var age:float=now-float(history.get("last_completed_at",-86400.0))
		weights.append(1.0 if n==0 else (0.02 if age<300.0 else 0.25+0.15*minf(float(n),4.0)))
	var index:int=rng.rand_weighted(weights)
	return options[maxi(0,index)]

func begin_listen(actor:Dictionary,now:float)->bool:
	var item_id:String=str(actor.get("activity_media_id",""))
	var duration:float=track_duration(_lookup("tracks",item_id))
	if duration<=0:return false
	actor["listen_session"]={"item_id":item_id,"started_at":now,"ends_at":now+duration,"seconds":duration,"room_id":str(actor.get("room_id",""))}
	actor["until"]=now+duration
	return true

func finish_listen(actor:Dictionary,now:float)->bool:
	var unit:Dictionary=actor.get("listen_session",{})
	if unit.is_empty() or now<float(unit.get("ends_at",INF)):return false
	if str(actor.get("phase",""))!="perform" or str(actor.get("intent",""))!="LISTEN_MUSIC" or str(actor.get("room_id",""))!=str(unit.get("room_id","")) or str(actor.get("activity_media_id",""))!=str(unit.get("item_id","")):return false
	var id:String=str(unit["item_id"])
	var actor_id:String=str(actor["id"])
	var all:Dictionary=world.runtime_state.get("music_progress",{})
	var history:Dictionary=all.get(actor_id,{})
	var previous:Dictionary=history.get(id,{})
	history[id]={"completed_count":int(previous.get("completed_count",0))+1,"total_seconds":float(previous.get("total_seconds",0))+float(unit["seconds"]),"last_completed_at":now}
	all[actor_id]=history
	world.runtime_state["music_progress"]=all
	actor.erase("listen_session")
	world._append_journal("MUSIC_TRACK_COMPLETED",actor_id,id,"",str(actor.get("room_id","")),{"seconds":unit["seconds"],"completed_count":history[id]["completed_count"]})
	return true

func can_listen(actor_id: String, item_id: String, room_id: String) -> bool:
	return world.residents.get(actor_id, {}).get("active", false) and world.room_by_id(room_id).get("type", "")=="music" and track_duration(_lookup("tracks",item_id))>0


# Live review: a reservation is not possession. Only a physically arrived
# actor at a measured shelf station may change the actual holder/location.
func reserved_book_ids(ignore_actor:String="")->Dictionary:
	var ids:Dictionary={}
	for id in world.residents:
		var a:Dictionary=world.residents[id]
		if str(id)==ignore_actor or not bool(a.get("active",false)):
			continue
		if str(a.get("book_task_stage",""))=="fetch" and str(a.get("phase",""))=="travel":
			var book_id:String=str(a.get("book_task_id",""))
			if book_id!="":ids[book_id]=str(id)
	return ids

func available_shelf_books(actor_id:String)->Array:
	var reserved:=reserved_book_ids(actor_id)
	var out:Array=[]
	for book in available_books():
		var room:Dictionary=world.room_by_id(str(book.get("location_room_id","")))
		if str(room.get("type",""))=="library" and world.is_accessible(room,actor_id) and not reserved.has(str(book["id"])):
			if candidate_navigation==null or not book_slot(str(book["id"])).is_empty():
				out.append(book)
	return out

func borrow_at_shelf(actor_id:String,book_id:String,room_id:String)->bool:
	var actor:Dictionary=world.residents.get(actor_id,{})
	var book:Dictionary=_lookup("books",book_id)
	if str(actor.get("room_id",""))!=room_id or str(actor.get("station_room_id",""))!=room_id or str(actor.get("intent",""))!="FETCH_BOOK" or str(actor.get("phase",""))!="perform" or str(book.get("location_room_id",""))!=room_id:
		return false
	if reserved_book_ids(actor_id).has(book_id):
		return false
	var slot:Dictionary=book_slot(book_id)
	if candidate_navigation!=null and (slot.is_empty() or str(slot.get("room_id",""))!=room_id or str(actor.get("station_anchor_id",""))!=str(slot["station_id"])):
		return false
	if not borrow(actor_id,book_id,int(world.sim_clock)):
		return false
	world._append_journal("BOOK_PICKED_UP_AT_SHELF",actor_id,book_id,room_id,actor_id,{"station_id":str(actor.get("station_anchor_id","")),"shelf_slot_id":str(slot.get("id",""))})
	return true

func return_at_shelf(actor_id:String,book_id:String,room_id:String)->bool:
	var actor:Dictionary=world.residents.get(actor_id,{})
	if str(actor.get("room_id",""))!=room_id or str(actor.get("station_room_id",""))!=room_id or str(actor.get("intent",""))!="RETURN_BOOK" or str(actor.get("phase",""))!="perform":
		return false
	var slot:Dictionary=book_slot(book_id)
	if candidate_navigation!=null and (slot.is_empty() or str(slot.get("room_id",""))!=room_id or str(actor.get("station_anchor_id",""))!=str(slot["station_id"])):
		return false
	if not return_book(actor_id,book_id,room_id):
		return false
	world._append_journal("BOOK_RETURNED_AT_SHELF",actor_id,book_id,actor_id,room_id,{"station_id":str(actor.get("station_anchor_id","")),"shelf_slot_id":str(slot.get("id",""))})
	return true

func reconcile_book_slots()->int:
	if candidate_navigation==null:return 0
	var previous:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{})
	var next:Dictionary={}
	var occupied:Dictionary={}
	var physical:Array=[]
	for book in world.media.get("books",[]):
		if bool(book.get("physical",true)):
			physical.append(book)
	physical.sort_custom(func(a,b):return str(a["id"])<str(b["id"]))
	# Preserve valid previous assignments first, including while held, so a
	# returning volume cannot find its exact physical home filled by another.
	for book in physical:
		var id:String=str(book["id"])
		var prior:Dictionary=previous.get(id,{})
		var room_id:String=str(book.get("location_room_id",""))
		if room_id=="":room_id=str(prior.get("room_id",book.get("home_room_id","")))
		var room:Dictionary=world.room_by_id(room_id)
		if room.is_empty() or room_id!=str(prior.get("room_id","")):
			continue
		for slot in candidate_navigation.book_slots(room):
			var key:String=room_id+"|"+str(slot["id"])
			if str(slot["id"])==str(prior.get("slot_id","")) and not occupied.has(key):
				next[id]=prior.duplicate()
				occupied[key]=true
				break
	for book in physical:
		var id:String=str(book["id"])
		if next.has(id):continue
		var room_id:String=str(book.get("location_room_id",""))
		if room_id=="":room_id=str(book.get("home_room_id",""))
		var room:Dictionary=world.room_by_id(room_id)
		if room.is_empty():continue
		for slot in candidate_navigation.book_slots(room):
			var key:String=room_id+"|"+str(slot["id"])
			if occupied.has(key):continue
			next[id]={"room_id":room_id,"slot_id":str(slot["id"])}
			occupied[key]=true
			break
	world.runtime_state["teea008_book_slot_assignments"]=next
	return next.size()

func book_slot(book_id:String)->Dictionary:
	if candidate_navigation==null:return {}
	var stored:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{}).get(book_id,{})
	var room_id:String=str(stored.get("room_id",""))
	var room:Dictionary=world.room_by_id(room_id)
	if room.is_empty():return {}
	for slot in candidate_navigation.book_slots(room):
		if str(slot["id"])==str(stored.get("slot_id","")):
			var result:Dictionary=slot.duplicate(true)
			result["room_id"]=room_id
			return result
	return {}
