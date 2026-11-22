extends SceneTree
const Resolver = preload("res://scripts/asset_bank_resolver.gd")
const ROOT := "res://assets/residents/RES_99/wardrobes/HOME/"
const TMP := "user://test_nov_assets.json"

func _initialize() -> void:
	var folder := ROOT+"IDLE_S/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT+"WALK_LEFT/"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT+"WALK_RIGHT/"))
	var img := Image.create(32,48,false,Image.FORMAT_RGBA8)
	img.fill(Color(0.8,0.2,0.3,0.85))
	var entries: Dictionary = {}
	for state in ["IDLE_S","WALK_LEFT","WALK_RIGHT"]:
		var relative: String = ROOT.trim_prefix("res://")+state+"/0001.png"
		assert(img.save_png("res://"+relative) == OK)
		entries[state] = {"frames":[relative],"fps":18,"status":"PASS"}
	var manifest: Dictionary = {"schema":1,"residents":{"RES_99":{
		"appearance_profile":"HELGA_99",
		"visual_bank_ready":true,
		"runtime_bound":false,
		"wardrobes":{"HOME":{"states":entries}}}}}
	var out := FileAccess.open(TMP,FileAccess.WRITE)
	out.store_string(JSON.stringify(manifest))
	out.close()
	var loader = Resolver.new()
	assert(loader.initialize(TMP))
	var actual_entries: Dictionary = loader.manifest["residents"]["RES_99"]["wardrobes"]["HOME"]["states"]
	assert(loader.verified_bank("RES_99","HELGA_99"))
	assert(not loader.verified_bank("RES_99","HELGA_98"),"Cannot swap identity")
	assert(not loader.verified_bank("RES_98","HELGA_99"),"Cannot cross resident paths")
	assert(loader.frame_count("RES_99","HOME","WALK_LEFT")==1)
	assert(loader.fps("RES_99","HOME","WALK_LEFT")==18)
	var tex: Texture2D = loader.texture_for("RES_99","HOME","WALK_LEFT",20)
	assert(tex != null and tex.get_width() == 32)
	actual_entries["WALK_LEFT"]["frames"] = ["assets/residents/RES_98/wardrobes/HOME/WALK_LEFT/0001.png"]
	assert(not loader.verified_bank("RES_99","HELGA_99"),"Wrong ID path rejected")
	actual_entries["WALK_LEFT"]["frames"] = ["assets/residents/RES_99/wardrobes/HOME/WALK_LEFT/../../../../bad.png"]
	assert(not loader.verified_bank("RES_99","HELGA_99"),"Traversal rejected")
	actual_entries["WALK_LEFT"]["frames"] = ["assets/residents/RES_99/wardrobes/HOME/WALK_LEFT/0001.png"]
	loader.manifest["residents"]["RES_99"]["visual_bank_ready"] = false
	assert(not loader.verified_bank("RES_99","HELGA_99"),"Found does not mean verified")
	assert(loader.candidate_bank("RES_99","HELGA_99"),"Technical PASS can be previewed explicitly")
	assert(loader.preferred_wardrobe("RES_99","HELGA_99") == "","Unapproved default stays hidden")
	assert(loader.preferred_wardrobe("RES_99","HELGA_99",true) == "HOME")
	assert(loader.preview_count([{"id":"RES_99","appearance_profile":"HELGA_99"}])==1)
	# Git LFS pointers contain readable text but no actual image pixels.
	var pointer_path: String = ROOT+"WALK_LEFT/0001.png"
	var ptr := FileAccess.open(pointer_path,FileAccess.WRITE)
	ptr.store_string("version https://git-lfs.github.com/spec/v1\noid sha256:"+"0".repeat(64)+"\nsize 69562\n")
	ptr.close()
	assert(not loader.candidate_bank("RES_99","HELGA_99"),
		"QA must not accept Git LFS pointer as decoded PNG")
	assert(img.save_png(pointer_path)==OK)
	assert(loader.candidate_bank("RES_99","HELGA_99"))
	for state in ["IDLE_S","WALK_LEFT","WALK_RIGHT"]:
		var absolute: String = ProjectSettings.globalize_path(ROOT+state+"/0001.png")
		DirAccess.remove_absolute(absolute)
		DirAccess.remove_absolute(absolute+".import")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("ASSET_BINDING_TEST_PASS approved=1 candidate_preview=separate wrong_identity=rejected traversal=rejected")
	quit(0)

