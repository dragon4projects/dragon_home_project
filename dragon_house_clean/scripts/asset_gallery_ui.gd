extends PanelContainer
## Read-only November sprite bank gallery, including residents not activated in the world.
## "PASS" is a decoder/frame test, NOT a human artistic-approval decision.
var resolver
var profile_rows: Array = []
var selected_id := ""
var active_wardrobe := ""
var active_state := ""
var display_frame := 0
var elapsed := 0.0
var roster_list: ItemList
var wardrobe_menu: OptionButton
var state_menu: OptionButton
var picture: TextureRect
var details: Label
var status: Label

func _ready() -> void:
	name = "NovemberBankGallery"
	position = Vector2(670,20)
	custom_minimum_size = Vector2(570,640)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var label := Label.new()
	label.text = "БАНКИ КАДРОВ — ТЕХНИЧЕСКИЙ ПРОСМОТР"
	header.add_child(label)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(func(): visible=false)
	header.add_child(close)
	var note := Label.new()
	note.text = "PASS ≠ утверждённая внешность. Ни одна жительница не активируется."
	box.add_child(note)
	var controls := HBoxContainer.new()
	box.add_child(controls)
	roster_list = ItemList.new()
	roster_list.custom_minimum_size = Vector2(205,440)
	roster_list.item_selected.connect(_on_resident)
	controls.add_child(roster_list)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(335,0)
	controls.add_child(right)
	status = Label.new()
	status.text = "Ожидаются изображения..."
	right.add_child(status)
	wardrobe_menu = OptionButton.new()
	wardrobe_menu.item_selected.connect(_on_wardrobe)
	right.add_child(wardrobe_menu)
	state_menu = OptionButton.new()
	state_menu.item_selected.connect(_on_state)
	right.add_child(state_menu)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(300,320)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(picture)
	details = Label.new()
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(details)

func bind(asset_resolver, profiles: Array) -> void:
	resolver = asset_resolver
	profile_rows = profiles.duplicate(true)
	refresh()

func refresh() -> void:
	if roster_list == null:
		return
	roster_list.clear()
	var real_ready := 0
	var candidates := 0
	for profile in profile_rows:
		var id := str(profile.get("id",""))
		var app := str(profile.get("appearance_profile",""))
		var choice: String = resolver.preferred_wardrobe(id,app,true) if resolver else ""
		var approved: String = resolver.preferred_wardrobe(id,app,false) if resolver else ""
		if choice != "":
			candidates += 1
		if approved != "":
			real_ready += 1
		var marker := "◌" if choice == "" else "✓" if approved != "" else "?"
		roster_list.add_item("%s  %s" % [marker,str(profile.get("display_name",id))])
	status.text = "Технически: %d / 24; утверждено: %d / 24" % [candidates,real_ready]
	if profile_rows.size() > 0:
		roster_list.select(0)
		_on_resident(0)

func _on_resident(index: int) -> void:
	if index<0 or index>=profile_rows.size() or resolver==null:
		return
	var profile: Dictionary = profile_rows[index]
	selected_id = str(profile["id"])
	active_wardrobe = ""
	wardrobe_menu.clear()
	for name in resolver.wardrobe_options(selected_id):
		var actor: Dictionary = resolver.manifest.get("residents",{}).get(selected_id,{})
		var app: String = str(actor.get("appearance_profile",""))
		if resolver.candidate_bank(selected_id,app,name):
			wardrobe_menu.add_item(name)
	if wardrobe_menu.item_count > 0:
		wardrobe_menu.select(0)
		_on_wardrobe(0)
	else:
		state_menu.clear()
		picture.texture = null
		details.text = str(profile["display_name"])+" — подтверждённого банка нет."

func _on_wardrobe(index: int) -> void:
	if index<0 or index>=wardrobe_menu.item_count:
		return
	active_wardrobe = wardrobe_menu.get_item_text(index)
	state_menu.clear()
	for state in resolver.technical_states(selected_id,active_wardrobe):
		state_menu.add_item(state)
	if state_menu.item_count > 0:
		state_menu.select(0)
		_on_state(0)

func _on_state(index: int) -> void:
	if index<0 or index>=state_menu.item_count:
		return
	active_state = state_menu.get_item_text(index)
	display_frame = 0
	elapsed = 0.0
	paint()

func paint() -> void:
	if resolver==null or selected_id=="" or active_state=="":
		return
	var tex: Texture2D = resolver.texture_for(selected_id,active_wardrobe,active_state,display_frame)
	picture.texture=tex
	var num: int = resolver.frame_count(selected_id,active_wardrobe,active_state)
	details.text = "ID: %s | %s | %s\nКадры: %d; FPS: %d\nИспользуется только для проверки" % [
		selected_id,active_wardrobe,active_state,num,
		resolver.fps(selected_id,active_wardrobe,active_state)
	]

func _process(delta: float) -> void:
	if not visible or resolver == null or active_state=="":
		return
	var count: int = resolver.frame_count(selected_id,active_wardrobe,active_state)
	if count <= 1:
		return
	elapsed += minf(delta,0.1)
	var period := 1.0/float(resolver.fps(selected_id,active_wardrobe,active_state))
	if elapsed >= period:
		display_frame=(display_frame+int(elapsed/period))%count
		elapsed=fmod(elapsed,period)
		paint()

