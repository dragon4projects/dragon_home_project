extends PanelContainer
## Full-screen viewer for explicit Dragon House content records.
## It never invents content. Missing local bytes remain a visible, non-fatal state.

signal artwork_assignment_requested(slot_id:String)
var artwork_assign:Button
var category := ""
var item: Dictionary = {}
var media_runtime
var title_label: Label
var meta_label: Label
var preview: TextureRect
var text_view: RichTextLabel

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
	artwork_assign=Button.new()
	artwork_assign.text="Назначить изображение"
	artwork_assign.visible=false
	artwork_assign.pressed.connect(func():artwork_assignment_requested.emit(str(item.get("id",""))))
	header.add_child(artwork_assign)
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

# Legacy callers cannot open external media; previews are local and static.
func _open_source()->void:
	pass

func bind(p_media_runtime) -> void:
	media_runtime = p_media_runtime

func close_viewer() -> void:
	stop_playback()
	visible = false
	# Release full-size artifact originals when the viewer is closed.
	if preview!=null:preview.texture=null
	item.clear()

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
	artwork_assign.visible=bool(item.get("dense_v2_assignable",false))
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
	var preview_path := str(item.get("preview",item.get("preview_path","")))
	preview.texture = texture_override if texture_override!=null else _load_preview(preview_path)
	var text_path := str(item.get("content_path",item.get("text_path","")))
	var body := _safe_text(text_path)
	if p_category == "books" and body != "":
		text_view.text = body
		text_view.visible = true
		preview.visible = preview.texture != null
	if p_category=="tracks":
		var seconds:int=int(item.get("runtime_seconds",0))
		if seconds>0:meta_label.text+="\nПродолжительность: %d:%02d" % [seconds/60,seconds%60]
		else:meta_label.text+="\nПродолжительность не установлена."
		meta_label.text+="\nСимуляция прослушивания; звук не воспроизводится."
	if p_category=="films":
		var duration:int=int(item.get("runtime_seconds",0))
		if duration>0:meta_label.text+="\nПродолжительность: %d мин." % int(duration/60)
		elif str(item.get("media_type",""))=="series":
			meta_label.text+="\nСериал · просмотр по одной серии"
		meta_label.text+="\nСимуляция просмотра; видео не воспроизводится."
	if p_category == "books" and body == "" and preview.texture == null:
		meta_label.text += ("\n" if meta_label.text != "" else "") + 			"Для этой записи пока нет локального полнотекстового содержимого или превью."
	if p_category in ["artifacts","paintings","posters","cups","creatures"] and preview.texture == null:
		meta_label.text += ("\n" if meta_label.text != "" else "") + 			"Для этого объекта пока нет локального превью."
	if bool(item.get("canonical_cube_master",false)) and preview.texture!=null:
		meta_label.text=""
	meta_label.visible=meta_label.text!=""
	visible = true
	return true

# Compatibility entry points; media is simulation-only even for legacy file records.
func stop_playback() -> void:
	pass

func play() -> void:
	pass
