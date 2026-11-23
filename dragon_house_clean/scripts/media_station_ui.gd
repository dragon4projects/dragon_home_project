extends PanelContainer
## On-demand UI for verified, imported local catalogs.
## Playback is explicit user action, never a fabricated autonomous event.
var model
var media_runtime
var category := "books"
var item_ids: Array = []
var title: Label
var list: ItemList
var details: Label
var preview: TextureRect
var video: VideoStreamPlayer
var audio: AudioStreamPlayer
var opened := false
var content_viewer

func _ready() -> void:
	name = "MediaLibrary"
	position = Vector2(704, 58)
	custom_minimum_size = Vector2(560, 610)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	add_child(col)
	title = Label.new()
	title.text = "МЕДИАТЕКА"
	col.add_child(title)
	var row := HBoxContainer.new()
	col.add_child(row)
	for label in ["Книги", "Музыка", "Фильмы"]:
		var b := Button.new()
		b.text = label
		row.add_child(b)
		match label:
			"Книги": b.pressed.connect(func(): switch_category("books"))
			"Музыка": b.pressed.connect(func(): switch_category("tracks"))
			"Фильмы": b.pressed.connect(func(): switch_category("films"))
	list = ItemList.new()
	list.custom_minimum_size = Vector2(510, 145)
	list.item_selected.connect(_on_selected)
	col.add_child(list)
	details = Label.new()
	details.text = "Нет выбранной записи."
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(0, 55)
	col.add_child(details)
	var button_row := HBoxContainer.new()
	col.add_child(button_row)
	var play := Button.new()
	play.text = "▶ Воспроизвести"
	play.pressed.connect(play_selected)
	button_row.add_child(play)
	var stop := Button.new()
	stop.text = "■ Стоп"
	stop.pressed.connect(stop_playback)
	button_row.add_child(stop)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(close_panel)
	button_row.add_child(close)
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(360, 215)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	col.add_child(preview)
	video = VideoStreamPlayer.new()
	video.custom_minimum_size = Vector2(360, 215)
	video.expand = true
	video.visible = false
	col.add_child(video)
	audio = AudioStreamPlayer.new()
	add_child(audio)

func bind(p_model, p_media_runtime, p_content_viewer = null) -> void:
	model = p_model
	media_runtime = p_media_runtime
	content_viewer = p_content_viewer
	refresh()

func open_panel() -> void:
	opened = true
	visible = true
	refresh()

func close_panel() -> void:
	stop_playback()
	opened = false
	visible = false

func switch_category(k: String) -> void:
	stop_playback()
	category = k
	refresh()

func refresh() -> void:
	if model == null or list == null:
		return
	list.clear()
	item_ids.clear()
	for item in model.media.get(category, []):
		var title_text: String = str(item.get("title","Без названия"))
		list.add_item(title_text)
		item_ids.append(str(item.get("id","")))
	var human: String = {"books":"КНИГИ","tracks":"АУДИОТЕКА","films":"ФИЛЬМОТЕКА"}.get(category,"МЕДИА")
	title.text = human + " — " + str(item_ids.size()) + " записей"
	details.text = "Каталог пуст. Импортируйте проверенный JSON." if item_ids.is_empty() else "Выберите запись."
	preview.texture = null
	preview.visible = true

func _on_selected(index: int) -> void:
	if index < 0 or index >= item_ids.size():
		return
	var item: Dictionary = media_runtime._lookup(category,item_ids[index])
	if item.is_empty():
		return
	var source := str(item.get("source",""))
	var raw_artist = item.get("artist",item.get("author",""))
	var artist: String = "" if raw_artist == null else str(raw_artist)
	details.text = str(item.get("title","")) + (" — " + artist if artist != "" else "")
	if category == "books" and not bool(item.get("physical", true)):
		details.text += "\nТолько каталог: физический экземпляр не подтверждён"
	var path: String = str(item.get("file_path",""))
	if path != "":
		details.text += "\nФайл: " + path.get_file()
	if category != "books" and not media_runtime.playable(category).any(func(it): return it.get("id","") == item_ids[index]):
		details.text += "\nНет совместимого локального файла для воспроизведения"
	var image_path: String = str(item.get("preview",""))
	preview.texture = null
	if image_path != "" and FileAccess.file_exists(image_path):
		var image := Image.new()
		if image.load(image_path) == OK:
			preview.texture = ImageTexture.create_from_image(image)
	if content_viewer != null:
		content_viewer.open_record(category,item)

func stop_playback() -> void:
	if audio and audio.playing:
		audio.stop()
	if video and video.is_playing():
		video.stop()
	if video:
		video.visible = false
	if preview:
		preview.visible = true

func play_selected() -> void:
	if list.get_selected_items().is_empty() or category == "books":
		return
	var index: int = list.get_selected_items()[0]
	var id: String = item_ids[index]
	var item: Dictionary = media_runtime._lookup(category,id)
	if item.is_empty():
		return
	if not media_runtime.playable(category).any(func(it): return it.get("id","") == id):
		details.text = "Файл недоступен или формат не поддерживается."
		return
	var path: String = str(item.get("file_path",""))
	stop_playback()
	if category == "tracks":
		var sound: AudioStream
		match path.get_extension().to_lower():
			"mp3": sound = AudioStreamMP3.load_from_file(path)
			"ogg": sound = AudioStreamOggVorbis.load_from_file(path)
			"wav": sound = AudioStreamWAV.load_from_file(path)
		if sound == null:
			details.text = "Не удалось загрузить аудио."
			return
		audio.stream = sound
		audio.play()
		details.text = "Играет: " + str(item.get("title",""))
	elif category == "films":
		# Godot core supports only Ogg/Theora, not MP4.
		var movie := VideoStreamTheora.new()
		movie.file = path
		video.stream = movie
		video.visible = true
		preview.visible = false
		video.play()
		details.text = "Смотрим: " + str(item.get("title",""))

