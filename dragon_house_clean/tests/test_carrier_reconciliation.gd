extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")
func _initialize()->void:
	var w=W.new()
	w.creatures={"rat":{"id":"rat","carried_object_id":"stale"}}
	w.residents={"a":{"id":"a","active":true,"intent":"GET_COFFEE","phase":"travel","cup_task_id":"cup","cup_task_stage":"fetch","waypoints":[{}]},"b":{"id":"b","active":true,"intent":"GET_COFFEE","phase":"perform","cup_task_id":"cup","cup_task_stage":"hold","drink_sips_left":3}}
	w.objects={"art":{"id":"art","current_holder_id":"rat"},"cup":{"id":"cup","viewer_category":"cups","current_holder_id":"a","home_room_id":"home"}}
	w.runtime_state["beverages"]={"cups":{"cup":{"remaining_ml":57.0,"consumer_id":"a","pending_choice":{"x":1}}},"preferences":{"a":{"total_choices":2}}}
	var before:Dictionary=w.runtime_state["beverages"].duplicate(true)
	assert(w.reconcile_object_carriers())
	assert(w.creatures["rat"]["carried_object_id"]=="art")
	var life=Life.new()
	life.world=w
	life.clock=123.0
	assert(life.reconcile_cup_tasks()==["a","b"])
	assert(w.residents["a"]["cup_task_stage"]=="hold")
	assert(w.residents["a"]["drink_sips_left"]==0)
	assert(w.residents["a"]["phase"]=="idle")
	assert(w.residents["a"]["until"]==123.0)
	assert(not w.residents["b"].has("cup_task_id"))
	assert(w.runtime_state["beverages"]==before)
	assert(life.reconcile_cup_tasks().is_empty())
	w.objects["art"]["current_holder_id"]=""
	assert(w.reconcile_object_carriers())
	assert(w.creatures["rat"]["carried_object_id"]=="")
	w.objects["second"]={"id":"second","viewer_category":"cups","current_holder_id":"a"}
	assert(not w.reconcile_object_carriers())
	assert(w.objects["second"]["current_holder_id"]=="a")
	assert(w.objects["cup"]["current_holder_id"]=="a")
	w.objects.erase("second")
	assert(w.reconcile_object_carriers())
	print("CARRIER_RECONCILIATION_TEST_PASS")
	quit(0)
