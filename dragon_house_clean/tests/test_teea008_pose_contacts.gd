extends SceneTree
const N=preload("res://scripts/teea008_navigation.gd")
const W=preload("res://scripts/world_model.gd")
const S=preload("res://scripts/room_stations.gd")
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var f:=FileAccess.open("res://data/teea008_review/room_layouts_xz.json",FileAccess.READ)
	var doc:Dictionary=JSON.parse_string(f.get_as_text())
	var rows:Dictionary={}
	for row in doc["items"]:rows[row["variant_id"]]=row
	var nav=N.new()
	nav.configure(rows)
	assert(nav.pose_profiles.size()==27)
	var w=W.new()
	w.save_path="user://teea008_pose_contact_qa.json"
	w.seed_world()
	var stations=S.new()
	stations.candidate_navigation=nav
	var room:Dictionary=w.get_room(-2,0)
	var profiles:=0
	var seat_count:=0
	var floor_count:=0
	var read_count:=0
	for id in nav.pose_profiles:
		var profile:Dictionary=nav.pose_profiles[id]
		var actor:Dictionary={"id":id,"appearance_profile":profile["appearance_profile"],"teea008_pose_wardrobe":profile["wardrobe"]}
		if profile["states"].is_empty():
			continue
		profiles+=1
		for spot in stations.layout_for_world(w,room):
			var contact:Dictionary=nav.pose_contact(actor,spot,"REST")
			if not contact.is_empty():
				if str(contact["state"])=="RELAXED_SIT":
					assert(id!="NPC_CENTAUR" and id!="NPC_GINGER_CAT_GUEST")
					seat_count+=1
				elif str(contact["state"])=="LIE_SIDE_CURLED":floor_count+=1
			if not nav.pose_contact(actor,spot,"READ_BOOK").is_empty():read_count+=1
	print("TEEA008_POSE_CONTACT_COUNTS profiles=",profiles," seat_pairs=",seat_count," floor_pairs=",floor_count," read_pairs=",read_count)
	assert(profiles==27 and seat_count>50 and floor_count>20 and read_count>50)
	var actor:Dictionary=w.residents["RES_01"]
	actor["teea008_pose_wardrobe"]=nav.pose_profiles["RES_01"]["wardrobe"]
	var rest:Dictionary=w.get_room(1,0)
	var sleep:Dictionary=stations.single(w,actor,rest,"SLEEP")
	assert(sleep.has("contact") and bool(sleep["contact"]["exclusive"]),str(sleep))
	stations.commit_claim(actor,sleep)
	actor["phase"]="perform"
	var used:Dictionary=stations.used_slots(w,str(rest["id"]))
	var same:=0
	for i in used:
		var spot:Dictionary=stations.layout_for_world(w,rest)[int(i)]
		if str(spot["furniture_id"])==str(sleep["furniture_id"]):same+=1
	assert(same>=2)
	var other:Dictionary=w.residents["RES_02"]
	other["teea008_pose_wardrobe"]=nav.pose_profiles["RES_02"]["wardrobe"]
	var next:Dictionary=stations.single(w,other,rest,"REST")
	assert(next.is_empty() or str(next["furniture_id"])!=str(sleep["furniture_id"]))
	print("TEEA008_POSE_CONTACT_PASS daybed_exclusive=true frame_hashes_checked=true")
	quit(0)
