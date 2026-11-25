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
		if not book.has("last_interaction_at"):
			var old:float=float(book.get("idle_since",0))
			book["last_interaction_at"]=old if old>0 and old<=world.sim_clock else world.sim_clock
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
	book["last_interaction_at"]=float(now)
	return true

func read(actor_id: String, book_id: String, seconds: float) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	var progress: Dictionary = book.get("progress_by_actor", {})
	progress[actor_id] = maxf(0.0, float(progress.get(actor_id, 0.0)) + seconds)
	book["progress_by_actor"] = progress
	book["last_interaction_at"]=float(world.sim_clock)
	return true

func drop_book(actor_id: String, book_id: String, now: int) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	book["holder_id"] = ""
	book["idle_since"] = now
	book["last_interaction_at"]=float(now)
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
	book["last_interaction_at"]=float(world.sim_clock)
	return true

func cleanup_abandoned(now: int) -> int:
	return _rolling_book_returns(float(now))

func tick_book_home_reset() -> int:
	return _rolling_book_returns(float(world.sim_clock))

func _rolling_book_returns(now:float)->int:
	var count:=0
	var pending:Dictionary={}
	var reserved:Dictionary=reserved_book_ids()
	for book in world.media.get("books",[]):
		if not bool(book.get("physical",true)):continue
		var id:String=str(book["id"])
		var home:String=str(book.get("home_room_id",""))
		var previous:String=str(book.get("location_room_id",""))
		var holder:String=str(book.get("holder_id",""))
		if holder=="" and previous==home:continue
		var last:float=float(book.get("last_interaction_at",now))
		var age:float=now-last
		if age<=world.RETURN_PREPARE_SECONDS:continue
		pending[id]={"due_at":last+world.GAME_DAY_SECONDS,"reason":"WAIT_DUE"}
		if age<world.GAME_DAY_SECONDS:continue
		if holder!="" or reserved.has(id):
			pending[id]["reason"]="ACTIVE_USE"
			continue
		if previous!="" and not world.public_cutaway_allowed(world.room_by_id(previous)):
			pending[id]["reason"]="SOURCE_NOT_AUTHORIZED"
			continue
		var room_id:String=home
		if candidate_navigation!=null:
			var slot:Dictionary=_book_return_slot(id,home)
			if slot.is_empty():
				pending[id]["reason"]="NO_COMPATIBLE_AUTHORIZED_SLOT"
				continue
			room_id=str(slot["room_id"])
			var assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{})
			assignments[id]={"room_id":room_id,"slot_id":str(slot["id"])}
			world.runtime_state["teea008_book_slot_assignments"]=assignments
		elif not world.public_cutaway_allowed(world.room_by_id(home)):
			pending[id]["reason"]="NO_AUTHORIZED_HOME"
			continue
		book["location_room_id"]=room_id
		book["idle_since"]=0
		book["last_interaction_at"]=now
		book.erase("borrowed_at")
		world._append_journal("BOOK_RESTORED_HOME","HOUSE_SPIRIT",id,previous,room_id,{"sim_clock":now})
		pending.erase(id)
		count+=1
	world.runtime_state["housekeeping_pending_books"]=pending
	world.runtime_state.erase("book_home_reset_day")
	return count

func _book_return_slot(id:String,home:String)->Dictionary:
	var assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{})
	var used:Dictionary={}
	for other in assignments:
		if str(other)==id:continue
		var entry:Dictionary=assignments[other]
		used[str(entry.get("room_id",""))+"|"+str(entry.get("slot_id",""))]=true
	var rooms:Array=world.matching_rooms(["library"])
	var preferred:Dictionary=world.room_by_id(home)
	if not preferred.is_empty():
		rooms.erase(preferred)
		rooms.push_front(preferred)
	var prior:Dictionary=assignments.get(id,{})
	for room in rooms:
		if not world.public_cutaway_allowed(room):continue
		var rid:String=str(room["id"])
		var slots:Array=candidate_navigation.book_slots(room).duplicate()
		for slot in slots.duplicate():
			if rid==str(prior.get("room_id","")) and str(slot["id"])==str(prior.get("slot_id","")):
				slots.erase(slot)
				slots.push_front(slot)
				break
		for slot in slots:
			if used.has(rid+"|"+str(slot["id"])):continue
			var result:Dictionary=slot.duplicate(true)
			result["room_id"]=rid
			return result
	return {}

