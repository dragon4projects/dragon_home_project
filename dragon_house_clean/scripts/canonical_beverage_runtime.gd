extends RefCounted
## Persisted beverage state is separate from the event-sourced object projection.
## Only the accepted object holder can sip; replays of object movement cannot
## reset contents or preferences. No physics, recipes or intoxication.
const LOG_PATH="user://house_content/logs/drink_choices.jsonl"
var world
var config:Dictionary={}
var entries:Array=[]
var by_id:Dictionary={}
var rng:=RandomNumberGenerator.new()
var enabled:=false

func setup(model)->void:
	world=model
	if not world.canonical_house_seed:return
	if not enabled:
		var f:=FileAccess.open("res://data/canonical_drinks.json",FileAccess.READ)
		if f==null:return
		var doc=JSON.parse_string(f.get_as_text())
		if typeof(doc)!=TYPE_DICTIONARY:return
		config=doc
		entries=doc.get("entries",[])
		for row in entries:by_id[str(row["drink_id"])]=row
		enabled=entries.size()==105 and by_id.size()==105
		rng.seed=10520261125
	if not enabled:return
	var store:Dictionary=world.runtime_state.get("beverages",{})
	if store.is_empty():
		store={"cups":{},"preferences":{},"serial":0,"rng_state":str(rng.state)}
		world.runtime_state["beverages"]=store
	rng.state=int(str(store.get("rng_state",str(rng.state))))

func _store()->Dictionary:
	return world.runtime_state["beverages"]

func content(cup_id:String)->Dictionary:
	if not enabled:return {}
	return _store()["cups"].get(cup_id,{})

func history(actor_id:String)->Dictionary:
	if not enabled:return {}
	var prefs:Dictionary=_store()["preferences"]
	if not prefs.has(actor_id):
		prefs[actor_id]={"drink_counts":{},"last_drink_id":"","recent_drinks":[],"total_choices":0,"completed_drinks":[],"last_choice":{}}
	return prefs[actor_id]

func learned_weight(n:int)->float:
	return 1.0 if n<5 else 1.0+2.35*pow(float(mini(n,30)-4),1.5)

func context_for(intent:String,daypart:String)->String:
	match intent:
		"READ_BOOK":return "READING"
		"TALK_PAIR","TALK_GROUP":return "SISTERS_SOCIAL"
		"WORK_CREATE":return "WORK_CREATE"
		"WATCH_FIRE":
			if daypart=="evening":return "HEARTH_EVENING"
	if daypart=="morning":return "MORNING"
	if daypart=="night":return "NIGHTCAP"
	return "GENERIC"

func weights(prefs:Dictionary,context:String,daypart:String,available:Array=["COFFEE_NOOK","BAR"])->Array:
	var out:Array=[]
	var counts:Dictionary=prefs.get("drink_counts",{})
	var recent:Array=prefs.get("recent_drinks",[])
	var completed:Array=prefs.get("completed_drinks",[])
	var alcoholic_streak:=0
	for i in range(completed.size()-1,-1,-1):
		if not bool(by_id.get(str(completed[i]),{}).get("alcoholic",false)):break
		alcoholic_streak+=1
	var families:Dictionary=config["weights"].get(context,config["weights"]["GENERIC"])
	for row in entries:
		var id:String=str(row["drink_id"])
		var family:String=str(row["family"])
		var n:int=int(counts.get(id,0))
		var learned:=learned_weight(n)
		var event:float=float(families.get(family,1.0))
		# Generic is intentionally equal-weight, including the time factor.
		# Morning/night effects are expressed through the explicit context.
		var time_factor:=1.0
		var tag:=1.0
		for name in config["tag_bonus"].get(context,[]):
			if row["tags"].has(name):
				tag=float(config["tag_factor"])
				break
		var availability:=1.0 if available.has(row["source_station"]) else 0.0
		var streak:=1.0
		if recent.size()>=3 and recent[-1]==id and recent[-2]==id and recent[-3]==id:
			streak=float(config["streak_factor"])
		if bool(config.get("variety_guard",true)) and alcoholic_streak>=2:
			if bool(row["alcoholic"]):streak*=0.35 if alcoholic_streak>=4 else 0.65
			elif family in ["WATER","SOFT"]:streak*=2.2 if alcoholic_streak>=4 else 1.5
		out.append({"drink_id":id,"history_count_before":n,"learned_weight":learned,"event_multiplier":event,"time_multiplier":time_factor,"tag_multiplier":tag,"availability_multiplier":availability,"recent_streak_modifier":streak,"final_weight":learned*event*time_factor*tag*availability*streak})
	return out

func select_weighted(options:Array,roll:float)->Dictionary:
	var total:=0.0
	for row in options:total+=float(row["final_weight"])
	if total<=0:return {}
	var remaining:=clampf(roll,0.0,0.999999999)*total
	for row in options:
		var w:float=float(row["final_weight"])
		if w<=0:continue
		if remaining<w:return row
		remaining-=w
	return {}

