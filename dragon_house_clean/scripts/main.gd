extends Node3D
## Fresh Godot 4.7.2 cutaway world. Geometry and presentation only;
## room truth + autonomous life are independent of the camera.
const WorldScript = preload("res://scripts/world_model.gd")
const LifeScript = preload("res://scripts/life.gd")
const W := 4.8
const H := 4.6
var world = WorldScript.new()
var life = LifeScript.new()
var camera: Camera3D
var room_root: Node3D
var actor_root: Node3D
var actor_sprites: Dictionary = {}
var actor_labels: Dictionary = {}
var material_cache: Dictionary = {}
var desired_focus := Vector3.ZERO
var smooth_focus := Vector3.ZERO
var zoom := 49.0
var zoom_current := 49.0
var yaw := 0.0
var current_mode := "HOUSE"
var follow_id := ""
var selected_room := ""
var build_mode := false
var build_type := "corridor"
var build_marker: MeshInstance3D
var build_cell := Vector2i(99, 99)
var moving_view := false
var save_timer := 0.0
var hud_title: Label
var hud_status: Label
var hud_help: Label
var media_label: Label
var notice: Label
var menu: OptionButton
var catalog_picker: FileDialog
var palette := {
	"rock": Color("#302d32"), "border": Color("#48424a"),
	"rock_light": Color("#5b5050"), "wood": Color("#654538"),
	"bronze": Color("#90704d"), "copper": Color("#a76c48"),
	"couch": Color("#6e253a"), "rug": Color("#5c2d39"),
	"light": Color("#dca365"), "screen": Color("#1b2839"),
	"book": Color("#715d53"), "floor": Color("#5a4a47"),
	"black": Color("#171418")
}
var room_names := {
	"arrival": "Вход", "corridor": "Переход",
	"common": "Гостиная", "study": "Кабинет",
	"rest": "Комната отдыха", "library": "Библиотека",
	"cinema": "Фильмотека", "music": "Аудиотека",
	"workshop": "Мастерская", "private": "Личная дверь",
	"lift": "Подъёмник", "artifact": "Артефакты"
}

func _ready() -> void:
	world.load_or_seed()
	life.setup(world)
	camera = Camera3D.new()
	camera.name = "ShelterPerspectiveCamera"
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 35.0
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#111018")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#998779")
	env.ambient_light_energy = 0.62
	ambient.environment = env
	add_child(ambient)
	room_root = Node3D.new()
	room_root.name = "Rooms"
	add_child(room_root)
	actor_root = Node3D.new()
	actor_root.name = "Residents"
	add_child(actor_root)
	make_rooms()
	make_residents()
	build_interface()
	desired_focus = Vector3(-1.0, 0.0, 0.0)
	smooth_focus = desired_focus
	apply_camera(1.0)
	notice.text = "Независимый прототип: камера, постройка, автономная жизнь"

