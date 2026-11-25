extends RefCounted
const MediaRuntime = preload("res://scripts/media_runtime.gd")
const CandidateCupRuntime = preload("res://scripts/teea008_cup_runtime.gd")
const CandidateTraffic = preload("res://scripts/teea008_traffic.gd")
const CanonicalLiftCapacity = preload("res://scripts/canonical_lift_capacity.gd")
const RoomLocomotion = preload("res://scripts/room_locomotion.gd")
const RoomStations = preload("res://scripts/room_stations.gd")
const AmbientCreatureRuntime = preload("res://scripts/ambient_creature_runtime.gd")
const LifeScheduler = preload("res://scripts/life_scheduler_v2.gd")
## Autonomous utility/need scheduler. No external events or AI dependency.
var world
var media_runtime = MediaRuntime.new()
var locomotion = RoomLocomotion.new()
var stations = RoomStations.new()
var creature_runtime = AmbientCreatureRuntime.new()
var life_scheduler = LifeScheduler.new()
var rng := RandomNumberGenerator.new()
var clock := 0.0
var max_jobs_per_tick := 2
var idle_retry_seconds := 8.0
var moving_ids: Dictionary = {}
var planner_calls := 0
var planner_usec_total := 0
var planner_usec_max := 0
var log: Array = []
var steps := 0
var candidate_navigation=null
var candidate_media_bindings=null
var planning_routes:Dictionary={}
var planning_pressure:Dictionary={}
var planning_actor_id:String=""
var planner_graph_signature:int=0
var planner_graph:Dictionary={}
var planner_route_queries:int=0
var planner_graph_rebuilds:int=0
var planner_sample_usec:Array=[]
var candidate_cups=CandidateCupRuntime.new()
var candidate_traffic=CandidateTraffic.new()
var canonical_lifts=CanonicalLiftCapacity.new()
# Deterministic QA may inject a daypart; production uses the system clock.
var daypart_override: String=""
var last_cleanup_wall_time := 0

const HUMAN_STATUS := {
	"REST": "отдыхает", "SLEEP": "спит",
	"WORK_CREATE": "занимается делами", "READ_BOOK": "читает книгу",
	"BROWSE_BOOK_CATALOG": "просматривает книжный каталог",
	"BROWSE_FILMS": "выбирает фильм", "BROWSE_AUDIO": "выбирает музыку",
	"GET_COFFEE": "готовит кофе", "WATCH_FIRE": "смотрит на огонь",
	"TALK_PAIR": "разговаривает", "LISTEN_MUSIC": "слушает музыку",
	"WATCH_FILM": "смотрит фильм", "VIEW_ART": "рассматривает артефакты",
	"PURPOSEFUL_EXPLORE": "исследует Дом"
}
const TRAVEL_STATUS := {
	"REST": "идёт отдыхать", "SLEEP": "идёт спать",
	"FETCH_BOOK":"идёт к книжной полке", "RETURN_BOOK":"несёт книгу обратно на полку",
	"WORK_CREATE": "идёт работать", "READ_BOOK": "идёт читать",
	"BROWSE_BOOK_CATALOG": "идёт к книжному каталогу",
	"BROWSE_FILMS": "идёт выбирать фильм", "BROWSE_AUDIO": "идёт к аудиотеке",
	"GET_COFFEE": "идёт за кофе", "WATCH_FIRE": "идёт к очагу",
	"TALK_PAIR": "идёт на встречу", "LISTEN_MUSIC": "идёт слушать музыку",
	"WATCH_FILM": "идёт смотреть фильм", "VIEW_ART": "идёт к артефактам",
	"PURPOSEFUL_EXPLORE": "гуляет по Дому"
}

func _quoted_media_title(actor: Dictionary, category_key: String,
		id_key: String) -> String:
	var category:String=str(actor.get(category_key,""))
	var item_id:String=str(actor.get(id_key,""))
	if category=="" or item_id=="":
		return ""
	var item:Dictionary=media_runtime._lookup(category,item_id)
	var title:String=str(item.get("title","")) if not item.is_empty() else ""
	if title=="":
		title=str(actor.get("activity_media_title",""))
	return ("«"+title+"»") if title!="" else ""

func status(actor: Dictionary) -> String:
	var intent: String = str(actor.get("intent","REST"))
	if candidate_navigation!=null and intent=="GET_COFFEE":
		var cup:Dictionary=world.physical_object(str(actor.get("cup_task_id","")))
		if str(actor.get("phase",""))=="travel":
			return "идёт за чашкой"
		if str(cup.get("current_holder_id",""))==str(actor["id"]):
			var content:Dictionary=candidate_cups.beverages.content(str(actor.get("cup_task_id","")))
			if float(content.get("remaining_ml",0))>0:
				return "пьёт "+str(content["display_name"])
			return "держит "+str(cup.get("display_name","чашку"))
		return "свободна" if not actor.has("cup_task_stage") else "ожидает чашку"
	if actor.get("phase","idle") == "travel":
		return str(TRAVEL_STATUS.get(intent, "идёт по делу"))
	var active_title:=_quoted_media_title(
		actor,"activity_media_category","activity_media_id")
	if active_title!="":
		match intent:
			"READ_BOOK": return "читает "+active_title
			"WATCH_FILM": return "смотрит "+active_title
			"LISTEN_MUSIC": return "слушает "+active_title
	if intent=="VIEW_ART":
		var viewing_id:String=str(actor.get("viewing_object_id",""))
		if viewing_id!="":
			var display:Dictionary=world.physical_object(viewing_id)
			if not display.is_empty():
				return "рассматривает "+str(display.get("display_name",viewing_id))
	var browse_title:=_quoted_media_title(
		actor,"browsing_category","browsing_item_id")
	if browse_title!="":
		match intent:
			"BROWSE_BOOK_CATALOG": return "смотрит в каталоге "+browse_title
			"BROWSE_FILMS": return "выбирает фильм "+browse_title
			"BROWSE_AUDIO": return "выбирает музыку "+browse_title
	return str(HUMAN_STATUS.get(intent,"отдыхает"))

const INTENTS := {
	"REST": ["rest", "private", "guest"], "SLEEP": ["rest", "private", "guest"],
	"WORK_CREATE": ["study", "workshop"], "READ_BOOK": ["library", "rest"],
	"BROWSE_BOOK_CATALOG": ["library"],
	"BROWSE_FILMS": ["cinema"], "BROWSE_AUDIO": ["music"],
	"GET_COFFEE": ["common"], "WATCH_FIRE": ["common"],
	"TALK_PAIR": ["common", "rest"], "LISTEN_MUSIC": ["music"],
	"WATCH_FILM": ["cinema"], "VIEW_ART": ["artifact"],
	"PURPOSEFUL_EXPLORE": ["arrival", "corridor", "study", "library", "artifact", "rest"]
}

func setup(p_world) -> void:
	world = p_world
	var previously_initialized:bool=bool(world.runtime_state.get("teea008_navigation_initialized",false))
	if candidate_navigation!=null:
		stations.candidate_navigation=candidate_navigation
		locomotion.candidate_navigation=candidate_navigation
		creature_runtime.locomotion.candidate_navigation=candidate_navigation
		candidate_cups.setup(world,candidate_navigation)
		_prepare_candidate_positions()
	media_runtime.candidate_navigation=candidate_navigation
	media_runtime.setup(world)
	creature_runtime.setup(world)
	if world.canonical_house_seed:
		canonical_lifts.setup(world)
		creature_runtime.canonical_lifts=canonical_lifts
	rng.seed = 814223
	clock = world.sim_clock
	stations.reconcile(world)
	stations.migrate_legacy_positions(world)
	reconcile_concrete_media()
	# Daily restoration uses the simulation clock, including after reload.
	media_runtime.tick_book_home_reset()
	moving_ids.clear()
	var active_ids: Array = []
	for id in world.residents:
		var actor: Dictionary = world.residents[id]
		if not bool(actor.get("active",false)) or not bool(actor.get("autonomy_enabled",true)):
			continue
		active_ids.append(str(id))
		if str(actor.get("phase","idle")) == "travel":
			moving_ids[str(id)] = true
	active_ids.sort()
	var saved_scheduler: Dictionary = world.runtime_state.get("life_scheduler",{})
	life_scheduler.restore(saved_scheduler,active_ids,clock,idle_retry_seconds,3.0)
	if candidate_navigation!=null:
		_migrate_review_geometry(previously_initialized)
	# Existing pre-scheduler saves retain their commitments. First wake only
	# reconciles/schedules them; it does not cancel an unexpired action.
	world.runtime_state["life_scheduler"] = life_scheduler.snapshot()

