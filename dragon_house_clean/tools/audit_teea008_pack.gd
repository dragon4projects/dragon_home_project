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
	assert(proof.get("frames",{}).size()==103)
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
	print("TEEA008_PACK_AUDIT_PASS assets=",count," layouts=33 media=32 pose_frames=",verified," actor_banks=",banks)
	quit(0)
