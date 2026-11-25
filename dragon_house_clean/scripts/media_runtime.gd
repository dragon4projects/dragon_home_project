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

# Legacy API: local bytes never make a work playable. Use duration-based candidates.
func playable(_kind: String) -> Array:
	return []

func next_watch_unit(actor_id:String,item:Dictionary)->Dictionary:
	if not bool(item.get("simulation_only",false)):return {}
	var id:String=str(item.get("id",""))
	if id=="":return {}
	var progress:Dictionary=world.runtime_state.get("cinema_progress",{}).get(actor_id,{}).get(id,{})
	if str(item.get("media_type",""))=="film":
		if bool(progress.get("complete",false)) and world.sim_clock-float(progress.get("last_completed_at",0))<world.GAME_DAY_SECONDS:return {}
		var duration:float=float(item.get("runtime_seconds",0))
		if duration<=0 or not is_finite(duration):return {}
		return {"item_id":id,"season":0,"episode":0,"seconds":duration}
	if str(item.get("media_type",""))!="series":return {}
	var season:int=int(progress.get("next_season",1))
	var episode:int=int(progress.get("next_episode",1))
	# Advance an exhausted season only with explicit evidence of its
	# completeness. A partial array is NOT a season finale.
	var completed_seasons:Array=item.get("complete_seasons",[])
	var current:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
	if not current.is_empty() and episode>current.size() and completed_seasons.any(func(value):return int(value)==season) and season<int(item.get("latest_season",0)):
		season+=1
		episode=1
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

func timed_session_key(actor:Dictionary)->String:
	match str(actor.get("intent","")):
		"WATCH_FILM":return "watch_session"
		"LISTEN_MUSIC":return "listen_session"
	return ""

func timed_session_valid(actor:Dictionary,now:float)->bool:
	if not is_finite(now):return false
	var key:String=timed_session_key(actor)
	if key=="" or not actor.has(key) or str(actor.get("phase",""))!="perform":return false
	var raw=actor[key]
	if typeof(raw)!=TYPE_DICTIONARY:return false
	var unit:Dictionary=raw
	var start:float=float(unit.get("started_at",-1))
	var end:float=float(unit.get("ends_at",-1))
	var seconds:float=float(unit.get("seconds",0))
	if not is_finite(start) or not is_finite(end) or not is_finite(seconds) or start<0 or start>now or seconds<=0 or absf(end-start-seconds)>0.001:return false
	var room_id:String=str(actor.get("room_id",""))
	if room_id=="" or room_id!=str(unit.get("room_id","")) or room_id!=str(actor.get("station_room_id","")):return false
	var item_id:String=str(actor.get("activity_media_id",""))
	if item_id=="" or item_id!=str(unit.get("item_id","")):return false
	if key=="watch_session":
		if not can_watch(str(actor["id"]),item_id,room_id):return false
		var expected:Dictionary=next_watch_unit(str(actor["id"]),_lookup("films",item_id))
		return int(expected.get("season",-1))==int(unit.get("season",-2)) and int(expected.get("episode",-1))==int(unit.get("episode",-2))
	return can_listen(str(actor["id"]),item_id,room_id,start)

func _timed_arrival_valid(actor:Dictionary,now:float,intent:String)->bool:
	if not is_finite(now) or now<0.0 or str(actor.get("intent",""))!=intent or str(actor.get("phase",""))!="perform":return false
	var room_id:String=str(actor.get("room_id",""))
	if room_id=="" or room_id!=str(actor.get("station_room_id","")):return false
	var actor_id:String=str(actor.get("id",""))
	var item_id:String=str(actor.get("activity_media_id",""))
	if intent=="WATCH_FILM":return can_watch(actor_id,item_id,room_id)
	if intent=="LISTEN_MUSIC":return can_listen(actor_id,item_id,room_id,now)
	return false