func daypart() -> String:
	if daypart_override in ["night","morning","day","evening"]:
		return daypart_override
	var hour: int = Time.get_datetime_dict_from_system().get("hour", 12)
	if hour < 6:
		return "night"
	if hour < 11:
		return "morning"
	if hour < 18:
		return "day"
	return "evening"

func _advance_needs(actor: Dictionary, elapsed: float) -> void:
	if elapsed <= 0.0:
		return
	var needs: Dictionary = actor.get("needs",{})
	needs["rest"] = clampf(float(needs.get("rest",0.5)) + elapsed*0.00065,0,1)
	needs["curiosity"] = clampf(float(needs.get("curiosity",0.4)) + elapsed*0.0004,0,1)
	needs["social"] = clampf(float(needs.get("social",0.4)) + elapsed*0.00025,0,1)
	if str(actor.get("phase","idle")) == "perform":
		var intent := str(actor.get("intent",""))
		if intent in ["REST","SLEEP"]:
			needs["rest"] = maxf(0.0,float(needs["rest"]) - elapsed*0.004)
		elif intent in ["PURPOSEFUL_EXPLORE","BROWSE_BOOK_CATALOG","BROWSE_FILMS","BROWSE_AUDIO"]:
			needs["curiosity"] = maxf(0.0,float(needs["curiosity"]) - elapsed*0.002)
	actor["needs"] = needs

func _schedule_actor(actor: Dictionary, reason: String = "PERIODIC_LOW_CADENCE") -> void:
	var id := str(actor.get("id",""))
	if id == "" or not bool(actor.get("active",false)) or not bool(actor.get("autonomy_enabled",true)):
		life_scheduler.cancel(id)
		moving_ids.erase(id)
		return
	if str(actor.get("phase","idle")) == "travel":
		moving_ids[id] = true
		# Travel itself is frame-driven. This wake is only a bounded safety check.
		life_scheduler.schedule_in(id,clock,2.0,"TRAVEL_ACTIVE")
		return
	var until := float(actor.get("until",0.0))
	if until > clock:
		life_scheduler.schedule_at(id,until,reason)
	else:
		life_scheduler.schedule_in(id,clock,idle_retry_seconds,reason)

func wake_actor(id: String, reason: String) -> void:
	if world == null or not world.residents.has(id):
		return
	var actor: Dictionary = world.residents[id]
	if not bool(actor.get("active",false)) or not bool(actor.get("autonomy_enabled",true)):
		return
	life_scheduler.wake(id,clock,reason)

func refresh_changed_station_claims() -> int:
	# A mounted object may add/remove a station or move it to another room.
	# Never teleport occupants to new coordinates to preserve old slot indices.
	var changed:=0
	for id in world.residents:
		var actor:Dictionary=world.residents[id]
		var room_id:String=str(actor.get("station_room_id",""))
		if room_id=="":
			continue
		var room:Dictionary=world.room_by_id(room_id)
		var points:Array=stations.layout_for_world(world,room)
		var slot:int=int(actor.get("station_slot",-1))
		var stable:String=str(actor.get("station_anchor_id",""))
		var point:Array=actor.get("station_point",[])
		var valid:bool=slot>=0 and slot<points.size() and point.size()==2
		if valid:
			var expected:Vector2=points[slot]["offset"]
			valid=str(points[slot]["id"])==stable and expected.distance_to(Vector2(float(point[0]),float(point[1])))<0.01
		if valid:
			continue
		var book_id:String=str(actor.get("held_book",""))
		if book_id!="":
			if candidate_navigation!=null:
				media_runtime.drop_book(str(id),book_id,int(maxf(1.0,clock)))
			else:
				media_runtime.return_book(str(id),book_id)
			actor.erase("held_book")
		end_concrete_media(actor)
		_clear_book_task(actor)
		if str(actor.get("cup_task_stage",""))=="fetch":
			_clear_cup_task(actor)
		var partner_id:String=str(actor.get("partner_id",""))
		actor.erase("partner_id")
		if partner_id!="" and world.residents.has(partner_id):
			world.residents[partner_id].erase("partner_id")
		stations.release(actor)
		actor["phase"]="idle"
		actor["waypoints"]=[]
		actor["waypoint_index"]=0
		actor["until"]=clock
		moving_ids.erase(str(id))
		wake_actor(str(id),"STATION_LAYOUT_CHANGED")
		changed+=1
	return changed

func scheduler_metrics() -> Dictionary:
	return {
		"planner_calls":planner_calls,
		"planner_usec_total":planner_usec_total,
		"planner_usec_max":planner_usec_max,
		"scheduled":life_scheduler.due_at.size(),
		"moving":moving_ids.size()
	}

func _utilities(actor: Dictionary) -> Dictionary:
	var need: Dictionary = actor.get("needs", {})
	var traits: Dictionary = actor.get("traits", {})
	var rest := float(need.get("rest", 0.4))
	var social := float(need.get("social", 0.4))
	var curiosity := float(need.get("curiosity", 0.4))
	var phase := daypart()
	var scores: Dictionary = {
		"REST": 0.3 + rest * 1.2, "SLEEP": 0.1 + rest * 1.5,
		"WORK_CREATE": 0.55 + curiosity * 0.5,
		"GET_COFFEE": 0.65,
		"WATCH_FIRE": 0.4 + (0.35 if phase == "evening" else 0.0),
		"TALK_PAIR": 0.2 + social * 1.0,
		"READ_BOOK": 0.3 + float(traits.get("reading", 0.3)) + curiosity * 0.3,
		"BROWSE_BOOK_CATALOG": 0.28 + float(traits.get("reading",0.3))*0.65 + curiosity*0.40,
		"BROWSE_FILMS": 0.25 + curiosity*0.35,
		"BROWSE_AUDIO": 0.23 + float(traits.get("music",0.3))*0.6 + curiosity*0.24,
		"LISTEN_MUSIC": 0.2 + float(traits.get("music", 0.3)),
		"WATCH_FILM": 0.3 + (0.35 if phase == "evening" else 0.0),
		"VIEW_ART": 0.2 + curiosity * 0.8,
		"PURPOSEFUL_EXPLORE": 0.2 + curiosity * 0.35
	}
	if phase == "night":
		scores["SLEEP"] += 1.0
		scores["TALK_PAIR"] -= 0.4
	if phase == "morning":
		scores["GET_COFFEE"] += 0.6
		scores["WORK_CREATE"] += 0.2
	if phase == "day":
		scores["WORK_CREATE"] += 0.45
	if actor["id"] == "MANJKA":
		return {"REST": 0.2 + rest, "PURPOSEFUL_EXPLORE": 1.0 + curiosity}
	if (media_runtime.available_shelf_books(str(actor["id"])) if candidate_navigation!=null else media_runtime.available_books()).is_empty():
		scores.erase("READ_BOOK")
	if world.media.get("books",[]).is_empty():
		scores.erase("BROWSE_BOOK_CATALOG")
	if world.media.get("films",[]).is_empty():
		scores.erase("BROWSE_FILMS")
	if world.media.get("tracks",[]).is_empty():
		scores.erase("BROWSE_AUDIO")
	if media_runtime.playable("films").is_empty():
		scores.erase("WATCH_FILM")
	if media_runtime.playable("tracks").is_empty():
		scores.erase("LISTEN_MUSIC")
	return scores

func _destination_pressure(actor: Dictionary, room: Dictionary) -> Dictionary:
	var room_id:String=str(room["id"])
	var memo:bool=planning_actor_id!="" and planning_actor_id==str(actor["id"])
	if memo and planning_pressure.has(room_id):
		return planning_pressure[room_id]
	var path:Array=planning_routes.get(room_id,[]) if memo else world.find_route(actor["room_id"],room["id"],actor["id"])
	if path.is_empty():
		return {}
	var room_capacity:int=maxi(1,stations.capacity(room))
	var room_used:int=stations.used_slots(world,str(room["id"]),[str(actor["id"])]).size()
	var room_ratio:float=float(room_used)/float(room_capacity)

	var group_ratio:float=0.0
	if world.canonical_house_seed:
		# One physical room: virtual modules are copies with the same room ID.
		# Preserve the exact old pressure without duplicating connector dictionaries.
		var width:int=world.room_size_modules(room)
		group_ratio=float(room_used*width)/float(maxi(1,stations.capacity(room)*width))
	else:
		var group:Dictionary=world.merged_group(int(room["x"]),int(room["level"]))
		var group_used:=0
		var group_capacity:=0
		for cell in group.get("cells",[]):
			group_used+=stations.used_slots(world,str(cell["id"]),[str(actor["id"])]).size()
			group_capacity+=stations.capacity(cell)
		group_ratio=float(group_used)/float(maxi(1,group_capacity))

	# Cell pressure spreads residents across merged R2/R3 rooms; group pressure
	# prevents one visual room from becoming a crowd magnet when another room
	# of the same purpose is available. Route cost remains deliberately weak.
	var pressure:float=room_ratio*0.95+group_ratio*0.30+float(path.size()-1)*0.035
	var result:Dictionary={"room":room,"path":path,"pressure":pressure}
	if memo:
		planning_pressure[room_id]=result
	return result