# Legacy API: local bytes never make a work playable. Use duration-based candidates.
func playable(_kind: String) -> Array:
	return []

func _cinema_history(actor_id:String,id:String)->Dictionary:
	return world.runtime_state.get("cinema_progress",{}).get(actor_id,{}).get(id,{})

func _episode_key(season:int,episode:int)->String:
	return "%d:%d" % [season,episode]

func _at_catalog_end(row:Dictionary,item:Dictionary)->bool:
	var s:int=int(item.get("latest_season",0))
	var e:int=int(item.get("latest_episode",0))
	return s>0 and e>0 and int(row.get("last_completed_season",0))==s and int(row.get("last_completed_episode",0))==e

func _unit_repeat_eligible(row:Dictionary,season:int,episode:int,now:float)->bool:
	var stamps:Dictionary=row.get("unit_completed_at",{})
	var key:String=_episode_key(season,episode)
	if not stamps.has(key):return true
	var last:float=float(stamps[key])
	return is_finite(now) and is_finite(last) and now-last>=world.GAME_DAY_SECONDS

func next_watch_unit(actor_id:String,item:Dictionary,now:float=-1.0)->Dictionary:
	if not bool(item.get("simulation_only",false)):return {}
	var at:float=world.sim_clock if now<0.0 else now
	var id:String=str(item.get("id",""))
	if id=="" or not is_finite(at):return {}
	var progress:Dictionary=_cinema_history(actor_id,id)
	if str(item.get("media_type",""))=="film":
		if bool(progress.get("complete",false)) and at-float(progress.get("last_completed_at",0))<world.GAME_DAY_SECONDS:return {}
		var duration:float=float(item.get("runtime_seconds",0))
		if duration<=0 or not is_finite(duration):return {}
		return {"item_id":id,"season":0,"episode":0,"seconds":duration}
	if str(item.get("media_type",""))!="series":return {}
	var season:int=int(progress.get("next_season",1))
	var episode:int=int(progress.get("next_episode",1))
	var latest_season:int=int(item.get("latest_season",0))
	var latest_episode:int=int(item.get("latest_episode",0))
	# A legacy caught-up row is also a completed cycle. Only the declared
	# source boundary counts, never exhaustion of a partially researched array.
	var restart_cycle:bool=_at_catalog_end(progress,item)
	if restart_cycle:
		if at-float(progress.get("last_completed_at",0))<world.GAME_DAY_SECONDS:return {}
		season=1
		episode=1
	# If authoring extended a completed series, use its saved next cursor.
	# Crossing into a new season still requires explicit completeness.
	var completed_seasons:Array=item.get("complete_seasons",[])
	var current:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
	if not current.is_empty() and episode>current.size() and completed_seasons.any(func(value):return int(value)==season) and season<latest_season:
		season+=1
		episode=1
	if season<1 or season>latest_season or (season==latest_season and episode>latest_episode):return {}
	var runtimes:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
	if episode<1 or episode>runtimes.size() or not _unit_repeat_eligible(progress,season,episode,at):return {}
	var duration:float=float(runtimes[episode-1])
	if duration<=0 or not is_finite(duration):return {}
	return {"item_id":id,"season":season,"episode":episode,"seconds":duration,"restart_cycle":restart_cycle}

func watch_candidates(actor_id:String,now:float=-1.0)->Array:
	var result:Array=[]
	for item in world.media.get("films",[]):
		if not next_watch_unit(actor_id,item,now).is_empty():result.append(item)
	return result

