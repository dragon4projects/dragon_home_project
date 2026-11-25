extends RefCounted
## Physical-media lifecycle, independent from camera and autonomous planner.
## Catalogue entries are explicit. No invented titles, playback or ownership.
var world
var candidate_navigation=null
# Simulation policy, not bibliographic length evidence.
const DEFAULT_READING_SECONDS:=18000.0
const READING_SESSION_MIN:=900.0
const READING_SESSION_MAX:=1800.0

func setup(model) -> void:
	world = model
	_normalize_catalogue()
	_migrate_legacy_series_progress()
	_restore_device_sessions()
	prune_device_sessions()
	if candidate_navigation!=null:
		reconcile_book_slots()

func _normalize_catalogue() -> void:
	for book in world.media.get("books", []):
		if not book.has("work_id"):book["work_id"]=str(book["id"])
		if bool(book.get("physical",true)) and not book.has("physical_item_id"):book["physical_item_id"]=str(book["id"])
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

func _reading_state(actor_id:String)->Dictionary:
	if not world.runtime_state.has("reading_state"):world.runtime_state["reading_state"]={}
	var all:Dictionary=world.runtime_state["reading_state"]
	if not all.has(actor_id):all[actor_id]={"works":{},"series":{},"wait_work_id":"","recent":[]}
	return all[actor_id]

func book_work_id(book:Dictionary)->String:
	return str(book.get("work_id",book.get("id","")))

func book_reading_length(book:Dictionary)->float:
	var explicit:float=float(book.get("reading_seconds",0))
	if is_finite(explicit) and explicit>0:return explicit
	return DEFAULT_READING_SECONDS

func book_history(actor_id:String,book:Dictionary)->Dictionary:
	var state:Dictionary=_reading_state(actor_id)
	var works:Dictionary=state["works"]
	var work:String=book_work_id(book)
	if not works.has(work):
		var old:float=float(book.get("progress_by_actor",{}).get(actor_id,0))
		works[work]={"progress":clampf(old,0.0,book_reading_length(book)),"completed_count":0,"complete":false,"total_seconds":maxf(0.0,old)}
	return works[work]

func _series_id(book:Dictionary)->String:
	return str(book.get("series_id",""))

func _volume(book:Dictionary)->int:
	return int(book.get("series_index",0))

func _series_state(actor_id:String,sid:String)->Dictionary:
	var series:Dictionary=_reading_state(actor_id)["series"]
	if not series.has(sid):series[sid]={"next_index":1,"cycle":0,"complete":false,"completed_cycles":0}
	return series[sid]

func _series_volume(sid:String,index:int)->Dictionary:
	for book in world.media.get("books",[]):
		if _series_id(book)==sid and _volume(book)==index:return book
	return {}

func _series_boundary(book:Dictionary)->bool:
	# A declared catalog boundary is not evidence of a literary finale.
	return int(book.get("series_catalog_last_index",0))>0 and _volume(book)==int(book["series_catalog_last_index"])

func book_eligible(actor_id:String,book:Dictionary,now:float)->bool:
	if not bool(book.get("physical",true)) or not is_finite(now):return false
	var row:Dictionary=book_history(actor_id,book)
	if bool(row.get("complete",false)) and now-float(row.get("last_completed_at",0))<world.GAME_DAY_SECONDS:return false
	var sid:String=_series_id(book)
	if sid=="":return true
	var series:Dictionary=_series_state(actor_id,sid)
	if bool(series.get("complete",false)):
		return _volume(book)==1 and now-float(series.get("last_completed_at",0))>=world.GAME_DAY_SECONDS
	return _volume(book)>0 and _volume(book)==int(series.get("next_index",1))

func _book_copy_available(actor_id:String,book:Dictionary)->bool:
	if not bool(book.get("physical",true)) or str(book.get("holder_id",""))!="" or reserved_book_ids(actor_id).has(str(book["id"])):return false
	var room:Dictionary=world.room_by_id(str(book.get("location_room_id","")))
	if not world.is_accessible(room,actor_id):return false
	return candidate_navigation==null or not book_slot(str(book["id"])).is_empty()