func mat(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key: String = str(color.to_html()) + ("_e" if emissive else "_n")
	if material_cache.has(key):
		return material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.65
	material_cache[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat(color, emissive)
	parent.add_child(node)
	return node

func label3(parent: Node3D, content: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = content
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.0037
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = color
	l.outline_size = 4
	l.fixed_size = false
	parent.add_child(l)
	return l

func add_shelf(parent: Node3D, at: Vector3, width: float = 1.6) -> void:
	box(parent, at + Vector3(0.0, 0.55, 0.0), Vector3(width, 0.10, 0.36), palette["wood"])
	box(parent, at + Vector3(0.0, 1.2, 0.0), Vector3(width, 0.10, 0.36), palette["wood"])
	box(parent, at + Vector3(-width * 0.48, 0.65, 0.0), Vector3(0.11, 1.4, 0.38), palette["wood"])
	box(parent, at + Vector3(width * 0.48, 0.65, 0.0), Vector3(0.11, 1.4, 0.38), palette["wood"])
	for i in range(8):
		var c: Color = [Color("#704b43"), Color("#92715a"), Color("#554454"), Color("#57645e")][i % 4]
		var px := -width * 0.39 + float(i) * width * 0.105
		box(parent, at + Vector3(px, 0.94, -0.025), Vector3(width * 0.07, 0.53, 0.26), c)

func add_sofa(parent: Node3D, at: Vector3, width: float = 2.5, color: Color = Color("#6e253a")) -> void:
	box(parent, at + Vector3(0, 0.47, 0), Vector3(width, 0.46, 0.9), color)
	box(parent, at + Vector3(0, 0.86, -0.34), Vector3(width, 0.67, 0.23), color.darkened(0.15))
	box(parent, at + Vector3(-width * 0.47, 0.65, 0.0), Vector3(0.2, 0.65, 0.87), color.darkened(0.10))
	box(parent, at + Vector3(width * 0.47, 0.65, 0.0), Vector3(0.2, 0.65, 0.87), color.darkened(0.10))

func add_tv(parent: Node3D, at: Vector3) -> void:
	box(parent, at + Vector3(0, 0.65, -0.04), Vector3(2.2, 1.25, 0.16), palette["black"])
	box(parent, at + Vector3(0, 0.65, 0.065), Vector3(1.98, 1.04, 0.035), palette["screen"], true)
	box(parent, at + Vector3(0, -0.12, 0), Vector3(1.15, 0.18, 0.46), palette["wood"])

func furnish(parent: Node3D, kind: String, x: int, level: int) -> void:
	var offset := int(abs(x) + abs(level)) % 2
	match kind:
		"common":
			box(parent, Vector3(0, 0.05, 0.45), Vector3(3.8, 0.04, 2.15), palette["rug"])
			if x == -2:
				box(parent, Vector3(-1.35, 1.38, -1.73), Vector3(1.25, 1.48, 0.25), palette["rock_light"])
				box(parent, Vector3(-1.35, 0.92, -1.45), Vector3(0.80, 0.58, 0.17), palette["black"])
				box(parent, Vector3(-1.32, 0.88, -1.30), Vector3(0.53, 0.45, 0.08), Color("#f4943c"), true)
			elif x == -1:
				add_sofa(parent, Vector3(0, 0, -1.06), 2.6)
				box(parent, Vector3(0, 0.44, 0.86), Vector3(1.4, 0.30, 0.7), palette["wood"])
			else:
				add_sofa(parent, Vector3(0.0, 0, -0.88), 2.35, Color("#76513e"))
				add_shelf(parent, Vector3(1.38, 0.25, -1.70), 1.25)
		"library":
			add_shelf(parent, Vector3(-1.24, 0.15, -1.64), 1.75)
			add_shelf(parent, Vector3(1.12, 0.15, -1.64), 1.55)
			box(parent, Vector3(0.0, 0.48, 0.82), Vector3(0.9, 0.35, 0.65), palette["wood"])
		"rest":
			add_sofa(parent, Vector3(-0.30, 0.0, -0.83), 2.4, Color("#766049"))
			add_shelf(parent, Vector3(1.42, 0.23, -1.58), 1.1)
			box(parent, Vector3(0.72, 0.30, 0.70), Vector3(0.80, 0.35, 0.62), palette["wood"])
		"study":
			box(parent, Vector3(0.0, 0.7, -1.05), Vector3(2.5, 0.18, 0.89), palette["wood"])
			box(parent, Vector3(-0.9, 0.38, -1.0), Vector3(0.15, 0.65, 0.50), palette["wood"])
			box(parent, Vector3(0.9, 0.38, -1.0), Vector3(0.15, 0.65, 0.50), palette["wood"])
			box(parent, Vector3(-0.1, 0.96, -1.0), Vector3(0.75, 0.52, 0.045), palette["screen"])
			add_shelf(parent, Vector3(1.50, 0.10, -1.7), 0.9)
		"music":
			box(parent, Vector3(-1.3, 0.7, -1.5), Vector3(1.2, 1.2, 0.58), palette["black"])
			box(parent, Vector3(1.3, 0.7, -1.5), Vector3(1.2, 1.2, 0.58), palette["black"])
			for side in [-1, 1]:
				box(parent, Vector3(side * 1.3, 0.89, -1.16), Vector3(0.7, 0.58, 0.10), palette["screen"])
			box(parent, Vector3(0, 0.68, -1.2), Vector3(1.25, 0.17, 0.75), palette["wood"])
		"cinema":
			add_tv(parent, Vector3(0.0, 0.70, -1.68))
			add_sofa(parent, Vector3(0, 0, 0.84), 2.9, Color("#71423b"))
		"arrival":
			# Coat rack and shoe storage; deliberately no bench.
			box(parent, Vector3(-1.30, 1.28, -1.65), Vector3(0.1, 2.4, 0.1), palette["bronze"])
			box(parent, Vector3(-1.30, 2.24, -1.65), Vector3(0.85, 0.11, 0.13), palette["bronze"])
			box(parent, Vector3(1.08, 0.25, -1.5), Vector3(1.70, 0.50, 0.40), palette["wood"])
		"workshop":
			box(parent, Vector3(0, 0.85, -1.30), Vector3(2.95, 0.20, 0.8), palette["wood"])
			add_shelf(parent, Vector3(1.2, 0.15, -1.72), 1.2)
		"artifact":
			add_shelf(parent, Vector3(0, 0.1, -1.62), 3.1)
			for side in [-1, 0, 1]:
				var cube := box(parent, Vector3(float(side) * 0.65, 1.0, -1.26), Vector3(0.36, 0.36, 0.36), Color("#7b8a83"))
				cube.transparency = 0.12
		"lift":
			box(parent, Vector3(-1.5, 1.0, -1.5), Vector3(0.14, 2.0, 0.30), palette["bronze"])
			box(parent, Vector3(1.5, 1.0, -1.5), Vector3(0.14, 2.0, 0.30), palette["bronze"])
			box(parent, Vector3(0, 0.04, 0.10), Vector3(3.3, 0.08, 3.4), palette["copper"])
		"corridor":
			if offset == 0:
				box(parent, Vector3(0, 0.5, -1.70), Vector3(1.0, 1.05, 0.16), palette["wood"])

func make_room(room: Dictionary) -> void:
	var n := Node3D.new()
	n.name = room["id"]
	n.position = world.world_pos(int(room["x"]), int(room["level"]))
	room_root.add_child(n)
	var t: String = room["type"]
	var side_left := world.get_room(int(room["x"]) - 1, int(room["level"]))
	var side_right := world.get_room(int(room["x"]) + 1, int(room["level"]))
	# Structural cutaway: open camera-side face, solid perspective floor and back.
	box(n, Vector3(0, -0.12, -0.07), Vector3(W * 1.01, 0.25, 4.05), palette["floor"])
	box(n, Vector3(0, 1.45, -2.04), Vector3(W * 1.01, 3.25, 0.35), palette["rock"])
	box(n, Vector3(0, 3.12, -0.35), Vector3(W * 1.01, 0.22, 3.55), palette["border"])
	box(n, Vector3(0, -0.20, 1.80), Vector3(W * 1.01, 0.22, 0.18), palette["border"])
	for side in [-1, 1]:
		var next_r: Dictionary = side_left if side == -1 else side_right
		if next_r.get("type", "") == t and t != "private":
			# Real visually merged shell, structural rib instead of full partition.
			box(n, Vector3(float(side) * W / 2, 2.67, -0.5),
				Vector3(0.13, 0.8, 3.6), palette["rock_light"])
		elif next_r.is_empty():
			box(n, Vector3(float(side) * (W / 2 - 0.1), 1.39, -0.22),
				Vector3(0.35, 2.90, 3.82), palette["rock_light"])
		else:
			# Arched threshold: open through middle with framing pillars.
			box(n, Vector3(float(side) * (W / 2 - 0.10), 2.67, -0.3),
				Vector3(0.26, 0.74, 3.18), palette["rock_light"])
			box(n, Vector3(float(side) * (W / 2 - 0.10), 0.56, -1.75),
				Vector3(0.26, 1.2, 0.28), palette["rock_light"])
	if t == "private":
		# No interior meshes, no character leakage behind private threshold.
		box(n, Vector3(0, 1.4, 1.05), Vector3(2.08, 2.8, 0.22), palette["wood"])
		box(n, Vector3(0.82, 1.33, 1.2), Vector3(0.12, 0.12, 0.07), palette["bronze"])
		label3(n, "ЛИЧНОЕ", Vector3(0, 2.80, 1.2), 31, Color("#d4bdb0"))
	else:
		furnish(n, t, int(room["x"]), int(room["level"]))
		label3(n, room_names.get(t, t), Vector3(0.0, 2.93, 0.55), 29, Color("#f4d9b9"))

func make_rooms() -> void:
	for child in room_root.get_children():
		child.queue_free()
	for room in world.rooms:
		make_room(room)

func make_sprite_texture(is_manka: bool) -> Texture2D:
	var img := Image.create(96, 144, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for py in range(144):
		for px in range(96):
			var xx := float(px - 48) / 48.0
			var yy := float(py)
			var inside := false
			if is_manka:
				inside = (pow(xx * 1.22, 2.0) + pow((yy - 82.0) / 39.0, 2.0) < 1.0)
				inside = inside or (pow((px - 44.0) / 23.0, 2.0) + pow((yy - 48.0) / 22.0, 2.0) < 1.0)
			else:
				inside = (pow(xx * 1.03, 2.0) + pow((yy - 95.0) / 46.0, 2.0) < 1.0)
				inside = inside or (pow((px - 48.0) / 20.0, 2.0) + pow((yy - 39.0) / 23.0, 2.0) < 1.0)
			if inside:
				var color := Color("#151318") if is_manka else Color("#e6dad3")
				if is_manka and yy < 58 and abs(xx) < 0.40:
					color = Color("#241b27")
				if is_manka and yy > 44 and yy < 49 and abs(xx) > 0.16 and abs(xx) < 0.43:
					color = Color("#9b121e")
				if not is_manka and yy > 58:
					color = Color("#713a4e")
				img.set_pixel(px, py, color)
	return ImageTexture.create_from_image(img)

func make_residents() -> void:
	var resident_tex := make_sprite_texture(false)
	var manka_tex := make_sprite_texture(true)
	for child in actor_root.get_children():
		child.queue_free()
	actor_sprites.clear()
	actor_labels.clear()
	var n := 0
	for id in world.residents:
		var actor: Dictionary = world.residents[id]
		if not actor.get("active", false) or actor.get("name", "") == "":
			continue
		var anchor := Node3D.new()
		anchor.name = id
		actor_root.add_child(anchor)
		var sprite := Sprite3D.new()
		sprite.name = "Body"
		sprite.texture = manka_tex if id == "MANJKA" else resident_tex
		sprite.pixel_size = 0.009 if id == "MANJKA" else 0.012
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.position = Vector3(0, 0.83 if id == "MANJKA" else 1.05, 0)
		if id != "MANJKA":
			var colors = [Color("#bfa4c1"), Color("#dca39e"), Color("#a3aeb3"), Color("#d4b78a"),
				Color("#c6c0c4"), Color("#9b9fbf"), Color("#bc9e97"), Color("#9ab4a9")]
			sprite.modulate = colors[n % colors.size()]
		anchor.add_child(sprite)
		actor_sprites[id] = anchor
		var lbl := label3(anchor, actor["name"], Vector3(0, 2.0, 0.2), 27, Color("#f1ddd0"))
		actor_labels[id] = lbl
		n += 1
	update_residents()

func update_residents() -> void:
	for id in actor_sprites:
		var actor: Dictionary = world.residents[id]
		var y: float = float(actor.get("visual_y", float(actor.get("level", 0)) * H))
		actor_sprites[id].position = Vector3(float(actor.get("x", 0.0)), y, float(actor.get("z", 0.3)))
		actor_labels[id].visible = zoom_current < 27 or id == follow_id
		if id == follow_id:
			actor_labels[id].text = actor["name"] + " • " + str(actor.get("intent", ""))

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var top := PanelContainer.new()
	top.position = Vector2(12, 12)
	top.custom_minimum_size = Vector2(292, 0)
	root.add_child(top)
	var col := VBoxContainer.new()
	top.add_child(col)
	hud_title = Label.new()
	hud_title.text = "ДОМ ДРАКОНА  /  2.5D"
	col.add_child(hud_title)
	hud_status = Label.new()
	col.add_child(hud_status)
	media_label = Label.new()
	col.add_child(media_label)
	var controls := HBoxContainer.new()
	col.add_child(controls)
	for item in ["Дом", "Комната", "Манька", "Строить"]:
		var button := Button.new()
		button.text = item
		controls.add_child(button)
		match item:
			"Дом": button.pressed.connect(func(): set_mode("HOUSE"))
			"Комната": button.pressed.connect(func(): set_mode("ROOM"))
			"Манька": button.pressed.connect(func(): follow_actor("MANJKA"))
			"Строить": button.pressed.connect(toggle_build)
	menu = OptionButton.new()
	for t in WorldScript.ROOM_TYPES:
		menu.add_item(room_names.get(t, t))
		menu.set_item_metadata(menu.item_count - 1, t)
	menu.select(1)
	menu.item_selected.connect(func(i): build_type = str(menu.get_item_metadata(i)))
	col.add_child(menu)
	var import_button := Button.new()
	import_button.text = "Импорт книг / фильмов / музыки (JSON)"
	import_button.pressed.connect(func(): catalog_picker.popup_centered_ratio(0.65))
	col.add_child(import_button)
	hud_help = Label.new()
	hud_help.text = "Колесо: масштаб | ПКМ: перемещение\nЛКМ: выбрать | Q/E: поворот\nF: следить | B: строить | Esc: весь дом"
	col.add_child(hud_help)
	notice = Label.new()
	notice.position = Vector2(18, 690)
	notice.add_theme_color_override("font_color", Color("#eac59d"))
	root.add_child(notice)
	catalog_picker = FileDialog.new()
	catalog_picker.access = FileDialog.ACCESS_FILESYSTEM
	catalog_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	catalog_picker.add_filter("*.json", "Media catalog JSON")
	catalog_picker.file_selected.connect(_import_media)
	root.add_child(catalog_picker)
	update_hud()

func _import_media(path: String) -> void:
	if world.import_catalog(path):
		notice.text = "Медиатека импортирована: " + path.get_file()
	else:
		notice.text = "Ошибка каталога: нужен JSON с books/films/tracks (id, title)"
	update_hud()

func set_mode(mode: String) -> void:
	build_mode = false
	if build_marker:
		build_marker.visible = false
	current_mode = mode
	match mode:
		"HOUSE":
			zoom = 54.0
			desired_focus = Vector3(-0.6, 0, 0)
			follow_id = ""
		"ROOM":
			zoom = 14.0
			follow_id = ""
			if selected_room != "":
				var r: Dictionary = world.room_by_id(selected_room)
				if not r.is_empty():
					desired_focus = world.world_pos(r["x"], r["level"]) + Vector3(0, 1.1, 0)
		"FOLLOW":
			zoom = 16.0
	update_hud()

func follow_actor(id: String) -> void:
	if not actor_sprites.has(id):
		return
	follow_id = id
	current_mode = "FOLLOW"
	build_mode = false
	zoom = minf(zoom, 20.0)
	update_hud()

func toggle_build() -> void:
	build_mode = not build_mode
	if build_mode:
		follow_id = ""
		current_mode = "BUILD"
		if build_marker == null:
			build_marker = MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(W * 0.9, 2.9, 3.9)
			build_marker.mesh = cube
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.22, 0.9, 0.55, 0.27)
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			build_marker.material_override = material
			add_child(build_marker)
		build_marker.visible = true
	elif build_marker:
		build_marker.visible = false
	update_hud()

func update_hud() -> void:
	if hud_status == null:
		return
	var tracked: Dictionary = world.residents.get(follow_id, {})
	hud_status.text = "Режим: %s | комнат: %d | жителей: %d" % [
		current_mode, world.rooms.size(), actor_sprites.size()]
	if not tracked.is_empty():
		hud_status.text += "\nСлежение: %s — %s" % [tracked.get("name", "?"), tracked.get("intent", "")]
	media_label.text = "Книги: %d  •  Фильмы: %d  •  Музыка: %d" % [
		world.media.get("books", []).size(), world.media.get("films", []).size(),
		world.media.get("tracks", []).size()]

func ray_to_front_plane(mouse: Vector2) -> Variant:
	var start: Vector3 = camera.project_ray_origin(mouse)
	var direction: Vector3 = camera.project_ray_normal(mouse)
	if absf(direction.z) < 0.0001:
		return null
	var distance: float = (0.25 - start.z) / direction.z
	if distance < 0:
		return null
	return start + direction * distance

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom = maxf(9.0, zoom * 0.87)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom = minf(89.0, zoom * 1.15)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			moving_view = e.pressed
	if event is InputEventMouseMotion:
		var e: InputEventMouseMotion = event
		if moving_view and not build_mode:
			var scale: float = zoom_current * 0.0019
			desired_focus.x -= e.relative.x * scale
			desired_focus.y += e.relative.y * scale
		elif build_mode:
			var hit = ray_to_front_plane(e.position)
			if hit != null:
				build_cell = Vector2i(roundi(hit.x / W), roundi(hit.y / H))
				build_marker.position = world.world_pos(build_cell.x, build_cell.y) + Vector3(0, 1.4, 0)
				var permitted := world.can_build(build_cell.x, build_cell.y, build_type)
				build_marker.modulate = Color("#6fd89e") if permitted else Color("#c35c61")
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: set_mode("HOUSE")
			KEY_F: follow_actor("MANJKA")
			KEY_B: toggle_build()
			KEY_Q: yaw -= 0.16
			KEY_E: yaw += 0.16
			KEY_1: set_mode("HOUSE")
			KEY_2: set_mode("ROOM")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index != MOUSE_BUTTON_LEFT or not e.pressed:
			return
		if build_mode:
			if world.build(build_cell.x, build_cell.y, build_type):
				make_rooms()
				notice.text = "Построено: %s (%d, %d)" % [
					room_names.get(build_type, build_type), build_cell.x, build_cell.y]
			else:
				notice.text = "Нет связного свободного участка"
			update_hud()
			return
		# Selection is by projected actor positions, independent of camera tracking.
		var nearest := ""
		var best := 39.0
		for id in actor_sprites:
			var anchor: Node3D = actor_sprites[id]
			if camera.is_position_behind(anchor.global_position + Vector3.UP):
				continue
			var screen: Vector2 = camera.unproject_position(anchor.global_position + Vector3.UP)
			var d: float = screen.distance_to(e.position)
			if d < best:
				best = d
				nearest = id
		if nearest != "":
			follow_actor(nearest)
			return
		var hit = ray_to_front_plane(e.position)
		if hit != null:
			var room: Dictionary = world.get_room(roundi(hit.x / W), roundi(hit.y / H))
			if not room.is_empty():
				selected_room = room["id"]
				if room["privacy"] == "door_only":
					notice.text = "Личная территория: камера остаётся у двери"
				else:
					notice.text = room_names.get(room["type"], room["type"])
				set_mode("ROOM")

func apply_camera(delta: float) -> void:
	if follow_id != "" and world.residents.has(follow_id):
		var actor: Dictionary = world.residents[follow_id]
		var target_room: Dictionary = world.room_by_id(actor.get("room_id", ""))
		if not target_room.is_empty() and target_room.get("privacy", "public") == "public":
			desired_focus = Vector3(float(actor.get("x", 0)), float(actor.get("visual_y",
				float(actor.get("level", 0)) * H)) + 0.95, float(actor.get("z", 0)))
		# Follow does not pass a private threshold.
	var k: float = 1.0 - exp(-4.0 * delta)
	smooth_focus = smooth_focus.lerp(desired_focus, k)
	zoom_current = lerpf(zoom_current, zoom, 1.0 - exp(-4.6 * delta))
	var x_shift := sin(yaw) * zoom_current
	var z_shift := cos(yaw) * zoom_current
	camera.global_position = smooth_focus + Vector3(x_shift, zoom_current * 0.22, z_shift)
	camera.look_at(smooth_focus, Vector3.UP)

func _process(delta: float) -> void:
	# The camera never chooses activities. Life is a separate simulation clock.
	life.tick(delta)
	update_residents()
	apply_camera(delta)
	save_timer += delta
	if save_timer > 20.0:
		world.save_world()
		save_timer = 0.0
	if Engine.get_process_frames() % 40 == 0:
		update_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		world.save_world()
		get_tree().quit()

