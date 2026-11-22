extends SceneTree
const InteriorLayerScript = preload("res://scripts/interior_skin.gd")
const TMP_MANIFEST := "user://test_interior_skin_v1.json"
const BACKDROP := "res://assets/rooms/qa_test_room/R3/qa_backdrop.png"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKDROP.get_base_dir()))
	var img := Image.create(288,98,false,Image.FORMAT_RGBA8)
	img.fill(Color("#4e3937"))
	assert(img.save_png(BACKDROP)==OK)
	var doc := {
		"schema":1,
		"room_types":{
			"qa_test_room":{"R3":{"layers":[
				{"role":"backdrop","path":BACKDROP.trim_prefix("res://"),"approved":true},
				{"role":"foreground","path":BACKDROP.trim_prefix("res://"),"approved":false},
				{"role":"back_decor","path":"assets/rooms/qa_test_room/R3/../private_unapproved.png","approved":true},
				{"role":"front_trim","path":"assets/rooms/private/R3/private.png","approved":true}
			]}}
		}
	}
	var f := FileAccess.open(TMP_MANIFEST,FileAccess.WRITE)
	f.store_string(JSON.stringify(doc))
	f.close()
	var skin = InteriorLayerScript.new()
	assert(skin.initialize(TMP_MANIFEST))
	var layers := skin.validated_layers("qa_test_room",3)
	assert(layers.size()==1 and layers[0]["role"]=="backdrop")
	assert(skin.validated_layers("private",3).is_empty(),"No private art from public manifest")
	assert(skin.validated_layers("qa_test_room",2).is_empty(),"Wrong room width")
	var target := Node3D.new()
	root.add_child(target)
	var added: int = skin.add_layers(target,"qa_test_room",3,14.4)
	assert(added==1)
	var art: Sprite3D = target.get_child(0)
	assert(art.texture != null and art.name == "Art_backdrop")
	assert(is_equal_approx(art.position.z,-1.79))
	assert(is_equal_approx(float(art.pixel_size)*288.0,14.4))
	var cache_tex: Texture2D = skin.texture_for(layers[0]["path"])
	assert(cache_tex == art.texture)
	# LFS pointer text has no pixels. It must not hide the old furniture.
	var pointer_file:=FileAccess.open(BACKDROP,FileAccess.WRITE)
	pointer_file.store_string("version https://git-lfs.github.com/spec/v1\n"
		+"oid sha256:"+"0".repeat(64)+"\nsize 290000\n")
	pointer_file.close()
	assert(skin.validated_layers("qa_test_room",3).is_empty(),
		"Pointer text named .png must never replace a rendered room")
	assert(img.save_png(BACKDROP)==OK)
	assert(skin.validated_layers("qa_test_room",3).size()==1)
	target.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(BACKDROP))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_MANIFEST))
	print("INTERIOR_LAYER_TEST_PASS width=R3 transparency=kept private=blocked depth=correct")
	quit(0)

