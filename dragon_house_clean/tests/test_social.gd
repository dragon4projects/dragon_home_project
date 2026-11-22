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
	assert(l.log.size() > 0 and str(l.log[-1]).contains("разговора"))
	print("SOCIAL_PAIR_TEST_PASS: ", actor["name"], " + ", partner["name"])
	quit(0)

