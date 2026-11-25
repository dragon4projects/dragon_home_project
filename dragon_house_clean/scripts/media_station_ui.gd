extends PanelContainer
## On-demand UI for verified, imported local catalogs.
## Playback is explicit user action, never a fabricated autonomous event.
var model
var media_runtime
var category := "books"
var item_ids: Array = []
var title: Label
var list: ItemList
var search_box: LineEdit
var play_button: Button
var stop_button: Button
var details: Label
var preview: TextureRect
var video: VideoStreamPlayer
var audio: AudioStreamPlayer
var opened := false
var content_viewer
signal surface_assignment_requested(room_id:String,surface_id:String,category:String,item_id:String)
var surface_room_id: String=""
var surface_id: String=""
var surface_category: String=""
var surface_controls: HBoxContainer
var surface_label: Label
var place_button:Button
signal artifact_placement_requested(room_id:String,surface_id:String,item_id:String)

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
	search_box=LineEdit.new()
	search_box.placeholder_text="Поиск по названию / исполнителю"
	search_box.text_changed.connect(func(_value): refresh())
	col.add_child(search_box)
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
	play_button = Button.new()
	play_button.text = "▶ Воспроизвести"
	play_button.pressed.connect(play_selected)
	button_row.add_child(play_button)
	stop_button = Button.new()
	stop_button.text = "■ Стоп"
	stop_button.pressed.connect(stop_playback)
	button_row.add_child(stop_button)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(close_panel)
	button_row.add_child(close)
	surface_label=Label.new()
	surface_label.visible=false
	col.add_child(surface_label)
	surface_controls=HBoxContainer.new()
	surface_controls.visible=false
	col.add_child(surface_controls)
	var assign_button:=Button.new()
	assign_button.text="Назначить на держатель"
	assign_button.pressed.connect(_assign_selected_surface)
	surface_controls.add_child(assign_button)
	place_button=Button.new()
	place_button.text="Поставить на опору"
	place_button.visible=false
	place_button.pressed.connect(_place_selected_artifact)
	surface_controls.add_child(place_button)
	var clear_button:=Button.new()
	clear_button.text="Очистить держатель"
	clear_button.pressed.connect(func(): surface_assignment_requested.emit(surface_room_id,surface_id,surface_category,""))
	surface_controls.add_child(clear_button)
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
	clear_surface_context()
	stop_playback()
	opened = false
	visible = false

func switch_category(k: String) -> void:
	if surface_category!="" and surface_category!=k:
		clear_surface_context()
	stop_playback()
	category = k
	if search_box!=null:search_box.set_text("")
	refresh()

func refresh() -> void:
	if model == null or list == null:
		return
	play_button.visible=category=="tracks"
	stop_button.visible=category=="tracks"
	list.clear()
	item_ids.clear()
	var records:Array=model.media.get(category,[])
	if category=="artifacts":
		records=[]
		for item in model.objects.values():
			if str(item.get("viewer_category",""))=="artifacts" and str(item.get("current_room_id",""))==surface_room_id and str(item.get("state",""))=="PLACED" and str(item.get("current_holder_id",""))=="":
				records.append(item)
	var query:String=search_box.text.strip_edges().to_lower() if search_box!=null else ""
	for item in records:
		var title_text: String = str(item.get("title",item.get("display_name","Без названия")))
		var byline:String=str(item.get("artist",item.get("author","")))
		if query!="" and not (title_text+" "+byline).to_lower().contains(query):continue
		list.add_item(title_text)
		item_ids.append(str(item.get("id","")))
	var human: String = {"books":"КНИГИ","tracks":"АУДИОТЕКА","films":"ФИЛЬМОТЕКА","artifacts":"АРТЕФАКТЫ"}.get(category,"МЕДИА")
	title.text = human + " — " + str(item_ids.size()) + ("/"+str(records.size()) if query!="" else "") + " записей"
	details.text = ("Ничего не найдено." if query!="" else "Каталог пуст. Импортируйте проверенный JSON.") if item_ids.is_empty() else "Выберите запись."
	preview.texture = null
	preview.visible = true

func _on_selected(index: int) -> void:
	if index < 0 or index >= item_ids.size():
		return
	var item: Dictionary = model.physical_object(str(item_ids[index])) if category=="artifacts" else media_runtime._lookup(category,item_ids[index])
	if item.is_empty():
		return
	var source := str(item.get("source",""))
	var raw_artist = item.get("artist",item.get("author",""))
	var artist: String = "" if raw_artist == null else str(raw_artist)
	details.text = str(item.get("title",item.get("display_name",""))) + (" — " + artist if artist != "" else "")
	if category == "books" and not bool(item.get("physical", true)):
		details.text += "\nТолько каталог: физический экземпляр не подтверждён"
	var path: String = str(item.get("file_path",""))
	if path != "":
		details.text += "\nФайл: " + path.get_file()
	if category=="films":
		details.text+="\nСимуляция просмотра · "+str(item.get("duration_status","Продолжительность не установлена"))
	elif category=="tracks" and not media_runtime.playable(category).any(func(it): return it.get("id","") == item_ids[index]):
		details.text += "\nНет совместимого локального файла для воспроизведения"
	var image_path: String = str(item.get("preview",item.get("preview_path","")))
	preview.texture = null
	if content_viewer!=null:
		preview.texture=content_viewer._load_preview(image_path)
	elif image_path.begins_with("res://") and ResourceLoader.exists(image_path,"Texture2D"):
		preview.texture=ResourceLoader.load(image_path,"Texture2D") as Texture2D
	elif image_path != "" and FileAccess.file_exists(image_path):
		var image := Image.new()
		if image.load(image_path) == OK:
			preview.texture = ImageTexture.create_from_image(image)
	if content_viewer != null and surface_id=="":
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
	if list.get_selected_items().is_empty() or category!="tracks":
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


func open_surface(room_id:String,id:String,k:String)->void:
	clear_surface_context()
	surface_room_id=room_id
	surface_id=id
	surface_category=k
	switch_category(k)
	opened=true
	visible=true
	surface_label.text={"books":"Книжная полка","films":"Кинозона","tracks":"Аудиоаппаратура","artifacts":"Полка артефактов"}.get(k,"Место экспозиции")
	surface_label.visible=true
	surface_controls.visible=true
	place_button.visible=k=="artifacts"

func clear_surface_context()->void:
	surface_room_id=""
	surface_id=""
	surface_category=""
	if surface_controls!=null:surface_controls.visible=false
	if surface_label!=null:surface_label.visible=false

func _assign_selected_surface()->void:
	if surface_id=="" or category!=surface_category or list.get_selected_items().is_empty():
		return
	var index:int=list.get_selected_items()[0]
	if index>=0 and index<item_ids.size():
		surface_assignment_requested.emit(surface_room_id,surface_id,category,str(item_ids[index]))

func _place_selected_artifact()->void:
	if surface_category!="artifacts" or list.get_selected_items().is_empty():return
	var index:int=list.get_selected_items()[0]
	if index>=0 and index<item_ids.size():
		artifact_placement_requested.emit(surface_room_id,surface_id,str(item_ids[index]))
