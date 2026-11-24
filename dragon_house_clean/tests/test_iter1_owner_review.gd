extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func _candidate_station_count(registry) -> int:
	var count := 0
	for key in registry.variant_cell_overrides:
		var s := str(key)
		if s.begins_with("music:") or s.begins_with("cinema:") or 				s.begins_with("artifact:") or s.begins_with("workshop:"):
			count += (registry.variant_cell_overrides[key] as Array).size()
	return count

func run() -> void:
	assert(FileAccess.file_exists("res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"))
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene

	assert(scene.iter1_owner_review)
	assert(scene.world.save_path == "user://dragon_house_iter1_owner_review.json")
	assert(scene.interior_skin.candidate_review_enabled)

	assert(scene.interior_skin.validated_layers("music",1).size() == 3)
	assert(scene.interior_skin.validated_layers("music",2).size() == 4)
	assert(scene.interior_skin.validated_layers("music",3).size() == 4)
	assert(scene.interior_skin.validated_layers("cinema",1).size() == 3)
	assert(scene.interior_skin.validated_layers("cinema",2).size() == 4)
	assert(scene.interior_skin.validated_layers("cinema",3).size() == 4)
	assert(scene.interior_skin.validated_layers("artifact",1).size() == 3)
	assert(scene.interior_skin.validated_layers("artifact",2).size() == 3)
	assert(scene.interior_skin.validated_layers("artifact",3).size() == 3)
	assert(scene.interior_skin.validated_layers("workshop",1).size() == 3)
	assert(scene.interior_skin.validated_layers("workshop",2).size() == 3)
	assert(scene.interior_skin.validated_layers("workshop",3).size() == 3)
	assert(scene.interior_skin.validated_layers("guest_vampire",1).size() == 3)
	assert(scene.interior_skin.validated_layers("guest_miu",1).size() == 3)
	assert(scene.interior_skin.validated_layers("guest_centaur",1).size() == 3)
	assert(FileAccess.file_exists("res://assets/props/dragon_mug_lod0_empty.glb"))

	# Fallout-Shelter cutaway contract: room art remains visible in HOUSE,
	# while manual FREE zoom gains the same proximity detail as ROOM/FOLLOW.
	scene.update_render_lod()
	var house_art_count: int = scene.art_loaded_groups.size()
	assert(house_art_count > 0)
	var near_group: Node3D = null
	for group_node in scene.room_root.get_children():
		var group: Dictionary = scene.visual_room_groups.get(group_node.name,{})
		if bool(group.get("has_art",false)) and not scene._group_facade_only(group):
			near_group = group_node
			break
	assert(near_group != null)
	scene.current_mode = "FREE"
	scene.zoom_current = 18.0
	scene.smooth_focus = near_group.position
	scene.desired_focus = near_group.position
	scene.update_render_lod()
	assert(scene.art_loaded_groups.size() >= house_art_count)
	assert(scene.art_loaded_groups.has(near_group.name))
	assert(scene.detailed_room_groups.has(near_group.name))

	assert(scene.life.stations.furniture.source_path.ends_with(
		"furniture_interactions_iter1_review.json"))

	for guest_id in ["NPC_CENTAUR","NPC_VAMPIRE_GIRL","NPC_GINGER_CAT_GUEST"]:
		assert(scene.world.residents.has(guest_id))
		var guest: Dictionary = scene.world.residents[guest_id]
		assert(str(guest.get("entity_type","")) == "guest")
		assert(str(guest.get("visual_status","")) == "CANDIDATE")
		assert(not bool(guest.get("autonomy_enabled",true)))
		assert(str(guest.get("bank_id","")) == guest_id)

	assert(scene.world.creatures.has("CREATURE_SHURSHUN"))
	var shurshun: Dictionary = scene.world.creatures["CREATURE_SHURSHUN"]
	assert(str(shurshun.get("bank_id","")) == "npc_cat_black_hero")
	assert(str(shurshun.get("owner_id","")) == "RES_03")
	assert(scene.world.creature_display_label("CREATURE_SHURSHUN").begins_with("Шуршун"))

	for bank_id in [
		"npc_cat_black_hero","npc_cat_calico","npc_mouse_gray",
		"npc_rat_hero","npc_hedgehog_01","npc_ai_magic_sphere"
	]:
		assert(scene.asset_banks.candidate_creature_bank(bank_id),bank_id)

	var report_text := FileAccess.get_file_as_string(
		"res://data/integration_candidates/ITER1_INTAKE_REPORT.json")
	var report = JSON.parse_string(report_text)
	assert(typeof(report) == TYPE_DICTIONARY)
	assert(report.get("approved",true) == false)
	assert(report.get("owner_approved",true) == false)
	assert(int(report["teea006"]["layers"]) == 40)
	assert(int(report["teea006"]["stations_claimed"]) == 31)
	var stations_applied := int(report["teea006"]["stations_applied"])
	var station_gap := bool(report["teea006"]["station_source_gap"])
	if stations_applied == 31:
		assert(not station_gap)
		assert(_candidate_station_count(scene.life.stations.furniture) == 31)
	else:
		assert(stations_applied == 0)
		assert(station_gap)

	print("ITER1_OWNER_REVIEW_PASS teea006_layers=40 stations_applied=%d station_gap=%s guests=3 shurshun=RES_03 candidate_approval=false" % [stations_applied,str(station_gap)])
	quit(0)