func _top(options:Array,count:int)->Array:
	var ranked:=options.duplicate()
	ranked.sort_custom(func(a,b):return float(a["final_weight"])>float(b["final_weight"]))
	return ranked.slice(0,mini(count,ranked.size()))

func can_use(cup_id:String,actor_id:String)->bool:
	var c:=content(cup_id)
	return c.is_empty() or float(c.get("remaining_ml",0))<=0 or str(c.get("consumer_id",""))==actor_id

func fill_or_resume(cup_id:String,actor_id:String,context:String,daypart:String,available:Array=["COFFEE_NOOK","BAR"],forced:String="")->bool:
	if not enabled:return false
	var obj:Dictionary=world.physical_object(cup_id)
	if str(obj.get("current_holder_id",""))!=actor_id or str(obj.get("viewer_category",""))!="cups":return false
	var existing:=content(cup_id)
	if float(existing.get("remaining_ml",0))>0:return can_use(cup_id,actor_id)
	var prefs:=history(actor_id)
	var options:=weights(prefs,context,daypart,available)
	var roll:=rng.randf()
	_store()["rng_state"]=str(rng.state)
	var selected:=select_weighted(options,roll)
	if forced!="":
		for row in options:
			if str(row["drink_id"])==forced and float(row["final_weight"])>0:
				selected=row
				break
	if selected.is_empty():return false
	var drink:Dictionary=by_id[selected["drink_id"]]
	var serial:int=int(_store()["serial"])+1
	_store()["serial"]=serial
	var choice:=selected.duplicate(true)
	choice.merge({"timestamp":Time.get_datetime_string_from_system(true),"resident_id":actor_id,"event_context":context,"time_bucket":daypart,"cup_id":cup_id,"selected_drink_id":drink["drink_id"],"choice_instance_id":"DRINK_%d"%serial,"top_candidates":_top(options,10),"rng_roll":roll,"first_sip_success":false,"history_count_after":int(selected["history_count_before"])},true)
	_store()["cups"][cup_id]={"cup_id":cup_id,"content_id":drink["drink_id"],"display_name":drink["display_name_ru"],"serving_ml":drink["default_serving_ml"],"remaining_ml":drink["default_serving_ml"],"temperature_class":drink["temperature"],"alcoholic":drink["alcoholic"],"technical_type":drink["technical_type"],"strength_class":drink["strength_class"],"consumer_id":actor_id,"choice_instance_id":choice["choice_instance_id"],"pending_choice":choice}
	return true

func _append_choice(row:Dictionary)->bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_PATH.get_base_dir()))
	var f:=FileAccess.open(LOG_PATH,FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if f==null:
		push_warning("Drink choice log unavailable")
		return false
	f.seek_end()
	f.store_line(JSON.stringify(row))
	f.flush()
	return true

func sip(cup_id:String,actor_id:String)->bool:
	var c:=content(cup_id)
	if c.is_empty() or float(c.get("remaining_ml",0))<=0 or str(c.get("consumer_id",""))!=actor_id:return false
	if str(world.physical_object(cup_id).get("current_holder_id",""))!=actor_id:return false
	var prefs:=history(actor_id)
	var id:String=str(c["content_id"])
	c["remaining_ml"]=maxf(0.0,float(c["remaining_ml"])-float(c["serving_ml"])*float(config["sip_fraction"]))
	if c.has("pending_choice"):
		var row:Dictionary=c["pending_choice"]
		var counts:Dictionary=prefs["drink_counts"]
		counts[id]=int(counts.get(id,0))+1
		prefs["total_choices"]=int(prefs["total_choices"])+1
		prefs["last_drink_id"]=id
		prefs["recent_drinks"].append(id)
		if prefs["recent_drinks"].size()>12:prefs["recent_drinks"].pop_front()
		row["first_sip_success"]=true
		row["history_count_after"]=counts[id]
		prefs["last_choice"]=row.duplicate(true)
		_append_choice(row)
		c.erase("pending_choice")
	if float(c["remaining_ml"])<=0:
		prefs["completed_drinks"].append(id)
		if prefs["completed_drinks"].size()>12:prefs["completed_drinks"].pop_front()
	return true

func empty_cup(cup_id:String)->void:
	var c:=content(cup_id)
	if c.is_empty():return
	if c.has("pending_choice"):
		var row:Dictionary=c["pending_choice"]
		row["failure_reason"]="EMPTIED_BEFORE_FIRST_SIP"
		_append_choice(row)
		c.erase("pending_choice")
	c["remaining_ml"]=0.0

func reset_history(actor_id:String)->void:
	if enabled:_store()["preferences"].erase(actor_id)