func best_destination(actor: Dictionary, candidates: Array) -> Dictionary:
	var best:Dictionary={}
	var best_pressure:=INF
	for room in candidates:
		var option:Dictionary=_destination_pressure(actor,room)
		if option.is_empty():
			continue
		var pressure:float=float(option["pressure"])
		if pressure<best_pressure-0.0001:
			best=option
			best_pressure=pressure
		elif is_equal_approx(pressure,best_pressure) and not best.is_empty():
			# Stable tie-break: do not let RNG make all residents pile into one
			# cell simply because identical candidates happened to repeat.
			if str(room["id"])<str(best["room"]["id"]):
				best=option
	return best

func choose_intent(actor: Dictionary) -> Dictionary:
	if candidate_navigation!=null:
		_begin_candidate_plan(actor)
	var scored: Dictionary = _utilities(actor)
	var best := ""
	var best_score := -999.0
	var best_room: Dictionary = {}
	for intent in scored:
		var types: Array = INTENTS[intent]
		if world.canonical_house_seed and intent in ["GET_COFFEE","TALK_PAIR","PURPOSEFUL_EXPLORE"]:
			types=types.duplicate()
			if not types.has("kitchen"):types.append("kitchen")
			if intent=="GET_COFFEE" and not types.has("rest"):types.append("rest")
		if candidate_navigation!=null and intent in ["REST","SLEEP"]:
			types=types.duplicate()
			if not types.has("common"):
				types.append("common")
		var candidates: Array = []
		for room in world.matching_rooms(types, actor["id"]):
			if (str(room.get("type","")) == "guest"
					and intent in ["REST","SLEEP"]
					and str(room.get("owner_id","")) != str(actor.get("id",""))):
				continue
			if candidate_navigation!=null and candidate_navigation.has_layout(room) and intent!="TALK_PAIR":
				if intent=="GET_COFFEE" and candidate_cups.candidates(actor,room).is_empty():
					continue
				if stations.single(world,actor,room,intent).is_empty():
					continue
			if stations.can_reserve(world,room,intent=="TALK_PAIR"):
				if str(room.get("type",""))=="private" and stations.single(world,actor,room,intent).is_empty():continue
				candidates.append(room)
		if candidates.is_empty():
			continue
		var selected:Dictionary={}
		if world.canonical_house_seed and intent=="SLEEP" and daypart()=="night":
			var home:Dictionary=world.room_by_id(str(actor.get("home_room_id","")))
			if not home.is_empty() and candidates.has(home):
				selected=_destination_pressure(actor,home)
		if selected.is_empty():selected=best_destination(actor,candidates)
		if selected.is_empty():
			continue
		var destination:Dictionary=selected["room"]
		var path:Array=selected["path"]
		var habits: Dictionary = actor.get("habits", {})
		var repeat_bonus := minf(float(habits.get(intent, 0.0)), 0.3)
		var path_cost: float = maxf(0.0, float(path.size() - 1) * 0.045)
		var score: float = float(scored[intent]) + repeat_bonus - path_cost + rng.randf_range(-0.2, 0.2)
		if intent == "TALK_PAIR" and rng.randf() > 0.15:
			# Reserve actual social sessions later; do not fake dialogue.
			continue
		if score > best_score:
			best_score = score
			best = intent
			best_room = destination
	if candidate_navigation!=null:
		_end_candidate_plan()
	if best == "":
		return {}
	return {"intent": best, "room": best_room}