func _set_wait(actor_id:String,work:String)->void:
	var state:Dictionary=_reading_state(actor_id)
	if str(state.get("wait_work_id",""))==work:return
	state["wait_work_id"]=work
	if work!="":world._append_journal("WAITING_FOR_BOOK",actor_id,work,"","",{})

func choose_book_options(actor_id:String,rng:RandomNumberGenerator,now:float,record_wait:bool=true)->Array:
	var state:Dictionary=_reading_state(actor_id)
	var target:Dictionary={}
	var best:float=-1.0
	var available:Array=[]
	var detours:Array=[]
	var wait:String=str(state.get("wait_work_id",""))
	for book in world.media.get("books",[]):
		if not book_eligible(actor_id,book,now):continue
		var row:Dictionary=book_history(actor_id,book)
		var sid:String=_series_id(book)
		var score:float=0.0
		if book_work_id(book)==wait:score=4.0
		elif not bool(row.get("complete",false)) and float(row.get("progress",0))>0:score=3.0
		elif sid!="" and int(_series_state(actor_id,sid).get("next_index",1))>1:score=2.0
		if score>best and score>0:
			best=score
			target=book
		if _book_copy_available(actor_id,book):
			available.append(book)
			if sid=="":detours.append(book)
	if not target.is_empty():
		for copy in available:
			if book_work_id(copy)==book_work_id(target):
				if record_wait:_set_wait(actor_id,"")
				return [copy]
		if record_wait:_set_wait(actor_id,book_work_id(target))
		available=detours
	elif wait!="" and record_wait:
		_set_wait(actor_id,"")
	# Weighted choice without replacement; new works favored, known favorites
	# recover over seven simulated days after the hard 24h gate.
	var result:Array=[]
	while not available.is_empty():
		var weights:=PackedFloat32Array()
		for book in available:
			var row:Dictionary=book_history(actor_id,book)
			var n:int=int(row.get("completed_count",0))
			var age:float=now-float(row.get("last_completed_at",0))
			var recovery:float=clampf((age-world.GAME_DAY_SECONDS)/(7.0*world.GAME_DAY_SECONDS),0.0,1.0)
			weights.append(1.0 if n==0 else lerpf(0.10,0.45+0.10*minf(float(n),4.0),recovery))
		var at:int=maxi(0,rng.rand_weighted(weights))
		result.append(available.pop_at(at))
	return result

func has_reading_choice(actor_id:String,now:float)->bool:
	for book in world.media.get("books",[]):
		if book_eligible(actor_id,book,now):return true
	return false

func begin_reading(actor:Dictionary,now:float,duration:float)->bool:
	var id:String=str(actor.get("id",""))
	var book:Dictionary=_lookup("books",str(actor.get("held_book","")))
	if book.is_empty() or str(book.get("holder_id",""))!=id or str(actor.get("intent",""))!="READ_BOOK" or str(actor.get("phase",""))!="perform" or str(actor.get("room_id",""))!=str(actor.get("station_room_id","")) or not world.is_accessible(world.room_by_id(str(actor.get("room_id",""))),id):return false
	if actor.has("reading_session"):return true
	if not is_finite(now) or not is_finite(duration) or duration<=0 or not book_eligible(id,book,now):return false
	var row:Dictionary=book_history(id,book)
	var sid:String=_series_id(book)
	if sid!="":
		var series:Dictionary=_series_state(id,sid)
		if bool(series.get("complete",false)):
			series["complete"]=false
			series["next_index"]=1
			series["cycle"]=int(series.get("cycle",0))+1
	if bool(row.get("complete",false)):
		row["complete"]=false
		row["progress"]=0.0
		row["repeat_cycle"]=int(row.get("repeat_cycle",0))+1
	var remaining:float=maxf(0.0,book_reading_length(book)-float(row["progress"]))
	if remaining<=0:return false
	var seconds:float=minf(duration,remaining)
	actor["reading_session"]={"book_id":str(book["id"]),"room_id":str(actor["room_id"]),"started_at":now,"ends_at":now+seconds}
	actor["until"]=now+seconds
	_reading_state(id)["current_work_id"]=book_work_id(book)
	world._append_journal("BOOK_READING_RESUME" if float(row["progress"])>0 else "BOOK_READING_START",id,str(book["id"]),"",str(actor["room_id"]),{"progress":row["progress"],"ends_at":actor["until"]})
	return true

