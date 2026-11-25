extends SceneTree
const W = preload("res://scripts/world_model.gd")
const L = preload("res://scripts/life.gd")
func _initialize() -> void:
	var w = W.new()
	w.seed_world()
	var l = L.new()
	l.setup(w)
	var actor: Dictionary = w.residents["RES_01"]
	var place: Dictionary = w.get_room(-1, 0)
	l._assign(actor, {"intent": "TALK_PAIR", "room": place})
	var partner_id: String = actor.get("partner_id", "")
	assert(partner_id != "", "Social session must reserve actual partner")
	var partner: Dictionary = w.residents[partner_id]
	assert(partner.get("partner_id", "") == "RES_01", "Reservation must be reciprocal")
	assert(partner.get("intent", "") == "TALK_PAIR", "Second resident must participate")
	assert(is_equal_approx(float(partner["until"]), float(actor["until"])))
	var session:Dictionary=l._pair_session(actor)
	assert(session.get("phase","")=="assembling")
	assert(session.get("members",[])==["RES_01",partner_id])
	assert(float(session.get("started_at",0))==-1.0)
	assert(w.journal.any(func(event):return str(event.get("event",""))=="PAIR_RESERVED"))
	print("SOCIAL_PAIR_TEST_PASS: ", actor["name"], " + ", partner["name"])
	quit(0)

