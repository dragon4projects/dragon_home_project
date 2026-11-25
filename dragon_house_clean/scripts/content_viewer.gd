extends PanelContainer
## Full-screen viewer for explicit Dragon House content records.
## It never invents content. Missing local bytes remain a visible, non-fatal state.

var category := ""
var item: Dictionary = {}
var media_runtime
var title_label: Label
var meta_label: Label
var preview: TextureRect
var text_view: RichTextLabel
var video: VideoStreamPlayer
var audio: AudioStreamPlayer
var play_button: Button
var source_button: Button

func _ready() -> void:
	name = "ContentViewer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 34
	offset_top = 28
	offset_right = -34
	offset_bottom = -28
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var col := VBoxContainer.new()
	add_child(col)
	var header := HBoxContainer.new()
	col.add_child(header)
	title_label = Label.new()
	title_label.text = "ПРОСМОТР"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)
	var close := Button.new()
	close.text = "Закрыть [Esc]"
	close.pressed.connect(close_viewer)
	header.add_child(close)
	meta_label = Label.new()
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(meta_label)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(720,340)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(preview)
	text_view = RichTextLabel.new()
	text_view.bbcode_enabled = false
	text_view.fit_content = false
	text_view.scroll_active = true
	text_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_view.custom_minimum_size = Vector2(720,220)
	text_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_view.visible = false
	col.add_child(text_view)
	video = VideoStreamPlayer.new()
	video.custom_minimum_size = Vector2(720,400)
	video.expand = true
	video.visible = false
	video.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(video)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	var controls := HBoxContainer.new()
	col.add_child(controls)
	play_button = Button.new()
	play_button.text = "▶ Воспроизвести"
	play_button.pressed.connect(play)
	controls.add_child(play_button)
	source_button=Button.new()
	source_button.text="Открыть оригинал на YouTube"
	source_button.visible=false
	source_button.pressed.connect(_open_source)
	controls.add_child(source_button)
	var stop := Button.new()
	stop.text = "■ Стоп"
	stop.pressed.connect(stop_playback)
	controls.add_child(stop)

func _youtube_source(record:Dictionary)->String:
	# Only the known exact YouTube watch URL shape is allowed, and only after
	# an explicit click. No arbitrary OS-shell URLs or automatic requests.
	var url:String=str(record.get("source_url",""))
	const PREFIX:="https://www.youtube.com/watch?v="
	if not url.begins_with(PREFIX):return ""
	var video_id:String=url.trim_prefix(PREFIX)
	if video_id.length()!=11:return ""
	for i in range(video_id.length()):
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-".contains(video_id.substr(i,1)):
			return ""
	return url

func _open_source()->void:
	var url:String=_youtube_source(item)
	if url!="":OS.shell_open(url)

func bind(p_media_runtime) -> void:
	media_runtime = p_media_runtime

func close_viewer() -> void:
	stop_playback()
	visible = false

func _safe_text(path: String) -> String:
	if path == "" or not path.begins_with("res://") and not path.begins_with("user://"):
		return ""
	if not ["md","txt"].has(path.get_extension().to_lower()) or not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 524288:
		return ""
	return file.get_as_text()

func _load_preview(path: String) -> Texture2D:
	if path == "" or not (path.begins_with("res://") or path.begins_with("user://")):
		return null
	if path.begins_with("res://") and ResourceLoader.exists(path,"Texture2D"):
		var imported:=ResourceLoader.load(path,"Texture2D") as Texture2D
		if imported!=null:
			return imported
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

func open_record(p_category: String, record: Dictionary, texture_override: Texture2D = null) -> bool:
	if record.is_empty():
		return false
	stop_playback()
	category = p_category
	item = record.duplicate(true)
	var title := str(item.get("title",item.get("display_name","Без названия")))
	title_label.text = title
	var byline_raw = item.get("artist",item.get("author",""))
	var byline := "" if byline_raw == null else str(byline_raw)
	var details: Array[String] = []
	if byline != "":
		details.append(byline)
	var description := str(item.get("description",item.get("notes","")))
	if description != "":
		details.append(description)
	var provenance := str(item.get("provenance",item.get("source","")))
	if provenance != "":
		details.append("Источник: " + provenance)
	meta_label.text = "\n".join(details)
	preview.texture = null
	preview.visible = true
	text_view.text = ""
	text_view.visible = false
	video.visible = false
	var preview_path := str(item.get("preview",item.get("preview_path","")))
	preview.texture = texture_override if texture_override!=null else _load_preview(preview_path)
	var text_path := str(item.get("content_path",item.get("text_path","")))
	var body := _safe_text(text_path)
	if p_category == "books" and body != "":
		text_view.text = body
		text_view.visible = true
		preview.visible = preview.texture != null
	var file_path := str(item.get("file_path",""))
	play_button.visible = p_category=="tracks"
	source_button.visible=p_category=="tracks" and _youtube_source(item)!=""
	if p_category=="films":
		var duration:int=int(item.get("runtime_seconds",0))
		if duration>0:meta_label.text+="\nПродолжительность: %d мин." % int(duration/60)
		elif str(item.get("media_type",""))=="series":
			meta_label.text+="\nСериал · просмотр по одной серии"
		meta_label.text+="\nСимуляция просмотра; видео не воспроизводится."
	if p_category=="tracks":
		if media_runtime == null or not media_runtime.playable(p_category).any(
			func(candidate): return str(candidate.get("id","")) == str(item.get("id",""))):
			meta_label.text += ("\n" if meta_label.text != "" else "") + 				"Локальный файл отсутствует или формат не поддерживается."
	if p_category == "books" and body == "" and preview.texture == null:
		meta_label.text += ("\n" if meta_label.text != "" else "") + 			"Для этой записи пока нет локального полнотекстового содержимого или превью."
	if p_category in ["artifacts","paintings","posters","cups","creatures"] and preview.texture == null:
		meta_label.text += ("\n" if meta_label.text != "" else "") + 			"Для этого объекта пока нет локального превью."
	visible = true
	return true

func stop_playback() -> void:
	if audio != null and audio.playing:
		audio.stop()
	if video != null and video.is_playing():
		video.stop()
	if video != null:
		video.visible = false
	if preview != null:
		preview.visible = true

func play() -> void:
	if item.is_empty() or category!="tracks" or media_runtime == null:
		return
	var id := str(item.get("id",""))
	if not media_runtime.playable(category).any(func(candidate): return str(candidate.get("id","")) == id):
		meta_label.text += "\nНечего воспроизводить: совместимых локальных байтов нет."
		return
	var path := str(item.get("file_path",""))
	stop_playback()
	if category == "tracks":
		var sound: AudioStream
		match path.get_extension().to_lower():
			"mp3": sound = AudioStreamMP3.load_from_file(path)
			"ogg": sound = AudioStreamOggVorbis.load_from_file(path)
			"wav": sound = AudioStreamWAV.load_from_file(path)
		if sound == null:
			meta_label.text += "\nНе удалось загрузить аудио."
			return
		audio.stream = sound
		audio.play()
	elif category == "films":
		var movie := VideoStreamTheora.new()
		movie.file = path
		video.stream = movie
		video.visible = true
		preview.visible = false
		video.play()