func pause_reading(actor:Dictionary,now:float)->bool:
	var raw=actor.get("reading_session",{})
	actor.erase("reading_session")
	if typeof(raw)!=TYPE_DICTIONARY or raw.is_empty():return false
	var session:Dictionary=raw
	var start:float=float(session.get("started_at",-1))
	var end:float=float(session.get("ends_at",-1))
	var id:String=str(actor.get("id",""))
	var book_id:String=str(session.get("book_id",""))
	var book:Dictionary=_lookup("books",book_id)
	if book.is_empty() or str(book.get("holder_id",""))!=id or str(actor.get("room_id",""))!=str(session.get("room_id","")) or not is_finite(start) or not is_finite(end) or start<0 or end<=start or now<start:return false
	var elapsed:float=maxf(0.0,minf(now,end)-start)
	if elapsed<=0:return false
	if not read(id,book_id,elapsed):return false
	if not bool(book_history(id,book).get("complete",false)):world._append_journal("BOOK_READING_PAUSE",id,book_id,str(actor["room_id"]),"",{"seconds":elapsed})
	return true

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
	if not _book_copy_available(actor_id,book) or not book_eligible(actor_id,book,float(now)):
		return false
	book["holder_id"] = actor_id
	book["location_room_id"] = ""
	book["idle_since"] = 0
	book["borrowed_at"] = now
	book["last_interaction_at"]=float(now)
	return true

func read(actor_id:String,book_id:String,seconds:float)->bool:
	var book:Dictionary=_lookup("books",book_id)
	if book.is_empty() or str(book.get("holder_id",""))!=actor_id or not is_finite(seconds) or seconds<=0:return false
	var row:Dictionary=book_history(actor_id,book)
	if bool(row.get("complete",false)):return false
	var length:float=book_reading_length(book)
	var applied:float=minf(seconds,maxf(0.0,length-float(row.get("progress",0))))
	row["progress"]=float(row.get("progress",0))+applied
	row["total_seconds"]=float(row.get("total_seconds",0))+applied
	book["progress_by_actor"][actor_id]=row["progress"]
	book["last_interaction_at"]=float(world.sim_clock)
	if float(row["progress"])>=length:
		row["complete"]=true
		row["completed_count"]=int(row.get("completed_count",0))+1
		row["last_completed_at"]=world.sim_clock
		var state:Dictionary=_reading_state(actor_id)
		state["recent"].append(book_work_id(book))
		if state["recent"].size()>32:state["recent"].pop_front()
		var sid:String=_series_id(book)
		if sid!="":
			var series:Dictionary=_series_state(actor_id,sid)
			series["next_index"]=_volume(book)+1
			if _series_boundary(book):
				series["complete"]=true
				series["completed_cycles"]=int(series.get("completed_cycles",0))+1
				series["last_completed_at"]=world.sim_clock
		world._append_journal("BOOK_READING_FINISH",actor_id,book_id,"","",{"completed_count":row["completed_count"],"reading_seconds":length})
	return true

func drop_book(actor_id: String, book_id: String, now: int) -> bool:
	var book: Dictionary = _lookup("books", book_id)
	if book.is_empty() or book.get("holder_id", "") != actor_id:
		return false
	book["holder_id"] = ""
	book["location_room_id"]=""
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
	if not stamps.has(key):
		# Legacy histories do not timestamp every episode. For already
		# completed units use the last known completion conservatively.
		var s:int=int(row.get("last_completed_season",-1))
		var e:int=int(row.get("last_completed_episode",-1))
		if int(row.get("completed_units",0))<=0 or season>s or (season==s and episode>e):return true
		return now-float(row.get("last_completed_at",0))>=world.GAME_DAY_SECONDS
	var last:float=float(stamps[key])
	return is_finite(now) and is_finite(last) and now-last>=world.GAME_DAY_SECONDS

