extends RefCounted
## Reused/adapted from the old Mora RC1.5 autonomy/life_scheduler_v2.gd.
## High-level planning wakes only when due; movement interpolation remains frame-driven.

var due_at: Dictionary = {}
var wake_reason: Dictionary = {}
var last_advanced_at: Dictionary = {}
var default_interval: float = 8.0
var sequence: int = 0

func setup(actor_ids: Array, started_at: float, interval_seconds: float,
		initial_spread_seconds: float = 3.0) -> void:
	clear()
	default_interval = maxf(0.5, interval_seconds)
	var count := maxi(1, actor_ids.size())
	for index in actor_ids.size():
		var id := str(actor_ids[index])
		last_advanced_at[id] = started_at
		var offset := initial_spread_seconds * float(index) / float(count)
		schedule_at(id, started_at + offset, "INITIAL_STAGGER", true)

func restore(snapshot: Dictionary, actor_ids: Array, now: float,
		interval_seconds: float, initial_spread_seconds: float = 3.0) -> bool:
	clear()
	default_interval = maxf(0.5, interval_seconds)
	if snapshot.is_empty() or typeof(snapshot.get("due_at",null)) != TYPE_DICTIONARY 			or typeof(snapshot.get("wake_reason",null)) != TYPE_DICTIONARY 			or typeof(snapshot.get("last_advanced_at",null)) != TYPE_DICTIONARY:
		setup(actor_ids, now, interval_seconds, initial_spread_seconds)
		return false
	due_at = snapshot.get("due_at",{}).duplicate(true)
	wake_reason = snapshot.get("wake_reason",{}).duplicate(true)
	last_advanced_at = snapshot.get("last_advanced_at",{}).duplicate(true)
	default_interval = maxf(0.5,float(snapshot.get("default_interval",interval_seconds)))
	sequence = maxi(0,int(snapshot.get("sequence",0)))
	var allowed: Dictionary = {}
	for raw_id in actor_ids:
		var id := str(raw_id)
		allowed[id] = true
		if not last_advanced_at.has(id):
			last_advanced_at[id] = now
		if not due_at.has(id):
			schedule_in(id,now,initial_spread_seconds,"RESTORE_MISSING_ACTOR")
	for id in due_at.keys():
		if not allowed.has(str(id)):
			cancel(str(id))
	for id in last_advanced_at.keys():
		if not allowed.has(str(id)):
			last_advanced_at.erase(id)
	return true

func clear() -> void:
	due_at.clear()
	wake_reason.clear()
	last_advanced_at.clear()
	sequence = 0

func has_actor(id: String) -> bool:
	return last_advanced_at.has(id)

func ensure_actor(id: String, timestamp: float) -> void:
	if not last_advanced_at.has(id):
		last_advanced_at[id] = timestamp

func schedule_at(id: String, timestamp: float,
		reason: String = "PERIODIC_LOW_CADENCE",
		only_if_earlier: bool = false) -> void:
	ensure_actor(id,timestamp)
	if only_if_earlier and due_at.has(id) and float(due_at[id]) <= timestamp:
		return
	due_at[id] = timestamp
	wake_reason[id] = reason
	sequence += 1

func schedule_in(id: String, timestamp: float, delay_seconds: float,
		reason: String = "PERIODIC_LOW_CADENCE",
		only_if_earlier: bool = false) -> void:
	schedule_at(id,timestamp+maxf(0.0,delay_seconds),reason,only_if_earlier)

func wake(id: String, timestamp: float, reason: String) -> void:
	schedule_at(id,timestamp,reason,true)

func cancel(id: String) -> void:
	due_at.erase(id)
	wake_reason.erase(id)

func consume_elapsed(id: String, timestamp: float) -> float:
	ensure_actor(id,timestamp)
	var previous := float(last_advanced_at[id])
	last_advanced_at[id] = timestamp
	return maxf(0.0,timestamp-previous)

func peek_due_at(id: String) -> float:
	return float(due_at.get(id,INF))

func pop_due(timestamp: float, limit: int = 1) -> Array:
	var rows: Array = []
	for id in due_at:
		var when := float(due_at[id])
		if when <= timestamp:
			rows.append({
				"id":str(id),
				"at":when,
				"reason":str(wake_reason.get(id,"PERIODIC_LOW_CADENCE"))
			})
	rows.sort_custom(func(a,b):
		if is_equal_approx(float(a["at"]),float(b["at"])):
			return str(a["id"]) < str(b["id"])
		return float(a["at"]) < float(b["at"])
	)
	if limit > 0 and rows.size() > limit:
		rows = rows.slice(0,limit)
	for row in rows:
		cancel(str(row["id"]))
	return rows

func snapshot() -> Dictionary:
	return {
		"schema":1,
		"due_at":due_at.duplicate(true),
		"wake_reason":wake_reason.duplicate(true),
		"last_advanced_at":last_advanced_at.duplicate(true),
		"default_interval":default_interval,
		"sequence":sequence
	}
