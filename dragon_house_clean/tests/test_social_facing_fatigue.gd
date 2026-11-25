extends SceneTree
const W=preload("res://scripts/world_model.gd")
const Life=preload("res://scripts/life.gd")
const Banks=preload("res://scripts/asset_bank_resolver.gd")

func _initialize()->void:
	assert(Banks.social_idle_state(Vector2(0,1),0.0)=="IDLE_S")
	assert(Banks.social_idle_state(Vector2(1,0),0.0)=="IDLE_E")
	assert(Banks.social_idle_state(Vector2(0,-1),0.0)=="IDLE_N")
	assert(Banks.social_idle_state(Vector2(-1,0),0.0)=="IDLE_W")
	assert(Banks.social_idle_state(Vector2(1,1),0.0)=="IDLE_SE")
	assert(Banks.social_idle_state(Vector2(0,1),PI/4)=="IDLE_SW")
	assert(Banks.social_idle_state(Vector2(1,0),PI/2)=="IDLE_S")
	var w=W.new()
	var life=Life.new()
	life.world=w
	var actor:Dictionary={"id":"a","active":true,"needs":{"social":0.8},"social_fatigue":0.0}
	var row:Dictionary={"phase":"active","started_at":100.0,"ends_at":10900.0,"members":["a"],"accounted_at":{"a":100.0}}
	life.clock=3700.0
	life._account_social_attendance(row,actor)
	assert(is_equal_approx(float(actor["needs"]["social"]),0.3))
	assert(is_equal_approx(float(actor["social_fatigue"]),1.0/3.0))
	var before:Dictionary=actor.duplicate(true)
	life._account_social_attendance(row,actor)
	assert(actor==before)
	row=JSON.parse_string(JSON.stringify(row))
	actor=JSON.parse_string(JSON.stringify(actor))
	life._account_social_attendance(row,actor)
	assert(is_equal_approx(float(actor["needs"]["social"]),float(before["needs"]["social"])))
	assert(is_equal_approx(float(actor["social_fatigue"]),float(before["social_fatigue"])))
	life.clock=7300.0
	life._account_social_attendance(row,actor)
	assert(is_equal_approx(float(actor["social_fatigue"]),2.0/3.0))
	assert(not life._social_start_allowed(actor))
	actor["social_fatigue"]=0.95
	assert(life._social_should_leave(row,actor))
	life._apply_social_cooldown(row,actor)
	assert(actor["social_rest_until"]==7900.0)
	life._advance_needs(actor,3600.0)
	assert(is_equal_approx(float(actor["social_fatigue"]),0.45))
	assert(not life._social_start_allowed(actor))
	life.clock=7900.0
	assert(life._social_start_allowed(actor))
	# Late participant cannot accumulate time before actual arrival.
	var late:Dictionary={"id":"b","needs":{"social":0.8}}
	row["late_members"]={"b":7500.0}
	row["accounted_at"]["b"]=7500.0
	life.clock=7500.0
	life._account_social_attendance(row,late)
	assert(not late.has("social_fatigue"))
	life.clock=9300.0
	life._account_social_attendance(row,late)
	assert(is_equal_approx(float(late["social_fatigue"]),1.0/6.0))
	assert(is_equal_approx(float(late["needs"]["social"]),0.55))
	assert(not life._social_should_leave(row,late))
	print("SOCIAL_FACING_FATIGUE_TEST_PASS")
	quit(0)