func _migrate_legacy_series_progress()->void:
	var all:Dictionary=world.runtime_state.get("cinema_progress",{})
	for actor_id in all:
		var progress:Dictionary=all[actor_id]
		for id in progress:
			var row:Dictionary=progress[id]
			var item:Dictionary=_lookup("films",str(id))
			if str(item.get("media_type",""))=="series" and _at_catalog_end(row,item):
				row["complete"]=true
				row["completed_count"]=maxi(1,int(row.get("completed_count",0)))
				row["next_season"]=int(row["last_completed_season"])
				row["next_episode"]=int(row["last_completed_episode"])+1

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
	# Prefer eligible continuations as a class, rather than allowing a large
	# catalog of new titles to dilute the active-series priority.
	var continuation:Dictionary={}
	var latest:float=-1.0
	for item in options:
		var row:Dictionary=_cinema_history(actor_id,str(item["id"]))
		var unit:Dictionary=next_watch_unit(actor_id,item,now)
		if str(item.get("media_type",""))=="series" and not row.is_empty() and not bool(unit.get("restart_cycle",false)):
			var last:float=float(row.get("last_completed_at",0))
			if last>latest:
				latest=last
				continuation=item
	if not continuation.is_empty():return continuation
	var weights:=PackedFloat32Array()
	for item in options:
		var id:String=str(item["id"])
		var row:Dictionary=_cinema_history(actor_id,id)
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

# One durable simulated program per physical cinema/audio source.
# Actor records retain a projection of timing for compatibility, but the
# shared program and its attendance map own the authoritative deadline.
func _devices()->Dictionary:
	if not world.runtime_state.has("media_device_sessions"):
		world.runtime_state["media_device_sessions"]={}
	return world.runtime_state["media_device_sessions"]

func _device_key(category:String,room_id:String)->String:
	return room_id+"|"+category

func _session_category(key:String)->String:
	return "films" if key=="watch_session" else "tracks"

func _category_key(category:String)->String:
	return "watch_session" if category=="films" else "listen_session"

func _device_access(actor_id:String,category:String,room_id:String)->bool:
	var room:Dictionary=world.room_by_id(room_id)
	return bool(world.residents.get(actor_id,{}).get("active",false)) and world.public_cutaway_allowed(room) and world.is_accessible(room,actor_id) and str(room.get("type",""))==("cinema" if category=="films" else "music")

func _catalog_unit(category:String,id:String,season:int,episode:int)->Dictionary:
	var item:Dictionary=_lookup(category,id)
	if not bool(item.get("simulation_only",false)):return {}
	var seconds:float=0.0
	if category=="tracks":
		if season!=0 or episode!=0:return {}
		seconds=track_duration(item)
	elif str(item.get("media_type",""))=="film":
		if season!=0 or episode!=0:return {}
		seconds=float(item.get("runtime_seconds",0))
	elif str(item.get("media_type",""))=="series":
		if season<1 or season>int(item.get("latest_season",0)) or (season==int(item.get("latest_season",0)) and episode>int(item.get("latest_episode",0))):return {}
		var runtimes:Array=item.get("episode_runtime_seconds",{}).get(str(season),[])
		if episode<1 or episode>runtimes.size():return {}
		seconds=float(runtimes[episode-1])
	if seconds<=0 or not is_finite(seconds):return {}
	return {"item_id":id,"season":season,"episode":episode,"seconds":seconds}

func _unit_matches(a:Dictionary,b:Dictionary)->bool:
	return not a.is_empty() and not b.is_empty() and str(a.get("item_id",""))==str(b.get("item_id","")) and int(a.get("season",0))==int(b.get("season",0)) and int(a.get("episode",0))==int(b.get("episode",0)) and absf(float(a.get("seconds",0))-float(b.get("seconds",0)))<0.001

func _program_valid(program:Dictionary,category:String,now:float)->bool:
	var start:float=float(program.get("started_at",-1))
	var end:float=float(program.get("ends_at",-1))
	var seconds:float=float(program.get("seconds",0))
	return is_finite(now) and is_finite(start) and is_finite(end) and is_finite(seconds) and start>=0 and start<=now and seconds>0 and absf(end-start-seconds)<0.001 and _unit_matches(program,_catalog_unit(category,str(program.get("item_id","")),int(program.get("season",0)),int(program.get("episode",0))))

