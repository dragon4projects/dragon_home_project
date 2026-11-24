extends SceneTree
## Audit the exported Mac PCK in an otherwise empty Linux Godot project.
## This intentionally does not boot the Mac-only SQLite native library.
func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error("MAC_PACK_AUDIT_FAIL: "+message)
	quit(1)

func read_dict(path: String) -> Dictionary:
	var f:=FileAccess.open(path,FileAccess.READ)
	if f==null:
		return {}
	var parsed=JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if typeof(parsed)==TYPE_DICTIONARY else {}

func run() -> void:
	var args:=OS.get_cmdline_user_args()
	if args.size()!=1 or not ProjectSettings.load_resource_pack(args[0],true):
		fail("cannot mount exported PCK")
		return
	var required:= [
		"res://data/resident_profiles.json",
		"res://data/asset_registry_nov2026.json",
		"res://data/interior_layers_v1.json",
		"res://data/furniture_interactions_v1.json",
		"res://data/room_visual_layout_v2.json",
		"res://data/room_visual_components_v2.json",
		"res://data/integration_candidates/ITER1_ROOM_ART_REVIEW.json",
		"res://data/integration_candidates/furniture_interactions_iter1_review.json",
		"res://data/integration_candidates/room_visual_components_iter2_review.json",
		"res://data/integration_candidates/TEEA_INT_20261123_007_runtime_contract.json",
		"res://data/private_doors_v1.json",
	]
	for path in required:
		if read_dict(path).is_empty():
			fail("missing or invalid manifest: "+path)
			return
	if not FileAccess.file_exists("res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"):
		fail("missing review marker")
		return
	var registry:=read_dict("res://data/asset_registry_nov2026.json")
	var bound:int=0
	for id in registry.get("residents",{}):
		var actor:Dictionary=registry["residents"][id]
		for wardrobe in actor.get("wardrobes",{}):
			var states:Dictionary=actor["wardrobes"][wardrobe].get("states",{})
			var valid:bool=true
			for state in ["IDLE_S","WALK_LEFT","WALK_RIGHT"]:
				var entry:Dictionary=states.get(state,{})
				var frames:Array=entry.get("frames",[])
				if str(entry.get("status",""))!="PASS" or frames.is_empty():
					valid=false
					break
				for frame in frames:
					var relative:String=str(frame.get("path",frame.get("file",""))) if typeof(frame)==TYPE_DICTIONARY else str(frame)
					var res_path:String="res://"+relative.trim_prefix("res://")
					if not ResourceLoader.exists(res_path):
						fail("missing resident texture: "+res_path)
						return
			if valid:
				bound+=1
				break
	if bound<1:
		fail("no technically usable resident banks")
		return
	for asset in ["gothic_coffee_table","sofa_02","chinese_armchair","wooden_display_shelves_01","chinese_commode","wooden_table_02","metal_stool_02","worn_metal_rack"]:
		if not ResourceLoader.exists("res://assets/decor_bank/"+asset+"/model.gltf"):
			fail("missing model: "+asset)
			return
	print("MAC_PACK_AUDIT_PASS manifests=%d resident_banks=%d decor=8 review_marker=true" % [required.size(),bound])
	quit(0)
