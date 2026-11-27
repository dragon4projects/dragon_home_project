extends SceneTree
func _initialize()->void:call_deferred("run")
func read_dict(path:String)->Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:return {}
	var d=JSON.parse_string(f.get_as_text())
	return d if typeof(d)==TYPE_DICTIONARY else {}
func run()->void:
	var args:=OS.get_cmdline_user_args()
	assert(args.size()==1 and ProjectSettings.load_resource_pack(args[0],true))
	assert(FileAccess.file_exists("res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"))
	assert(FileAccess.file_exists("res://data/integration_candidates/TEEA008_LIVE_REVIEW.enabled"))
	var layout:=read_dict("res://data/teea008_review/room_layouts_xz.json")
	var media:=read_dict("res://data/teea008_review/media_surface_delta.json")
	var geometry:=read_dict("res://data/teea008_review/asset_geometry.json")
	assert(layout.get("items",[]).size()==33 and media.get("items",[]).size()==32)
	var count:=0
	for item in geometry.get("items",[]):
		assert(ResourceLoader.exists("res://assets/teea008_review/decor_bank/"+str(item["asset_id"])+"/model.gltf","PackedScene"),str(item["asset_id"]))
		count+=1
	assert(count==243,str(count))
	var proof:=read_dict("res://data/integration_candidates/TEEA008_POSE_EXPORT_PROOF.json")
	var poses:=read_dict("res://data/teea008_pose_contacts_review.json")
	var intake_path:="res://data/asset_proposals/DH_SPRITE_20261126_INTAKE/frames.json"
	var intake_count:=0
	if FileAccess.file_exists(intake_path):
		var intake_file:=FileAccess.open(intake_path,FileAccess.READ)
		var records=JSON.parse_string(intake_file.get_as_text())
		assert(typeof(records)==TYPE_ARRAY and records.size()==42)
		for rec in records:
			var p:String="res://"+str(rec["path"])
			assert(str(proof["frames"].get(p,""))==str(rec["sha256"]),p)
			var tex:=ResourceLoader.load(p,"Texture2D") as Texture2D
			assert(tex!=null and tex.get_width()==int(rec["canvas"][0]) and tex.get_height()==int(rec["canvas"][1]),p)
			intake_count+=1
	var expected_paths:Dictionary={}
	for profile in poses.get("profiles",{}).values():
		for entry in profile.get("states",{}).values():expected_paths["res://"+str(entry.path)]=true
	if intake_count>0:
		var old=JSON.parse_string(FileAccess.get_file_as_string(intake_path))
		for rec in old:expected_paths["res://"+str(rec.path)]=true
	var complete_path:="res://data/asset_proposals/DH_SPRITE_20261126_COMPLETE/frames.json"
	if FileAccess.file_exists(complete_path):
		var complete=JSON.parse_string(FileAccess.get_file_as_string(complete_path))
		assert(complete.size()==204)
		for rec in complete:expected_paths["res://"+str(rec.path)]=true
	var side_path:="res://data/asset_proposals/DH_I93_SIDE_READ/frames.json"
	if FileAccess.file_exists(side_path):
		var side:=read_dict(side_path)
		for rec in side.get("frames",[]):
			var path:String="res://"+str(rec.path)
			assert(proof.frames.get(path,"")==rec.sha256,path)
			var tex:=ResourceLoader.load(path,"Texture2D") as Texture2D
			assert(tex!=null and tex.get_size()==Vector2(512,512),path)
			expected_paths[path]=true
	assert(proof.get("frames",{}).size()==expected_paths.size())
	var verified:=0
	for profile in poses["profiles"].values():
		for entry in profile["states"].values():
			var path:String="res://"+str(entry["path"])
			assert(str(proof["frames"].get(path,""))==str(entry["sha256"]))
			var tex:=ResourceLoader.load(path,"Texture2D") as Texture2D
			assert(tex!=null and tex.get_width()==int(entry["canvas"][0]) and tex.get_height()==int(entry["canvas"][1]),path)
			verified+=1
	var registry:=read_dict("res://data/asset_registry_nov2026.json")
	var banks:=0
	for id in registry["residents"]:
		var profile:Dictionary=registry["residents"][id]
		var ward:String=str(profile["default_wardrobe"])
		var states:Dictionary=profile["wardrobes"][ward]["states"]
		for state in ["IDLE_S","WALK_LEFT","WALK_RIGHT"]:
			for frame in states[state]["frames"]:
				assert(ResourceLoader.exists("res://"+str(frame),"Texture2D"),str(frame))
		banks+=1
	assert(banks==27)
	var sketchfab:=read_dict("res://data/asset_proposals/SKETCHFAB_20261125/asset_index.json")
	var new_models:=0
	for item in sketchfab.get("items",[]):
		var path:String="res://assets/sketchfab_review/decor_bank/"+str(item["asset_id"])+"/model.gltf"
		assert(ResourceLoader.exists(path,"PackedScene"),path)
		new_models+=1
	assert(new_models==6)
	var delta:=read_dict("res://data/sketchfab_common_review.json")
	assert(str(delta.get("variant_id",""))=="common/R3" and delta.get("instances",[]).size()==3)
	var hands:=read_dict("res://data/teea008_hand_contacts_review.json")
	assert(hands.get("profiles",{}).size()==27)
	for id in hands["profiles"]:
		var hand:Dictionary=hands["profiles"][id]
		var path:String="res://"+str(hand["path"])
		assert(str(proof["frames"].get(path,""))==str(hand["sha256"]),id)
		assert(hand["hand_px"].size()==2)
	if FileAccess.file_exists("res://data/integration_candidates/CANONICAL_HOUSE_ARCHITECTURE.enabled"):
		assert(ResourceLoader.exists("res://scripts/canonical_house_seed.gd"))
		for asset in ["owner_sleeping_dragon","artifact_glass_cube_s","artifact_glass_cube_m","artifact_glass_cube_l"]:
			assert(ResourceLoader.exists("res://assets/decor_bank/"+asset+"/model.gltf","PackedScene"),asset)
		var drinks:=read_dict("res://data/canonical_drinks.json")
		assert(drinks.get("entries",[]).size()==105)
		assert(ResourceLoader.exists("res://scripts/canonical_beverage_runtime.gd"))
		for filename in ["canonical_social_interiors_20261125.json","canonical_library_gallery_20261125.json","canonical_media_work_interiors_20261125.json","canonical_guest_display_interiors_20261125.json","canonical_conditional_shelves_20261125.json"]:
			var doc:=read_dict("res://data/"+filename)
			assert(not doc.is_empty(),filename)
			var items:Array=[]
			for row in doc.get("variants",[]):items.append_array(row.get("instances",[]))
			items.append_array(doc.get("hearth_additions",[]))
			for key in doc.get("additions",{}):items.append_array(doc["additions"][key])
			for item in items:
				var asset:String=str(item["asset_id"])
				var base:String="res://assets/teea008_review/decor_bank/"
				if asset.begins_with("sketchfab_"):base="res://assets/sketchfab_review/decor_bank/"
				if asset=="owner_sleeping_dragon" or asset.begins_with("artifact_glass_cube_"):base="res://assets/decor_bank/"
				assert(ResourceLoader.exists(base+asset+"/model.gltf","PackedScene"),asset)
		print("CANONICAL_PACK_ASSETS_PASS dragon=1 cubes=3 drinks=105 all_rc_interiors=true")
	print("TEEA008_PACK_AUDIT_PASS assets=",count," sketchfab=",new_models," layouts=33 media=32 pose_frames=",verified," hand_contacts=27 actor_banks=",banks)
	quit(0)