func _member_matches(actor:Dictionary,key:String,program:Dictionary)->bool:
	var raw=actor.get(key,{})
	if typeof(raw)!=TYPE_DICTIONARY:return false
	var unit:Dictionary=raw
	var id:String=str(actor.get("id",""))
	var members:Dictionary=program.get("members",{})
	var member:Dictionary=members.get(id,{})
	return not member.is_empty() and bool(actor.get("active",false)) and str(actor.get("phase",""))=="perform" and timed_session_key(actor)==key and str(actor.get("room_id",""))==str(program.get("room_id","")) and str(actor.get("station_room_id",""))==str(program.get("room_id","")) and str(actor.get("activity_media_id",""))==str(program.get("item_id","")) and str(unit.get("session_id",""))==str(program.get("session_id","")) and _unit_matches(unit,program) and float(unit.get("started_at",-1))==float(program.get("started_at",-2)) and float(unit.get("ends_at",-1))==float(program.get("ends_at",-2)) and float(unit.get("joined_at",-1))==float(member.get("joined_at",-2)) and bool(unit.get("full_credit",false))==bool(member.get("full_credit",false))

func _has_member(program:Dictionary,category:String)->bool:
	for id in program.get("members",{}):
		if _member_matches(world.residents.get(id,{}),_category_key(category),program):return true
	return false

func active_device_session(category:String,room_id:String,now:float=-1.0)->Dictionary:
	var at:float=world.sim_clock if now<0.0 else now
	var program:Dictionary=_devices().get(_device_key(category,room_id),{})
	if program.is_empty() or not _program_valid(program,category,at) or at>=float(program["ends_at"]) or not _has_member(program,category):return {}
	return program

func active_device_record(category:String,room_id:String,now:float=-1.0)->Dictionary:
	var program:Dictionary=active_device_session(category,room_id,now)
	return _lookup(category,str(program.get("item_id",""))) if not program.is_empty() else {}

func _full_credit_eligible(actor_id:String,category:String,program:Dictionary,at:float)->bool:
	var id:String=str(program["item_id"])
	if category=="tracks":return listen_repeat_eligible(actor_id,id,at)
	return _unit_matches(program,next_watch_unit(actor_id,_lookup("films",id),at))

func _attendance_eligible(actor_id:String,category:String,program:Dictionary,now:float)->bool:
	if not _device_access(actor_id,category,str(program.get("room_id",""))):return false
	var id:String=str(program["item_id"])
	if category=="tracks":return listen_repeat_eligible(actor_id,id,now)
	var row:Dictionary=_cinema_history(actor_id,id)
	var season:int=int(program.get("season",0))
	var episode:int=int(program.get("episode",0))
	if int(row.get("last_completed_season",-1))==season and int(row.get("last_completed_episode",-1))==episode and now-float(row.get("last_completed_at",0))<world.GAME_DAY_SECONDS:return false
	return _unit_repeat_eligible(row,season,episode,now)

func has_joinable_device(actor_id:String,category:String,now:float)->bool:
	for program in _devices().values():
		var room_id:String=str(program.get("room_id",""))
		if str(program.get("category",""))!=category:continue
		var active:Dictionary=active_device_session(category,room_id,now)
		if not active.is_empty() and _attendance_eligible(actor_id,category,active,now):return true
	return false

func _attach_member(actor:Dictionary,key:String,program:Dictionary,joined:float,full:bool)->void:
	var id:String=str(actor["id"])
	program["members"][id]={"joined_at":joined,"full_credit":full}
	var unit:Dictionary=program.duplicate(true)
	unit.erase("members")
	unit["joined_at"]=joined
	unit["full_credit"]=full
	actor[key]=unit
	actor["until"]=float(program["ends_at"])

