extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	OS.set_environment("DRAGON_HOUSE_ARCHITECTURE","1")
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	scene.set_process(false)
	await process_frame
	var world=scene.world
	var gallery:Dictionary=scene._artifact_room()
	var rid:String=str(gallery["id"])
	var file:=FileAccess.open("res://assets/manifests/artifact_master_sources_zna004.json",FileAccess.READ)
	var manifest=JSON.parse_string(file.get_as_text())
	var count:=0
	var homes:Dictionary={}
	for entry in manifest["entries"]:
		var path:String="res://"+str(entry["repo_source_target"])
		assert(ResourceLoader.exists(path,"Texture2D"),path)
		assert(ResourceLoader.exists("res://"+str(entry["preview_target"]),"Texture2D"))
		var id:String=str(entry["normalized_id"])
		var obj:Dictionary=world.physical_object(id)
		if id=="ARTEFACT_006_CUBE_LETTERS_BEFORE_SLEEP" and obj.is_empty():obj=world.physical_object("CUBE_LETTERS")
		assert(not obj.is_empty(),id)
		if str(obj.get("id",""))==id:
			assert(obj.get("artifact_source_status","")!="" and obj.get("full_image_path","")==path)
			assert(str(obj.get("canonical_owner_id",""))=="")
			assert(str(obj.get("home_room_id",""))==rid)
			var sid:String=str(obj.get("home_support_id",""))
			assert(sid!="" and not homes.has(sid))
			homes[sid]=true
		count+=1
	assert(count==10)
	assert(scene._restore_zna_artifact_sources()==0)
	print("ZNA_ARTIFACT_SOURCE_RESTORE_PASS count=",count)
	quit(0)