func begin_watch(actor:Dictionary,now:float)->bool:
	if not _timed_arrival_valid(actor,now,"WATCH_FILM"):return false
	# Duplicate arrival/reconciliation must not restart an active commitment.
	if actor.has("watch_session"):
		if not timed_session_valid(actor,now):return false
		actor["until"]=float(actor["watch_session"]["ends_at"])
		return true
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
	if timed_session_key(actor)!="watch_session" or not timed_session_valid(actor,now):return false
	var unit:Dictionary=actor["watch_session"]
	if now<float(unit["ends_at"]):return false
	var id:String=str(unit["item_id"])
	var item:Dictionary=_lookup("films",id)
	var expected:Dictionary=next_watch_unit(str(actor["id"]),item)
	if expected.is_empty() or int(expected["season"])!=int(unit["season"]) or int(expected["episode"])!=int(unit["episode"]):return false
	var all:Dictionary=world.runtime_state.get("cinema_progress",{})
	var actor_id:String=str(actor["id"])
	var progress:Dictionary=all.get(actor_id,{})
	var season:int=int(unit["season"])
	var episode:int=int(unit["episode"])
	var previous:Dictionary=progress.get(id,{})
	var row:Dictionary={"last_completed_season":season,"last_completed_episode":episode,"last_completed_at":now,"complete":false,"completed_units":int(previous.get("completed_units",0))+1,"total_seconds":float(previous.get("total_seconds",0))+float(unit["seconds"])}
	if season==0:
		row["complete"]=true
		row["completed_count"]=int(previous.get("completed_count",1 if bool(previous.get("complete",false)) else 0))+1
	else:
		var latest_season:int=int(item.get("latest_season",0))
		var latest_episode:int=int(item.get("latest_episode",0))
		var runtimes:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
		if season==latest_season and episode>=latest_episode:
			# Caught up to the source snapshot, not necessarily series finale.
			row["next_season"]=season
			row["next_episode"]=episode+1
		elif episode==runtimes.size() and season<latest_season and item.get("complete_seasons",[]).any(func(value):return int(value)==season):
			# Explicitly verified complete earlier season.
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

func listen_history(actor_id:String,item_id:String)->Dictionary:
	return world.runtime_state.get("music_progress",{}).get(actor_id,{}).get(item_id,{})

func listen_repeat_eligible(actor_id:String,item_id:String,now:float)->bool:
	var history:Dictionary=listen_history(actor_id,item_id)
	if int(history.get("completed_count",0))<=0:return true
	var last:float=float(history.get("last_completed_at",0))
	return is_finite(now) and is_finite(last) and now-last>=world.GAME_DAY_SECONDS

func listen_candidates(actor_id:String="",now:float=-1.0)->Array:
	var at:float=world.sim_clock if now<0.0 else now
	var out:Array=[]
	for item in world.media.get("tracks",[]):
		if track_duration(item)>0 and (actor_id=="" or listen_repeat_eligible(actor_id,str(item["id"]),at)):
			out.append(item)
	return out

func choose_listen_item(actor_id:String,rng:RandomNumberGenerator,now:float)->Dictionary:
	var options:Array=listen_candidates(actor_id,now)
	if options.is_empty():return {}
	# New works have weight 1. Eligible repeats gradually recover over seven
	# game days, with a bounded familiar-favorite bonus.
	var weights:=PackedFloat32Array()
	for item in options:
		var history:Dictionary=listen_history(actor_id,str(item["id"]))
		var n:int=int(history.get("completed_count",0))
		var age:float=now-float(history.get("last_completed_at",0))
		var recovery:float=clampf((age-world.GAME_DAY_SECONDS)/(7.0*world.GAME_DAY_SECONDS),0.0,1.0)
		weights.append(1.0 if n==0 else lerpf(0.10,0.45+0.10*minf(float(n),4.0),recovery))
	var index:int=rng.rand_weighted(weights)
	return options[maxi(0,index)]

func begin_listen(actor:Dictionary,now:float)->bool:
	if not _timed_arrival_valid(actor,now,"LISTEN_MUSIC"):return false
	if actor.has("listen_session"):
		if not timed_session_valid(actor,now):return false
		actor["until"]=float(actor["listen_session"]["ends_at"])
		return true
	var item_id:String=str(actor.get("activity_media_id",""))
	var duration:float=track_duration(_lookup("tracks",item_id))
	if duration<=0:return false
	actor["listen_session"]={"item_id":item_id,"started_at":now,"ends_at":now+duration,"seconds":duration,"room_id":str(actor.get("room_id",""))}
	actor["until"]=now+duration
	return true

func finish_listen(actor:Dictionary,now:float)->bool:
	if timed_session_key(actor)!="listen_session" or not timed_session_valid(actor,now):return false
	var unit:Dictionary=actor["listen_session"]
	if now<float(unit["ends_at"]):return false
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

func can_listen(actor_id: String, item_id: String, room_id: String, now:float=-1.0) -> bool:
	var at:float=world.sim_clock if now<0.0 else now
	return world.residents.get(actor_id, {}).get("active", false) and world.room_by_id(room_id).get("type", "")=="music" and track_duration(_lookup("tracks",item_id))>0 and listen_repeat_eligible(actor_id,item_id,at)


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