func _restore_device_sessions()->void:
	# Legacy snapshots carry actor-local timing only. Adopt a matching
	# legacy deadline without restarting it; conflicting old timings fail closed.
	var ids:Array=world.residents.keys()
	ids.sort()
	for id in ids:
		var actor:Dictionary=world.residents[id]
		var key:String=timed_session_key(actor)
		if key=="" or not actor.has(key):continue
		var raw=actor[key]
		if typeof(raw)!=TYPE_DICTIONARY:continue
		var unit:Dictionary=raw
		if unit.has("session_id"):continue
		var category:String=_session_category(key)
		var rid:String=str(actor.get("room_id",""))
		if str(actor.get("phase",""))!="perform" or rid!=str(actor.get("station_room_id","")) or rid!=str(unit.get("room_id","")) or str(unit.get("item_id",""))!=str(actor.get("activity_media_id","")) or not _device_access(str(id),category,rid) or not _program_valid(unit,category,world.sim_clock):continue
		var device:String=_device_key(category,rid)
		var program:Dictionary=_devices().get(device,{})
		if program.is_empty():
			program=unit.duplicate(true)
			program["session_id"]=_new_session_id()
			program["category"]=category
			program["members"]={}
			_devices()[device]=program
		elif not _unit_matches(unit,program) or float(unit["started_at"])!=float(program["started_at"]) or float(unit["ends_at"])!=float(program["ends_at"]):continue
		var start:float=float(program["started_at"])
		_attach_member(actor,key,program,start,_full_credit_eligible(str(id),category,program,start))

func prune_device_sessions()->void:
	# Discard only invalid/stale references during reconciliation. A valid
	# ended session is retained until its due members settle normally.
	var devices:Dictionary=_devices()
	for device in devices.keys():
		var program:Dictionary=devices[device]
		var category:String=str(program.get("category",""))
		var members:Dictionary=program.get("members",{})
		if not category in ["films","tracks"] or not _program_valid(program,category,world.sim_clock):
			devices.erase(device)
			continue
		for id in members.keys():
			if not _member_matches(world.residents.get(id,{}),_category_key(category),program):members.erase(id)
		if members.is_empty():devices.erase(device)

func _new_session_id()->String:
	var serial:int=int(world.runtime_state.get("media_device_serial",0))+1
	world.runtime_state["media_device_serial"]=serial
	return "MEDIA_"+str(serial)

func timed_session_valid(actor:Dictionary,now:float)->bool:
	var key:String=timed_session_key(actor)
	if key=="" or not actor.has(key):return false
	var category:String=_session_category(key)
	var rid:String=str(actor.get("room_id",""))
	var program:Dictionary=_devices().get(_device_key(category,rid),{})
	if program.is_empty() or not _device_access(str(actor.get("id","")),category,rid) or not _program_valid(program,category,now) or not _member_matches(actor,key,program):return false
	var member:Dictionary=program["members"][str(actor["id"])]
	var joined:float=float(member.get("joined_at",-1))
	if not is_finite(joined) or joined<float(program["started_at"]) or joined>=float(program["ends_at"]) or joined>now:return false
	if bool(member.get("full_credit",false)):
		return joined==float(program["started_at"]) and _full_credit_eligible(str(actor["id"]),category,program,joined)
	return true

func _begin_timed(actor:Dictionary,now:float,category:String)->bool:
	var key:String=_category_key(category)
	if not is_finite(now) or now<0 or timed_session_key(actor)!=key or str(actor.get("phase",""))!="perform":return false
	var rid:String=str(actor.get("room_id",""))
	var id:String=str(actor.get("id",""))
	var item_id:String=str(actor.get("activity_media_id",""))
	if rid=="" or rid!=str(actor.get("station_room_id","")) or not _device_access(id,category,rid):return false
	if actor.has(key):
		if not timed_session_valid(actor,now):return false
		actor["until"]=float(actor[key]["ends_at"])
		return true
	var device:String=_device_key(category,rid)
	var program:Dictionary=active_device_session(category,rid,now)
	if not program.is_empty():
		if str(program["item_id"])!=item_id or not _attendance_eligible(id,category,program,now):return false
		_attach_member(actor,key,program,now,now==float(program["started_at"]) and _full_credit_eligible(id,category,program,now))
		world._append_journal("MEDIA_ATTENDANCE_JOINED",id,item_id,"",rid,{"session_id":program["session_id"],"full_credit":actor[key]["full_credit"],"ends_at":program["ends_at"]})
		return true
	# Do not replace an ended program before its due attendees settle.
	var old:Dictionary=_devices().get(device,{})
	if not old.is_empty() and _has_member(old,category):return false
	var unit:Dictionary={}
	if category=="films":
		unit=next_watch_unit(id,_lookup(category,item_id),now)
	else:
		if listen_repeat_eligible(id,item_id,now):unit=_catalog_unit(category,item_id,0,0)
	if unit.is_empty():return false
	program=unit.duplicate(true)
	program.merge({"category":category,"room_id":rid,"session_id":_new_session_id(),"started_at":now,"ends_at":now+float(unit["seconds"]),"members":{}},true)
	_devices()[device]=program
	_attach_member(actor,key,program,now,true)
	world._append_journal("MEDIA_SESSION_STARTED",id,item_id,"",rid,{"session_id":program["session_id"],"seconds":unit["seconds"]})
	return true

