extends SceneTree

const MARKER := "res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"
const ART := "res://data/integration_candidates/ITER1_ROOM_ART_REVIEW.json"
const FURN := "res://data/integration_candidates/furniture_interactions_iter1_review.json"

func _json(path: String) -> Dictionary:
	assert(FileAccess.file_exists(path))
	var f:=FileAccess.open(path,FileAccess.READ)
	assert(f!=null)
	var parsed=JSON.parse_string(f.get_as_text())
	f.close()
	assert(typeof(parsed)==TYPE_DICTIONARY)
	return parsed

func run() -> void:
	assert(FileAccess.file_exists(MARKER))
	var art_doc:Dictionary=_json(ART)
	var room_types:Dictionary=art_doc.get("room_types",{})
	var library_r1:Dictionary=room_types.get("library",{}).get("R1",{})
	var music_r1:Dictionary=room_types.get("music",{}).get("R1",{})
	assert(str(library_r1.get("source_batch",""))=="TEEA_INT_20261123_005")
	assert(library_r1.get("layers",[]).size()==4)
	for layer in library_r1.get("layers",[]):
		assert(str(layer.get("path","")).contains(
			"assets/room_candidates/TEEA_INT_20261123_005/library/R1/"))
		assert(bool(layer.get("candidate_review",false)))
		assert(not bool(layer.get("approved",true)))
	assert(str(music_r1.get("source_batch",""))=="TEEA_INT_20261123_006")
	assert(music_r1.get("layers",[]).size()>=3)

	var furn_doc:Dictionary=_json(FURN)
	var overrides:Dictionary=furn_doc.get("variant_cell_overrides",{})
	var lib_raw:Array=overrides.get("library:R1:0",[])
	assert(lib_raw.size()==2)
	var ids:Array=[]
	for spot in lib_raw:
		ids.append(str(spot.get("id","")))
		assert(str(spot.get("source_batch",""))=="TEEA_INT_20261123_005")
	assert(ids.has("library_r1_front_reader_seat"))
	assert(ids.has("library_r1_lectern_read"))
	var music_raw:Array=overrides.get("music:R1:0",[])
	assert(not music_raw.is_empty())
	for spot in music_raw:
		assert(str(spot.get("source_batch",""))=="TEEA_INT_20261123_006")

	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await process_frame
	assert(scene.iter1_owner_review)
	var layers:Array=scene.interior_skin.validated_layers("library",1)
	assert(layers.size()==4)
	for layer in layers:
		assert(str(layer.get("path","")).contains(
			"assets/room_candidates/TEEA_INT_20261123_005/library/R1/"))

	var library:Dictionary=scene.world.get_room(2,0)
	assert(not library.is_empty() and scene.world.room_size_modules(library)==1)
	var spots:Array=scene.life.stations.layout_for_world(scene.world,library)
	var runtime_ids:Array=[]
	for spot in spots:
		runtime_ids.append(str(spot.get("id","")))
	assert(runtime_ids.has("m0_library_r1_front_reader_seat"))
	assert(runtime_ids.has("m0_library_r1_lectern_read"))
	var front_index:int=runtime_ids.find("m0_library_r1_front_reader_seat")
	var lectern_index:int=runtime_ids.find("m0_library_r1_lectern_read")
	assert(front_index>=0 and lectern_index>=0)
	var front:Vector2=spots[front_index]["offset"]
	var lectern:Vector2=spots[lectern_index]["offset"]
	assert(front.distance_to(Vector2(-1.12,-0.0563))<0.01)
	assert(lectern.distance_to(Vector2(1.12,-0.61))<0.01)

	print("ITER2_REVIEW_PACKAGES_PASS library_R1=TEEA005 music_R1=TEEA006 stations=26+31")
	quit(0)

func _initialize() -> void:
	call_deferred("run")
