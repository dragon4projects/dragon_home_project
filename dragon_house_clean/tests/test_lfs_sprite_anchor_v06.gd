extends SceneTree
## Must run only after Git LFS pull and Godot image import.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene=load("res://scenes/main.tscn").instantiate()
	scene.world.save_path="user://test_lfs_attached_sprite_v06.json"
	root.add_child(scene)
	current_scene=scene
	assert(not scene.qa_visual_preview,"Canonical approval must not be inferred from LFS")
	var res01: Dictionary=scene.world.residents["RES_01"]
	assert(not res01.get("runtime_visual_bound",false))
	scene.toggle_qa_art_preview()
	assert(scene.qa_visual_preview)
	var actor: Dictionary=scene.world.residents["RES_01"]
	assert(actor.get("runtime_visual_bound",false),"Actual bank was not attached in QA mode")
	assert(actor.get("visual_preview_only",false),"Visual bank must remain QA-only")
	var body: Sprite3D=scene.actor_sprites["RES_01"].get_node("Body")
	assert(body.texture!=null)
	var outfit: String=str(actor.get("visual_wardrobe",""))
	assert(outfit==scene.asset_banks.preferred_wardrobe("RES_01","HELGA_01",true))
	var h: int=body.texture.get_height()
	var feet_y: float=scene.asset_banks.feet_anchor("RES_01",outfit,h)
	var expected:float=maxf(0.15,(feet_y-float(h)*0.5)*body.pixel_size)
	assert(absf(body.position.y-expected)<0.0001,
		"Feet anchor was overwritten or resized inconsistently")
	var creature: Dictionary=scene.world.residents["MANJKA"]
	assert(creature.get("runtime_visual_bound",false))
	var pet: Sprite3D=scene.actor_sprites["MANJKA"].get_node("Body")
	assert(pet.texture!=null)
	scene.qa_visual_preview=false
	scene.make_residents()
	assert(not scene.world.residents["RES_01"].get("runtime_visual_bound",false),
		"QA toggle-off must restore stand-in until human acceptance")
	assert(not scene.world.residents["MANJKA"].get("runtime_visual_bound",false))
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(scene.world.save_path+ext))
	print("LFS_ANCHOR_V06_PASS RES_01 outfit=%s feet=%0.3f Manka=QA_only restored" % [outfit,expected])
	quit(0)