func begin_watch(actor:Dictionary,now:float)->bool:
	return _begin_timed(actor,now,"films")

func _settle_attendance(actor:Dictionary,key:String,now:float,full:bool,reason:String)->void:
	var raw=actor.get(key,{})
	if typeof(raw)!=TYPE_DICTIONARY:return
	var unit:Dictionary=raw
	var category:String=_session_category(key)
	var device:String=_device_key(category,str(unit.get("room_id","")))
	var program:Dictionary=_devices().get(device,{})
	var id:String=str(actor.get("id",""))
	if program.is_empty() or str(program.get("session_id",""))!=str(unit.get("session_id","")):return
	var members:Dictionary=program.get("members",{})
	var member:Dictionary=members.get(id,{})
	if member.is_empty():return
	var joined:float=float(member.get("joined_at",-1))
	if not _program_valid(program,category,now) or not is_finite(joined) or joined<float(program["started_at"]) or joined>now or joined>=float(program["ends_at"]):
		members.erase(id)
		if members.is_empty():_devices().erase(device)
		return
	var elapsed:float=clampf(minf(now,float(program["ends_at"]))-joined,0.0,float(program["seconds"]))
	var all:Dictionary=world.runtime_state.get("media_attendance",{})
	var per_actor:Dictionary=all.get(id,{})
	var item_key:String=category+"|"+str(program["item_id"])
	var row:Dictionary=per_actor.get(item_key,{})
	row["attended_seconds"]=float(row.get("attended_seconds",0))+elapsed
	row["full_sessions"]=int(row.get("full_sessions",0))+(1 if full else 0)
	row["partial_sessions"]=int(row.get("partial_sessions",0))+(0 if full else 1)
	per_actor[item_key]=row
	all[id]=per_actor
	world.runtime_state["media_attendance"]=all
	members.erase(id)
	if members.is_empty():_devices().erase(device)
	world._append_journal("MEDIA_ATTENDANCE_ENDED",id,str(program["item_id"]),str(program["room_id"]),"",{"session_id":program["session_id"],"seconds":elapsed,"full_credit":full,"reason":reason})

func cancel_timed_media(actor:Dictionary,now:float)->void:
	for key in ["watch_session","listen_session"]:
		if actor.has(key):
			_settle_attendance(actor,key,now,false,"INTERRUPTED")
			actor.erase(key)

func finish_watch(actor:Dictionary,now:float)->bool:
	if timed_session_key(actor)!="watch_session" or not timed_session_valid(actor,now):return false
	var unit:Dictionary=actor["watch_session"]
	if now<float(unit["ends_at"]):return false
	if not bool(unit.get("full_credit",false)):
		_settle_attendance(actor,"watch_session",now,false,"PARTIAL_END")
		actor.erase("watch_session")
		return true
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
	_settle_attendance(actor,"watch_session",now,true,"COMPLETE")
	actor.erase("watch_session")
	world._append_journal("CINEMA_UNIT_COMPLETED",actor_id,id,"",str(actor.get("room_id","")),{"season":season,"episode":episode,"seconds":unit["seconds"]})
	return true

func can_watch(actor_id:String,item_id:String,room_id:String,now:float=-1.0)->bool:
	var at:float=world.sim_clock if now<0.0 else now
	if not _device_access(actor_id,"films",room_id):return false
	var active:Dictionary=active_device_session("films",room_id,at)
	if not active.is_empty():return str(active["item_id"])==item_id and _attendance_eligible(actor_id,"films",active,at)
	return not next_watch_unit(actor_id,_lookup("films",item_id),at).is_empty()

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
	return _begin_timed(actor,now,"tracks")