func choose_watch_item(actor_id:String,rng:RandomNumberGenerator,now:float)->Dictionary:
	var options:Array=watch_candidates(actor_id,now)
	if options.is_empty():return {}
	var weights:=PackedFloat32Array()
	for item in options:
		var id:String=str(item["id"])
		var row:Dictionary=_cinema_history(actor_id,id)
		var unit:Dictionary=next_watch_unit(actor_id,item,now)
		if str(item.get("media_type",""))=="series" and not row.is_empty() and not bool(unit.get("restart_cycle",false)):
			# An unfinished series or newly added episode is a continuation.
			weights.append(6.0)
			continue
		var n:int=int(row.get("completed_count",1 if not row.is_empty() else 0))
		var age:float=now-float(row.get("last_completed_at",0))
		var recovery:float=clampf((age-world.GAME_DAY_SECONDS)/(7.0*world.GAME_DAY_SECONDS),0.0,1.0)
		weights.append(1.0 if n==0 else lerpf(0.10,0.45+0.10*minf(float(n),4.0),recovery))
	return options[maxi(0,rng.rand_weighted(weights))]

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
		if not can_watch(str(actor["id"]),item_id,room_id,start):return false
		var expected:Dictionary=next_watch_unit(str(actor["id"]),_lookup("films",item_id),start)
		return int(expected.get("season",-1))==int(unit.get("season",-2)) and int(expected.get("episode",-1))==int(unit.get("episode",-2))
	return can_listen(str(actor["id"]),item_id,room_id,start)

func _timed_arrival_valid(actor:Dictionary,now:float,intent:String)->bool:
	if not is_finite(now) or now<0.0 or str(actor.get("intent",""))!=intent or str(actor.get("phase",""))!="perform":return false
	var room_id:String=str(actor.get("room_id",""))
	if room_id=="" or room_id!=str(actor.get("station_room_id","")):return false
	var actor_id:String=str(actor.get("id",""))
	var item_id:String=str(actor.get("activity_media_id",""))
	if intent=="WATCH_FILM":return can_watch(actor_id,item_id,room_id,now)
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
	var unit:Dictionary=next_watch_unit(str(actor["id"]),item,now)
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
	var expected:Dictionary=next_watch_unit(str(actor["id"]),item,float(unit["started_at"]))
	if expected.is_empty() or int(expected["season"])!=int(unit["season"]) or int(expected["episode"])!=int(unit["episode"]):return false
	var all:Dictionary=world.runtime_state.get("cinema_progress",{})
	var actor_id:String=str(actor["id"])
	var progress:Dictionary=all.get(actor_id,{})
	var season:int=int(unit["season"])
	var episode:int=int(unit["episode"])
	var previous:Dictionary=progress.get(id,{})
	var row:Dictionary=previous.duplicate(true)
	row.merge({"last_completed_season":season,"last_completed_episode":episode,"last_completed_at":now,"complete":false,"completed_units":int(previous.get("completed_units",0))+1,"total_seconds":float(previous.get("total_seconds",0))+float(unit["seconds"])},true)
	var stamps:Dictionary=row.get("unit_completed_at",{})
	stamps[_episode_key(season,episode)]=now
	row["unit_completed_at"]=stamps
	var old_count:int=int(previous.get("completed_count",1 if bool(previous.get("complete",false)) else 0))
	# Migrate an old caught-up record before its first repeat.
	if _at_catalog_end(previous,item):old_count=maxi(1,old_count)
	row["completed_count"]=old_count
	if season==0:
		row["complete"]=true
		row["completed_count"]=old_count+1
	else:
		var latest_season:int=int(item.get("latest_season",0))
		var latest_episode:int=int(item.get("latest_episode",0))
		var runtimes:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
		row["repeat_cycle"]=int(previous.get("repeat_cycle",0))+(1 if bool(expected.get("restart_cycle",false)) else 0)
		if season==latest_season and episode==latest_episode:
			row["complete"]=true
			row["completed_count"]=old_count+1
			row["next_season"]=season
			row["next_episode"]=episode+1
		elif episode==runtimes.size() and season<latest_season and item.get("complete_seasons",[]).any(func(value):return int(value)==season):
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

func can_watch(actor_id: String, item_id: String, room_id: String, now:float=-1.0) -> bool:
	if not world.residents.get(actor_id, {}).get("active", false) or world.room_by_id(room_id).get("type", "")!="cinema":return false
	var item:Dictionary=_lookup("films",item_id)
	return not next_watch_unit(actor_id,item,now).is_empty()

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
