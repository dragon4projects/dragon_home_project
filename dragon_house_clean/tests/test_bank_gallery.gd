extends SceneTree
const RES = preload("res://scripts/asset_bank_resolver.gd")
const UI = preload("res://scripts/asset_gallery_ui.gd")
const TMP := "user://test_gallery_qa.json"
const ROOT := "res://assets/residents/RES_99/wardrobes/SHORT/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var map := {}
	for name in ["IDLE_S","WALK_LEFT","WALK_RIGHT"]:
		var relative: String = ROOT.trim_prefix("res://")+name+"/0001.png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT+name))
		var image := Image.create(32,48,false,Image.FORMAT_RGBA8)
		image.fill(Color("#ba5a6d"))
		assert(image.save_png("res://"+relative)==OK)
		map[name]={"frames":[relative],"status":"PASS","fps":6}
	var json = {"schema":1,"residents":{"RES_99":{"appearance_profile":"HELGA_99",
		"visual_bank_ready":false,"default_wardrobe":"SHORT",
		"wardrobes":{"SHORT":{"states":map}}}}}
	var f := FileAccess.open(TMP,FileAccess.WRITE)
	f.store_string(JSON.stringify(json))
	f.close()
	var resolver = RES.new()
	assert(resolver.initialize(TMP))
	var gallery = UI.new()
	root.add_child(gallery)
	gallery.bind(resolver,[{"id":"RES_99","display_name":"QA тест","appearance_profile":"HELGA_99"}])
	assert(gallery.roster_list.item_count==1)
	assert(gallery.wardrobe_menu.item_count==1)
	assert(gallery.wardrobe_menu.get_item_text(0)=="SHORT")
	assert(gallery.picture.texture != null)
	assert(gallery.status.text.contains("Технически: 1"))
	gallery.visible=true
	gallery._process(0.3)
	assert(gallery.picture.texture != null)
	gallery.queue_free()
	for state in ["IDLE_S","WALK_LEFT","WALK_RIGHT"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT+state+"/0001.png"))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOT+state+"/0001.png.import"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	print("BANK_GALLERY_TEST_PASS all_roster QA_not_approved preview=visible")
	quit(0)