func _choose_partner(actor: Dictionary, destination: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_cost := 99999
	for id in world.residents:
		var other: Dictionary = world.residents[id]
		if id == actor["id"] or id == "MANJKA" or not other.get("active", false) or \
				not bool(other.get("autonomy_enabled",true)):
			continue
		if other.get("partner_id", "") != "" or other.get("phase", "idle") == "travel":
			continue
		if other.get("held_book","") != "":
			continue
		if float(other.get("until", 0.0)) > clock:
			continue
		if float(other.get("needs", {}).get("social", 0.0)) < 0.15:
			continue
		var route: Array = world.find_route(other.get("room_id", ""), destination["id"], id)
		if route.is_empty():
			continue
		if route.size() < best_cost:
			best_cost = route.size()
			best = other
	return best

func _record(message: String) -> void:
	log.push_back(message)
	while log.size() > 60:
		log.pop_front()

func end_catalog_browse(actor: Dictionary) -> void:
	# Looking up a catalog entry is not borrowing, reading, watching or playing it.
	actor.erase("browsing_item_id")
	actor.erase("browsing_category")

func end_concrete_media(actor: Dictionary) -> void:
	# Concrete media state is evidence for the resident activity, not a global
	# playback command. UI playback remains explicit user action.
	actor.erase("activity_media_category")
	actor.erase("activity_media_id")
	actor.erase("activity_media_title")

func _set_concrete_media(actor: Dictionary, category: String,
		item: Dictionary) -> void:
	var item_id:String=str(item.get("id",""))
	if item_id=="":
		return
	actor["activity_media_category"]=category
	actor["activity_media_id"]=item_id
	actor["activity_media_title"]=str(item.get("title",""))

func _concrete_media_is_valid(actor: Dictionary) -> bool:
	var category:String=str(actor.get("activity_media_category",""))
	var item_id:String=str(actor.get("activity_media_id",""))
	if category=="" or item_id=="":
		return false
	var item:Dictionary=media_runtime._lookup(category,item_id)
	if item.is_empty():
		return false
	if category=="books":
		return bool(item.get("physical",true)) and (
			str(item.get("holder_id",""))==str(actor.get("id","")))
	var destination_id:String=str(actor.get("station_room_id",""))
	if category=="films":
		return media_runtime.can_watch(str(actor.get("id","")),item_id,destination_id)
	if category=="tracks":
		return media_runtime.can_listen(str(actor.get("id","")),item_id,destination_id)
	return false

func reconcile_concrete_media() -> int:
	# Saves from before v0.14 may contain a real borrowed book but no concrete
	# media metadata. That identity is recoverable from holder_id and is safe
	# to restore. Film/music identity is not recoverable and is never guessed.
	var fixed:=0
	for id in world.residents:
		var actor:Dictionary=world.residents[id]
		if not bool(actor.get("active",false)):
			continue
		var active_id:String=str(actor.get("activity_media_id",""))
		var held_book:String=str(actor.get("held_book",""))
		if candidate_navigation!=null and actor.has("book_task_stage"):
			var stage:String=str(actor["book_task_stage"])
			var book:Dictionary=media_runtime._lookup("books",str(actor.get("book_task_id","")))
			var valid:bool=not book.is_empty() and ((stage=="fetch" and str(book.get("holder_id",""))=="" and str(book.get("location_room_id",""))==str(actor.get("book_source_room","")) and str(actor.get("phase",""))=="travel") or (stage in ["read","return","return_wait"] and str(book.get("holder_id",""))==str(id)))
			if not valid:
				_clear_book_task(actor)
				actor.erase("held_book")
				end_concrete_media(actor)
				stations.release(actor)
				actor["phase"]="idle"
				actor["waypoints"]=[]
				actor["waypoint_index"]=0
				actor["until"]=clock
				fixed+=1
				continue
		if active_id=="" and held_book!="":
			var book:Dictionary=media_runtime._lookup("books",held_book)
			if not book.is_empty() and str(book.get("holder_id",""))==str(id):
				_set_concrete_media(actor,"books",book)
				fixed+=1
				continue
		if active_id!="" and _concrete_media_is_valid(actor):
			continue
		var intent:String=str(actor.get("intent",""))
		var needs_concrete:bool=intent in ["READ_BOOK","WATCH_FILM","LISTEN_MUSIC"]
		if active_id=="" and not needs_concrete:
			continue
		end_concrete_media(actor)
		if held_book!="" and intent=="READ_BOOK":
			# Do not pretend an inconsistent book is still in the actor's hand.
			var book:Dictionary=media_runtime._lookup("books",held_book)
			if book.is_empty() or str(book.get("holder_id",""))!=str(id):
				actor.erase("held_book")
		if needs_concrete and str(actor.get("phase","idle")) in ["travel","perform"]:
			stations.release(actor)
			actor["phase"]="idle"
			actor["waypoints"]=[]
			actor["waypoint_index"]=0
			actor["until"]=clock
		fixed+=1
	return fixed

func _assign(actor: Dictionary, task: Dictionary) -> void:
	if candidate_navigation!=null:
		if str(actor.get("cup_task_stage","")) in ["hold","serve"] and str(world.physical_object(str(actor.get("cup_task_id",""))).get("current_holder_id",""))==str(actor["id"]):
			return
		if actor.has("held_book") and actor.has("book_task_stage"):
			return
		if actor.has("cup_task_stage"):
			_clear_cup_task(actor)
		if actor.has("book_task_stage"):
			_clear_book_task(actor)
	# Previous reservation ends before a new activity; actor state owns the
	# claim, making occupancy recoverable from JSON snapshots.
	stations.release(actor)
	end_catalog_browse(actor)
	end_concrete_media(actor)
	actor.erase("viewing_object_id")
	if candidate_navigation!=null:
		actor["phase"]="idle"
		actor["waypoints"]=[]
		actor["waypoint_index"]=0
	if task.is_empty():
		actor["until"] = clock + 15.0
		return
	var room: Dictionary = task["room"]
	var intent: String = str(task["intent"])
	if candidate_navigation!=null and intent=="READ_BOOK":
		_begin_book_task(actor,room)
		return
	if candidate_navigation!=null and intent=="GET_COFFEE":
		if candidate_cups.beverages.enabled:
			actor["drink_context"]=candidate_cups.beverages.context_for(str(actor.get("intent","")),daypart())
		_begin_cup_task(actor,room)
		return
	var route: Array = world.find_route(actor["room_id"], room["id"], actor["id"])
	if route.is_empty():
		actor["until"] = clock + 15.0
		return

	var partner: Dictionary = {}
	var partner_route: Array = []
	var partner_claim: Dictionary = {}
	var actor_claim: Dictionary = {}
	var viewing_object:Dictionary={}
	var partner_waypoints: Array = []
	var end_time := 0.0
	if intent == "TALK_PAIR":
		partner = _choose_partner(actor,room)
		if partner.is_empty():
			actor["until"] = clock + 10.0
			return
		partner_route = world.find_route(partner["room_id"],room["id"],str(partner["id"]))
		var pair_claim: Dictionary = stations.pair(world,actor,partner,room)
		if pair_claim.is_empty() or partner_route.is_empty():
			actor["until"] = clock + 10.0
			return
		actor_claim = pair_claim["actor"]
		partner_claim = pair_claim["partner"]
		partner_waypoints = locomotion.build_waypoints(
			world,partner,partner_route,intent,partner_claim["offset"],
			float(partner_claim.get("approach_z",0.95)))
		if partner_waypoints.is_empty():
			actor["until"] = clock + 10.0
			return
		end_time = clock + maxf(float(route.size()),float(partner_route.size()))*3.2+34.0
	else:
		if intent=="VIEW_ART":
			var displays:Array=stations.display_objects(world,room)
			if not displays.is_empty():
				viewing_object=displays[rng.randi_range(0,displays.size()-1)]
				actor_claim=stations.display_claim(world,actor,room,viewing_object)
		if actor_claim.is_empty():
			actor_claim = stations.single(world,actor,room,intent)
		if actor_claim.is_empty():
			actor["until"] = clock + 10.0
			return
	var actor_waypoints: Array = locomotion.build_waypoints(
		world,actor,route,intent,actor_claim["offset"],
		float(actor_claim.get("approach_z",0.95)))
	if actor_waypoints.is_empty():
		actor["until"] = clock + 10.0
		return
	# Catalog browsing is truthful even without playable audio/video or a
	# physical book. It holds only a reference ID, never an imaginary object.
	var browse_category := ""
	var browse_id := ""
	match intent:
		"BROWSE_BOOK_CATALOG": browse_category = "books"
		"BROWSE_FILMS": browse_category = "films"
		"BROWSE_AUDIO": browse_category = "tracks"
	if browse_category != "":
		var entries: Array = world.media.get(browse_category,[])
		if entries.is_empty():
			actor["until"] = clock + 12.0
			return
		var selected: Dictionary = entries[rng.randi_range(0,entries.size()-1)]
		browse_id = str(selected.get("id",""))
		if browse_id == "":
			actor["until"] = clock + 12.0
			return

	var concrete_category:=""
	var concrete_item:Dictionary={}
	# Watching/listening is allowed only after choosing one concrete playable
	# entry. A room visit alone is not evidence that a film or track was used.
	if intent=="WATCH_FILM":
		var playable_films:Array=media_runtime.playable("films")
		if playable_films.is_empty():
			actor["until"]=clock+12.0
			return
		if candidate_media_bindings!=null:
			concrete_item=candidate_media_bindings.choose_film(str(room["id"]),str(actor["id"]))
		if concrete_item.is_empty():
			concrete_item=playable_films[rng.randi_range(0,playable_films.size()-1)]
		if not media_runtime.can_watch(str(actor["id"]),
				str(concrete_item.get("id","")),str(room["id"])):
			actor["until"]=clock+12.0
			return
		concrete_category="films"
	elif intent=="LISTEN_MUSIC":
		var playable_tracks:Array=media_runtime.playable("tracks")
		if playable_tracks.is_empty():
			actor["until"]=clock+12.0
			return
		concrete_item=playable_tracks[rng.randi_range(0,playable_tracks.size()-1)]
		if not media_runtime.can_listen(str(actor["id"]),
				str(concrete_item.get("id","")),str(room["id"])):
			actor["until"]=clock+12.0
			return
		concrete_category="tracks"

	# Acquiring an object comes only after a destination and station are valid.
	if intent == "READ_BOOK":
		var books: Array = media_runtime.available_books()
		if books.is_empty():
			actor["until"] = clock + 12.0
			return
		concrete_item=books[rng.randi_range(0,books.size()-1)]
		var book_id: String = str(concrete_item.get("id",""))
		if not media_runtime.borrow(actor["id"],book_id,int(Time.get_unix_time_from_system())):
			actor["until"] = clock + 12.0
			return
		actor["held_book"] = book_id
		concrete_category="books"

	if intent == "TALK_PAIR":
		stations.release(partner)
		stations.commit_claim(partner,partner_claim)
		partner["intent"] = intent
		partner["waypoints"] = partner_waypoints
		partner["waypoint_index"] = 0
		partner["phase"] = "travel"
		partner["route"] = partner_route
		partner["path_index"] = 1
		partner["until"] = end_time
		partner["partner_id"] = actor["id"]
		actor["partner_id"] = partner["id"]
		_schedule_actor(partner,"PAIR_COMMITMENT")
		_record("%s и %s — договорились встретиться для разговора" %
			[actor.get("name",""),partner.get("name","")])
	stations.commit_claim(actor,actor_claim)
	if browse_category != "":
		actor["browsing_category"] = browse_category
		actor["browsing_item_id"] = browse_id
	if concrete_category!="" and not concrete_item.is_empty():
		_set_concrete_media(actor,concrete_category,concrete_item)
	if intent=="VIEW_ART" and not viewing_object.is_empty():
		actor["viewing_object_id"]=str(viewing_object.get("id",""))
	actor["intent"] = intent
	actor["waypoints"] = actor_waypoints
	actor["waypoint_index"] = 0
	actor["phase"] = "travel"
	moving_ids[str(actor["id"])] = true
	actor["route"] = route
	actor["path_index"] = 1
	actor["until"] = end_time if intent == "TALK_PAIR" else (
		clock + rng.randf_range(20.0,40.0)+float(route.size())*2.0)
	var habits: Dictionary = actor.get("habits",{})
	habits[intent] = minf(0.3,float(habits.get(intent,0.0))+0.012)
	actor["habits"] = habits
	if intent != "TALK_PAIR":
		_record("%s — %s" % [actor.get("name",actor["id"]),status(actor)])
	steps += 1

const PASS_TRIGGER_X := 1.85
const PASS_LANE_OFFSET := 0.34
const FOLLOW_GAP := 0.58
const OPPOSING_YIELD_X := 0.54
const PASSING_WAYPOINT_KINDS := [
	"leave_station","local_aisle_entry","local_aisle",
	"connector_out","connector_in","lift_align","station_approach"
]

func _travel_adjustment(actor: Dictionary, at: Vector3, target: Vector3,
		point: Dictionary) -> Dictionary:
	# Cheap deterministic local avoidance for the public walking aisle.
	# It changes only the transient movement target; authored waypoints and
	# station coordinates remain untouched.
	if candidate_navigation!=null:
		# Old lateral bypass can cut through a newly authored obstacle.
		return {"target":target,"wait":false,"passing":false}
	if not PASSING_WAYPOINT_KINDS.has(str(point.get("kind",""))):
		return {"target":target,"wait":false,"passing":false}
	var dx:float=target.x-at.x
	if absf(dx)<0.05:
		return {"target":target,"wait":false,"passing":false}
	var direction:float=signf(dx)
	var actor_id:String=str(actor.get("id",""))
	var adjusted:=target
	for other_id in world.residents:
		if str(other_id)==actor_id:
			continue
		var other:Dictionary=world.residents[other_id]
		if not bool(other.get("active",false)) or str(other.get("phase",""))!="travel":
			continue
		var other_at:=Vector3(
			float(other.get("x",0.0)),
			float(other.get("visual_y",float(other.get("level",0))*world.FLOOR_H)),
			float(other.get("z",0.0)))
		if absf(other_at.y-at.y)>0.18 or absf(other_at.x-at.x)>PASS_TRIGGER_X:
			continue
		if absf(other_at.z-at.z)>0.50:
			continue
		var other_target:Vector3=locomotion.get_target(other)
		var other_dx:float=other_target.x-other_at.x
		if absf(other_dx)<0.05:
			continue
		var other_direction:float=signf(other_dx)
		var relative_x:float=other_at.x-at.x
		if is_equal_approx(direction,other_direction):
			# Same direction: the rear resident yields instead of walking
			# through the resident immediately ahead.
			if direction*relative_x>0.0 and absf(relative_x)<FOLLOW_GAP:
				return {"target":adjusted,"wait":true,"passing":false}
			continue
		if direction*other_direction<0.0 and direction*relative_x>0.0:
			# Opposing traffic gets two shallow depth lanes. Stable ID order
			# makes the choice deterministic across saves and machines.
			var lane_sign:float=-1.0 if actor_id<str(other_id) else 1.0
			adjusted.z=clampf(target.z+lane_sign*PASS_LANE_OFFSET,-1.45,1.64)
			# Close to the actual crossing one walker has deterministic
			# right-of-way. The other holds briefly instead of intersecting
			# the same screen-space body.
			if absf(relative_x)<OPPOSING_YIELD_X and actor_id>str(other_id):
				return {"target":adjusted,"wait":true}
			# A short transient X target makes the side-step happen before the
			# walkers meet. authored_target remains unchanged in _move().
			adjusted.x=at.x+direction*minf(0.38,absf(dx))
			return {"target":adjusted,"wait":false}
	return {"target":adjusted,"wait":false}

func _move(actor: Dictionary, delta: float) -> void:
	var waypoints: Array = actor.get("waypoints", [])
	var idx: int = int(actor.get("waypoint_index", 0))
	if idx >= waypoints.size():
		actor["phase"] = "perform"
		return
	var point: Dictionary = waypoints[idx]
	if candidate_navigation!=null and str(point.get("kind",""))=="station":
		var destination:Dictionary=world.room_by_id(str(point.get("room_id","")))
		if not world.is_accessible(destination,str(actor["id"])):
			stations.release(actor)
			end_catalog_browse(actor)
			end_concrete_media(actor)
			if actor.has("held_book"):
				media_runtime.drop_book(str(actor["id"]),str(actor["held_book"]),int(maxf(1.0,clock)))
				actor.erase("held_book")
			_clear_book_task(actor)
			actor["phase"]="idle"
			actor["waypoints"]=[]
			actor["waypoint_index"]=0
			actor["until"]=clock
			moving_ids.erase(str(actor["id"]))
			wake_actor(str(actor["id"]),"GUEST_ACCESS_REVOKED")
			return
	var authored_target: Vector3 = locomotion.get_target(actor)
	var target: Vector3 = authored_target
	var at := Vector3(float(actor.get("x",0.0)),
		float(actor.get("visual_y", float(actor.get("level",0)) * world.FLOOR_H)),
		float(actor.get("z",0.0)))
	if world.canonical_house_seed and str(point["kind"])=="lift":
		var lift_move:Dictionary=canonical_lifts.target(actor,at,authored_target)
		if bool(lift_move.get("wait",false)):
			actor["moving_axis"]="wait"
			return
		var lift_target:Vector3=lift_move["target"]
		if bool(lift_move.get("boarding",false)):
			var aligned:=at.move_toward(lift_target,2.25*minf(delta,0.15))
			actor["x"]=aligned.x
			actor["z"]=aligned.z
			actor["moving_axis"]="depth"
			return
		authored_target=lift_target
		target=lift_target
	var adjustment:Dictionary=_travel_adjustment(actor,at,target,point)
	if bool(adjustment.get("wait",false)):
		actor["moving_axis"]="wait"
		return
	target=adjustment.get("target",target)
	var speed := 2.25 if actor["id"] != "MANJKA" else 3.25
	if point["kind"] == "lift":
		speed = 1.65
	var next: Vector3 = at.move_toward(target, speed * minf(delta, 0.15))
	if candidate_navigation!=null and candidate_traffic.enabled:
		next=candidate_traffic.step(actor,at,authored_target,next,speed*minf(delta,0.15),str(point["kind"]))
		candidate_traffic.publish(str(actor["id"]),next)
	actor["x"] = next.x
	actor["visual_y"] = next.y
	actor["z"] = next.z
	actor["moving_axis"] = ("up" if next.y>=at.y else "down") if point["kind"] == "lift" else ("right" if next.x > at.x else "left" if next.x < at.x else "depth")
	if next.distance_squared_to(at)<0.000001:
		actor["moving_axis"]="wait"
	if candidate_navigation!=null and candidate_traffic.enabled and point["kind"]!="lift" and next.distance_to(authored_target)>0.025:
		if candidate_traffic.stalled(str(actor["id"]),idx,next,authored_target,delta):
			if _recover_traffic_stall(actor,next):
				return
	if next.distance_to(authored_target) <= 0.025:
		if candidate_navigation!=null:
			candidate_traffic.clear_progress(str(actor["id"]))
		actor["room_id"] = point["room_id"]
		var current_room: Dictionary = world.room_by_id(point["room_id"])
		if not current_room.is_empty():
			actor["level"] = current_room["level"]
		actor["waypoint_index"] = idx + 1
		if world.canonical_house_seed and str(point["kind"])=="lift" and (idx+1>=waypoints.size() or str(waypoints[idx+1]["kind"])!="lift"):
			canonical_lifts.release(actor)
		if actor.has("teea008_geometry_replan_pending") and candidate_navigation!=null:
			if _finish_review_geometry_replan(actor,false):
				return
		if int(actor["waypoint_index"]) >= waypoints.size():
			# Consume only the travel interval before switching need semantics.
			var actor_id := str(actor.get("id",""))
			_advance_needs(actor,life_scheduler.consume_elapsed(actor_id,clock))
			actor["phase"] = "perform"
			if candidate_navigation!=null and str(actor.get("book_task_stage","")) in ["fetch","return"]:
				_arrive_book_shelf(actor)
				return
			if candidate_navigation!=null and str(actor.get("cup_task_stage",""))=="fetch":
				if candidate_cups.pickup(actor):
					actor["cup_task_stage"]="hold"
					actor["until"]=clock+12.0
					if candidate_cups.beverages.enabled:
						if _route_drink_source(actor):
							return
						actor["until"]=clock+3.0
				else:
					_clear_cup_task(actor)
					stations.release(actor)
					actor["phase"]="idle"
					actor["until"]=clock+3.0
				moving_ids.erase(actor_id)
				_schedule_actor(actor,"CUP_ARRIVAL")
				return
			if candidate_navigation!=null and str(actor.get("cup_task_stage",""))=="serve":
				_complete_drink_service(actor)
				moving_ids.erase(actor_id)
				_schedule_actor(actor,"DRINK_SERVICE_ARRIVAL")
				return
			if candidate_navigation!=null and str(actor.get("book_task_stage",""))=="read":
				actor["book_read_started"]=clock
			actor["until"] = maxf(float(actor.get("until",0.0)),clock+12.0)
			moving_ids.erase(actor_id)
			life_scheduler.schedule_at(actor_id,float(actor["until"]),"ACTION_COMMITMENT")

func _process_due_actor(id: String, wake_reason: String) -> void:
	var actor: Dictionary = world.residents.get(id,{})
	if actor.is_empty() or not bool(actor.get("active",false)) or \
			not bool(actor.get("autonomy_enabled",true)):
		life_scheduler.cancel(id)
		moving_ids.erase(id)
		return
	var elapsed := life_scheduler.consume_elapsed(id,clock)
	_advance_needs(actor,elapsed)
	if str(actor.get("phase","idle")) == "travel":
		moving_ids[id] = true
		life_scheduler.schedule_in(id,clock,2.0,"TRAVEL_ACTIVE")
		return
	if float(actor.get("until",0.0)) > clock:
		life_scheduler.schedule_at(id,float(actor["until"]),"COMMITMENT_ACTIVE")
		return
	if actor.get("partner_id","") != "":
		var partner_id := str(actor["partner_id"])
		actor.erase("partner_id")
		var partner: Dictionary = world.residents.get(partner_id,{})
		if partner.get("partner_id","") == id:
			partner.erase("partner_id")
			wake_actor(partner_id,"PAIR_RELEASED")
	if candidate_navigation!=null and actor.has("cup_task_stage"):
		if str(actor.get("cup_task_stage",""))=="serve":
			# A restored/replanned non-travelling service route cannot pour
			# from an arbitrary position. Validate or fail and return the cup.
			_complete_drink_service(actor)
			_schedule_actor(actor,"DRINK_SERVICE_RECOVERY")
			return
		if str(actor.get("cup_task_stage",""))=="hold":
			if str(world.physical_object(str(actor.get("cup_task_id",""))).get("current_holder_id",""))==id:
				if candidate_cups.beverages.enabled and int(actor.get("drink_sips_left",0))>0:
					var sipped:bool=candidate_cups.beverages.sip(str(actor["cup_task_id"]),id)
					actor["drink_sips_left"]=int(actor["drink_sips_left"])-1 if sipped else 0
					if sipped and int(actor["drink_sips_left"])>0 and float(candidate_cups.beverages.content(str(actor["cup_task_id"])).get("remaining_ml",0))>0:
						actor["until"]=clock+3.0
						_schedule_actor(actor,"DRINK_SIP")
						return
				actor.erase("drink_service_id")
				if not candidate_cups.put_back(actor):
					if _route_cup_return(actor):
						return
					actor["until"]=clock+5.0
					_schedule_actor(actor,"CUP_RETURN_RETRY")
					return
		_clear_cup_task(actor)
	if candidate_navigation!=null and actor.has("book_task_stage"):
		if _continue_book_task(actor):
			_schedule_actor(actor,"BOOK_TASK")
			return
	if actor.get("held_book","") != "":
		var book_id := str(actor["held_book"])
		media_runtime.read(id,book_id,25.0)
		media_runtime.return_book(id,book_id)
		actor.erase("held_book")
		_record("%s — вернула книгу" % actor.get("name",id))
	var started := Time.get_ticks_usec()
	var task := choose_intent(actor)
	_assign(actor,task)
	var spent := int(Time.get_ticks_usec()-started)
	planner_calls += 1
	planner_usec_total += spent
	planner_usec_max = maxi(planner_usec_max,spent)
	if candidate_navigation!=null:
		planner_sample_usec.append(spent)
		if planner_sample_usec.size()>2048:planner_sample_usec.pop_front()
	_schedule_actor(actor,"PLANNER_RESULT")
	world._append_journal("LIFE_PLANNER_RAN",id,id,wake_reason,str(actor.get("intent","")),
		{"planner_usec":spent,"next_due":life_scheduler.peek_due_at(id)})

func tick(delta: float) -> void:
	clock += delta
	world.sim_clock = clock
	var home_restored:int=world.tick_object_home_reset()
	if home_restored>0:
		_record("Дом вернул вещи на назначенные места: %d" % home_restored)
	var books_restored:int=media_runtime.tick_book_home_reset()
	if books_restored>0:
		if candidate_navigation!=null:media_runtime.reconcile_book_slots()
		reconcile_concrete_media()
		_record("Дом вернул книги на назначенные места: %d" % books_restored)
	if world.canonical_house_seed:
		canonical_lifts.sync()
	creature_runtime.tick(delta)
	if candidate_navigation!=null:
		for creature in world.creatures.values():
			if creature.has("teea008_geometry_replan_pending"):
				_finish_review_geometry_replan(creature,true)
	# Movement stays frame-driven, but only actors actually travelling are touched.
	if candidate_navigation!=null and not moving_ids.is_empty():
		candidate_traffic.begin(world,candidate_navigation)
	for raw_id in moving_ids.keys().duplicate():
		var id := str(raw_id)
		var actor: Dictionary = world.residents.get(id,{})
		if actor.is_empty() or not bool(actor.get("active",false)) or \
				not bool(actor.get("autonomy_enabled",true)) or \
				str(actor.get("phase","idle")) != "travel":
			moving_ids.erase(id)
			continue
		_move(actor,delta)
	if candidate_traffic.enabled:
		candidate_traffic.finish()
	for due in life_scheduler.pop_due(clock,max_jobs_per_tick):
		_process_due_actor(str(due.get("id","")),str(due.get("reason","PERIODIC_LOW_CADENCE")))
	world.runtime_state["life_scheduler"] = life_scheduler.snapshot()
	world.runtime_state["life_scheduler_metrics"] = scheduler_metrics()

func _prepare_candidate_positions()->void:
	# One-time migration in the separate live-review save. Never teleport a
	# walking actor every frame. Invalidate old route/claim commitments.
	if bool(world.runtime_state.get("teea008_navigation_initialized",false)):
		return
	for collection in [world.residents,world.creatures]:
		for id in collection:
			var actor:Dictionary=collection[id]
			var room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
			if room.is_empty():
				continue
			var c:Vector3=world.room_center_pos(room)
			var at:=Vector2(float(actor.get("x",c.x))-c.x,float(actor.get("z",0.0)))
			if candidate_navigation.has_layout(room) and not candidate_navigation.clear(room,at):
				var safe:Vector2=candidate_navigation.nearest_clear(room,at)
				actor["x"]=c.x+safe.x
				actor["z"]=safe.y
				actor["visual_y"]=c.y
				world._append_journal("TEEA008_REVIEW_POSITION_MIGRATED",str(id),str(id),str(room["id"]),str(room["id"]),{"from":[at.x,at.y],"to":[safe.x,safe.y]})
			stations.release(actor)
			actor["phase"]="idle"
			actor["waypoints"]=[]
			actor["waypoint_index"]=0
			actor["until"]=world.sim_clock
			actor.erase("partner_id")
	world.runtime_state["teea008_navigation_initialized"]=true

func _clear_book_task(actor:Dictionary)->void:
	for key in ["book_task_stage","book_task_id","book_source_room","book_read_room","book_read_started"]:
		actor.erase(key)

func _book_route(actor:Dictionary,room:Dictionary,intent:String,shelf_station:String="")->bool:
	if room.is_empty() or not world.is_accessible(room,str(actor["id"])):
		return false
	var claim:Dictionary={}
	if intent in ["FETCH_BOOK","RETURN_BOOK"]:
		if shelf_station=="":
			shelf_station=str(media_runtime.book_slot(str(actor.get("book_task_id",""))).get("station_id",""))
		claim=stations.book_shelf_claim(world,actor,room,intent,shelf_station)
	else:
		claim=stations.single(world,actor,room,intent)
	if claim.is_empty():
		return false
	var route:Array=world.find_route(str(actor["room_id"]),str(room["id"]),str(actor["id"]))
	var points:Array=locomotion.build_waypoints(world,actor,route,intent,claim["offset"],float(claim.get("approach_z",0.95)))
	if points.is_empty():
		return false
	stations.release(actor)
	stations.commit_claim(actor,claim)
	actor["intent"]=intent
	actor["route"]=route
	actor["waypoints"]=points
	actor["waypoint_index"]=0
	actor["phase"]="travel"
	actor["until"]=clock+30.0+float(route.size())*2.0
	moving_ids[str(actor["id"])]=true
	_schedule_actor(actor,"BOOK_ROUTE")
	return true

func _begin_book_task(actor:Dictionary,reading_room:Dictionary)->void:
	if actor.has("held_book"):
		actor["until"]=clock+8.0
		return
	_clear_book_task(actor)
	var options:Array=media_runtime.available_shelf_books(str(actor["id"]))
	for book in options:
		var source:Dictionary=world.room_by_id(str(book["location_room_id"]))
		if not candidate_navigation.has_layout(source):
			continue
		if not _book_route(actor,source,"FETCH_BOOK",str(media_runtime.book_slot(str(book["id"])).get("station_id",""))):
			continue
		actor["book_task_stage"]="fetch"
		actor["book_task_id"]=str(book["id"])
		actor["book_source_room"]=str(source["id"])
		actor["book_read_room"]=str(reading_room["id"])
		world._append_journal("BOOK_RESERVED_FOR_PICKUP",str(actor["id"]),str(book["id"]),str(source["id"]),str(reading_room["id"]),{})
		return
	actor["until"]=clock+8.0

func _arrive_book_shelf(actor:Dictionary)->void:
	var id:String=str(actor["id"])
	var book_id:String=str(actor.get("book_task_id",""))
	var source:String=str(actor.get("book_source_room",""))
	var stage:String=str(actor.get("book_task_stage",""))
	if stage=="fetch" and media_runtime.borrow_at_shelf(id,book_id,source):
		actor["held_book"]=book_id
		actor["book_task_stage"]="read"
		var book:Dictionary=media_runtime._lookup("books",book_id)
		_set_concrete_media(actor,"books",book)
		var target:Dictionary=world.room_by_id(str(actor.get("book_read_room","")))
		if _book_route(actor,target,"READ_BOOK"):
			return
		# Seat became unavailable while walking to the shelf; return at the
		# exact shelf already reached, rather than teleporting the book.
		actor["intent"]="RETURN_BOOK"
		media_runtime.return_at_shelf(id,book_id,source)
	elif stage=="return":
		if not media_runtime.return_at_shelf(id,book_id,source):
			# Failed placement must not create a second copy.
			media_runtime.drop_book(id,book_id,int(maxf(1.0,clock)))
	actor.erase("held_book")
	_clear_book_task(actor)
	end_concrete_media(actor)
	stations.release(actor)
	actor["phase"]="idle"
	actor["waypoints"]=[]
	actor["waypoint_index"]=0
	actor["until"]=clock+3.0
	moving_ids.erase(id)
	_schedule_actor(actor,"BOOK_FINISHED")

func _continue_book_task(actor:Dictionary)->bool:
	var stage:String=str(actor.get("book_task_stage",""))
	var id:String=str(actor["id"])
	var book_id:String=str(actor.get("book_task_id",""))
	var book:Dictionary=media_runtime._lookup("books",book_id)
	if stage in ["read","return_wait"] and str(book.get("holder_id",""))==id:
		if stage=="read":
			var start:float=float(actor.get("book_read_started",clock-12.0))
			media_runtime.read(id,book_id,maxf(0.0,clock-start))
			world._append_journal("BOOK_READING_FINISHED",id,book_id,str(actor["room_id"]),str(actor["room_id"]),{"seconds":maxf(0.0,clock-start)})
		actor["book_task_stage"]="return_wait"
		end_concrete_media(actor)
		var source:Dictionary=world.room_by_id(str(actor.get("book_source_room","")))
		if _book_route(actor,source,"RETURN_BOOK"):
			actor["book_task_stage"]="return"
			return true
		# Keep the real book in hand while waiting for the shelf, without
		# falsely claiming the actor continues to read it.
		actor["phase"]="idle"
		actor["intent"]="RETURN_BOOK"
		actor["until"]=clock+5.0
		stations.release(actor)
		return true
	if stage=="fetch" or stage=="return":
		# An interrupted route can be retried only from the real position.
		var source:Dictionary=world.room_by_id(str(actor.get("book_source_room","")))
		if _book_route(actor,source,"FETCH_BOOK" if stage=="fetch" else "RETURN_BOOK"):
			return true
		if stage=="return" and str(book.get("holder_id",""))==id:
			actor["book_task_stage"]="return_wait"
			actor["until"]=clock+5.0
			return true
	_clear_book_task(actor)
	return false

func _clear_cup_task(actor:Dictionary)->void:
	for key in ["cup_task_id","cup_task_room","cup_task_slot","cup_task_stage","drink_sips_left","drink_context","drink_service_id","drink_service_plan","drink_service_approach"]:
		actor.erase(key)

func _begin_cup_task(actor:Dictionary,room:Dictionary)->void:
	var context:String=str(actor.get("drink_context","GENERIC"))
	_clear_cup_task(actor)
	actor["drink_context"]=context
	for item in candidate_cups.candidates(actor,room):
		var slot:Dictionary=item["slot"]
		var claim:Dictionary=stations.cup_claim(world,actor,room,str(slot["id"]))
		if claim.is_empty():
			continue
		var route:Array=world.find_route(str(actor["room_id"]),str(room["id"]),str(actor["id"]))
		var points:Array=locomotion.build_waypoints(world,actor,route,"GET_COFFEE",claim["offset"],float(claim.get("approach_z",0.95)))
		if points.is_empty():
			continue
		stations.commit_claim(actor,claim)
		actor["cup_task_id"]=str(item["object_id"])
		actor["cup_task_room"]=str(room["id"])
		actor["cup_task_slot"]=str(slot["id"])
		actor["cup_task_stage"]="fetch"
		actor["intent"]="GET_COFFEE"
		actor["route"]=route
		actor["waypoints"]=points
		actor["waypoint_index"]=0
		actor["phase"]="travel"
		actor["until"]=clock+30.0
		moving_ids[str(actor["id"])]=true
		_schedule_actor(actor,"CUP_ROUTE")
		return
	actor["until"]=clock+8.0

func _route_drink_source(actor:Dictionary)->bool:
	var room:Dictionary=world.room_by_id(str(actor.get("cup_task_room","")))
	var id:String=str(actor["id"])
	var cup_id:String=str(actor["cup_task_id"])
	var beverage=candidate_cups.beverages
	if float(beverage.content(cup_id).get("remaining_ml",0))>0:
		if beverage.can_use(cup_id,id):actor["drink_sips_left"]=rng.randi_range(1,4)
		return false
	var sources:Array=candidate_cups.service_sources(actor,room)
	var available:Array=[]
	for source in sources:
		if not available.has(source["type"]):available.append(source["type"])
	var choice:Dictionary=beverage.plan_new(cup_id,id,str(actor.get("drink_context","GENERIC")),daypart(),available)
	if choice.is_empty():return false
	for source in sources:
		if str(source["type"])!=str(choice["source_station"]):continue
		var approach:Vector2=source["approach"]
		var points:Array=locomotion.build_waypoints(world,actor,[str(room["id"])],"GET_COFFEE",approach)
		if points.is_empty():continue
		actor["drink_service_id"]=str(source["id"])
		actor["drink_service_plan"]=choice
		actor["drink_service_approach"]=[approach.x,approach.y]
		actor["cup_task_stage"]="serve"
		actor["waypoints"]=points
		actor["waypoint_index"]=0
		actor["phase"]="travel"
		actor["until"]=clock+15.0
		moving_ids[id]=true
		_schedule_actor(actor,"DRINK_SERVICE_ROUTE")
		return true
	beverage.fail_choice(choice,"NO_REACHABLE_SOURCE")
	return false

func _complete_drink_service(actor:Dictionary)->void:
	var choice:Dictionary=actor.get("drink_service_plan",{})
	var room:Dictionary=world.room_by_id(str(actor.get("cup_task_room","")))
	var raw:Array=actor.get("drink_service_approach",[])
	var valid:bool=raw.size()==2 and str(actor.get("room_id",""))==str(room.get("id",""))
	var beverage=candidate_cups.beverages
	if valid:
		valid=candidate_cups.at_approach(actor,room,Vector2(float(raw[0]),float(raw[1])))
	if valid:
		valid=beverage.fill_planned(str(actor.get("cup_task_id","")),str(actor["id"]),choice)
	if valid:
		actor["drink_sips_left"]=rng.randi_range(1,4)
	else:
		beverage.fail_choice(choice,"SERVICE_NOT_REACHED")
		actor["drink_sips_left"]=0
		actor.erase("drink_service_id")
	actor.erase("drink_service_plan")
	actor.erase("drink_service_approach")
	actor["cup_task_stage"]="hold"
	actor["phase"]="perform"
	actor["until"]=clock+3.0

func _route_cup_return(actor:Dictionary)->bool:
	var room:Dictionary=world.room_by_id(str(actor.get("cup_task_room","")))
	if room.is_empty() or not world.is_accessible(room,str(actor["id"])):
		return false
	var claim:Dictionary=stations.cup_claim(world,actor,room,str(actor.get("cup_task_slot","")))
	if claim.is_empty():
		return false
	var route:Array=world.find_route(str(actor["room_id"]),str(room["id"]),str(actor["id"]))
	var points:Array=locomotion.build_waypoints(world,actor,route,"GET_COFFEE",claim["offset"],float(claim.get("approach_z",0.95)))
	if points.is_empty():
		return false
	stations.release(actor)
	stations.commit_claim(actor,claim)
	actor["intent"]="GET_COFFEE"
	actor["route"]=route
	actor["waypoints"]=points
	actor["waypoint_index"]=0
	actor["phase"]="travel"
	actor["until"]=clock+15.0
	moving_ids[str(actor["id"])]=true
	_schedule_actor(actor,"CUP_RETURN_ROUTE")
	return true

func _begin_candidate_plan(actor:Dictionary)->void:
	planning_actor_id=str(actor["id"])
	planning_routes.clear()
	planning_pressure.clear()
	stations.begin_planning_snapshot()
	# Adjacency contains geometry only. Access/transit is evaluated at each
	# decision from live room state. Signature includes authored connectors.
	var shape:Array=[]
	var current_rooms:Dictionary={}
	for room in world.rooms:
		current_rooms[str(room["id"])]=room
		shape.append([room["id"],room["x"],room["level"],room.get("size_modules",1),room.get("type",""),room.get("connectors",[])])
	var signature:int=hash(shape)
	if planner_graph.is_empty() or signature!=planner_graph_signature:
		planner_graph.clear()
		var geometry:Dictionary=world.route_geometry_index() if world.canonical_house_seed else {}
		for room in world.rooms:
			var neighbors:Array=[]
			if world.canonical_house_seed:
				for other in world.indexed_geometry_neighbors(room,geometry):
					neighbors.append(str(other["id"]))
			else:
				for other in world.rooms:
					if str(room["id"])!=str(other["id"]) and not world.connection_between(room,other).is_empty():
						neighbors.append(str(other["id"]))
			planner_graph[str(room["id"])]=neighbors
		planner_graph_signature=signature
		planner_graph_rebuilds+=1
	var start:String=str(actor.get("room_id",""))
	if not current_rooms.has(start):
		return
	var visited:Dictionary={start:[start]}
	var q:Array=[start]
	var at:=0
	while at<q.size():
		var current:String=str(q[at])
		at+=1
		for rid in planner_graph.get(current,[]):
			if visited.has(rid):continue
			var room:Dictionary=current_rooms.get(str(rid),{})
			if not world.allows_transit(room) and not world.is_accessible(room,planning_actor_id):
				continue
			var path:Array=visited[current].duplicate()
			path.append(rid)
			visited[rid]=path
			q.append(rid)
	for rid in visited:
		if world.is_accessible(current_rooms.get(str(rid),{}),planning_actor_id):
			planning_routes[rid]=visited[rid]
	planner_route_queries+=1

func _end_candidate_plan()->void:
	stations.end_planning_snapshot()
	planning_actor_id=""
	planning_routes.clear()
	planning_pressure.clear()

func candidate_planner_percentiles()->Dictionary:
	var values:Array=planner_sample_usec.duplicate()
	values.sort()
	if values.is_empty():return {}
	return {"samples":values.size(),"p50_us":values[int((values.size()-1)*0.5)],"p95_us":values[int((values.size()-1)*0.95)],"p99_us":values[int((values.size()-1)*0.99)],"max_us":values[-1],"graph_rebuilds":planner_graph_rebuilds,"route_trees":planner_route_queries}

func _recover_traffic_stall(actor:Dictionary,at:Vector3)->bool:
	# Replanning is legal only at an actual traversable physical position.
	# Do not move the actor, rewrite the graph, or lose a held object.
	var room:Dictionary=world.get_room(roundi(at.x/world.MODULE_W),roundi(at.y/world.FLOOR_H))
	if room.is_empty():
		return false
	# A public frontage is legal transit, not private interior access.
	if not world.is_accessible(room,str(actor["id"])) and not (world.allows_transit(room) and at.z>=1.35):
		return false
	if candidate_navigation.has_layout(room) and not candidate_navigation.clear(room,world.room_space.world_to_local(room,at)):
		return false
	var id:String=str(actor["id"])
	actor["room_id"]=str(room["id"])
	actor["level"]=int(room["level"])
	stations.release(actor)
	end_catalog_browse(actor)
	end_concrete_media(actor)
	actor.erase("viewing_object_id")
	var partner_id:String=str(actor.get("partner_id",""))
	actor.erase("partner_id")
	if partner_id!="" and world.residents.has(partner_id):
		world.residents[partner_id].erase("partner_id")
		wake_actor(partner_id,"TRAFFIC_PARTNER_REPLAN")
	if actor.has("held_book") and actor.has("book_task_stage"):
		actor["book_task_stage"]="return_wait"
	else:
		_clear_book_task(actor)
	if str(actor.get("cup_task_stage",""))=="serve":
		candidate_cups.beverages.fail_choice(actor.get("drink_service_plan",{}),"ROUTE_REPLAN")
		actor.erase("drink_service_plan")
		actor.erase("drink_service_approach")
		actor.erase("drink_service_id")
		actor["cup_task_stage"]="hold"
		actor["drink_sips_left"]=0
	elif str(actor.get("cup_task_stage",""))!="hold":
		_clear_cup_task(actor)
	actor["phase"]="idle"
	actor["waypoints"]=[]
	actor["waypoint_index"]=0
	actor["until"]=clock+2.0+float(id.hash()%7)*0.35
	moving_ids.erase(id)
	_schedule_actor(actor,"TRAFFIC_REPLAN")
	return true

func _migrate_review_geometry(previously_initialized:bool)->int:
	var revision:String=str(candidate_navigation.layouts.get("common/R3",{}).get("runtime_review_geometry_revision",""))
	if world.canonical_house_seed and candidate_navigation.layouts.get("library/R3",{}).get("canonical_dressing_revision","")!="":
		revision+="|"+str(candidate_navigation.layouts["library/R3"]["canonical_dressing_revision"])
	if world.canonical_house_seed and candidate_navigation.layouts.get("music/R3",{}).get("canonical_dressing_revision","")!="":
		revision+="|MEDIA_WORK_V1"
	if world.canonical_house_seed and candidate_navigation.layouts.get("guest_centaur/R2",{}).get("guest_display_revision","")!="":
		revision+="|GUEST_DISPLAY_V1"
	if revision=="" or str(world.runtime_state.get("teea008_geometry_revision",""))==revision:
		return 0
	var affected:Dictionary={}
	for room in world.rooms:
		var key:String=candidate_navigation.key(room)
		if key=="common/R3" or (world.canonical_house_seed and key in ["kitchen/R3","rest_social_upper/R3","rest_social_lower/R3","library/R3","artifact/R3","cinema/R3","music/R3","study/R3","workshop/R3","guest_centaur/R2","guest_vampire/R1","guest_miu/R1"]):
			affected[str(room["id"])]=true
	var count:=0
	if previously_initialized:
		for is_creature in [false,true]:
			var collection:Dictionary=world.creatures if is_creature else world.residents
			for actor in collection.values():
				if not bool(actor.get("active",false)):continue
				var relevant:bool=affected.has(str(actor.get("room_id",""))) or affected.has(str(actor.get("station_room_id","")))
				if not relevant and str(actor.get("phase",""))=="travel":
					var points:Array=actor.get("waypoints",[])
					for i in range(int(actor.get("waypoint_index",0)),points.size()):
						if affected.has(str(points[i].get("room_id",""))):
							relevant=true
							break
				if not relevant:continue
				actor["teea008_geometry_replan_pending"]=revision
				# A snapshot may be between floors. Keep that connector leg
				# and defer invalidation to the next accessible floor waypoint.
				_finish_review_geometry_replan(actor,is_creature)
				count+=1
	world.runtime_state["teea008_geometry_revision"]=revision
	return count

func _finish_review_geometry_replan(actor:Dictionary,is_creature:bool)->bool:
	if not actor.has("teea008_geometry_replan_pending"):return false
	var id:String=str(actor["id"])
	var y:float=float(actor.get("visual_y",float(actor.get("level",0))*world.FLOOR_H))
	var level:int=roundi(y/world.FLOOR_H)
	if absf(y-float(level)*world.FLOOR_H)>0.05:return false
	var at:=Vector3(float(actor.get("x",0)),y,float(actor.get("z",0)))
	var room:Dictionary=world.get_room(roundi(at.x/world.MODULE_W),level)
	if room.is_empty() or (is_creature and not world.public_cutaway_allowed(room)) or (not is_creature and not world.is_accessible(room,id)):
		return false
	var old:Vector3=at
	if candidate_navigation.has_layout(room):
		var local:Vector2=world.room_space.world_to_local(room,at)
		if not candidate_navigation.clear(room,local):
			var safe:Vector2=candidate_navigation.nearest_clear(room,local)
			if not candidate_navigation.clear(room,safe):return false
			var center:Vector3=world.room_center_pos(room)
			at=Vector3(center.x+safe.x,center.y,safe.y)
			actor["x"]=at.x
			actor["z"]=at.z
			actor["visual_y"]=at.y
	var old_room:String=str(actor.get("room_id",""))
	actor["room_id"]=str(room["id"])
	actor["level"]=level
	if is_creature:
		actor["phase"]="idle"
		actor["waypoints"]=[]
		actor["waypoint_index"]=0
		actor.erase("route_target_room_id")
		actor.erase("route_origin_room_id")
		actor["next_decision_at"]=clock+1.0
	else:
		if not _recover_traffic_stall(actor,at):return false
	var revision:String=str(actor["teea008_geometry_replan_pending"])
	actor.erase("teea008_geometry_replan_pending")
	world._append_journal("TEEA008_REVIEW_GEOMETRY_MIGRATED",id,id,old_room,str(room["id"]),{"revision":revision,"from_xyz":[old.x,old.y,old.z],"to_xyz":[at.x,at.y,at.z],"relocated":old.distance_squared_to(at)>0.000001})
	return true
