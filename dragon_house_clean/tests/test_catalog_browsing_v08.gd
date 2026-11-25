extends SceneTree
const W = preload("res://scripts/world_model.gd")
const L = preload("res://scripts/life.gd")
const MediaPanel = preload("res://scripts/media_station_ui.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := W.new()
	world.save_path = "user://test_catalog_browsing_v08.json"
	world.seed_world()
	var added := world.merge_reference_book_metadata([
		{"id":"BOOK_REFERENCE_01","title":"Достоверная книга","author":null,
		 "status":"METADATA_ONLY","source":"cloud-reviewed"}
	])
	assert(added==1)
	world.media["films"]=[{"id":"FILM_01","title":"Фильм без локального файла",
		"file_path":"user://not_present.mp4"}]
	world.media["tracks"]=[{"id":"TRACK_01","title":"Аудио без локального файла",
		"file_path":"user://not_present.wav"}]
	var life := L.new()
	life.setup(world)
	var reader: Dictionary=world.residents["RES_01"]
	var scores: Dictionary=life._utilities(reader)
	assert(scores.has("BROWSE_BOOK_CATALOG") and scores.has("BROWSE_FILMS") and scores.has("BROWSE_AUDIO"))
	assert(not scores.has("READ_BOOK"),"Metadata is not a physical volume")
	assert(not scores.has("WATCH_FILM"),"Film without duration metadata cannot be watched")
	assert(not scores.has("LISTEN_MUSIC"),"Track without duration metadata cannot be listened to")
	for example in [
		{"id":"RES_01","intent":"BROWSE_BOOK_CATALOG","room":world.get_room(2,0),
		 "category":"books","entry":"BOOK_REFERENCE_01"},
		{"id":"RES_02","intent":"BROWSE_FILMS","room":world.get_room(4,0),
		 "category":"films","entry":"FILM_01"},
		{"id":"RES_03","intent":"BROWSE_AUDIO","room":world.get_room(3,0),
		 "category":"tracks","entry":"TRACK_01"}
	]:
		var actor: Dictionary=world.residents[example["id"]]
		life._assign(actor,{"intent":example["intent"],"room":example["room"]})
		assert(actor.get("intent","")==example["intent"])
		assert(actor.get("browsing_category","")==example["category"])
		assert(actor.get("browsing_item_id","")==example["entry"])
		assert(actor.get("station_room_id","")==example["room"]["id"])
		assert(actor.get("held_book","")=="")
		life.end_catalog_browse(actor)
		assert(not actor.has("browsing_category") and not actor.has("browsing_item_id"))
	var metadata: Dictionary=world.media["books"][0]
	assert(not metadata["physical"])
	assert(str(metadata.get("holder_id",""))=="")
	assert(metadata.get("progress_by_actor",{}).is_empty())
	var ui := MediaPanel.new()
	root.add_child(ui)
	ui.bind(world,life.media_runtime)
	ui.switch_category("books")
	ui._on_selected(0)
	assert(ui.details.text.contains("физический экземпляр не подтверждён"))
	assert(not ui.details.text.contains("Null"),"null author cannot be displayed as a name")
	ui.switch_category("films")
	ui._on_selected(0)
	assert(ui.details.text.contains("Симуляция просмотра"))
	assert(ui.details.text.contains("Продолжительность не установлена"))
	ui.switch_category("tracks")
	ui._on_selected(0)
	assert(ui.details.text.contains("симуляция прослушивания"))
	ui.play_selected()
	assert(ui.find_children("*","AudioStreamPlayer",true,false).is_empty())
	assert(ui.find_children("*","VideoStreamPlayer",true,false).is_empty())
	ui.queue_free()
	for ext in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path+ext))
	print("MEDIA_CATALOG_BROWSE_V08_PASS books=metadata_only films=not_playable tracks=not_playable no_fake_consumption")
	quit(0)

