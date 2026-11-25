extends SceneTree
const World = preload("res://scripts/world_model.gd")
const Media = preload("res://scripts/media_runtime.gd")
const Viewer = preload("res://scripts/content_viewer.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	world.seed_world()
	world.media["books"] = [{
		"id":"BOOK_VIEW_01","title":"Книга без превью","author":"Автор",
		"physical":false,"preview":""
	}]
	world.media["films"] = [{
		"id":"FILM_VIEW_01","title":"Фильм без файла","file_path":"user://missing.ogv"
	}]
	world.media["tracks"] = [{
		"id":"TRACK_VIEW_01","title":"Трек без файла","file_path":"user://missing.wav"
	}]
	var media := Media.new()
	media.setup(world)
	var viewer := Viewer.new()
	root.add_child(viewer)
	viewer.bind(media)
	assert(viewer.open_record("books",world.media["books"][0]))
	assert(viewer.visible)
	assert(viewer.title_label.text=="Книга без превью")
	assert(viewer.meta_label.text.contains("Автор"))
	assert(viewer.meta_label.text.contains("нет локального"))
	viewer.close_viewer()
	assert(not viewer.visible)
	assert(viewer.open_record("films",world.media["films"][0]))
	assert(viewer.meta_label.text.contains("Симуляция просмотра"))
	assert(viewer.find_children("*","VideoStreamPlayer",true,false).is_empty())
	assert(viewer.find_children("*","AudioStreamPlayer",true,false).is_empty())
	assert(viewer.open_record("tracks",world.media["tracks"][0]))
	assert(viewer.meta_label.text.contains("Симуляция прослушивания"))
	viewer.play()
	viewer._open_source()
	assert(viewer.visible and viewer.preview.visible)
	assert(media.playable("tracks").is_empty() and media.playable("films").is_empty())
	assert(viewer.open_record("artifacts",{
		"id":"ART_01","display_name":"Артефакт без картинки","description":"Описание"
	}))
	assert(viewer.title_label.text=="Артефакт без картинки")
	assert(viewer.meta_label.text.contains("Описание"))
	assert(viewer.meta_label.text.contains("нет локального превью"))
	viewer.queue_free()
	print("CONTENT_VIEWER_V018_PASS fullscreen=yes missing_content=safe categories=book_film_track_artifact")
	quit(0)