func finish_listen(actor:Dictionary,now:float)->bool:
	if timed_session_key(actor)!="listen_session" or not timed_session_valid(actor,now):return false
	var unit:Dictionary=actor["listen_session"]
	if now<float(unit["ends_at"]):return false
	if not bool(unit.get("full_credit",false)):
		_settle_attendance(actor,"listen_session",now,false,"PARTIAL_END")
		actor.erase("listen_session")
		return true
	var id:String=str(unit["item_id"])
	var actor_id:String=str(actor["id"])
	var all:Dictionary=world.runtime_state.get("music_progress",{})
	var history:Dictionary=all.get(actor_id,{})
	var previous:Dictionary=history.get(id,{})
	history[id]={"completed_count":int(previous.get("completed_count",0))+1,"total_seconds":float(previous.get("total_seconds",0))+float(unit["seconds"]),"last_completed_at":now}
	all[actor_id]=history
	world.runtime_state["music_progress"]=all
	_settle_attendance(actor,"listen_session",now,true,"COMPLETE")
	actor.erase("listen_session")
	world._append_journal("MUSIC_TRACK_COMPLETED",actor_id,id,"",str(actor.get("room_id","")),{"seconds":unit["seconds"],"completed_count":history[id]["completed_count"]})
	return true

func can_listen(actor_id:String,item_id:String,room_id:String,now:float=-1.0)->bool:
	var at:float=world.sim_clock if now<0.0 else now
	if not _device_access(actor_id,"tracks",room_id):return false
	var active:Dictionary=active_device_session("tracks",room_id,at)
	if not active.is_empty():return str(active["item_id"])==item_id and _attendance_eligible(actor_id,"tracks",active,at)
	return track_duration(_lookup("tracks",item_id))>0 and listen_repeat_eligible(actor_id,item_id,at)

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
		if world.is_accessible(room,actor_id) and not reserved.has(str(book["id"])) and book_eligible(actor_id,book,world.sim_clock):
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

func free_book_slot(book_id:String,room:Dictionary)->Dictionary:
	if candidate_navigation==null or not world.public_cutaway_allowed(room):return {}
	var assignments:Dictionary=world.runtime_state.get("teea008_book_slot_assignments",{})
	var occupied:Dictionary={}
	for id in assignments:
		if str(id)==book_id:continue
		var entry:Dictionary=assignments[id]
		if str(entry.get("room_id",""))==str(room["id"]):occupied[str(entry["slot_id"])]=true
	for slot in candidate_navigation.book_slots(room):
		if not occupied.has(str(slot["id"])):return slot
	return {}

func return_at_shelf(actor_id:String,book_id:String,room_id:String)->bool:
	var actor:Dictionary=world.residents.get(actor_id,{})
	if str(actor.get("room_id",""))!=room_id or str(actor.get("station_room_id",""))!=room_id or str(actor.get("intent",""))!="RETURN_BOOK" or str(actor.get("phase",""))!="perform":
		return false
	var slot:Dictionary=book_slot(book_id)
	if candidate_navigation!=null:
		var wanted:String=str(actor.get("book_return_slot",""))
		if wanted!="":
			slot={}
			for candidate in candidate_navigation.book_slots(world.room_by_id(room_id)):
				if str(candidate["id"])!=wanted:continue
				var used:bool=false
				for other in world.runtime_state.get("teea008_book_slot_assignments",{}):
					var entry:Dictionary=world.runtime_state["teea008_book_slot_assignments"][other]
					if str(other)!=book_id and str(entry.get("room_id",""))==room_id and str(entry.get("slot_id",""))==wanted:used=true
				if not used:slot=candidate.duplicate(true);slot["room_id"]=room_id
				break
		if slot.is_empty() or str(slot.get("room_id",""))!=room_id or str(actor.get("station_anchor_id",""))!=str(slot["station_id"]):return false
	if not return_book(actor_id,book_id,room_id):
		return false
	if candidate_navigation!=null:
		world.runtime_state["teea008_book_slot_assignments"][book_id]={"room_id":room_id,"slot_id":str(slot["id"])}
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
