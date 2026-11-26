extends Node3D
## Fresh Godot 4.7.2 cutaway world. Geometry and presentation only;
## room truth + autonomous life are independent of the camera.
const WorldScript = preload("res://scripts/world_model.gd")
const LifeScript = preload("res://scripts/life.gd")
const MediaPanelScript = preload("res://scripts/media_station_ui.gd")
const ContentViewerScript = preload("res://scripts/content_viewer.gd")
const ObjectImportScript = preload("res://scripts/runtime_object_import.gd")
const WallPlacementScript = preload("res://scripts/wall_display_placement.gd")
const AssetBankResolverScript = preload("res://scripts/asset_bank_resolver.gd")
const InteriorSkinScript = preload("res://scripts/interior_skin.gd")
const RoomVisualLayoutScript = preload("res://scripts/room_visual_layout_v2.gd")
const OwnerDecorBankScript = preload("res://scripts/owner_decor_bank.gd")
const TEEA008ReviewScript = preload("res://scripts/teea008_review_bank.gd")
const StaticOverviewBatch=preload("res://scripts/static_overview_batch.gd")
const TEEA008NavigationScript = preload("res://scripts/teea008_navigation.gd")
const TEEA008MediaBindingsScript = preload("res://scripts/teea008_media_bindings.gd")
const BankGalleryScript = preload("res://scripts/asset_gallery_ui.gd")
const PrivateDoorRegistryScript = preload("res://scripts/private_door_registry.gd")
const SemanticViewScript = preload("res://scripts/semantic_view_v019.gd")
const CandidateContentRuntimeScript = preload("res://scripts/candidate_content_runtime.gd")
const ITER1_REVIEW_MARKER := "res://data/integration_candidates/ITER1_OWNER_REVIEW.enabled"
const ARTIFACT_CUBE_SIDE:float=0.18
const CanonicalArtifactCubes=preload("res://scripts/canonical_artifact_cubes.gd")
var artifact_cubes=CanonicalArtifactCubes.new()
const ARTIFACT_CUBE_MODEL:="res://assets/decor_bank/artifact_glass_cube_s/model.gltf"
const W := 4.8
const H := 4.6
const BASE_FOV := 35.0
const CLOSE_FOV := 50.0
const CLOSE_FOV_NEAR_ZOOM := 12.0
const CLOSE_FOV_FAR_ZOOM := 48.0
var world = WorldScript.new()
var life = LifeScript.new()
var asset_banks = AssetBankResolverScript.new()
var interior_skin = InteriorSkinScript.new()
var room_visual_layout = RoomVisualLayoutScript.new()
var owner_decor_bank = OwnerDecorBankScript.new()
var teea008_review = TEEA008ReviewScript.new()
var teea008_live:=false
var teea008_media_bindings=TEEA008MediaBindingsScript.new()
var door_registry = PrivateDoorRegistryScript.new()
var semantic_view = SemanticViewScript.new()
var candidate_content = CandidateContentRuntimeScript.new()
var iter1_owner_review := false
const ARCHITECTURE_MARKER := "res://data/integration_candidates/CANONICAL_HOUSE_ARCHITECTURE.enabled"
var architecture_review := false
var art_layer_count := 0
var detailed_room_groups: Dictionary = {}
var art_loaded_groups: Dictionary = {}
var visual_room_groups: Dictionary = {}
var canonical_guest_nodes:Dictionary={}
var detail_materialization_count := 0
var detail_eviction_count := 0
var validated_visual_banks := 0
var qa_visual_preview := false
var preview_visual_banks := 0
var actor_animations: Dictionary = {}
var camera: Camera3D
var room_root: Node3D
var actor_root: Node3D
var creature_root: Node3D
var creature_nodes: Dictionary = {}
var creature_labels: Dictionary = {}
var creature_animations: Dictionary = {}
var creature_hover_clock:float=0.0
var object_root: Node3D
var book_root:Node3D
var book_nodes:Dictionary={}
var object_nodes: Dictionary = {}
var actor_sprites: Dictionary = {}
var actor_labels: Dictionary = {}
var door_note_anchors: Dictionary = {}
var material_cache: Dictionary = {}
var mesh_cache: Dictionary = {}
var desired_focus := Vector3.ZERO
var smooth_focus := Vector3.ZERO
var zoom := 47.0
var zoom_current := 47.0
var yaw := 0.0
var current_mode := "HOUSE"
var follow_id := ""
var selected_room := ""
var selected_outline: Node3D
var journal_panel: PanelContainer
var journal_text: Label
var journal_open := false
var public_journal=preload("res://scripts/public_house_journal.gd").new()
var journal_actor_filter:OptionButton
var journal_room_filter:OptionButton
var journal_category_filter:OptionButton
var follow_deadzone_ratio := 0.12
var build_mode := false
var build_type := "corridor"
var build_size := 1
var build_marker: MeshInstance3D
var build_cell := Vector2i(99, 99)
var moving_view := false
var hud_title: Label
var hud_status: Label
var hud_help: Label
var hud_main_body: VBoxContainer
var hud_toggle_button: Button
var hud_brief: Label
var hud_expanded := false
var shutdown_requested:=false
var recovery_screen_visible:=false
var media_label: Label
var notice: Label
var menu: OptionButton
var catalog_picker: FileDialog
var media_panel: PanelContainer
var content_viewer: PanelContainer
var content_hover_label: Label
var content_hotspots: Array = []
var object_home_drag_id := ""
var object_home_drag_room_id := ""
var object_home_drag_anchor := Vector2.ZERO
var object_home_drag_world_x := 0.0
var object_home_drag_wall_y := -1.0
var bank_gallery: PanelContainer
var door_note_panel: PanelContainer
var door_note_title: Label
var door_note_text: RichTextLabel
var catalog_metadata_added := 0
var palette := {
	"rock": Color("#453b3a"), "border": Color("#4b3b35"),
	"rock_light": Color("#6b574d"), "wood": Color("#805a3c"),
	"bronze": Color("#a87645"), "copper": Color("#ad6f45"),
	"couch": Color("#5a2431"), "rug": Color("#4b2530"),
	"light": Color("#e8a45f"), "screen": Color("#263d54"),
	"book": Color("#795643"), "floor": Color("#403632"),
	"black": Color("#120f12")
}
var room_names := {
	"arrival": "Вход", "corridor": "Переход",
	"common": "Гостиная", "study": "Кабинет",
	"rest": "Комната отдыха", "library": "Библиотека",
	"cinema": "Фильмотека", "music": "Аудиотека",
	"workshop": "Мастерская", "private": "Личная дверь", "guest": "Гостевая",
	"lift": "Подъёмник", "artifact": "Артефакты", "kitchen": "Кухня / бар"
}

func _artifact_room() -> Dictionary:
	for room in world.rooms:
		if str(room.get("type",""))=="artifact" and str(room.get("privacy","public"))=="public":
			return room
	return {}

func _ensure_canonical_wall_displays() -> int:
	if asset_banks.manifest.is_empty():
		return 0
	var room:Dictionary=_artifact_room()
	if room.is_empty():
		return 0
	var specs:Array=[
		{"id":"POSTER_SHURSHUN","anchor":[-0.55,1.45,-1.52],
			"station":"WALL_GALLERY_LEFT","point":[-0.55,-1.22]},
		{"id":"PHOTO_MOON","anchor":[0.55,1.45,-1.52],
			"station":"WALL_GALLERY_RIGHT","point":[0.85,-1.22]},
		{"id":"PORTRAIT_SHURS","anchor":[1.65,1.45,-1.52],
			"station":"WALL_GALLERY_RIGHT","point":[0.85,-1.22]}
	]
	if teea008_review.enabled:
		# Default candidate gallery above the actual shelving, not in front
		# of its contents. Existing owner-assigned records are not rewritten.
		for spec in specs:
			spec["anchor"][1]=2.23
	var added:=0
	for spec in specs:
		var object_id:String=str(spec["id"])
		if not world.physical_object(object_id).is_empty():
			continue
		var record:Dictionary=asset_banks.prop_display_record(object_id)
		var master:String=asset_banks.prop_master_path(object_id)
		if record.is_empty() or master=="":
			continue
		var display_name:String=str(record.get("display_name",
			record.get("title",object_id)))
		var metadata:Dictionary={
			"description":str(record.get("description","")),
			"preview_path":"res://"+master,
			"asset_id":object_id,
			"viewer_category":"artifacts",
			"display_mode":"wall",
			"home_anchor":spec["anchor"],
			"interaction_station_id":str(spec["station"]),
			"interaction_point":spec["point"],
			"interaction_approach_z":0.95,
			"display_world_height":0.68 if teea008_review.enabled else 1.18
		}
		if world.register_physical_object(
				object_id,display_name,"",str(room["id"]),
				false,false,false,false,true,metadata):
			added+=1
	if added>0:
		world.save_world()
	return added

func _ensure_canonical_artifact_cube()->bool:
	# Restore only the identified existing master; no automatic import of
	# unverified candidates, no duplicate object, no fabricated owner event.
	if not architecture_review or life.candidate_navigation==null:return false
	const OBJECT_ID:="CUBE_LETTERS"
	if not world.physical_object(OBJECT_ID).is_empty():return false
	var record:Dictionary=asset_banks.prop_display_record(OBJECT_ID)
	var master:String=asset_banks.prop_master_path(OBJECT_ID)
	if record.is_empty() or master=="":return false
	var room:Dictionary=_artifact_room()
	if room.is_empty():return false
	var rid:String=str(room["id"])
	var slots:Array=life.candidate_navigation.artifact_slots(room).duplicate()
	# Prefer the second marked display opening. Other existing homes are
	# respected; this default is a system registration, not Dragon authorship.
	var preferred:Dictionary=life.candidate_navigation.artifact_support(room,"artifact_r3_shelf_c.shelf_4_1")
	if not preferred.is_empty():
		slots.erase(preferred)
		slots.push_front(preferred)
	for slot in slots:
		var p:Array=slot["xyz"]
		var dims:Array=slot["dimensions"]
		if float(p[1])<0.35 or float(p[1])>1.70:continue
		if float(dims[0])<ARTIFACT_CUBE_SIDE or float(dims[1])<ARTIFACT_CUBE_SIDE or float(dims[2])<ARTIFACT_CUBE_SIDE:continue
		var occupied:=false
		for obj in world.objects.values():
			if str(obj.get("home_room_id",""))==rid and str(obj.get("home_support_id",""))==str(slot["id"]):
				occupied=true
				break
			if str(obj.get("current_room_id",""))==rid and str(obj.get("current_support_id",""))==str(slot["id"]):
				occupied=true
				break
		if occupied:continue
		var metadata:Dictionary={"description":str(record.get("description","")),"preview_path":"res://"+master,"asset_id":OBJECT_ID,"viewer_category":"artifacts","home_anchor":[p[0],p[2]],"home_support_id":str(slot["id"]),"display_world_height":ARTIFACT_CUBE_SIDE}
		var title:String=str(record.get("display_name",record.get("title","Письма перед сном")))
		if world.register_physical_object(OBJECT_ID,title,"",rid,true,true,false,false,true,metadata):
			world.save_world()
			return true
	return false

func _restore_zna_artifact_sources()->int:
	if not architecture_review or life.candidate_navigation==null:return 0
	var file:=FileAccess.open("res://assets/manifests/artifact_master_sources_zna004.json",FileAccess.READ)
	if file==null:return 0
	var manifest=JSON.parse_string(file.get_as_text())
	if typeof(manifest)!=TYPE_DICTIONARY:return 0
	var room:Dictionary=_artifact_room()
	if room.is_empty():return 0
	var rid:String=str(room["id"])
	var slots:Array=life.candidate_navigation.artifact_slots(room)
	var added:=0
	for entry in manifest.get("entries",[]):
		var id:String=str(entry.get("normalized_id",""))
		var title:String=str(entry.get("title",""))
		if not id.begins_with("ARTEFACT_") or not id.contains("_CUBE_") or title=="":continue
		var aliases:Array=[id,str(entry.get("current_media_content_id",""))]
		if id=="ARTEFACT_006_CUBE_LETTERS_BEFORE_SLEEP":aliases.append("CUBE_LETTERS")
		var exists:=false
		for object in world.objects.values():
			if str(object.get("id","")) in aliases or str(object.get("display_name",""))==title:
				exists=true
				break
		if exists:continue
		var source:String=str(entry.get("repo_source_target",""))
		var preview:String=str(entry.get("preview_target",""))
		if not source.begins_with("assets/props/artifacts/cubes/sources/library_confirmed/") or not preview.begins_with("assets/media/previews/artifacts/") or source.contains("..") or preview.contains(".."):continue
		source="res://"+source
		preview="res://"+preview
		# Real imported textures are required; do not mount an LFS pointer
		# or empty proxy if the binary assets were not hydrated.
		if not ResourceLoader.exists(source,"Texture2D") or not ResourceLoader.exists(preview,"Texture2D"):continue
		for slot in slots:
			var sid:String=str(slot["id"])
			var p:Array=slot["xyz"]
			var dims:Array=slot["dimensions"]
			# Keep central review/test opening available for owner-added art.
			if sid=="artifact_r3_shelf_c.shelf_3_1":continue
			if float(p[1])<0.35 or float(p[1])>1.70:continue
			if float(dims[0])<ARTIFACT_CUBE_SIDE or float(dims[1])<ARTIFACT_CUBE_SIDE or float(dims[2])<ARTIFACT_CUBE_SIDE:continue
			var occupied:=false
			for object in world.objects.values():
				if (str(object.get("home_room_id",""))==rid and str(object.get("home_support_id",""))==sid) or (str(object.get("current_room_id",""))==rid and str(object.get("current_support_id",""))==sid):
					occupied=true
					break
			if occupied:continue
			var metadata:Dictionary={"viewer_category":"artifacts","preview_path":preview,"full_image_path":source,"artifact_source_status":str(entry.get("migration_status","MIGRATION_REQUIRED")),"description":"Восстановленный исходник; художественная миграция ещё не утверждена.","home_anchor":[p[0],p[2]],"home_support_id":sid,"display_world_height":ARTIFACT_CUBE_SIDE}
			if world.register_physical_object(id,title,"",rid,true,true,false,false,true,metadata):
				added+=1
				break
	if added>0:world.save_world()
	return added

func _ready() -> void:
	# Closing must pass through the checkpoint handler, including on failure.
	get_tree().auto_accept_quit=false
	Engine.max_fps = 30 # Low-end hardware baseline; detail modes can unlock 60.
	architecture_review = FileAccess.file_exists(ARCHITECTURE_MARKER) or OS.get_environment("DRAGON_HOUSE_ARCHITECTURE")=="1"
	iter1_owner_review = architecture_review or FileAccess.file_exists(ITER1_REVIEW_MARKER)
	world.canonical_house_seed=architecture_review
	# Owner-review is explicitly allowed to show delivered candidate resident
	# banks without changing their approval state. Production stays strict.
	qa_visual_preview = iter1_owner_review
	if iter1_owner_review:
		world.save_path = "user://dragon_house_iter1_owner_review.json"
		if architecture_review or OS.get_environment("DRAGON_TEEA008_REVIEW")=="1" or FileAccess.file_exists(teea008_review.LIVE_EXPORT_MARKER):
			if teea008_review.initialize(architecture_review):
				if architecture_review:
					teea008_review.apply_architecture_layouts()
				world.save_path="user://dragon_house_teea008_review.json"
				teea008_live=architecture_review or OS.get_environment("DRAGON_TEEA008_LIVE")=="1" or FileAccess.file_exists(teea008_review.LIVE_EXPORT_MARKER)
				if teea008_live:
					world.save_path="user://dragon_house_teea008_live_review.json"
			else:
				push_warning("TEEA008 review unavailable: "+teea008_review.error)
	if architecture_review:
		# Do not reinterpret or overwrite the legacy world or its event stores.
		world.save_path="user://dragon_house_canonical_architecture_20261125.json"
	if not world.load_or_seed():
		_show_recovery_blocked()
		return
	if iter1_owner_review:
		if candidate_content.initialize():
			var guest_review_result: Dictionary = candidate_content.apply_guest_candidate(world)
			if not bool(guest_review_result.get("ok",false)):
				push_warning("Iteration-1 guest candidate activation failed: "+str(guest_review_result))
		else:
			push_warning("Iteration-1 candidate contract could not be initialized: "+candidate_content.last_error)
	semantic_view.install(world,"HOUSE")
	semantic_view.all_levels_visible=architecture_review
	asset_banks.initialize()
	asset_banks.begin_validation_pass()
	world.merge_zna_media_previews()
	world.load_private_cinema_catalog()
	_ensure_canonical_wall_displays()
	if iter1_owner_review:
		_register_iter1_review_creatures()
	# Metadata is not a physical book or a movie/audio file.
	if not asset_banks.manifest.is_empty():
		catalog_metadata_added = world.merge_reference_book_metadata(
			asset_banks.manifest.get("media_previews",{}).get("books",[]))
	if teea008_review.enabled:
		teea008_media_bindings.setup(world,teea008_review,life.media_runtime)
		life.candidate_media_bindings=teea008_media_bindings
	if teea008_live:
		print("TEEA008_LIVE_START navigation")
		life.candidate_navigation=TEEA008NavigationScript.new()
		life.candidate_navigation.configure(teea008_review.layouts)
		_ensure_canonical_artifact_cube()
		_restore_zna_artifact_sources()
		if architecture_review:
			artifact_cubes.provisional_size_m=ARTIFACT_CUBE_SIDE
			artifact_cubes.setup(world,life.candidate_navigation)
		teea008_review.live_physical_objects=true
		life.candidate_cups.setup(world,life.candidate_navigation)
		life.candidate_cups.register_review_mugs()
		life.candidate_navigation.prepare_rooms(world.rooms)
		print("TEEA008_LIVE_START roster")
		_activate_teea008_roster()
		for actor in world.residents.values():
			if str(actor.get("entity_type",""))=="guest":
				actor["autonomy_enabled"]=true
			actor["teea008_pose_wardrobe"]=asset_banks.preferred_wardrobe(str(actor["id"]),str(actor.get("appearance_profile","")),true)
	if teea008_live:
		asset_banks.cache_capacity=96
		print("TEEA008_LIVE_START life")
	life.setup(world)
	if architecture_review and teea008_live:
		var books_installed:Dictionary=life.media_runtime.install_canonical_book_catalog()
		if int(books_installed.get("catalog",0))+int(books_installed.get("physical",0))>0:
			world.save_world()
	interior_skin.initialize()
	if not room_visual_layout.initialize():
		push_warning("Physical room visual layout unavailable: "+room_visual_layout.error)
	door_registry.initialize()
	validated_visual_banks = asset_banks.accepted_count(world.read_resident_profiles())
	preview_visual_banks = asset_banks.preview_count(world.read_resident_profiles())
	camera = Camera3D.new()
	camera.name = "ShelterPerspectiveCamera"
	camera.current = true
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = BASE_FOV
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#111018")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#d2c6b8")
	env.ambient_light_energy = 1.02
	ambient.environment = env
	add_child(ambient)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -23, 0)
	sun.light_color = Color("#ecd7bc")
	sun.light_energy = 0.74
	sun.shadow_enabled = false
	add_child(sun)
	make_mountain()
	room_root = Node3D.new()
	room_root.name = "Rooms"
	add_child(room_root)
	selected_outline = Node3D.new()
	selected_outline.name = "RoomSelectionOutline"
	selected_outline.visible = false
	add_child(selected_outline)
	actor_root = Node3D.new()
	actor_root.name = "Residents"
	add_child(actor_root)
	creature_root = Node3D.new()
	creature_root.name = "AmbientCreatures"
	add_child(creature_root)
	object_root = Node3D.new()
	object_root.name = "PhysicalObjects"
	add_child(object_root)
	book_root=Node3D.new()
	book_root.name="PhysicalBooks"
	add_child(book_root)
	if teea008_live:
		print("TEEA008_LIVE_START scene")
	make_rooms()
	make_residents()
	if teea008_live:print("ASSET_STARTUP_VALIDATION probes=",asset_banks.validation_disk_probes," reused=",asset_banks.validation_cache_hits)
	asset_banks.end_validation_pass()
	build_interface()
	make_creatures()
	make_physical_objects()
	fit_house_camera()
	smooth_focus = desired_focus
	zoom_current = zoom
	apply_camera(0.1)
	update_render_lod()
	if teea008_live:
		print("TEEA008_LIVE_START ready")
	notice.text = ("TEEA008 LIVE REVIEW · provisional body clearance · approved=false" if teea008_live else
		"TEEA008 GEOMETRY REVIEW · life paused · approved=false" if teea008_review.enabled else
		"ITER1 OWNER REVIEW · candidate art/guests/fauna · approved=false"
		if iter1_owner_review else
		"Независимый прототип: камера, постройка, автономная жизнь")

func _first_public_room_id(room_type: String) -> String:
	for room in world.rooms:
		if str(room.get("type","")) == room_type and str(room.get("privacy","public")) == "public":
			return str(room.get("id",""))
	return ""

func _register_iter1_review_creatures() -> void:
	var specs := [
		{"id":"CREATURE_SHURSHUN","name":"Шуршун","bank":"npc_cat_black_hero","owner":"RES_03","room":"common"},
		{"id":"CREATURE_CAT_CALICO_REVIEW","name":"Кошка","bank":"npc_cat_calico","owner":"","room":"rest"},
		{"id":"CREATURE_MOUSE_GRAY_REVIEW","name":"Мышь","bank":"npc_mouse_gray","owner":"","room":"library"},
		{"id":"CREATURE_RAT_HERO_REVIEW","name":"Крыса","bank":"npc_rat_hero","owner":"","room":"study"},
		{"id":"CREATURE_HEDGEHOG_REVIEW","name":"Ёж","bank":"npc_hedgehog_01","owner":"","room":"arrival"},
		{"id":"CREATURE_AI_SPHERE_REVIEW","name":"Сфера","bank":"npc_ai_magic_sphere","owner":"","room":"artifact"}
	]
	var changed := false
	for spec in specs:
		var creature_id := str(spec["id"])
		if world.creatures.has(creature_id):
			continue
		var bank_id := str(spec["bank"])
		if not asset_banks.candidate_creature_bank(bank_id):
			push_warning("Iteration-1 creature bank failed validation: "+bank_id)
			continue
		var room_id := _first_public_room_id(str(spec["room"]))
		if architecture_review and room_id=="" and str(spec["room"])=="arrival":
			room_id=_first_public_room_id("rest")
		if room_id == "":
			continue
		if world.register_creature(creature_id,str(spec["name"]),room_id,bank_id,
				str(spec["owner"]),false,false,false):
			changed = true
	if changed:
		world.save_world()

func _review_room_art_type(group: Dictionary) -> String:
	var room_type := str(group.get("type",""))
	if architecture_review:
		var physical_room:Dictionary=world.room_by_id(str(group.get("primary_id","")))
		if str(physical_room.get("interior_variant",""))!="":
			return str(physical_room["interior_variant"])
	if not iter1_owner_review or room_type != "guest":
		return room_type
	var cells: Array = group.get("cells",[])
	if cells.is_empty():
		return room_type
	match str(cells[0].get("candidate_room_id","")):
		"guest_centaur_01":
			return "guest_centaur"
		"guest_vampire_01":
			return "guest_vampire"
		"guest_miu_01":
			return "guest_miu"
	return room_type

func _creature_canvas_width(bank_id: String) -> float:
	if bank_id.contains("mouse"):
		return 0.65
	if bank_id.contains("rat"):
		return 0.85
	if bank_id.contains("hedgehog"):
		return 0.85
	if bank_id.contains("cat"):
		return 1.20
	if bank_id.contains("sphere"):
		return 0.95
	return 1.0

func surface_texture(color: Color) -> Texture2D:
	# Poly Haven materials are CC0 per imported asset provenance registry.
	# Reuse across modules. Geometry remains original and separately authored.
	var preference := ""
	if color == palette["rock"]:
		# Dark Rock has the correct fractured wall structure. A bright neutral
		# material tint below lifts it into the warm interior range.
		preference = "res://assets/materials/texture_albedo/dark_rock_diff_2k.jpg"
	elif color == palette["rock_light"]:
		# Lighter irregular stone is reserved for jambs, returns and trim.
		preference = "res://assets/materials/texture_albedo/stone_pathway_diff_2k.jpg"
	elif color == palette["floor"]:
		preference = "res://assets/materials/texture_albedo/weathered_brown_planks_diff_1k.jpg"
	elif color == palette["wood"]:
		preference = "res://assets/materials/texture_albedo/natural_walnut_veneer_diff_1k.jpg"
	elif color == palette["couch"]:
		preference = "res://assets/materials/texture_albedo/brown_leather_albedo_1k.jpg"
	elif color == palette["rug"]:
		preference = "res://assets/materials/texture_albedo/rough_linen_diff_1k.jpg"
	elif color == palette["bronze"] or color == palette["copper"]:
		preference = "res://assets/materials/texture_albedo/rust_coarse_01_diff_1k.jpg"
	if preference != "":
		return _texture_from_source(preference)
	return null

func mat(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var key: String = str(color.to_html()) + ("_e" if emissive else "_n")
	if material_cache.has(key):
		return material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	var texture_path := ""
	if color == palette["rock"] or color == palette["rock_light"]:
		texture_path = "res://assets/textures/basalt.jpg"
	elif color == palette["wood"]:
		texture_path = "res://assets/textures/wood.jpg"
	elif color == palette["floor"]:
		texture_path = "res://assets/textures/floor.jpg"
	var licensed: Texture2D = surface_texture(color)
	if licensed != null:
		m.albedo_texture = licensed
		# The imported albedos are already naturally graded. Multiplying them by
		# the old near-black palette destroyed material readability.
		if color == palette["rock"]:
			# HDR multiplier: preserve dark-rock cracks without turning the room
			# into a black cave.
			m.albedo_color = Color(1.28,1.20,1.12,1.0)
		elif color == palette["rock_light"]:
			m.albedo_color = Color("#f2e7dc")
		elif color == palette["floor"]:
			m.albedo_color = Color("#c9a98a")
		elif color == palette["wood"]:
			m.albedo_color = Color("#d5aa7e")
		elif color == palette["couch"]:
			m.albedo_color = Color("#d8b8a6")
		elif color == palette["rug"]:
			# Keep the linen weave, but restore the deep burgundy room identity.
			m.albedo_color = Color("#7b4652")
		elif color == palette["bronze"] or color == palette["copper"]:
			m.albedo_color = Color("#e2c7ac")
		m.uv1_scale = Vector3(2.3, 1.35, 1.0)
	elif texture_path != "":
		var fallback_texture:Texture2D=_texture_from_source(texture_path)
		if fallback_texture!=null:
			m.albedo_texture=fallback_texture
			m.uv1_scale=Vector3(2.0,2.0,1.0)
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.65
	material_cache[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	# Reuse geometry resources for repeated furniture elements / rock modules.
	var geometry_key := "%.4f:%.4f:%.4f" % [size.x,size.y,size.z]
	var mesh: BoxMesh
	if mesh_cache.has(geometry_key):
		mesh = mesh_cache[geometry_key]
	else:
		mesh = BoxMesh.new()
		mesh.size = size
		mesh_cache[geometry_key] = mesh
	node.mesh = mesh
	node.position = pos
	node.material_override = mat(color, emissive)
	parent.add_child(node)
	if not emissive and size.x < 0.57 and size.y < 0.69 and size.z < 0.62:
		node.add_to_group("low_end_micro_detail")
	return node

func box_line_xz(parent: Node3D, name: String, a: Vector3, b: Vector3,
		width: float, height: float, color: Color) -> MeshInstance3D:
	var delta:=b-a
	var length:=sqrt(delta.x*delta.x+delta.z*delta.z)
	var node:=box(parent,(a+b)*0.5,Vector3(width,height,length),color)
	node.name=name
	node.rotation.y=atan2(delta.x,delta.z)
	return node

func sphere(parent: Node3D, pos: Vector3, radius: float, color: Color,
		emissive: bool = false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*2.0
	mesh.radial_segments=16
	mesh.rings=8
	node.mesh=mesh
	node.position=pos
	node.material_override=mat(color,emissive)
	parent.add_child(node)
	return node

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		color: Color, emissive: bool = false) -> MeshInstance3D:
	var node:=MeshInstance3D.new()
	var mesh:=CylinderMesh.new()
	mesh.top_radius=radius
	mesh.bottom_radius=radius
	mesh.height=height
	mesh.radial_segments=16
	node.mesh=mesh
	node.position=pos
	node.material_override=mat(color,emissive)
	parent.add_child(node)
	return node

func _texture_from_source(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is Texture2D:
			return loaded
	if FileAccess.file_exists(path):
		var image := Image.new()
		if image.load(path) == OK:
			return ImageTexture.create_from_image(image)
	return null

func make_mountain() -> void:
	# Tiled original basalt atlas behind the cutaway, not rectangular checkerboard.
	var shell := Node3D.new()
	shell.name = "MountainMassBehindRooms"
	add_child(shell)
	var bounds:Rect2=camera_world_bounds()
	var rock := box(shell, Vector3(bounds.get_center().x,bounds.get_center().y,-5.6), Vector3(maxf(83.0,bounds.size.x+12.0),maxf(26.0,bounds.size.y+8.0),0.8), Color("#6f696a"))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#655d5e")
	material.albedo_texture = _texture_from_source("res://assets/textures/basalt.jpg")
	material.roughness = 1.0
	material.uv1_scale = Vector3(19.0, 6.0, 1.0)
	rock.material_override = material
	# Keep the mountain as one continuous textured mass. The old floating
	# grey support boxes read as prototype debris in HOUSE view and had no
	# topology or collision role.

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

func add_canonical_prop(parent: Node3D, prop_id: String, position: Vector3,
		world_height: float = 0.8) -> bool:
	if not world.physical_object(prop_id).is_empty():
		return true
	var tex: Texture2D = asset_banks.prop_display_texture(prop_id)
	if tex == null:
		return false
	var pic := Sprite3D.new()
	pic.name = "Canon_" + prop_id
	pic.texture = tex
	pic.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	pic.pixel_size = world_height/maxf(1.0,float(tex.get_height()))
	pic.position = position
	pic.no_depth_test = false
	parent.add_child(pic)
	return true

func add_tv(parent: Node3D, at: Vector3) -> void:
	box(parent, at + Vector3(0, 0.65, -0.04), Vector3(2.2, 1.25, 0.16), palette["black"])
	box(parent, at + Vector3(0, 0.65, 0.065), Vector3(1.98, 1.04, 0.035), palette["screen"], true)
	box(parent, at + Vector3(0, -0.12, 0), Vector3(1.15, 0.18, 0.46), palette["wood"])

func _named_dressing(parent: Node3D, name: String, at: Vector3 = Vector3.ZERO) -> Node3D:
	var node:=Node3D.new()
	node.name=name
	node.position=at
	parent.add_child(node)
	return node

func _add_candle(parent: Node3D, at: Vector3, height: float = 0.24) -> void:
	box(parent,at+Vector3(0,height*0.5,0),Vector3(0.055,height,0.055),Color("#d8c6a2"))
	box(parent,at+Vector3(0,height+0.045,0),Vector3(0.045,0.085,0.045),Color("#f2a14b"),true)

func _add_sconces(parent: Node3D, span: float, z: float = -1.48) -> void:
	for side in [-1.0,1.0]:
		var x:float=side*minf(span*0.34,2.6)
		box(parent,Vector3(x,2.15,z),Vector3(0.08,0.32,0.10),palette["bronze"])
		box(parent,Vector3(x,2.36,z+0.04),Vector3(0.14,0.13,0.10),Color("#d89055"),true)

func _add_warm_room_light(parent: Node3D, at: Vector3, energy: float = 0.42) -> void:
	var light:=OmniLight3D.new()
	light.name="DressingWarmLight"
	light.position=at
	light.light_color=Color("#e8a05e")
	light.light_energy=energy
	light.omni_range=4.8
	light.shadow_enabled=false
	parent.add_child(light)

func _add_authored_room_atmosphere(root: Node3D, kind: String, span: float,
		has_decor_art: bool = false) -> void:
	# When photorealistic furniture exists, procedural geometry must not
	# duplicate it. Keep only lighting, floor textiles and architecture that
	# adds depth without pretending to be replacement furniture.
	match kind:
		"common":
			var rug:=_named_dressing(root,"Dressing_Rug")
			box(rug,Vector3(-0.25,0.018,0.18),
				Vector3(minf(span*0.56,7.6),0.028,1.72),palette["rug"])
			var fire:=_named_dressing(root,"Dressing_Fireplace",Vector3(-0.35,0,-1.50))
			box(fire,Vector3(-0.58,0.72,0),Vector3(0.22,1.45,0.32),palette["rock_light"])
			box(fire,Vector3(0.58,0.72,0),Vector3(0.22,1.45,0.32),palette["rock_light"])
			box(fire,Vector3(0,1.43,0),Vector3(1.42,0.20,0.40),palette["wood"])
			box(fire,Vector3(0,0.36,0.04),Vector3(0.86,0.68,0.25),palette["black"])
			box(fire,Vector3(0,0.36,0.19),Vector3(0.55,0.44,0.045),Color("#e97935"),true)
			for x in [-0.42,0.0,0.39]:
				_add_candle(fire,Vector3(float(x),1.55,0.06),0.20+0.05*absf(float(x)))
			if not has_decor_art:
				_add_sconces(root,span,-1.54)
			_add_warm_room_light(root,Vector3(-0.35,1.05,-1.05),0.62)
		"library":
			var rug:=_named_dressing(root,"Dressing_ReadingRug")
			box(rug,Vector3(0,0.016,0.24),
				Vector3(minf(span*0.68,4.0),0.025,1.65),palette["rug"])
			if not has_decor_art:
				_add_sconces(root,span)
			_add_warm_room_light(root,Vector3(0,1.55,-0.85),0.34)
		"music":
			var rug:=_named_dressing(root,"Dressing_MusicRug")
			box(rug,Vector3(0,0.016,0.20),
				Vector3(minf(span*0.72,4.1),0.025,1.62),palette["rug"])
			if not has_decor_art:
				_add_sconces(root,span,-1.52)
			_add_warm_room_light(root,Vector3(0,1.55,-0.85),0.34)
		"cinema":
			var runner:=_named_dressing(root,"Dressing_TheatreRunner")
			box(runner,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.74,4.2),0.025,1.82),Color("#4b222b"))
			if not has_decor_art:
				_add_sconces(root,span,-1.46)
			_add_warm_room_light(root,Vector3(0,1.45,-0.85),0.24)
		"study":
			var rug:=_named_dressing(root,"Dressing_StudyRug")
			box(rug,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.58,4.0),0.025,1.55),palette["rug"])
			if not has_decor_art:
				_add_sconces(root,span)
			_add_warm_room_light(root,Vector3(0,1.45,-0.90),0.28)
		"rest":
			var rug:=_named_dressing(root,"Dressing_RestRug")
			box(rug,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.64,5.5),0.025,1.72),palette["rug"])
			_add_warm_room_light(root,Vector3(0,1.40,-0.80),0.25)
		"artifact":
			var rug:=_named_dressing(root,"Dressing_ArtifactRug")
			box(rug,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.58,4.8),0.025,1.52),Color("#49333e"))
			if not has_decor_art:
				_add_sconces(root,span)
			_add_warm_room_light(root,Vector3(0,1.25,-0.72),0.32)
		"workshop":
			var mat_node:=_named_dressing(root,"Dressing_WorkMat")
			box(mat_node,Vector3(0,0.016,0.12),
				Vector3(minf(span*0.66,5.0),0.025,1.48),Color("#4a413d"))
			_add_warm_room_light(root,Vector3(-minf(span*0.18,0.75),1.10,-0.88),0.34)
		"arrival","corridor":
			var runner:=_named_dressing(root,"Dressing_Runner")
			box(runner,Vector3(0,0.016,0.18),
				Vector3(maxf(1.4,span*0.62),0.025,1.46),Color("#4b2e33"))
			_add_warm_room_light(root,Vector3(0,1.40,-0.90),0.20)
		_:
			pass

func _add_physical_room_dressing(parent: Node3D, group: Dictionary) -> Node3D:
	# Supplemental atmosphere only. Main authored furniture/stations stay owned
	# by the art + station contracts. Dressing remains behind z=0.70 except for
	# paper-thin floor textiles, leaving the front connector aisle unobstructed.
	var root:=_named_dressing(parent,"PhysicalDressing")
	var kind:String=str(group.get("type",""))
	var span:float=float(group.get("width",1))*W
	if bool(group.get("replaces_furniture",false)):
		_add_authored_room_atmosphere(root,kind,span,bool(group.get("has_decor_art",false)))
		return root
	match kind:
		"common":
			var rug:=_named_dressing(root,"Dressing_Rug")
			box(rug,Vector3(-0.25,0.018,0.18),
				Vector3(minf(span*0.56,7.6),0.028,1.72),palette["rug"])
			var fire:=_named_dressing(root,"Dressing_Fireplace",Vector3(-0.35,0,-1.50))
			box(fire,Vector3(-0.58,0.72,0),Vector3(0.22,1.45,0.32),palette["rock_light"])
			box(fire,Vector3(0.58,0.72,0),Vector3(0.22,1.45,0.32),palette["rock_light"])
			box(fire,Vector3(0,1.43,0),Vector3(1.42,0.20,0.40),palette["wood"])
			box(fire,Vector3(0,0.36,0.04),Vector3(0.86,0.68,0.25),palette["black"])
			box(fire,Vector3(0,0.36,0.19),Vector3(0.55,0.44,0.045),Color("#e97935"),true)
			for x in [-0.42,0.0,0.39]:
				_add_candle(fire,Vector3(float(x),1.55,0.06),0.20+0.05*absf(float(x)))
			_add_sconces(root,span,-1.54)
			var side_table:=_named_dressing(root,"Dressing_CommonSideTable",Vector3(span*0.24,0,-0.74))
			box(side_table,Vector3(0,0.34,0),Vector3(0.72,0.12,0.54),palette["wood"])
			box(side_table,Vector3(-0.26,0.17,0),Vector3(0.08,0.34,0.40),palette["wood"])
			box(side_table,Vector3(0.26,0.17,0),Vector3(0.08,0.34,0.40),palette["wood"])
			_add_candle(side_table,Vector3(0,0.42,0),0.16)
			_add_warm_room_light(root,Vector3(-0.35,1.05,-1.05),0.62)
		"library":
			var rug:=_named_dressing(root,"Dressing_ReadingRug")
			box(rug,Vector3(0,0.016,0.24),
				Vector3(minf(span*0.68,4.0),0.025,1.65),palette["rug"])
			var books:=_named_dressing(root,"Dressing_BookStacks",Vector3(0,0,-1.08))
			for i in range(5):
				var bx:float=-0.48+float(i)*0.24
				box(books,Vector3(bx,0.055+float(i%2)*0.035,0),
					Vector3(0.20,0.10,0.32),
					[Color("#704b43"),Color("#92715a"),Color("#554454")][i%3])
			var desk:=_named_dressing(root,"Dressing_ReadingDesk",Vector3(0,0,-0.52))
			box(desk,Vector3(0,0.58,0),Vector3(minf(1.55,span*0.30),0.12,0.66),palette["wood"])
			for sx in [-0.55,0.55]:
				box(desk,Vector3(float(sx),0.29,0),Vector3(0.09,0.58,0.48),palette["wood"])
			var desk_lamp:=_named_dressing(desk,"Dressing_DeskLamp",Vector3(0.34,0.66,-0.06))
			box(desk_lamp,Vector3(0,0.20,0),Vector3(0.05,0.40,0.05),palette["bronze"])
			sphere(desk_lamp,Vector3(0,0.42,0),0.11,Color("#e8aa64"),true)
			_add_sconces(root,span)
			_add_warm_room_light(root,Vector3(0,1.65,-1.05),0.42)
		"music":
			var rug:=_named_dressing(root,"Dressing_MusicRug")
			box(rug,Vector3(0,0.016,0.20),
				Vector3(minf(span*0.72,4.1),0.025,1.62),palette["rug"])
			for side in [-1.0,1.0]:
				var amp:=_named_dressing(root,
					"Dressing_Amp_%s" % ("L" if side<0 else "R"),
					Vector3(side*span*0.36,0,-1.34))
				box(amp,Vector3(0,0.34,0),Vector3(0.54,0.68,0.38),palette["black"])
				box(amp,Vector3(0,0.35,0.205),Vector3(0.38,0.42,0.035),Color("#6f5b4f"))
			var drums:=_named_dressing(root,"Dressing_DrumKit",Vector3(-0.62,0,-0.72))
			cylinder(drums,Vector3(0,0.30,0),0.30,0.58,Color("#6f3429"))
			cylinder(drums,Vector3(0.45,0.42,-0.12),0.20,0.34,Color("#7b4032"))
			box(drums,Vector3(-0.34,0.62,-0.10),Vector3(0.05,1.10,0.05),palette["bronze"])
			cylinder(drums,Vector3(-0.34,1.12,-0.10),0.30,0.025,Color("#a77b49"))
			for side in [-1.0,1.0]:
				var stand:=_named_dressing(root,
					"Dressing_InstrumentStand_%s" % ("L" if side<0 else "R"),
					Vector3(side*minf(span*0.23,1.3),0,-1.48))
				box(stand,Vector3(0,0.55,0),Vector3(0.05,1.10,0.05),palette["wood"])
				box(stand,Vector3(0,1.08,0),Vector3(0.28,0.06,0.06),palette["wood"])
			_add_sconces(root,span,-1.52)
			_add_warm_room_light(root,Vector3(0,1.65,-1.05),0.40)
		"cinema":
			var runner:=_named_dressing(root,"Dressing_TheatreRunner")
			box(runner,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.74,4.2),0.025,1.82),Color("#4b222b"))
			for side in [-1.0,1.0]:
				var speaker:=_named_dressing(root,
					"Dressing_Speaker_%s" % ("L" if side<0 else "R"),
					Vector3(side*span*0.37,0,-1.38))
				box(speaker,Vector3(0,0.68,0),Vector3(0.38,1.36,0.34),palette["black"])
				for yy in [0.36,0.82,1.12]:
					box(speaker,Vector3(0,float(yy),0.185),Vector3(0.24,0.24,0.025),Color("#463d3a"))
				var curtain:=_named_dressing(root,
					"Dressing_Curtain_%s" % ("L" if side<0 else "R"),
					Vector3(side*minf(span*0.43,2.0),0,-1.56))
				box(curtain,Vector3(0,1.45,0),Vector3(0.34,2.40,0.09),Color("#5a1f2b"))
			var seats:=_named_dressing(root,"Dressing_CinemaSeats",Vector3(0,0,-0.15))
			for row in range(2):
				var zrow:float=-0.45+float(row)*0.58
				for col in [-1.0,0.0,1.0]:
					var seat:=_named_dressing(seats,"Seat_%d_%d" % [row,int(col+1)],Vector3(float(col)*0.72,0,zrow))
					box(seat,Vector3(0,0.26,0),Vector3(0.56,0.34,0.48),palette["couch"])
					box(seat,Vector3(0,0.62,-0.18),Vector3(0.56,0.54,0.12),palette["couch"])
			_add_sconces(root,span,-1.46)
			_add_warm_room_light(root,Vector3(0,1.45,-0.95),0.28)
		"study":
			var rug:=_named_dressing(root,"Dressing_StudyRug")
			box(rug,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.58,4.0),0.025,1.55),palette["rug"])
			_add_sconces(root,span)
		"rest":
			var rug:=_named_dressing(root,"Dressing_RestRug")
			box(rug,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.64,5.5),0.025,1.72),palette["rug"])
			for side in [-1.0,1.0]:
				var lamp:=_named_dressing(root,
					"Dressing_Lantern_%s" % ("L" if side<0 else "R"),
					Vector3(side*minf(span*0.34,2.8),0,-1.35))
				box(lamp,Vector3(0,0.34,0),Vector3(0.07,0.68,0.07),palette["bronze"])
				box(lamp,Vector3(0,0.73,0),Vector3(0.24,0.22,0.20),Color("#d89055"),true)
		"artifact":
			var rug:=_named_dressing(root,"Dressing_ArtifactRug")
			box(rug,Vector3(0,0.016,0.18),
				Vector3(minf(span*0.58,4.8),0.025,1.52),Color("#49333e"))
			var pedestal:=_named_dressing(root,"Dressing_ArtifactPedestal",Vector3(0,0,-0.78))
			box(pedestal,Vector3(0,0.48,0),Vector3(0.74,0.96,0.74),palette["wood"])
			box(pedestal,Vector3(0,0.98,0),Vector3(0.92,0.10,0.92),palette["bronze"])
			var orb:=sphere(pedestal,Vector3(0,1.28,0),0.26,Color("#8f55d8"),true)
			orb.name="DisplayOrb"
			for side in [-1.0,1.0]:
				var side_ped:=_named_dressing(root,
					"Dressing_SidePedestal_%s" % ("L" if side<0 else "R"),
					Vector3(side*minf(span*0.30,1.35),0,-1.18))
				box(side_ped,Vector3(0,0.36,0),Vector3(0.50,0.72,0.50),palette["wood"])
				_add_candle(side_ped,Vector3(0,0.76,0),0.15)
			_add_sconces(root,span)
			_add_warm_room_light(root,Vector3(0,1.25,-0.72),0.46)
		"workshop":
			var mat_node:=_named_dressing(root,"Dressing_WorkMat")
			box(mat_node,Vector3(0,0.016,0.12),
				Vector3(minf(span*0.66,5.0),0.025,1.48),Color("#4a413d"))
			for side in [-1.0,1.0]:
				var crate:=_named_dressing(root,
					"Dressing_Crate_%s" % ("L" if side<0 else "R"),
					Vector3(side*minf(span*0.36,3.0),0,-1.36))
				box(crate,Vector3(0,0.24,0),Vector3(0.64,0.48,0.48),palette["wood"])
			var forge:=_named_dressing(root,"Dressing_Forge",Vector3(-minf(span*0.28,1.25),0,-1.26))
			box(forge,Vector3(0,0.48,0),Vector3(0.92,0.96,0.62),palette["rock_light"])
			box(forge,Vector3(0,0.52,0.22),Vector3(0.62,0.42,0.06),Color("#e1662f"),true)
			_add_warm_room_light(root,Vector3(-minf(span*0.28,1.25),1.05,-1.04),0.58)
			var bench:=_named_dressing(root,"Dressing_Workbench",Vector3(minf(span*0.18,0.85),0,-0.68))
			box(bench,Vector3(0,0.70,0),Vector3(minf(1.75,span*0.42),0.16,0.72),palette["wood"])
			for sx in [-0.70,0.70]:
				box(bench,Vector3(float(sx),0.35,0),Vector3(0.10,0.70,0.50),palette["wood"])
			for x in [-0.45,0.0,0.42]:
				_add_candle(bench,Vector3(float(x),0.80,-0.08),0.12)
		"arrival","corridor":
			var runner:=_named_dressing(root,"Dressing_Runner")
			box(runner,Vector3(0,0.016,0.18),
				Vector3(maxf(1.4,span*0.62),0.025,1.46),Color("#4b2e33"))
		_:
			pass
	return root

func furniture_object(parent: Node3D, object_id: String) -> Node3D:
	# Stable scene names mirror data/furniture_interactions_v1.json.
	# The node exists only while the camera materializes this room's detail,
	# but the simulation's data-owned station IDs persist independently.
	var object := Node3D.new()
	object.name = object_id
	parent.add_child(object)
	return object

func furnish(parent: Node3D, kind: String, x: int, level: int) -> void:
	var offset := int(abs(x) + abs(level)) % 2
	match kind:
		"common":
			box(parent, Vector3(0, 0.05, 0.45), Vector3(3.8, 0.04, 2.15), palette["rug"])
			if x == -2:
				var skins := furniture_object(parent, "FIREPLACE_SKINS")
				for side in [-1.0,1.0]:
					box(skins,Vector3(side*1.29,0.022,-0.32),
						Vector3(0.84,0.025,0.70),palette["rug"])
				box(parent, Vector3(-1.35, 1.38, -1.73), Vector3(1.25, 1.48, 0.25), palette["rock_light"])
				box(parent, Vector3(-1.35, 0.92, -1.45), Vector3(0.80, 0.58, 0.17), palette["black"])
				box(parent, Vector3(-1.32, 0.88, -1.30), Vector3(0.53, 0.45, 0.08), Color("#f4943c"), true)
				var fire_light := OmniLight3D.new()
				fire_light.name = "WarmHearthLight"
				fire_light.position = Vector3(-1.32,1.22,-1.12)
				fire_light.light_color = Color("#efaa68")
				fire_light.light_energy = 0.68
				fire_light.omni_range = 6.5
				fire_light.shadow_enabled = false
				parent.add_child(fire_light)
			elif x == -1:
				add_sofa(furniture_object(parent,"SOFA_COMMON_MIDDLE"), Vector3(0, 0, -1.06), 2.6)
				box(parent, Vector3(0, 0.44, 0.86), Vector3(1.4, 0.30, 0.7), palette["wood"])
				# Canonical historical mugs belong in the Common, not the Library.
				add_canonical_prop(parent,"MUG_RED_A",Vector3(-0.37,0.91,0.90),0.45)
				add_canonical_prop(parent,"MUG_BLUE_A",Vector3(0.34,0.91,0.90),0.45)
			else:
				add_sofa(furniture_object(parent,"SOFA_COMMON_GENERIC"), Vector3(0.0, 0, -0.88), 2.35, Color("#76513e"))
				add_shelf(parent, Vector3(1.38, 0.25, -1.70), 1.25)
		"library":
			add_shelf(parent, Vector3(-1.24, 0.15, -1.64), 1.75)
			add_shelf(parent, Vector3(1.12, 0.15, -1.64), 1.55)
			box(furniture_object(parent,"TABLE_LIBRARY"), Vector3(0.0, 0.48, 0.82), Vector3(0.9, 0.35, 0.65), palette["wood"])
		"rest":
			add_sofa(furniture_object(parent,"SOFA_REST"), Vector3(-0.30, 0.0, -0.83), 2.4, Color("#766049"))
			add_shelf(parent, Vector3(1.42, 0.23, -1.58), 1.1)
			box(parent, Vector3(0.72, 0.30, 0.70), Vector3(0.80, 0.35, 0.62), palette["wood"])
		"study":
			var desk := furniture_object(parent,"DESK_STUDY")
			box(desk, Vector3(0.0, 0.7, -1.05), Vector3(2.5, 0.18, 0.89), palette["wood"])
			box(desk, Vector3(-0.9, 0.38, -1.0), Vector3(0.15, 0.65, 0.50), palette["wood"])
			box(desk, Vector3(0.9, 0.38, -1.0), Vector3(0.15, 0.65, 0.50), palette["wood"])
			box(parent, Vector3(-0.1, 0.96, -1.0), Vector3(0.75, 0.52, 0.045), palette["screen"])
			add_shelf(parent, Vector3(1.50, 0.10, -1.7), 0.9)
		"music":
			box(parent, Vector3(-1.3, 0.7, -1.5), Vector3(1.2, 1.2, 0.58), palette["black"])
			box(parent, Vector3(1.3, 0.7, -1.5), Vector3(1.2, 1.2, 0.58), palette["black"])
			for side in [-1, 1]:
				box(parent, Vector3(side * 1.3, 0.89, -1.16), Vector3(0.7, 0.58, 0.10), palette["screen"])
			box(furniture_object(parent,"DESK_MUSIC"), Vector3(0, 0.68, -1.2), Vector3(1.25, 0.17, 0.75), palette["wood"])
		"cinema":
			add_tv(parent, Vector3(0.0, 0.70, -1.68))
			add_sofa(furniture_object(parent,"SOFA_CINEMA"), Vector3(0, 0, 0.84), 2.9, Color("#71423b"))
		"arrival":
			# Coat rack and shoe storage; deliberately no bench.
			box(parent, Vector3(-1.30, 1.28, -1.65), Vector3(0.1, 2.4, 0.1), palette["bronze"])
			box(parent, Vector3(-1.30, 2.24, -1.65), Vector3(0.85, 0.11, 0.13), palette["bronze"])
			box(parent, Vector3(1.08, 0.25, -1.5), Vector3(1.70, 0.50, 0.40), palette["wood"])
		"workshop":
			box(furniture_object(parent,"BENCH_WORKSHOP"), Vector3(0, 0.85, -1.30), Vector3(2.95, 0.20, 0.8), palette["wood"])
			add_shelf(parent, Vector3(1.2, 0.15, -1.72), 1.2)
		"artifact":
			add_shelf(parent, Vector3(0, 0.1, -1.62), 3.1)
			var canvas_ids := ["CUBE_LETTERS","POSTER_SHURSHUN","PHOTO_MOON","PORTRAIT_SHURS"]
			var art_shown := 0
			for i in range(canvas_ids.size()):
				var world_x: float = -1.65 + float(i) * 1.1
				if add_canonical_prop(parent,canvas_ids[i],Vector3(world_x,1.45,-1.52),0.95):
					art_shown += 1
			if art_shown == 0:
				# Temporary placeholder only. Never present cubes as the real masters.
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

func _add_rear_architecture(parent: Node3D, group: Dictionary) -> void:
	var kind:String=str(group.get("type",""))
	if kind not in ["common","library"]:
		return
	var span:float=float(group.get("width",1))*W
	var root:=Node3D.new()
	root.name="RearArchitecture"
	parent.add_child(root)
	# Structural timber gives one continuous room rhythm without reintroducing
	# module seams. All elements stay behind the playable rear boundary.
	for fraction in [-0.36,-0.12,0.14,0.38]:
		var x:float=span*float(fraction)
		var post:=box(root,Vector3(x,1.47,-2.005),
			Vector3(0.14,2.72,0.10),palette["wood"])
		post.name="RearTimberPost_%d" % root.get_child_count()
	var header:=box(root,Vector3(0,2.77,-2.00),
		Vector3(span-0.70,0.16,0.12),palette["wood"])
	header.name="RearTimberHeader"

	# A cool lightwell breaks the brown cave wall and gives the room the
	# architectural depth visible in the target concepts. It is scenery only.
	var lightwell_x:float=span*0.28 if kind=="common" else -span*0.18
	var well:=Node3D.new()
	well.name="RearLightwell"
	well.position=Vector3(lightwell_x,0,-1.995)
	root.add_child(well)
	var pane:=box(well,Vector3(0,1.55,0),
		Vector3(1.70,1.68,0.035),Color("#506678"),true)
	pane.name="LightwellGlass"
	pane.material_override.emission_energy_multiplier=0.18
	for sx in [-0.90,0.90]:
		box(well,Vector3(float(sx),1.55,0.025),
			Vector3(0.13,1.94,0.10),palette["rock_light"])
	box(well,Vector3(0,2.51,0.025),Vector3(1.93,0.14,0.10),palette["rock_light"])
	box(well,Vector3(0,0.59,0.025),Vector3(1.93,0.14,0.10),palette["rock_light"])
	box(well,Vector3(0,1.55,0.045),Vector3(0.08,1.68,0.06),palette["wood"])
	box(well,Vector3(0,1.55,0.045),Vector3(1.70,0.08,0.06),palette["wood"])

func add_backwall_stage(parent: Node3D, group: Dictionary) -> void:
	# One continuous rear wall per physical room. R2/R3 are not three
	# architectural bays stitched together; only outer returns frame the volume.
	var kind:String=str(group["type"])
	if kind in ["private","lift"]:
		return
	var span:float=float(group["width"])*W
	var base_color:=Color("#4a4143")
	match kind:
		"common": base_color=Color("#514046")
		"library","artifact": base_color=Color("#433739")
		"cinema": base_color=Color("#26242b")
		"study","workshop": base_color=Color("#554843")
		"music": base_color=Color("#403842")
		"rest": base_color=Color("#51473f")
	var rear:=Node3D.new()
	rear.name="PhysicalRearWall"
	parent.add_child(rear)
	_add_rear_architecture(rear,group)
	var rear_panel:=box(rear,Vector3(0,1.49,-2.12),
		Vector3(span-0.42,2.67,0.08),base_color)
	rear_panel.name="StructuralRearPanel"
	if kind in ["common","library"]:
		# The sparse pilot backdrop is suppressed for these two rooms, so the
		# physical rear wall carries real stone. Rear-wall UVs are denser than
		# generic side-wall UVs to avoid giant cliff forms across an R3 span.
		var rear_material:StandardMaterial3D=mat(palette["rock"]).duplicate() as StandardMaterial3D
		rear_material.uv1_scale=Vector3(4.8,3.1,1.0)
		rear_material.albedo_color=Color(1.42,1.30,1.17,1.0)
		rear_material.emission_enabled=true
		rear_material.emission=Color("#5a4030")
		rear_material.emission_energy_multiplier=0.16
		if rear_material.albedo_texture!=null:
			rear_material.emission_texture=rear_material.albedo_texture
		rear_panel.material_override=rear_material
	box(rear,Vector3(-span*0.5+0.16,1.47,-1.59),
		Vector3(0.18,2.76,0.24),palette["rock_light"])
	box(rear,Vector3(span*0.5-0.16,1.47,-1.59),
		Vector3(0.18,2.76,0.24),palette["rock_light"])
	box(rear,Vector3(0,2.83,-1.58),Vector3(span-0.36,0.15,0.25),palette["border"])
	box(rear,Vector3(0,0.19,-1.55),Vector3(span-0.48,0.31,0.27),palette["border"])
	if ["common","rest","study","library","arrival"].has(kind) and not (architecture_review and kind=="common" and bool(group.get("teea008_review",false))):
		var lamp_count:int=1 if int(group["width"])==1 else int(group["width"])
		for i in range(lamp_count):
			var px:float=0.0 if lamp_count==1 else lerpf(
				-span*0.5+1.45,span*0.5-1.45,float(i)/float(lamp_count-1))
			box(rear,Vector3(px,2.22,-1.41),
				Vector3(0.09,0.34,0.10),palette["bronze"])
			box(rear,Vector3(px,2.43,-1.33),
				Vector3(0.15,0.14,0.09),Color("#b17c55"),true)

func add_cutaway_depth(parent: Node3D, group: Dictionary) -> void:
	# Render-only perspective scaffold. Physical navigation remains the full
	# rectangular X/Z room, but visual floor guides converge toward the rear.
	var kind:String=str(group["type"])
	if kind in ["private","lift"]:
		return
	var span:float=float(group["width"])*W
	var volume:=Node3D.new()
	volume.name="PhysicalDepthVolume"
	parent.add_child(volume)
	var guide_index:=0
	for z in [-1.19,0.18,1.10]:
		var zz:float=float(z)
		var scale_value:float=depth_visual_scale(zz)
		var guide:=box(volume,Vector3(0,-0.006,zz),
			Vector3(maxf(0.5,(span-0.52)*scale_value),0.006,0.008),palette["floor"])
		guide.name="PerspectiveGuide_%d" % guide_index
		guide.set_meta("depth_scale",scale_value)
		guide_index+=1
	var rear_z:float=-1.52
	var front_z:float=1.31
	var rear_half:float=(span*0.5-0.18)*depth_visual_scale(rear_z)
	var front_half:float=span*0.5-0.18
	for side in [-1.0,1.0]:
		box_line_xz(volume,
			"PerspectiveRail_%s" % ("L" if side<0 else "R"),
			Vector3(side*rear_half,-0.035,rear_z),
			Vector3(side*front_half,-0.035,front_z),
			0.020,0.008,palette["floor"])
	var front_lip:=box(volume,Vector3(0,-0.09,front_z),
		Vector3(maxf(0.5,span-0.34),0.055,0.11),palette["rock_light"])
	front_lip.name="PerspectiveFrontLip"
	for side in [-1.0,1.0]:
		var pier:=box(volume,Vector3(side*front_half,0.14,1.28),
			Vector3(0.10,0.26,0.14),palette["rock_light"])
		pier.name="PerspectiveFrontPier_%s" % ("L" if side<0 else "R")
	# No rear panel here: accepted backdrop or Stage_Backwall owns the rear
	# architecture. Depth geometry must never occlude room art.

func add_room_overview_cues(parent: Node3D, group: Dictionary) -> void:
	# Cheap room identity at distant zoom, but still one physical composition.
	var kind:String=str(group["type"])
	if kind=="private":
		return
	var span:float=float(group["width"])*W
	var width:int=int(group["width"])
	var root:=Node3D.new()
	root.name="OverviewPhysicalRoom"
	parent.add_child(root)
	match kind:
		"common","rest":
			box(root,Vector3(0,0.10,-0.35),
				Vector3(maxf(1.8,span*0.62),0.035,2.18),palette["rug"])
			box(root,Vector3(-span*0.18,0.48,-0.86),
				Vector3(maxf(1.4,span*0.34),0.58,0.64),palette["couch"])
		"library","artifact":
			box(root,Vector3(0,1.16,-1.70),
				Vector3(maxf(2.8,span*0.72),1.80,0.22),palette["wood"])
			box(root,Vector3(0,0.48,0.28),
				Vector3(maxf(1.0,span*0.28),0.35,0.72),palette["wood"])
		"cinema":
			box(root,Vector3(0,1.65,-1.74),
				Vector3(maxf(2.5,span*0.62),1.42,0.15),palette["black"])
			box(root,Vector3(0,1.65,-1.63),
				Vector3(maxf(2.16,span*0.56),1.10,0.07),palette["screen"],true)
			box(root,Vector3(0,0.45,0.78),
				Vector3(maxf(2.4,span*0.50),0.58,0.66),palette["couch"])
		"music":
			for side in [-1.0,1.0]:
				box(root,Vector3(side*span*0.25,1.09,-1.67),
					Vector3(0.62,1.40,0.24),palette["black"])
			box(root,Vector3(0,0.68,-1.05),
				Vector3(maxf(1.25,span*0.24),0.17,0.75),palette["wood"])
		"study","workshop","kitchen":
			box(root,Vector3(0,0.66,-1.26),
				Vector3(maxf(2.72,span*0.62),0.18,0.66),palette["wood"])
		"arrival":
			box(root,Vector3(-span*0.22,1.20,-1.67),
				Vector3(0.10,2.15,0.12),palette["bronze"])
			box(root,Vector3(span*0.18,0.25,-1.50),
				Vector3(maxf(1.2,span*0.30),0.50,0.40),palette["wood"])
		"lift":
			box(root,Vector3(0,0.06,-0.35),
				Vector3(maxf(3.5,span-0.6),0.08,3.1),palette["copper"])
		_:
			pass

func _is_near_detail(group_node: Node3D) -> bool:
	# Detail follows the camera position but never drives simulation.
	# R1/R2/R3 shells stay drawn; rich furniture is mounted only near focus.
	if zoom_current >= 44.0 or current_mode in ["HOUSE","LEVEL"]:
		return false
	var half_width: float = float(visual_room_groups.get(group_node.name,{}).get("width",1))*W*0.5
	var radius_x: float = maxf(7.0,zoom_current*0.63)+half_width
	var radius_y: float = maxf(H*1.15,zoom_current*0.30)
	return absf(group_node.position.x-smooth_focus.x) <= radius_x and absf(group_node.position.y-smooth_focus.y) <= radius_y

func register_art_foreground(group_node: Node3D) -> void:
	var layer:Node3D=group_node.get_node_or_null("Layer_ApprovedArt")
	if layer==null or camera==null:
		return
	var fg:Sprite3D=layer.get_node_or_null("Art_foreground")
	var reference:Sprite3D=layer.get_node_or_null("Art_furniture_back")
	if fg==null or reference==null or not fg.has_meta("physical_z"):
		return
	var target_z:float=float(fg.get_meta("physical_z"))
	var camera_local:Vector3=group_node.to_local(camera.global_position)
	var denominator:float=reference.position.z-camera_local.z
	if absf(denominator)<0.001:
		return
	var k:float=(target_z-camera_local.z)/denominator
	if k<=0.0 or k>2.0:
		return
	fg.position=Vector3(
		camera_local.x+(reference.position.x-camera_local.x)*k,
		camera_local.y+(reference.position.y-camera_local.y)*k,
		target_z)
	fg.scale=Vector3(k,k,1.0)

func register_loaded_foregrounds() -> void:
	if room_root==null:
		return
	for group_node in room_root.get_children():
		if art_loaded_groups.has(group_node.name):
			register_art_foreground(group_node)

func _load_room_art(group_node: Node3D) -> void:
	if art_loaded_groups.has(group_node.name):
		return
	var group: Dictionary=visual_room_groups.get(group_node.name,{})
	if not bool(group.get("has_art",false)):
		return
	var layer: Node3D=group_node.get_node_or_null("Layer_ApprovedArt")
	if layer==null:
		return
	var art_type := str(group.get("art_type",group["type"]))
	var count: int=interior_skin.add_layers(layer,art_type,
		int(group["width"]),float(group["width"])*W,bool(group.get("native_decor",false)))
	if count>0:
		art_loaded_groups[group_node.name]=count
		art_layer_count+=count
		register_art_foreground(group_node)
		# Hide only the old rear panels when a real accepted backdrop is mounted.
		var stage:Node3D=group_node.get_node_or_null("Layer_Background/Stage_Backwall")
		if stage!=null and layer.get_node_or_null("Art_backdrop")!=null:
			stage.visible=false

func _clear_children_now(parent: Node) -> void:
	# Room/art rebuilds can unload and reload within one rendered frame.
	# queue_free() leaves old names alive until frame end, which caused new
	# Art_backdrop / room nodes to be auto-renamed and broke visibility logic.
	for child in parent.get_children():
		parent.remove_child(child)
		child.free()

func _release_room_art(group_node: Node3D) -> void:
	if not art_loaded_groups.has(group_node.name):
		return
	var count: int=int(art_loaded_groups[group_node.name])
	art_loaded_groups.erase(group_node.name)
	art_layer_count=maxi(0,art_layer_count-count)
	var layer: Node3D=group_node.get_node_or_null("Layer_ApprovedArt")
	if layer:
		_clear_children_now(layer)
	var stage:Node3D=group_node.get_node_or_null("Layer_Background/Stage_Backwall")
	if stage!=null:
		stage.visible=true

func _group_facade_only(group: Dictionary) -> bool:
	var cells: Array = group.get("cells",[])
	if cells.is_empty():
		return false
	return not world.public_cutaway_allowed(world.room_by_id(str(group.get("primary_id",""))))

func _ensure_fallback_anchor_furniture(module: Node3D, anchors: Array) -> void:
	# Approved furniture_back art carries the visible furniture itself and uses
	# invisible named anchors. When that art is unavailable/rejected (including
	# an LFS pointer instead of real image bytes), procedural fallback must still
	# keep the data-owned interaction contract truthful: every advertised
	# furniture_id has one visible proxy object in this room module.
	var created: Dictionary = {}
	for raw in anchors:
		if typeof(raw)!=TYPE_DICTIONARY:
			continue
		var anchor: Dictionary=raw
		var object_id:String=str(anchor.get("furniture_id",""))
		if object_id=="" or module.get_node_or_null(object_id)!=null or created.has(object_id):
			continue
		var object:=furniture_object(module,object_id)
		var x:float=float(anchor.get("x",0.0))
		var z:float=float(anchor.get("z",0.0))
		match str(anchor.get("kind","standing")):
			"seat","floor_rest":
				# Low seat + back. Anchor is the pelvis/interaction position.
				box(object,Vector3(x,0.28,z),Vector3(0.64,0.42,0.58),palette["wood"])
				box(object,Vector3(x,0.70,z-0.24),Vector3(0.64,0.72,0.12),palette["wood"])
			"work":
				# Work anchor is in front of the work surface; keep the proxy
				# behind the resident's approach aisle.
				box(object,Vector3(x,0.72,z-0.38),Vector3(1.15,0.16,0.66),palette["wood"])
				box(object,Vector3(x-0.47,0.37,z-0.38),Vector3(0.12,0.70,0.48),palette["wood"])
				box(object,Vector3(x+0.47,0.37,z-0.38),Vector3(0.12,0.70,0.48),palette["wood"])
			_:
				# Standing/view anchors point at an object rather than a seat.
				box(object,Vector3(x,0.66,z-0.48),Vector3(0.62,1.20,0.34),palette["wood"])
		created[object_id]=true

func _proxy_authored_object(parent: Node3D, item: Dictionary) -> void:
	var id:String=str(item.get("id","visual_object"))
	var node:=furniture_object(parent,id)
	var x:float=float(item.get("x",0.0))
	var z:float=float(item.get("z",-1.0))
	node.position=Vector3(x,0.0,z)
	var scale_value:float=maxf(0.25,float(item.get("scale",0.7)))
	var asset:String=str(item.get("asset",item.get("type",""))).to_lower()
	if asset.contains("chair") or asset.contains("lounge"):
		box(node,Vector3(0,0.27,0),Vector3(0.62*scale_value,0.42,0.58),palette["wood"])
		box(node,Vector3(0,0.70,-0.24),Vector3(0.62*scale_value,0.70,0.12),palette["wood"])
	elif asset.contains("shelf") or asset.contains("bookshelf"):
		add_shelf(node,Vector3(0,0.12,0),maxf(0.9,1.9*scale_value))
	elif asset.contains("day_bed") or asset.contains("sofa"):
		add_sofa(node,Vector3.ZERO,maxf(1.2,2.8*scale_value),palette["couch"])
	elif asset.contains("lamp"):
		box(node,Vector3(0,0.58,0),Vector3(0.08,1.10,0.08),palette["bronze"])
		box(node,Vector3(0,1.15,0),Vector3(0.32,0.18,0.28),Color("#b17c55"),true)
	else:
		box(node,Vector3(0,0.42,0),
			Vector3(maxf(0.48,1.05*scale_value),0.78,maxf(0.30,0.62*scale_value)),
			palette["wood"])

func _proxy_authored_procedural(parent: Node3D, item: Dictionary) -> void:
	var id:String=str(item.get("id","visual_procedural"))
	var node:=furniture_object(parent,id)
	var width:float=maxf(0.35,float(item.get("width",1.0)))
	var depth:float=maxf(0.25,float(item.get("depth",0.6)))
	var height:float=maxf(0.06,float(item.get("height",0.72)))
	var x:float=float(item.get("x",0.0))
	var z:float=float(item.get("z",-1.0))
	node.position=Vector3(x,0.0,z)
	var kind:String=str(item.get("type",""))
	if kind.contains("rest_pad"):
		box(node,Vector3(0,height*0.5,0),Vector3(width,height,depth),palette["rug"])
	else:
		box(node,Vector3(0,height*0.5,0),Vector3(width,height,depth),palette["wood"])

func _populate_physical_fallback(parent: Node3D, group: Dictionary) -> bool:
	var kind:String=str(group["type"])
	var width:int=int(group["width"])
	if not room_visual_layout.has_variant(kind,width):
		return false
	for raw in room_visual_layout.objects(kind,width):
		if typeof(raw)!=TYPE_DICTIONARY:
			continue
		var item:Dictionary=raw
		# Back-decor without collision belongs to the rear visual plane; the
		# fallback geometry is reserved for tangible mid/front-depth objects.
		if bool(item.get("collision",false)):
			_proxy_authored_object(parent,item)
	for raw in room_visual_layout.procedural(kind,width):
		if typeof(raw)==TYPE_DICTIONARY:
			_proxy_authored_procedural(parent,raw)
	return true

func _populate_furniture(group_node: Node3D) -> void:
	var group:Dictionary=visual_room_groups.get(group_node.name,{})
	if group.is_empty() or _group_facade_only(group):
		return
	var decoration_layer:Node3D=group_node.get_node_or_null("LocalFurniture")
	if decoration_layer==null or detailed_room_groups.has(group_node.name):
		return
	var physical_room:Dictionary=world.room_by_id(str(group.get("primary_id","")))
	if physical_room.is_empty():
		return
	var root:=Node3D.new()
	root.name="PhysicalFurniture"
	decoration_layer.add_child(root)
	if bool(group.get("replaces_furniture",false)):
		# The visual furniture lives in the authored image layer. Keep only
		# stable, invisible data anchors in one physical room root.
		var seen:Dictionary={}
		for spot in life.stations.layout_for_world(world,physical_room):
			var name:String=str(spot.get("furniture_id",""))
			if name=="" or seen.has(name):
				continue
			var anchor:=furniture_object(root,name)
			var offset:Vector2=spot.get("offset",Vector2.ZERO)
			anchor.position=Vector3(offset.x,0.0,offset.y)
			seen[name]=true
		if bool(group.get("teea008_review",false)):
			var review:=Node3D.new()
			review.name="TEEA008CandidateFurniture"
			review.set_meta("room_id",str(physical_room["id"]))
			root.add_child(review)
			var count:int=teea008_review.populate(review,str(group["art_type"]),int(group["width"]),Callable(self,"depth_visual_scale"))
			if count==0:
				push_error("TEEA008 candidate layout did not materialize")
		elif bool(group.get("native_decor",false)):
			var decor:=Node3D.new()
			decor.name="OwnerDecorBank"
			root.add_child(decor)
			var count:int=owner_decor_bank.populate(decor,str(group["type"]),int(group["width"]),
				life.stations.layout_for_world(world,physical_room),Callable(self,"depth_visual_scale"))
			if count==0:
				push_error("Owner decor did not materialize: "+str(group["type"]))
	else:
		var used_authored:bool=_populate_physical_fallback(root,group)
		if not used_authored:
			# R1 legacy rooms without a pinned wide layout remain one coherent
			# furniture composition, never one composition per virtual module.
			furnish(root,str(group["type"]),int(group["x_start"]),int(group["level"]))
			_ensure_fallback_anchor_furniture(
				root,life.stations.layout_for_world(world,physical_room))
	if bool(group.get("teea008_review",false)):
		# Retain the current Common hearth, without duplicate legacy rugs/sconces.
		if str(group["type"])=="common":
			var dressing:=_named_dressing(decoration_layer,"PhysicalDressing")
			_add_authored_room_atmosphere(dressing,"common",float(group["width"])*W,true)
			var rug:Node3D=dressing.get_node_or_null("Dressing_Rug")
			if rug!=null:
				rug.free()
			if teea008_review.sketchfab_common_enabled and int(group["width"])==3:
				var old_hearth:Node3D=dressing.get_node_or_null("Dressing_Fireplace")
				if old_hearth!=null:
					old_hearth.free()
				if architecture_review:
					_add_warm_room_light(dressing,Vector3(-4.65,1.85,-0.35),0.24)
					_add_warm_room_light(dressing,Vector3(5.55,1.55,-0.75),0.30)
	else:
		_add_physical_room_dressing(decoration_layer,group)
	detailed_room_groups[group_node.name]=true
	detail_materialization_count+=1

func _release_furniture(group_node: Node3D) -> void:
	if not detailed_room_groups.has(group_node.name):
		return
	var decoration_layer: Node3D = group_node.get_node_or_null("LocalFurniture")
	if decoration_layer:
		_clear_children_now(decoration_layer)
	detailed_room_groups.erase(group_node.name)
	detail_eviction_count += 1

func make_room(group: Dictionary) -> void:
	# One shell per logical R1/R2/R3 merge group, not N adjacent full-walled rooms.
	# Individual module IDs remain in the World Core so residents keep legal routes.
	var n := Node3D.new()
	n.name = group["primary_id"]
	var level: int = int(group["level"])
	var x_start: int = int(group["x_start"])
	var x_end: int = int(group["x_end"])
	var center_cell: float = (float(x_start)+float(x_end))*0.5
	var span: float = float(group["width"])*W
	n.position = Vector3(center_cell*W,float(level)*H,0.0)
	room_root.add_child(n)
	visual_room_groups[n.name] = group
	var t: String = group["type"]
	var facade_only := _group_facade_only(group)
	n.set_meta("facade_only",facade_only)
	if architecture_review and t=="guest":canonical_guest_nodes[str(n.name)]=n
	var art_type := _review_room_art_type(group)
	visual_room_groups[n.name]["art_type"] = art_type
	var accepted: Array=interior_skin.validated_layers(art_type,int(group["width"]))
	visual_room_groups[n.name]["has_art"] = not facade_only and not accepted.is_empty()
	var has_authored_furniture:bool=accepted.any(
		func(item): return str(item.get("role","")) == "furniture_back")
	# The owner explicitly replaced Artifact pedestals and Workshop workbenches
	# with real shelves/cabinets/tables. Preserve accepted Common/Cinema art.
	var native_decor:bool=not facade_only and owner_decor_bank.ready_for(t) and (
		t in ["artifact","workshop"] or not has_authored_furniture)
	var teea008_variant:bool=not facade_only and iter1_owner_review and not teea008_review.variant(art_type,int(group["width"])).is_empty()
	visual_room_groups[n.name]["teea008_review"]=teea008_variant
	native_decor=native_decor or teea008_variant
	visual_room_groups[n.name]["native_decor"]=native_decor
	visual_room_groups[n.name]["has_decor_art"]=not native_decor and accepted.any(
		func(item): return str(item.get("role","")) == "back_decor")
	visual_room_groups[n.name]["replaces_furniture"]=has_authored_furniture or native_decor or t in ["common","cinema","artifact","workshop"]
	var side_left: Dictionary = world.get_room(x_start-1,level)
	var side_right: Dictionary = world.get_room(x_end+1,level)
	# Render hierarchy is spatial, not a single baked background image.
	var background := Node3D.new()
	background.name = "Layer_Background"
	n.add_child(background)
	var structure := Node3D.new()
	structure.name = "Layer_Structure"
	n.add_child(structure)
	var overlay := Node3D.new()
	overlay.name = "Layer_Foreground"
	n.add_child(overlay)
	var artwork := Node3D.new()
	artwork.name = "Layer_ApprovedArt"
	n.add_child(artwork)
	# Back wall at -Z, gameplay and furniture in the middle, low foreground at +Z.
	# Structural slabs are deliberately thin: they frame the cutaway instead of
	# competing with the room artwork at close zoom.
	var floor_slab:=box(structure,Vector3(0,-0.040,-0.15),
		Vector3(span*1.01,0.055,3.60),palette["floor"])
	floor_slab.name="CutawayFloorSlab"
	if not facade_only:
		var cutaway_depth:=Node3D.new()
		cutaway_depth.name="Stage_CutawayDepth"
		structure.add_child(cutaway_depth)
		add_cutaway_depth(cutaway_depth,group)
	var rear_backup:=box(background,Vector3(0,1.45,-2.14),
		Vector3(span*1.01,3.25,0.16),palette["rock"])
	rear_backup.name="StructuralRearBackup"
	if not facade_only:
		var rear_stage := Node3D.new()
		rear_stage.name = "Stage_Backwall"
		background.add_child(rear_stage)
		add_backwall_stage(rear_stage,group)
	var ceiling_slab:=box(structure,Vector3(0,3.055,-0.62),
		Vector3(span*1.01,0.09,2.72),palette["border"])
	ceiling_slab.name="CutawayCeilingSlab"
	if not facade_only and t not in ["cinema","lift"]:
		var beams:=Node3D.new()
		beams.name="CeilingDepthBeams"
		structure.add_child(beams)
		var beam_i:=0
		for beam_z in [-1.48,-0.62,0.24]:
			var beam:=box(beams,Vector3(0,2.91,float(beam_z)),
				Vector3(maxf(0.6,span-0.38),0.12,0.15),palette["wood"])
			beam.name="DepthBeam_%d" % beam_i
			beam_i+=1
	var front_lip:=box(overlay,Vector3(0,-0.070,1.39),
		Vector3(span*1.01,0.04,0.075),palette["border"])
	front_lip.name="CutawayFrontLip"
	# Expensive full-resolution artwork is loaded on demand by
	# update_render_lod(), not permanently allocated for all 49+ rooms.
	var physical_room:Dictionary=world.room_by_id(str(group.get("primary_id","")))
	for side in [-1,1]:
		var neighbour:Dictionary=side_left if side==-1 else side_right
		var edge:float=float(side)*(span*0.5-0.10)
		var connected:bool=not physical_room.is_empty() and not neighbour.is_empty() and (
			not world.connection_between(physical_room,neighbour).is_empty())
		if not connected:
			box(structure,Vector3(edge,1.42,-0.42),
				Vector3(0.16,2.75,3.08),palette["rock"])
			box(overlay,Vector3(edge,0.18,1.31),
				Vector3(0.16,0.34,0.14),palette["rock"])
		else:
			# The explicit connector occupies the front aisle. Keep a solid
			# rear-side return so the room still reads as a cutaway volume,
			# while z≈1.5 remains fully traversable between rooms.
			var rear_return:=box(structure,Vector3(edge,1.40,-0.58),
				Vector3(0.14,2.68,2.18),palette["rock"])
			rear_return.name="ConnectorRearReturn_%s" % ("L" if side<0 else "R")
			var header:=box(structure,Vector3(edge,2.84,0.73),
				Vector3(0.16,0.34,0.92),palette["rock_light"])
			header.name="ConnectorHeader_%s" % ("L" if side<0 else "R")
			var rear_jamb:=box(structure,Vector3(edge,0.48,-1.82),
				Vector3(0.18,0.96,0.16),palette["rock_light"])
			rear_jamb.name="ConnectorRearJamb_%s" % ("L" if side<0 else "R")
	# Physical R2/R3 rooms deliberately have no internal module ribs.
	if not facade_only:
		var overview := Node3D.new()
		overview.name = "Layer_OverviewCues"
		n.add_child(overview)
		if architecture_review and teea008_variant:
			var overview_count:int=teea008_review.populate_overview(overview,art_type,int(group["width"]),Callable(self,"depth_visual_scale"))
			overview.set_meta("real_model_count",overview_count)
			if overview_count==0:
				add_room_overview_cues(overview,group)
			elif OS.get_environment("DRAGON_QA_DISABLE_OVERVIEW_BATCH")!="1":
				StaticOverviewBatch.new().batch(overview)
		else:
			add_room_overview_cues(overview,group)
	if facade_only:
		# Private/closed-guest interiors are facade-only; no hidden room is materialized.
		# Solid facade sits behind the independent front transit lane (z >= 1.35).
		# No private interior geometry or stations are materialized.
		var facade:=box(n,Vector3(0,1.50,0.99),Vector3(span-0.08,3.0,0.18),palette["rock"])
		facade.name="PrivateFacadeWall"
		var door:=box(n,Vector3(0,1.4,1.105),Vector3(2.08,2.8,0.16),palette["wood"])
		door.name="FacadeDoor"
		box(n,Vector3(0.82,1.33,1.2),Vector3(0.12,0.12,0.07),palette["bronze"])
		var private_room:Dictionary=group["cells"][0]
		var owner_id:String=str(private_room.get("owner_id",""))
		var sign:String=str(private_room.get("display_name","Гостевая")) if t=="guest" else \
			door_registry.sign_text(owner_id,world.read_resident_profiles())
		if architecture_review and t=="private" and owner_id=="":
			sign="Резерв"
		var door_label := label3(n,sign,Vector3(0,3.34,1.0),24,Color("#d4bdb0"))
		door_label.name = "RoomRoofLabel"
		if t=="private" and owner_id!="":
			# The name and paper belong on the wall beside the door, not on its leaf.
			var sign_x:float=-(span*0.5+1.04)*0.5
			var sign_width:float=minf(1.18,span*0.5-1.12)
			var plaque:=box(n,Vector3(sign_x,2.25,1.115),Vector3(sign_width,0.34,0.055),palette["wood"])
			plaque.name="DoorNamePlaque"
			var wall_label:=label3(n,sign,Vector3(sign_x,2.25,1.155),24,Color("#eadfc8"))
			wall_label.name="DoorWallName"
			wall_label.billboard=BaseMaterial3D.BILLBOARD_DISABLED
			wall_label.pixel_size=minf(0.0037,sign_width/(24.0*maxf(1.0,float(sign.length())*0.65)))
			# Every assigned room has a sheet; missing notes stay genuinely blank.
			var frame:=box(n,Vector3(sign_x,1.67,1.115),Vector3(0.52,0.70,0.055),palette["bronze"])
			frame.name="DoorNoteFrame"
			var paper:=box(n,Vector3(sign_x,1.67,1.15),Vector3(0.39,0.55,0.020),Color("#eadfc8"),true)
			paper.name="DoorNotePaper"
			var note_anchor:=Node3D.new()
			note_anchor.name="DoorPublicNoteAnchor"
			note_anchor.position=Vector3(sign_x,1.67,1.17)
			n.add_child(note_anchor)
			door_note_anchors[str(private_room["id"])]=note_anchor
	else:
		var decoration_layer := Node3D.new()
		decoration_layer.name = "LocalFurniture"
		n.add_child(decoration_layer)
		var title: String = room_names.get(t,t)
		var titled_room:Dictionary=world.room_by_id(str(group["primary_id"]))
		if architecture_review and str(titled_room.get("display_name",""))!="":
			title=str(titled_room["display_name"])
		if int(group["width"]) > 1:
			title += " · %d" % int(group["width"])
		var roof_label := label3(n,title,Vector3(0,3.35,0.40),24,Color("#f4d9b9"))
		roof_label.name = "RoomRoofLabel"

func _batch_static_shell_boxes(parent:Node3D)->int:
	if parent==null:return 0
	var groups:Dictionary={}
	for child in parent.get_children():
		if not child is MeshInstance3D:continue
		var mesh_node:MeshInstance3D=child
		if not mesh_node.mesh is BoxMesh or mesh_node.is_in_group("low_end_micro_detail") or not mesh_node.visible:continue
		if mesh_node.material_override==null:continue
		var key:String=str(mesh_node.mesh.get_instance_id())+":"+str(mesh_node.material_override.get_instance_id())
		if not groups.has(key):groups[key]=[]
		groups[key].append(mesh_node)
	var saved:=0
	for items in groups.values():
		if items.size()<2:continue
		var first:MeshInstance3D=items[0]
		var batch:=MultiMesh.new()
		batch.transform_format=MultiMesh.TRANSFORM_3D
		batch.mesh=first.mesh
		batch.instance_count=items.size()
		for i in range(items.size()):
			batch.set_instance_transform(i,items[i].transform)
			items[i].visible=false
		var node:=MultiMeshInstance3D.new()
		node.name="StaticShellBatch_%d"%parent.get_child_count()
		node.multimesh=batch
		node.material_override=first.material_override
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
		saved+=items.size()-1
	return saved

func make_rooms() -> void:
	art_layer_count = 0
	detailed_room_groups.clear()
	art_loaded_groups.clear()
	visual_room_groups.clear()
	canonical_guest_nodes.clear()
	door_note_anchors.clear()
	_clear_children_now(room_root)
	for group in world.visual_groups():
		make_room(group)
	if architecture_review:
		var saved:=0
		for group_node in room_root.get_children():
			# Rear returns are used by the occlusion controller; do not batch
			# those mutable nodes. Only immutable repeated ceiling beams.
			var beams:Node3D=group_node.get_node_or_null("Layer_Structure/CeilingDepthBeams")
			saved+=_batch_static_shell_boxes(beams)
		world.runtime_state["canonical_shell_draws_saved"]=saved

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

func depth_visual_scale(z: float) -> float:
	return world.room_space.perspective_scale(z)

func depth_visual_x(room_id: String, physical_x: float, z: float) -> float:
	var room:Dictionary=world.room_by_id(room_id)
	if room.is_empty():
		return physical_x
	var center_x:float=world.room_center_pos(room).x
	var scale_value:float=depth_visual_scale(z)
	return center_x+(physical_x-center_x)*scale_value

func make_creatures() -> void:
	if creature_root == null:
		return
	for child in creature_root.get_children():
		child.queue_free()
	creature_nodes.clear()
	creature_labels.clear()
	var placeholder := make_sprite_texture(true)
	creature_animations.clear()
	for creature_id in world.creatures:
		var creature: Dictionary = world.creatures[creature_id]
		if not bool(creature.get("active",false)):
			continue
		var anchor := Node3D.new()
		anchor.name = str(creature_id)
		creature_root.add_child(anchor)
		var sprite := Sprite3D.new()
		sprite.name = "Body"
		var bank_id := str(creature.get("bank_id",""))
		var bank_texture: Texture2D = null
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		if bank_id != "" and asset_banks.candidate_creature_bank(bank_id):
			bank_texture = asset_banks.creature_texture(bank_id,"IDLE_RIGHT",0)
		sprite.texture = bank_texture if bank_texture != null else placeholder
		if bank_texture != null:
			sprite.pixel_size = _creature_canvas_width(bank_id) / maxf(1.0,float(bank_texture.get_width()))
			sprite.position.y = float(bank_texture.get_height()) * 0.43 * sprite.pixel_size
			sprite.set_meta("candidate_bank",bank_id)
			creature_animations[str(creature_id)] = {"state":"IDLE_RIGHT","frame":0,"elapsed":0.0}
		else:
			sprite.pixel_size = 0.0055
			sprite.position.y = 0.38
		anchor.add_child(sprite)
		var label := label3(anchor,world.creature_display_label(str(creature_id)),
			Vector3(0,0.92,0.15),21,Color("#ead8bf"))
		label.visible = false
		creature_nodes[str(creature_id)] = anchor
		creature_labels[str(creature_id)] = label
	update_creatures()

func _creature_hover_height(bank_id:String,clock:float)->float:
	# The magical sphere alone floats; all ordinary animals remain grounded.
	return 0.95+0.10*sin(clock*2.0) if bank_id=="npc_ai_magic_sphere" else 0.0

func update_creatures(delta: float = 0.0) -> void:
	creature_hover_clock=fposmod(creature_hover_clock+maxf(0.0,delta),TAU)
	var active_count := 0
	for creature_id in world.creatures:
		if bool(world.creatures[creature_id].get("active",false)):
			active_count += 1
	if active_count != creature_nodes.size():
		make_creatures()
		return
	for creature_id in creature_nodes:
		var creature: Dictionary = world.creatures.get(creature_id,{})
		var anchor: Node3D = creature_nodes[creature_id]
		if creature.is_empty() or not bool(creature.get("active",false)):
			anchor.visible = false
			continue
		anchor.visible = semantic_view.actor_visible(creature) and world.public_cutaway_allowed(world.room_by_id(str(creature.get("room_id",""))))
		if not anchor.visible:
			continue
		var y := float(creature.get("visual_y",
			float(creature.get("level",0))*H))
		var creature_z: float = float(creature.get("z",0.25))
		var creature_x:float=depth_visual_x(
			str(creature.get("room_id","")),float(creature.get("x",0.0)),creature_z)
		var bank_id := str(creature.get("bank_id",""))
		anchor.position = Vector3(creature_x,y+_creature_hover_height(bank_id,creature_hover_clock),creature_z)
		var creature_scale:=depth_visual_scale(creature_z)
		anchor.scale=Vector3.ONE*creature_scale
		var body: Sprite3D = anchor.get_node_or_null("Body")
		if body != null and bank_id != "" and body.has_meta("candidate_bank"):
			var moving_left := str(creature.get("moving_axis","right")) == "left"
			var state := ("WALK_LEFT" if moving_left else "WALK_RIGHT") if (
				str(creature.get("phase","idle")) == "travel") else (
				"IDLE_LEFT" if moving_left else "IDLE_RIGHT")
			# No floor-walking cycle for a floating entity. Use directional idle
			# art while its horizontal travel remains owned by simulation.
			if bank_id=="npc_ai_magic_sphere":
				state="IDLE_LEFT" if moving_left else "IDLE_RIGHT"
				if asset_banks.creature_frame_count(bank_id,state)==0:
					state="IDLE_RIGHT"
			var anim: Dictionary = creature_animations.get(creature_id,
				{"state":state,"frame":0,"elapsed":0.0})
			if str(anim.get("state","")) != state:
				anim = {"state":state,"frame":0,"elapsed":0.0}
			else:
				anim["elapsed"] = float(anim.get("elapsed",0.0)) + delta
			var frame_count := asset_banks.creature_frame_count(bank_id,state)
			var frame_time := 1.0 / asset_banks.creature_fps(bank_id,state)
			if frame_count > 0 and float(anim["elapsed"]) >= frame_time:
				anim["frame"] = (int(anim.get("frame",0)) + 1) % frame_count
				anim["elapsed"] = 0.0
			var tex := asset_banks.creature_texture(bank_id,state,int(anim.get("frame",0)))
			if tex != null:
				body.texture = tex
			creature_animations[creature_id] = anim
		var label: Label3D = creature_labels.get(creature_id)
		if label != null:
			label.text = world.creature_display_label(creature_id)
			var owner_id := str(creature.get("owner_id",""))
			# Owner labels are evidence-driven and shown only close enough to read.
			label.visible = owner_id != "" and zoom_current < 26.0

func _object_offset(object_id: String) -> Vector3:
	var code := 0
	for i in range(object_id.length()):
		code = (code * 33 + object_id.unicode_at(i)) & 0x7fffffff
	var ox := (float(code % 7) - 3.0) * 0.16
	var oz := (float(int(code / 7) % 5) - 2.0) * 0.12
	return Vector3(ox,0.0,oz)

func _make_artifact_cube(anchor:Node3D,texture:Texture2D)->bool:
	# The physical artifact IS a glass cube, not a loose picture next to a cube.
	# Measured source model: 0.20 m, floor pivot. Uniformly fit shelf clearance.
	var model:PackedScene=ResourceLoader.load(ARTIFACT_CUBE_MODEL,"PackedScene") as PackedScene
	if model==null:return false
	var glass:Node3D=Node3D.new()
	glass.name="ArtifactGlassCube"
	glass.scale=Vector3.ONE*(ARTIFACT_CUBE_SIDE/0.20)
	glass.add_child(model.instantiate())
	anchor.add_child(glass)
	anchor.set_meta("artifact_cube_side",ARTIFACT_CUBE_SIDE)
	if texture!=null:
		var face:=Sprite3D.new()
		face.name="Visual"
		face.texture=texture
		face.billboard=BaseMaterial3D.BILLBOARD_DISABLED
		face.pixel_size=ARTIFACT_CUBE_SIDE*0.80/maxf(float(texture.get_width()),float(texture.get_height()))
		face.position=Vector3(0,ARTIFACT_CUBE_SIDE*0.5,ARTIFACT_CUBE_SIDE*0.5+0.002)
		face.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
		face.no_depth_test=false
		anchor.add_child(face)
	return true

func _artifact_cube_hotspot(point:Vector2)->Dictionary:
	if camera==null:return {}
	var ray_origin:Vector3=camera.project_ray_origin(point)
	var ray_direction:Vector3=camera.project_ray_normal(point)
	var nearest:float=INF
	var found:Dictionary={}
	for entry in content_hotspots:
		var anchor:Node3D=entry.get("anchor")
		if not is_instance_valid(anchor) or not anchor.is_visible_in_tree() or not anchor.has_meta("artifact_cube_side"):
			continue
		var side:float=float(anchor.get_meta("artifact_cube_side"))
		var inverse:Transform3D=anchor.global_transform.affine_inverse()
		var bounds:=AABB(Vector3(-side*0.5,0,-side*0.5),Vector3.ONE*side)
		var hit:Variant=bounds.intersects_ray(inverse*ray_origin,inverse.basis*ray_direction)
		if hit==null:continue
		var distance:float=ray_origin.distance_squared_to(anchor.to_global(hit))
		if distance<nearest:
			nearest=distance
			found=entry
	return found

func make_physical_objects() -> void:
	if object_root == null:
		return
	for child in object_root.get_children():
		child.queue_free()
	object_nodes.clear()
	clear_content_hotspots()
	for object_id in world.objects:
		var object: Dictionary = world.objects[object_id]
		var anchor := Node3D.new()
		anchor.name = "Object_" + str(object_id)
		object_root.add_child(anchor)
		var asset_id := str(object.get("asset_id",""))
		if teea008_live and asset_id in ["candidate_dragon_mug_red","candidate_guest_mug_blue"]:
			var model:PackedScene=ResourceLoader.load(teea008_review.ROOT+asset_id+"/model.gltf","PackedScene") as PackedScene
			if model!=null:
				anchor.add_child(model.instantiate())
				if architecture_review:
					var content_label:=label3(anchor,"",Vector3(0,0.23,0.04),18,Color("#f3dfb7"))
					content_label.name="BeverageContent"
					content_label.visible=false
				object_nodes[str(object_id)]=anchor
				register_content_hotspot(anchor,"cups",str(object_id),str(object.get("display_name",object_id)))
				continue
		var texture: Texture2D = asset_banks.prop_display_texture(asset_id) if asset_id != "" else null
		if texture==null and content_viewer!=null:
			texture=content_viewer._load_preview(str(object.get("preview_path","")))
		if architecture_review and str(object.get("viewer_category",""))=="artifacts" and str(object.get("display_mode",""))!="wall":
			if _make_artifact_cube(anchor,texture):
				object_nodes[str(object_id)]=anchor
				register_content_hotspot(anchor,"artifacts",str(object_id),str(object.get("display_name",object_id)))
				continue
		if texture != null:
			var sprite := Sprite3D.new()
			sprite.name = "Visual"
			sprite.texture = texture
			var wall_display:bool=str(object.get("display_mode",""))=="wall"
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED if wall_display else BaseMaterial3D.BILLBOARD_FIXED_Y
			var visual_height:float=float(object.get("display_world_height",0.48))
			sprite.pixel_size = visual_height / maxf(1.0,float(texture.get_height()))
			sprite.position.y = 0.0 if wall_display else 0.28
			if teea008_live and str(object.get("viewer_category",""))=="cups":
				sprite.position.y=visual_height*0.5
			if wall_display:
				# A wall display is a physical mounted object, not a floating
				# transparent PNG. Build its frame from the actual texture
				# aspect ratio so every canonical master remains readable.
				var world_width:float=visual_height*float(texture.get_width())/maxf(
					1.0,float(texture.get_height()))
				var frame:=Node3D.new()
				frame.name="WallFrame"
				anchor.add_child(frame)
				var pad:float=0.075
				var rail:float=0.055
				var backing:=box(frame,Vector3(0,0,-0.022),
					Vector3(world_width+pad*2.0,visual_height+pad*2.0,0.028),
					Color("#241c19"))
				backing.name="Backing"
				for sx in [-1.0,1.0]:
					var side:=box(frame,
						Vector3(float(sx)*(world_width*0.5+pad*0.55),0,0.012),
						Vector3(rail,visual_height+pad*2.0,0.045),palette["wood"])
					side.name="FrameSide_%s" % ("L" if sx<0 else "R")
				for sy in [-1.0,1.0]:
					var edge:=box(frame,
						Vector3(0,float(sy)*(visual_height*0.5+pad*0.55),0.012),
						Vector3(world_width+pad*2.0,rail,0.045),palette["wood"])
					edge.name="FrameEdge_%s" % ("B" if sy<0 else "T")
			anchor.add_child(sprite)
		else:
			var marker := box(anchor,Vector3(0,0.12,0),Vector3(0.22,0.22,0.22),palette["bronze"])
			marker.name = "VisualFallback"
		object_nodes[str(object_id)] = anchor
		register_content_hotspot(anchor,
			str(object.get("viewer_category","artifacts")),str(object_id),
			str(object.get("display_name",object_id)))
	update_physical_objects()

func update_physical_objects() -> void:
	for object_id in object_nodes:
		if str(object_id)==object_home_drag_id:
			continue
		var anchor: Node3D = object_nodes[object_id]
		var object: Dictionary = world.physical_object(str(object_id))
		if object.is_empty():
			anchor.visible = false
			continue
		if architecture_review:
			var beverage_label:Label3D=anchor.get_node_or_null("BeverageContent")
			if beverage_label!=null:
				var content:Dictionary=life.candidate_cups.beverages.content(str(object_id))
				var title:String=str(content.get("display_name",""))
				if beverage_label.text!=title:beverage_label.text=title
				beverage_label.visible=float(content.get("remaining_ml",0))>0
		var holder_id := str(object.get("current_holder_id",""))
		if holder_id != "":
			var holder: Dictionary = world._physical_actor(holder_id)
			if holder.is_empty():
				anchor.visible = false
				continue
			anchor.visible = semantic_view.actor_visible(holder) and world.public_cutaway_allowed(world.room_by_id(str(holder.get("room_id",""))))
			if not anchor.visible:
				continue
			var holder_z:float=float(holder.get("z",0.25))
			var holder_x:float=depth_visual_x(
				str(holder.get("room_id","")),float(holder.get("x",0.0)),holder_z)
			anchor.position = Vector3(
				holder_x,
				float(holder.get("visual_y",float(holder.get("level",0))*H))+0.78,
				holder_z+0.18) + _object_offset(str(object_id))*0.25
			var held_scale: float = depth_visual_scale(holder_z)
			anchor.scale=Vector3.ONE*held_scale
			if teea008_live and str(object.get("viewer_category",""))=="cups":
				# Actual cup mesh, not the unrelated cup baked into DRINK art.
				anchor.rotation=Vector3.ZERO
				anchor.position=Vector3(holder_x+0.24*held_scale,float(holder.get("visual_y",0.0))+0.92*held_scale,holder_z+0.16)
				anchor.set_meta("hand_contact_status","UNCALIBRATED_MOVING_OR_NONMODEL")
				_place_cup_at_verified_hand(anchor,holder)
			continue
		if str(object.get("state","")) == "STASHED":
			# Hidden means hidden: the canonical location remains in world state,
			# but the normal renderer and hover hit-test expose no visible copy.
			anchor.visible = false
			continue
		if teea008_live and str(object.get("viewer_category",""))=="cups":
			anchor.rotation=Vector3.ZERO
			anchor.set_meta("hand_contact_status","NOT_HELD")
		var room_id := str(object.get("current_room_id",""))
		var room: Dictionary = world.room_by_id(room_id)
		if not world.public_cutaway_allowed(room):
			anchor.visible = false
			continue
		anchor.visible = semantic_view.group_visible(room)
		if not anchor.visible:
			continue
		var room_center:Vector3=world.room_center_pos(room)
		var home_anchor=object.get("display_anchor",object.get("home_anchor",[]))
		if str(object.get("display_mode",""))=="wall" and (
				typeof(home_anchor)==TYPE_ARRAY and home_anchor.size()>=3):
			var local_x:float=float(home_anchor[0])
			var local_y:float=float(home_anchor[1])
			var local_z:float=float(home_anchor[2])
			if teea008_review.enabled and bool(visual_room_groups.get(room_id,{}).get("teea008_review",false)):
				# Canonical wall lane remains compatible with v0.22 events.
				# Map it onto the measured rear wall plane for this renderer.
				local_z=-1.98
			var physical_x:float=room_center.x+local_x
			anchor.position=Vector3(
				depth_visual_x(room_id,physical_x,local_z),
				room_center.y+local_y,local_z)
			anchor.scale=Vector3.ONE*depth_visual_scale(local_z)
		else:
			var raw_anchor=object.get("current_anchor",[])
			var local_anchor:Vector2
			if typeof(raw_anchor)==TYPE_ARRAY and (raw_anchor as Array).size()==2:
				local_anchor=Vector2(float(raw_anchor[0]),float(raw_anchor[1]))
			else:
				var fallback:Vector3=_object_offset(str(object_id))
				local_anchor=Vector2(fallback.x,0.72+fallback.z)
			var cube:bool=anchor.has_meta("artifact_cube_side")
			if str(object.get("viewer_category",""))=="artifacts" and not cube:
				var plain_sprite:Sprite3D=anchor.get_node_or_null("Visual")
				if plain_sprite!=null:plain_sprite.position.y=0.28
			var room_world:Vector3=world.room_local_to_world(room,local_anchor)
			anchor.position=Vector3(depth_visual_x(room_id,room_world.x,local_anchor.y),room_world.y+(0.0 if cube else 0.22),room_world.z)
			anchor.scale=Vector3.ONE*depth_visual_scale(local_anchor.y)
			if teea008_live and str(object.get("viewer_category",""))=="artifacts" and str(object.get("current_support_id",""))!="":
				var support:Dictionary=life.candidate_navigation.artifact_support(room,str(object.get("current_support_id","")))
				if not support.is_empty():
					if not detailed_room_groups.has(room_id):
						anchor.visible=false
						continue
					var pos:Array=support["xyz"]
					var inst:Array=support["instance_xyz"]
					var scale_value:float=depth_visual_scale(float(inst[2]))
					anchor.position=Vector3(room_center.x+float(pos[0])*scale_value,room_center.y+float(inst[1])+(float(pos[1])-float(inst[1]))*scale_value,float(inst[2])+(float(pos[2])-float(inst[2]))*scale_value)
					anchor.scale=Vector3.ONE*scale_value
					var sprite:Sprite3D=anchor.get_node_or_null("Visual")
					if sprite!=null and not cube:
						sprite.position.y=float(object.get("display_world_height",0.48))*0.5
			if teea008_live and str(object.get("viewer_category",""))=="cups":
				var slot:Dictionary=life.candidate_cups.slot_for_object(object)
				if not slot.is_empty():
					var pos:Array=slot["xyz"]
					var inst:Array=slot["instance_xyz"]
					var scale_value:float=depth_visual_scale(float(inst[2]))
					anchor.position=Vector3(room_center.x+float(pos[0])*scale_value,room_center.y+float(inst[1])+(float(pos[1])-float(inst[1]))*scale_value,float(inst[2])+(float(pos[2])-float(inst[2]))*scale_value)
					anchor.scale=Vector3.ONE*scale_value

func make_residents() -> void:
	var resident_tex := make_sprite_texture(false)
	var manka_tex := make_sprite_texture(true)
	for child in actor_root.get_children():
		child.queue_free()
	actor_sprites.clear()
	actor_labels.clear()
	actor_animations.clear()
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
		# Binary alpha depth avoids transparent-quad sorting cutting actors.
		if architecture_review:
			sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.alpha_scissor_threshold=0.12
		actor["runtime_visual_bound"] = false
		if id == "MANJKA" and qa_visual_preview:
			var sprite_manka: Texture2D = asset_banks.manka_texture("IDLE_RIGHT",0)
			if sprite_manka != null:
				sprite.texture = sprite_manka
				sprite.pixel_size = 1.55/maxf(1.0,float(sprite_manka.get_height()))
				sprite.position.y = 0.77
				actor["runtime_visual_bound"] = true
				actor["visual_preview_only"] = true
				actor_animations[id] = {"state":"IDLE_RIGHT","frame":0,"elapsed":0.0}
		if id != "MANJKA":
			var profile_id: String = str(actor.get("appearance_profile",""))
			var candidate_guest: bool = str(actor.get("entity_type","")) == "guest" and \
				str(actor.get("visual_status","")) == "CANDIDATE" and \
				str(actor.get("bank_id","")) == id
			var chosen_wardrobe: String = asset_banks.preferred_wardrobe(
				id,profile_id,qa_visual_preview or candidate_guest)
			if chosen_wardrobe != "":
				var approved_idle: Texture2D = asset_banks.texture_for(id,chosen_wardrobe,"IDLE_S",0)
				if approved_idle != null:
					sprite.texture = approved_idle
					sprite.pixel_size = 1.9 / maxf(1.0,float(approved_idle.get_height()))
					sprite.position.y = maxf(0.15,
						(asset_banks.feet_anchor(id,chosen_wardrobe,approved_idle.get_height())
						 - float(approved_idle.get_height())*0.5)*sprite.pixel_size)
					actor["runtime_visual_bound"] = true
					actor["visual_wardrobe"] = chosen_wardrobe
					actor["visual_preview_only"] = not asset_banks.verified_bank(id,profile_id,chosen_wardrobe)
					actor_animations[id] = {"state":"IDLE_S","frame":0,"elapsed":0.0}

		if not actor["runtime_visual_bound"]:
			sprite.position = Vector3(0, 0.83 if id == "MANJKA" else 1.05, 0)
		if id != "MANJKA" and not actor["runtime_visual_bound"]:
			var colors = [Color("#bfa4c1"), Color("#dca39e"), Color("#a3aeb3"), Color("#d4b78a"),
				Color("#c6c0c4"), Color("#9b9fbf"), Color("#bc9e97"), Color("#9ab4a9")]
			sprite.modulate = colors[n % colors.size()]
		anchor.add_child(sprite)
		actor_sprites[id] = anchor
		var lbl := label3(anchor, actor["name"], Vector3(0, 2.0, 0.2), 27, Color("#f1ddd0"))
		actor_labels[id] = lbl
		n += 1
	update_residents()

func update_residents(delta: float = 0.0) -> void:
	for id in actor_sprites:
		# Review captures may reseed/reset the world while old visual anchors are
		# still alive for one frame. Stale visuals must never crash the renderer.
		if not world.residents.has(id):
			actor_sprites[id].visible=false
			if actor_labels.has(id):
				actor_labels[id].visible=false
			continue
		var actor: Dictionary = world.residents[id]
		var y: float = float(actor.get("visual_y", float(actor.get("level", 0)) * H))
		var actor_z: float = float(actor.get("z",0.3))
		var actor_x:float=depth_visual_x(
			str(actor.get("room_id","")),float(actor.get("x",0.0)),actor_z)
		actor_sprites[id].position = Vector3(actor_x,y,actor_z)
		var actor_scale:=depth_visual_scale(actor_z)
		var contact:Dictionary=_active_station_render_contact(actor)
		if not contact.is_empty() and bool(actor.get("runtime_visual_bound",false)):
			var room:Dictionary=world.room_by_id(str(actor.get("station_room_id","")))
			if not room.is_empty():
				var c:Vector3=world.room_center_pos(room)
				var pos:Array=contact["local_xyz"]
				var inst:Array=contact["instance_xyz"]
				# Same transform as the real model wrapper, not the approach point.
				actor_scale=depth_visual_scale(float(inst[2]))
				var physical_contact:=Vector3(c.x+float(pos[0])*actor_scale,c.y+float(inst[1])+(float(pos[1])-float(inst[1]))*actor_scale,float(inst[2])+(float(pos[2])-float(inst[2]))*actor_scale)
				actor_sprites[id].position=physical_contact
				# A flat sprite at the pelvis plane gets its entire legs cut by
				# a deep cushion. Move only its render plane forward, along the
				# camera ray, and preserve the projected contact and body scale.
				# Other foreground objects still depth-test normally.
				if contact.has("seat_front_z"):
					var front:float=float(inst[2])+(float(contact["seat_front_z"])-float(inst[2]))*actor_scale
					var projected:Dictionary=_seat_render_projection(physical_contact,front,actor_scale)
					actor_sprites[id].position=projected["position"]
					actor_scale=float(projected["scale"])
		actor_sprites[id].scale=Vector3.ONE*actor_scale
		var actor_room:Dictionary=world.room_by_id(str(actor.get("room_id","")))
		# An accessible private owner room is still not a public cutaway.
		# Transit on its front aisle remains visible; interior poses do not.
		var frontage:bool=world.allows_transit(actor_room) and str(actor.get("phase",""))=="travel" and actor_z>=1.35
		actor_sprites[id].visible = semantic_view.actor_visible(actor) and (world.public_cutaway_allowed(actor_room) or frontage)
		if not actor_sprites[id].visible:
			continue
		if actor.get("runtime_visual_bound",false):
			if id == "MANJKA":
				animate_manka(actor,delta)
			else:
				animate_verified_actor(id,actor,delta)
		# Names live in the status panel, never stacked over actors or furniture.
		actor_labels[id].visible = false
		if id == follow_id:
			actor_labels[id].text = actor["name"] + " • " + public_journal.status(world,life,actor)

func animate_manka(actor: Dictionary, delta: float) -> void:
	var state := "IDLE_LEFT" if str(actor.get("moving_axis","")) == "left" else "IDLE_RIGHT"
	if actor.get("phase","idle") == "travel":
		state = "WALK_LEFT" if str(actor.get("moving_axis","")) == "left" else "WALK_RIGHT"
	elif actor.get("intent","") == "REST" and actor.get("phase","") == "perform":
		state = "REST"
	if asset_banks.manka_frame_count(state) <= 0:
		state = "IDLE_RIGHT"
	var animation: Dictionary = actor_animations.get("MANJKA",{"state":"","frame":0,"elapsed":0.0})
	if animation.get("state","") != state:
		animation = {"state":state,"frame":0,"elapsed":0.0}
	else:
		animation["elapsed"] = float(animation["elapsed"])+minf(delta,0.1)
		var period: float = 1.0/maxf(1.0,asset_banks.manka_fps(state))
		if float(animation["elapsed"]) >= period:
			animation["frame"] = (int(animation["frame"])+int(float(animation["elapsed"])/period)) % maxi(1,asset_banks.manka_frame_count(state))
			animation["elapsed"] = fmod(float(animation["elapsed"]),period)
	actor_animations["MANJKA"] = animation
	var texture: Texture2D = asset_banks.manka_texture(state,int(animation["frame"]))
	var sprite: Sprite3D = actor_sprites["MANJKA"].get_node("Body")
	if texture != null and texture != sprite.texture:
		sprite.texture = texture
		sprite.pixel_size = 1.55/maxf(1.0,float(texture.get_height()))
		sprite.position.y = 0.77

func _active_station_render_contact(actor:Dictionary)->Dictionary:
	# A contact is valid only for the actual visible actor, pose bank and room.
	# Never project a fallback standing frame onto the top of a seat.
	if not teea008_live or str(actor.get("phase",""))!="perform":
		return {}
	if not bool(actor.get("runtime_visual_bound",false)):
		return {}
	var room_id:String=str(actor.get("station_room_id",""))
	if room_id=="" or room_id!=str(actor.get("room_id","")):
		return {}
	var contact:Dictionary=actor.get("station_contact",{})
	if contact.is_empty():
		return {}
	var state:String=str(contact.get("state",""))
	var wardrobe:String=str(actor.get("visual_wardrobe","HOME"))
	var calibrated_wardrobe:String=str(actor.get("teea008_pose_wardrobe",wardrobe))
	if calibrated_wardrobe!=wardrobe:
		return {}
	if state=="" or asset_banks.frame_count(str(actor.get("id","")),wardrobe,state)<1:
		return {}
	if contact.get("local_xyz",[]).size()!=3 or contact.get("instance_xyz",[]).size()!=3 or contact.get("contact_px",[]).size()!=2:
		return {}
	if life.candidate_navigation==null:return {}
	var profile:Dictionary=life.candidate_navigation.pose_profile(actor,state)
	if profile.is_empty() or profile.get("contact_px",[])!=contact.get("contact_px",[]) or profile.get("canvas",[])!=contact.get("canvas",[]):return {}
	if not _calibrated_frame_matches(actor,state,profile):return {}
	if bool(contact.get("book_baked",false))!=bool(profile.get("book_baked",false)):return {}
	return contact

# A contact measured on one source frame cannot be applied to another bank.
func _calibrated_frame_matches(actor:Dictionary,state:String,profile:Dictionary)->bool:
	var id:String=str(actor.get("id",""))
	var wardrobe:String=str(actor.get("visual_wardrobe","HOME"))
	var frames:Array=asset_banks._entry(id,wardrobe,state).get("frames",[])
	return frames.size()>0 and asset_banks._normalize_frame(frames[0])==str(profile.get("path",""))

func _sprite_camera_right()->Vector3:
	if camera==null:return Vector3.RIGHT
	var right:Vector3=camera.global_transform.basis.x
	right.y=0.0
	return right.normalized()

func _sprite_pixel_world(actor_node:Node3D,sprite:Sprite3D,px:Array)->Vector3:
	var m:float=sprite.pixel_size*actor_node.scale.x
	return sprite.global_position+_sprite_camera_right()*(float(px[0])-float(sprite.texture.get_width())*0.5)*m+Vector3.UP*(float(sprite.texture.get_height())*0.5-float(px[1]))*m

func desired_actor_animation(actor: Dictionary) -> String:
	# Pure pose selection. A sofa station is an actual authored seat, not
	# simply two actors standing at the same arbitrary position in a room.
	var requested := "IDLE_S"
	if str(actor.get("phase",""))=="perform" and str(actor.get("intent","")) in ["TALK_PAIR","TALK_GROUP"] and not actor.has("station_contact"):
		var session:Dictionary=life._pair_session(actor)
		var facing=actor.get("social_facing_xz",[])
		if str(session.get("phase",""))=="active" and typeof(facing)==TYPE_ARRAY and facing.size()==2:
			var direction:String=AssetBankResolverScript.social_idle_state(Vector2(float(facing[0]),float(facing[1])),effective_camera_yaw())
			if asset_banks.frame_count(str(actor.get("id","")),str(actor.get("visual_wardrobe","HOME")),direction)>0:return direction
	if teea008_live and str(actor.get("phase",""))=="perform":
		var contact:Dictionary=_active_station_render_contact(actor)
		if not contact.is_empty():
			return str(contact["state"])
		if str(actor.get("intent",""))=="WATCH_FILM":
			return "IDLE_N"
		if str(actor.get("intent","")) in ["GET_COFFEE","TALK_PAIR","TALK_GROUP","REST","SLEEP","READ_BOOK","WORK_CREATE","LISTEN_MUSIC"]:
			# Uncalibrated activity art can contain a seated body. Never use it
			# at a standing approach point or at a stale furniture claim.
			return "IDLE_S"
	if zoom_current < 55.0 and actor.get("phase","idle") == "travel":
		var direction: String = str(actor.get("moving_axis",""))
		if direction == "left":
			requested = "WALK_LEFT"
		elif direction == "right":
			requested = "WALK_RIGHT"
	elif zoom_current < 55.0 and actor.get("phase","idle") == "perform":
		var intent: String = str(actor.get("intent",""))
		match intent:
			"READ_BOOK": requested = "READ"
			"WORK_CREATE":
				if str(actor.get("station_kind","")) == "work":
					requested = str(actor.get("station_pose_hint","USE"))
			"REST":
				if str(actor.get("station_kind","")) in ["seat","floor_rest"]:
					requested = str(actor.get("station_pose_hint","RELAXED_SIT"))
			"SLEEP":
				if str(actor.get("station_kind","")) in ["seat","floor_rest"]:
					requested = str(actor.get("station_pose_hint","SLEEP"))
			"TALK_PAIR","TALK_GROUP":
				# A participant waiting for the other arrival is not talking.
				var session:Dictionary=life._pair_session(actor)
				if str(session.get("phase",""))=="active":
					requested = "RELAXED_SIT" if str(actor.get("station_kind","")) == "seat" else "TALK"
				else:
					requested = "IDLE_S"
			"GET_COFFEE": requested = "DRINK"
			"WATCH_FILM", "LISTEN_MUSIC":
				requested = str(actor.get("station_pose_hint","VIEW")) if (
					str(actor.get("station_kind",""))=="seat") else "VIEW"
			"WATCH_FIRE", "VIEW_ART", "BROWSE_BOOK_CATALOG", "BROWSE_FILMS", "BROWSE_AUDIO":
				requested = "VIEW"
	return requested

func animate_verified_actor(id: String, actor: Dictionary, delta: float) -> void:
	# Visual state does not change life and cannot assume a real chair exists.
	var requested: String = desired_actor_animation(actor)
	var wardrobe: String = str(actor.get("visual_wardrobe","HOME"))
	if asset_banks.frame_count(id,wardrobe,requested) < 1:
		requested = "IDLE_S"
	var state: Dictionary = actor_animations.get(id,{"state":"","frame":0,"elapsed":0.0})
	var old_state:String=str(state["state"])
	var old_frame:int=int(state["frame"])
	var wardrobe_changed:bool=str(state.get("wardrobe",""))!=wardrobe
	if state["state"] != requested or wardrobe_changed:
		state["state"] = requested
		state["elapsed"] = 0.0
		state["frame"] = 0
	else:
		state["elapsed"] = float(state["elapsed"])+minf(delta,0.1)
		var period: float = 1.0 / float(asset_banks.fps(id,wardrobe,requested))
		if float(state["elapsed"]) >= period:
			state["frame"] = (int(state["frame"])+int(float(state["elapsed"])/period)) % maxi(1,asset_banks.frame_count(id,wardrobe,requested))
			state["elapsed"] = fmod(float(state["elapsed"]),period)
	# The validated seat/lying calibration is for the first frame only.
	if not _active_station_render_contact(actor).is_empty():state["frame"]=0
	state["wardrobe"]=wardrobe
	actor_animations[id] = state
	var sprite: Sprite3D = actor_sprites[id].get_node("Body")
	var texture:Texture2D=sprite.texture
	if wardrobe_changed or old_state!=requested or old_frame!=int(state["frame"]) or texture==null:
		texture=asset_banks.texture_for(id,wardrobe,requested,int(state["frame"]))
	if texture != null and (texture != sprite.texture or teea008_live):
		if texture!=sprite.texture:
			sprite.texture=texture
		var height_m:float=2.45 if teea008_live else 1.9
		sprite.pixel_size=height_m/maxf(1.0,float(texture.get_height()))
		var contact:Dictionary=_active_station_render_contact(actor)
		if not contact.is_empty() and requested==str(contact.get("state","")):
			var px:Array=contact["contact_px"]
			sprite.position=_sprite_camera_right()*(float(texture.get_width())*0.5-float(px[0]))*sprite.pixel_size+Vector3.UP*(float(px[1])-float(texture.get_height())*0.5)*sprite.pixel_size
		else:
			var feet:float=float(texture.get_height())*480.0/512.0 if teea008_live else asset_banks.feet_anchor(id,wardrobe,texture.get_height())
			sprite.position=Vector3(0,maxf(0.15,(feet-float(texture.get_height())*0.5)*sprite.pixel_size),0)

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
	var header := HBoxContainer.new()
	col.add_child(header)
	hud_title = Label.new()
	hud_title.text = "ДОМ ДРАКОНА"
	header.add_child(hud_title)
	hud_toggle_button = Button.new()
	hud_toggle_button.text = "☰ Меню"
	hud_toggle_button.pressed.connect(toggle_hud)
	header.add_child(hud_toggle_button)
	var exit_button:=Button.new()
	exit_button.name="SaveAndExit"
	exit_button.text="Выйти"
	exit_button.tooltip_text="Сохранить состояние Дома и штатно завершить программу"
	exit_button.pressed.connect(_request_shutdown)
	header.add_child(exit_button)
	hud_brief = Label.new()
	hud_brief.text = "Обзор"
	col.add_child(hud_brief)
	hud_main_body = VBoxContainer.new()
	hud_main_body.visible = hud_expanded
	col.add_child(hud_main_body)
	hud_status = Label.new()
	hud_main_body.add_child(hud_status)
	media_label = Label.new()
	hud_main_body.add_child(media_label)
	var controls := HBoxContainer.new()
	hud_main_body.add_child(controls)
	for item in ["Дом", "Этаж", "Комната", "Манька", "Строить"]:
		var button := Button.new()
		button.text = item
		controls.add_child(button)
		match item:
			"Дом": button.pressed.connect(func(): set_mode("HOUSE"))
			"Этаж": button.pressed.connect(func(): set_mode("LEVEL"))
			"Комната": button.pressed.connect(func(): set_mode("ROOM"))
			"Манька": button.pressed.connect(func(): follow_actor("MANJKA"))
			"Строить": button.pressed.connect(toggle_build)
	menu = OptionButton.new()
	for t in WorldScript.ROOM_TYPES:
		menu.add_item(room_names.get(t, t))
		menu.set_item_metadata(menu.item_count - 1, t)
	menu.select(1)
	menu.item_selected.connect(func(i): build_type = str(menu.get_item_metadata(i)))
	hud_main_body.add_child(menu)
	var size_menu := OptionButton.new()
	for size_id in [1,2,3]:
		size_menu.add_item("R%d · %d мод." % [size_id,size_id])
		size_menu.set_item_metadata(size_menu.item_count-1,size_id)
	size_menu.select(0)
	size_menu.item_selected.connect(func(i):
		build_size=int(size_menu.get_item_metadata(i))
		if build_marker!=null:
			var cube:BoxMesh=build_marker.mesh
			cube.size.x=W*float(build_size)*0.94)
	hud_main_body.add_child(size_menu)
	var media_button := Button.new()
	media_button.text = "Открыть библиотеку / медиа [M]"
	media_button.pressed.connect(toggle_media_panel)
	hud_main_body.add_child(media_button)
	content_viewer = ContentViewerScript.new()
	root.add_child(content_viewer)
	content_viewer.bind(life.media_runtime)
	media_panel = MediaPanelScript.new()
	root.add_child(media_panel)
	media_panel.bind(world,life.media_runtime,content_viewer)
	media_panel.surface_assignment_requested.connect(_assign_teea008_media)
	media_panel.artifact_placement_requested.connect(_place_teea008_artifact)
	bank_gallery = BankGalleryScript.new()
	root.add_child(bank_gallery)
	bank_gallery.bind(asset_banks,world.read_resident_profiles())
	var gallery_button := Button.new()
	gallery_button.text = "Галерея 24 банков [K]"
	gallery_button.pressed.connect(toggle_bank_gallery)
	hud_main_body.add_child(gallery_button)
	var qa_button := Button.new()
	qa_button.text = "QA-спрайты [V]"
	qa_button.pressed.connect(toggle_qa_art_preview)
	hud_main_body.add_child(qa_button)
	if architecture_review:
		var drinks_button:=Button.new()
		drinks_button.text="Напитки · QA"
		drinks_button.pressed.connect(_open_drink_qa)
		hud_main_body.add_child(drinks_button)
	var journal_button := Button.new()
	journal_button.text = "Журнал дома [J]"
	journal_button.pressed.connect(toggle_journal)
	hud_main_body.add_child(journal_button)
	journal_panel = PanelContainer.new()
	journal_panel.position = Vector2(925, 15)
	journal_panel.custom_minimum_size = Vector2(335, 240)
	journal_panel.visible = false
	root.add_child(journal_panel)
	var journal_column:=VBoxContainer.new()
	journal_panel.add_child(journal_column)
	var journal_heading:=Label.new()
	journal_heading.text="Журнал дома · симуляция"
	journal_column.add_child(journal_heading)
	journal_actor_filter=OptionButton.new()
	journal_room_filter=OptionButton.new()
	journal_category_filter=OptionButton.new()
	for filter in [journal_actor_filter,journal_room_filter,journal_category_filter]:
		filter.fit_to_longest_item=false
		filter.custom_minimum_size.x=310
		filter.item_selected.connect(func(_index):update_journal())
		journal_column.add_child(filter)
	var journal_scroll:=ScrollContainer.new()
	journal_scroll.custom_minimum_size=Vector2(310,300)
	journal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	journal_column.add_child(journal_scroll)
	journal_text = Label.new()
	journal_text.custom_minimum_size = Vector2(300,0)
	journal_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	journal_scroll.add_child(journal_text)
	var import_button := Button.new()
	import_button.text = "Импорт контента / предметов (JSON)"
	import_button.pressed.connect(func(): catalog_picker.popup_centered_ratio(0.65))
	hud_main_body.add_child(import_button)
	hud_help = Label.new()
	hud_help.text = "Колесо: масштаб | ПКМ: перемещение\nЛКМ: выбрать | Shift+ЛКМ: переставить предмет и назначить дом\nQ/E: поворот | PgUp/PgDn: этаж | F: следить | B: строить\nEsc: Follow→Room→Level→House | 1/2/3: House/Level/Room\nV: QA-спрайты | M: медиа | J: журнал"
	hud_main_body.add_child(hud_help)
	hud_help.visible = false
	var help_button := Button.new()
	help_button.text = "Управление [?]"
	help_button.pressed.connect(func(): hud_help.visible = not hud_help.visible)
	hud_main_body.add_child(help_button)
	notice = Label.new()
	notice.position = Vector2(18, 690)
	notice.add_theme_color_override("font_color", Color("#eac59d"))
	root.add_child(notice)
	content_hover_label = Label.new()
	content_hover_label.visible = false
	content_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_hover_label.add_theme_color_override("font_color",Color("#f4ddc4"))
	root.add_child(content_hover_label)
	catalog_picker = FileDialog.new()
	catalog_picker.access = FileDialog.ACCESS_FILESYSTEM
	catalog_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	catalog_picker.add_filter("*.json", "Content catalog JSON")
	catalog_picker.file_selected.connect(_import_media)
	root.add_child(catalog_picker)

	# Full-screen owner-public door note. This panel never grants room access.
	door_note_panel = PanelContainer.new()
	door_note_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	door_note_panel.offset_left = 42
	door_note_panel.offset_top = 32
	door_note_panel.offset_right = -42
	door_note_panel.offset_bottom = -32
	door_note_panel.visible = false
	door_note_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(door_note_panel)
	var door_col:=VBoxContainer.new()
	door_note_panel.add_child(door_col)
	var door_header:=HBoxContainer.new()
	door_col.add_child(door_header)
	door_note_title=Label.new()
	door_note_title.text="ДВЕРЬ"
	door_note_title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	door_header.add_child(door_note_title)
	var door_close:=Button.new()
	door_close.text="Закрыть [Esc]"
	door_close.pressed.connect(close_door_note)
	door_header.add_child(door_close)
	door_note_text=RichTextLabel.new()
	door_note_text.bbcode_enabled=false
	door_note_text.fit_content=false
	door_note_text.scroll_active=true
	door_note_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	door_note_text.size_flags_vertical=Control.SIZE_EXPAND_FILL
	door_note_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	door_note_text.custom_minimum_size=Vector2(640,520)
	door_col.add_child(door_note_text)
	update_hud()

func register_content_hotspot(anchor: Node3D, category: String,
		item_id: String, display_name: String) -> void:
	if anchor == null or category == "" or item_id == "":
		return
	for entry in content_hotspots:
		if entry.get("anchor") == anchor:
			entry["category"] = category
			entry["item_id"] = item_id
			entry["display_name"] = display_name
			return
	content_hotspots.append({
		"anchor":anchor, "category":category,
		"item_id":item_id, "display_name":display_name
	})

func clear_content_hotspots() -> void:
	content_hotspots.clear()
	if content_hover_label != null:
		content_hover_label.visible = false

func content_hotspot_at_screen(point: Vector2) -> Dictionary:
	if camera == null:
		return {}
	var cube_hit:Dictionary=_artifact_cube_hotspot(point)
	if not cube_hit.is_empty():return cube_hit
	var best := 42.0
	var found: Dictionary = {}
	for entry in content_hotspots:
		var anchor = entry.get("anchor")
		if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
			continue
		# Cubes use their real projected volume, never an oversized pixel halo.
		if anchor.has_meta("artifact_cube_side"):continue
		if camera.is_position_behind(anchor.global_position):
			continue
		var screen := camera.unproject_position(anchor.global_position)
		var distance := screen.distance_to(point)
		if distance < best:
			best = distance
			found = entry
	for id in book_nodes:
		var node:Node3D=book_nodes[id]
		if not is_instance_valid(node) or not node.is_visible_in_tree() or camera.is_position_behind(node.global_position):
			continue
		var distance:float=camera.unproject_position(node.global_position).distance_to(point)
		if distance<minf(best,16.0):
			var book:Dictionary=life.media_runtime._lookup("books",str(id))
			if not book.is_empty():
				best=distance
				found={"anchor":node,"category":"books","item_id":str(id),"display_name":str(book.get("title",id)),"physical_book":true}
	# Inspect a real book/film/track currently consumed by a visible actor.
	# Do not fabricate a film frame or a final decor surface before TEEA008.
	for id in actor_sprites:
		var actor:Dictionary=world.residents.get(id,{})
		var node:Node3D=actor_sprites[id]
		if not node.is_visible_in_tree() or not world.public_cutaway_allowed(world.room_by_id(str(actor.get("room_id","")))):
			continue
		if str(actor.get("phase",""))!="perform" or not life._concrete_media_is_valid(actor):
			continue
		var body:Sprite3D=node.get_node_or_null("Body")
		if body==null or camera.is_position_behind(body.global_position):
			continue
		var distance:float=camera.unproject_position(body.global_position).distance_to(point)
		if distance<best:
			var category:String=str(actor.get("activity_media_category",""))
			var item_id:String=str(actor.get("activity_media_id",""))
			var record:Dictionary=life.media_runtime._lookup(category,item_id)
			if not record.is_empty():
				best=distance
				found={"anchor":node,"category":category,"item_id":item_id,"display_name":str(record.get("title",item_id)),"actor_id":str(id)}
	for creature_id in creature_nodes:
		var creature:Dictionary=world.creatures.get(creature_id,{})
		var node:Node3D=creature_nodes[creature_id]
		if str(creature.get("owner_id",""))=="" or not bool(creature.get("active",false)) or not node.is_visible_in_tree():
			continue
		if not world.public_cutaway_allowed(world.room_by_id(str(creature.get("room_id","")))):
			continue
		var body:Sprite3D=node.get_node_or_null("Body")
		if body==null or camera.is_position_behind(body.global_position):
			continue
		var distance:float=camera.unproject_position(body.global_position).distance_to(point)
		if distance<best:
			best=distance
			found={"anchor":node,"category":"creatures","item_id":str(creature_id),"display_name":world.creature_display_label(str(creature_id))}
	if found.is_empty():
		var surface:Dictionary=teea008_review.aperture_hit(camera,point)
		if not surface.is_empty() and world.public_cutaway_allowed(world.room_by_id(str(surface.get("room_id","")))):
			var item:Dictionary=teea008_media_bindings.resolve(str(surface["room_id"]),str(surface["item_id"]))
			if not item.is_empty():
				surface["display_name"]=str(item.get("title",item.get("display_name","Без названия")))
			else:
				var category:String=str(teea008_review.surfaces.get(str(surface["item_id"]),{}).get("legacy_runtime_category",""))
				surface["display_name"]={"books":"Книжная полка","films":"Кинозона","tracks":"Аудиотека","artifacts":"Полка артефактов"}.get(category,"Место для экспозиции")
			found=surface
	return found

func open_content_hotspot(entry: Dictionary) -> bool:
	if entry.is_empty() or content_viewer == null:
		return false
	var category := str(entry.get("category",""))
	var item_id := str(entry.get("item_id",""))
	var record: Dictionary = {}
	if category=="teea008_surface":
		var surface:Dictionary=teea008_review.surfaces.get(item_id,{})
		if surface.is_empty() or not world.public_cutaway_allowed(world.room_by_id(str(entry.get("room_id","")))):
			return false
		var bound_category:String=str(surface.get("legacy_runtime_category",""))
		var room_id:String=str(entry.get("room_id",""))
		record=teea008_media_bindings.resolve(room_id,item_id)
		if bound_category in ["books","films","tracks"]:
			media_panel.open_surface(room_id,item_id,bound_category)
			if not record.is_empty() and not bool(entry.get("assign_only",false)):
				return content_viewer.open_record(bound_category,record)
		elif bound_category=="artifacts":
			media_panel.open_surface(room_id,item_id,bound_category)
			if not record.is_empty() and not bool(entry.get("assign_only",false)):
				return open_content_hotspot({"category":"artifacts","item_id":str(record["id"])})
		return true
	if category in ["books","films","tracks"]:
		if bool(entry.get("physical_book",false)):
			var node:Node3D=book_nodes.get(item_id)
			if not is_instance_valid(node) or not node.is_visible_in_tree():
				return false
		if entry.has("actor_id"):
			var actor:Dictionary=world.residents.get(str(entry["actor_id"]),{})
			if str(actor.get("phase",""))!="perform" or not world.public_cutaway_allowed(world.room_by_id(str(actor.get("room_id","")))) or not life._concrete_media_is_valid(actor):
				return false
			if str(actor.get("activity_media_id",""))!=item_id or str(actor.get("activity_media_category",""))!=category:
				return false
		record = life.media_runtime._lookup(category,item_id)
	elif category == "creatures":
		var creature:Dictionary=world.creatures.get(item_id,{})
		if str(creature.get("owner_id",""))=="" or not bool(creature.get("active",false)) or not world.public_cutaway_allowed(world.room_by_id(str(creature.get("room_id","")))):
			return false
		var node:Node3D=creature_nodes.get(item_id)
		if node==null or not node.is_visible_in_tree():
			return false
		var body:Sprite3D=node.get_node_or_null("Body")
		var picture:Texture2D=body.texture if body!=null and body.has_meta("candidate_bank") else null
		record={"id":item_id,"display_name":world.creature_display_label(item_id),"description":"Именное животное Дома"}
		return content_viewer.open_record(category,record,picture)
	elif category in ["artifacts","paintings","posters","cups"]:
		record = world.physical_object(item_id)
		var location:String=str(record.get("current_room_id",""))
		var holder:String=str(record.get("current_holder_id",""))
		if holder!="":
			location=str(world._physical_actor(holder).get("room_id",""))
		if str(record.get("state",""))=="STASHED" or not world.public_cutaway_allowed(world.room_by_id(location)):
			return false
	if record.is_empty():
		return false
	if architecture_review and category=="artifacts" and artifact_cubes.is_cube(item_id):
		var master:String=artifact_cubes.master_path(item_id)
		var image_record:Dictionary=record.duplicate(true)
		image_record["title"]=artifact_cubes.title(item_id)
		image_record["preview_path"]=master
		image_record.erase("preview")
		image_record["canonical_cube_master"]=true
		if master=="":image_record["description"]="Оригинал не установлен или не прошёл проверку SHA-256."
		return content_viewer.open_record(category,image_record)
	if category=="artifacts":
		var full_path:String=str(record.get("full_image_path",""))
		if full_path!="":
			record=record.duplicate(true)
			if ResourceLoader.exists(full_path,"Texture2D") or FileAccess.file_exists(full_path):
				record["preview_path"]=full_path
			else:
				record["description"]=str(record.get("description",""))+"\nПолноразмерный исходник недоступен; показано превью."
		elif str(record.get("preview_path",""))=="":
			var master:String=asset_banks.prop_master_path(str(record.get("asset_id","")))
			if master!="":
				record=record.duplicate(true)
				record["preview_path"]="res://"+master
	return content_viewer.open_record(category,record)

func update_content_hover(point: Vector2) -> void:
	if content_hover_label == null or content_viewer == null or content_viewer.visible:
		return
	var entry := content_hotspot_at_screen(point)
	content_hover_label.visible = not entry.is_empty()
	if entry.is_empty():
		return
	content_hover_label.text = str(entry.get("display_name",entry.get("item_id","")))
	var hovered_object:Dictionary=world.physical_object(str(entry.get("item_id","")))
	if bool(hovered_object.get("movable",false)) or str(hovered_object.get("display_mode",""))=="wall":
		content_hover_label.text += "  ·  Shift+ЛКМ: переставить/дом"
	content_hover_label.position = point + Vector2(14,12)

func close_door_note()->void:
	if door_note_panel!=null:
		door_note_panel.visible=false

func open_door_note(room_id:String)->bool:
	var room:Dictionary=world.room_by_id(room_id)
	if room.is_empty() or str(room.get("privacy","public"))!="door_only":
		return false
	var owner_id:String=str(room.get("owner_id",""))
	if owner_id=="":
		return false
	# Registry reads explicitly public notes only; absent notes open an empty sheet.
	var body:String=door_registry.note_text(owner_id)
	door_note_title.text=door_registry.sign_text(owner_id,world.read_resident_profiles())
	door_note_text.text=body
	door_note_text.scroll_to_line(0)
	door_note_panel.visible=true
	return true

func door_note_at_screen(point:Vector2)->String:
	if camera==null:
		return ""
	var best:=INF
	var found:=""
	for room_id in door_note_anchors:
		var anchor:Node3D=door_note_anchors[room_id]
		if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
			continue
		if camera.is_position_behind(anchor.global_position):
			continue
		var screen:Vector2=camera.unproject_position(anchor.global_position)
		# Hit the projected paper/frame, not an oversized 44-pixel circle that
		# can steal adjacent room clicks at whole-house zoom.
		var bounds:=Rect2(screen,Vector2.ZERO)
		for dx in [-0.26,0.26]:
			for dy in [-0.35,0.35]:
				var corner:Vector3=anchor.global_position+Vector3(float(dx),float(dy),0)
				bounds=bounds.expand(camera.unproject_position(corner))
		if not bounds.grow(2.0).has_point(point):
			continue
		var distance:float=screen.distance_to(point)
		if distance<best:
			best=distance
			found=str(room_id)
	return found

func _import_media(path: String) -> void:
	var importer=ObjectImportScript.new()
	var result:Dictionary=importer.import_file(world,path,teea008_review if teea008_review.enabled else null,life.candidate_navigation)
	if not bool(result.get("ok",false)):
		notice.text="Ошибка импорта: "+str(result.get("error","unknown"))
		if int(result.get("added",0))>0:
			make_physical_objects()
		update_hud()
		return
	if bool(result.get("has_media",false)):
		if not world.import_catalog(path):
			notice.text="Предметы добавлены: %d; ошибка медиакаталога" % int(result.get("added",0))
			make_physical_objects()
			update_hud()
			return
		life.media_runtime.setup(world)
		media_panel.refresh()
	if int(result.get("added",0))>0:
		life.refresh_changed_station_claims()
		make_physical_objects()
	notice.text="Импорт: %s · предметов %d" % [path.get_file(),int(result.get("added",0))]
	update_hud()

func toggle_hud() -> void:
	hud_expanded = not hud_expanded
	if hud_main_body != null:
		hud_main_body.visible = hud_expanded
	if hud_toggle_button != null:
		hud_toggle_button.text = "Скрыть ▲" if hud_expanded else "☰ Меню"

func toggle_bank_gallery() -> void:
	if bank_gallery == null:
		return
	bank_gallery.visible = not bank_gallery.visible
	if bank_gallery.visible:
		bank_gallery.refresh()

func toggle_qa_art_preview() -> void:
	qa_visual_preview = not qa_visual_preview
	make_residents()
	update_hud()
	if notice != null:
		notice.text = "Визуальные банки: QA-ПРОСМОТР" if qa_visual_preview else "Визуальные банки: только утверждённые"

func toggle_media_panel() -> void:
	if media_panel.visible:
		media_panel.close_panel()
	else:
		media_panel.open_panel()

func toggle_journal() -> void:
	journal_open = not journal_open
	journal_panel.visible = journal_open
	if journal_open:
		_refresh_journal_filters()
		update_journal()

func _add_journal_option(filter:OptionButton,label:String,key:String)->void:
	filter.add_item(label)
	filter.set_item_metadata(filter.item_count-1,key)

func _refresh_journal_filters()->void:
	for filter in [journal_actor_filter,journal_room_filter,journal_category_filter]:filter.clear()
	_add_journal_option(journal_actor_filter,"Все жители","")
	for collection in [world.residents,world.creatures]:
		for id in collection:_add_journal_option(journal_actor_filter,public_journal.actor_label(world,str(id)),str(id))
	_add_journal_option(journal_room_filter,"Все публичные помещения","")
	for room in world.rooms:
		if world.public_cutaway_allowed(room):_add_journal_option(journal_room_filter,public_journal.room_label(room)+" · этаж "+str(int(room["level"])),str(room["id"]))
	_add_journal_option(journal_category_filter,"Все занятия и события","")
	for key in public_journal.CATEGORY_NAMES:_add_journal_option(journal_category_filter,public_journal.CATEGORY_NAMES[key],str(key))
	for filter in [journal_actor_filter,journal_room_filter,journal_category_filter]:filter.select(0)

func _journal_filter_value(filter:OptionButton)->String:
	return str(filter.get_item_metadata(filter.selected)) if filter!=null and filter.selected>=0 else ""

func update_journal() -> void:
	if journal_text == null:return
	var lines:Array[String]=public_journal.lines(world,_journal_filter_value(journal_actor_filter),_journal_filter_value(journal_room_filter),_journal_filter_value(journal_category_filter))
	journal_text.text="\n\n".join(lines) if not lines.is_empty() else "Нет публичных событий по выбранным условиям."

func camera_world_bounds() -> Rect2:
	var lo := Vector2(99999,99999)
	var hi := Vector2(-99999,-99999)
	for room in world.rooms:
		var start_x: float = float(room["x"])*W
		var end_x: float = float(world.room_space.x_end(room))*W
		var center_x: float = (start_x+end_x)*0.5
		var span: float = float(world.room_size_modules(room))*W
		var pos := Vector2(center_x, float(room["level"]) * H)
		lo.x = minf(lo.x,pos.x - span * 0.5)
		lo.y = minf(lo.y,pos.y - (0.15 if architecture_review else H*0.5))
		hi.x = maxf(hi.x,pos.x + span * 0.5)
		hi.y = maxf(hi.y,pos.y + (3.65 if architecture_review else H*0.5))
	return Rect2(lo,hi-lo)

func fit_house_camera() -> void:
	var bounds: Rect2 = camera_world_bounds()
	var size: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = maxf(0.25 if architecture_review else 1.0, size.x / maxf(1.0,size.y))
	var angle: float = deg_to_rad(BASE_FOV * 0.5)
	# HOUSE is an overview, but it should feel like a Shelter cutaway filling
	# the viewport rather than a tiny diagram floating in rock.
	var vertical_dist: float = (bounds.size.y + 1.0) / maxf(0.1, 2.0 * tan(angle))
	var horizontal_dist: float = (bounds.size.x + 0.8) / maxf(0.1, 2.0 * aspect * tan(angle))
	# HOUSE is a navigable overview, not a mandatory fit-all blueprint.
	# A modest crop keeps rooms legible; mouse pan still reaches every edge.
	zoom = clampf(maxf(horizontal_dist,vertical_dist)*(1.10 if architecture_review else 0.87),12.0,160.0 if architecture_review else 110.0)
	if architecture_review:
		yaw=0.0
	desired_focus = Vector3(bounds.get_center().x,bounds.get_center().y,0.0)

func update_selection_outline() -> void:
	if selected_outline == null:
		return
	for child in selected_outline.get_children():
		child.queue_free()
	selected_outline.visible = false
	if selected_room == "" or current_mode != "ROOM":
		return
	var room: Dictionary = world.room_by_id(selected_room)
	if room.is_empty():
		return
	var group: Dictionary = world.merged_group(int(room["x"]),int(room["level"]))
	if group.is_empty():
		return
	var cx: float = (float(group["x_start"])+float(group["x_end"]))*0.5*W
	var length: float = float(group["width"])*W
	selected_outline.position = Vector3(cx,float(room["level"])*H,0.0)
	var tone := Color("#e8b875")
	box(selected_outline,Vector3(0,-0.04,1.51),
		Vector3(length,0.045,0.055),tone,true)
	box(selected_outline,Vector3(0,3.08,1.51),
		Vector3(length,0.045,0.055),tone,true)
	for side in [-1,1]:
		box(selected_outline,Vector3(float(side)*length*0.5,1.52,1.51),
			Vector3(0.050,3.12,0.055),tone,true)
	selected_outline.visible = true

func level_world_bounds(level: int) -> Rect2:
	var lo_x := INF
	var hi_x := -INF
	var found := false
	for room in world.rooms:
		if int(room.get("level",0)) != level:
			continue
		var start_x:=float(room["x"])*W
		var end_x:=float(world.room_space.x_end(room))*W
		lo_x = minf(lo_x,start_x-W*0.5)
		hi_x = maxf(hi_x,end_x+W*0.5)
		found = true
	if not found:
		return Rect2()
	var center_y := float(level)*H+1.45
	return Rect2(Vector2(lo_x,center_y-1.75),Vector2(hi_x-lo_x,3.5))

func fit_level_camera(level: int) -> bool:
	var bounds := level_world_bounds(level)
	if not bounds.has_area():
		return false
	var viewport := get_viewport().get_visible_rect().size
	var aspect := maxf(1.0,viewport.x/maxf(1.0,viewport.y))
	var angle := deg_to_rad(BASE_FOV*0.5)
	var vertical_dist := (bounds.size.y+1.4)/maxf(0.1,2.0*tan(angle))
	var horizontal_dist := (bounds.size.x+3.0)/maxf(0.1,2.0*aspect*tan(angle))
	zoom = clampf(maxf(vertical_dist,horizontal_dist)*1.08,12.0,160.0 if architecture_review else 82.0)
	desired_focus = Vector3(bounds.get_center().x,bounds.get_center().y,0.0)
	return true

func select_level(level: int) -> void:
	follow_id = ""
	build_mode = false
	if build_marker:
		build_marker.visible = false
	var selected := semantic_view.select_level(world,level)
	semantic_view.set_view(world,"LEVEL","",selected)
	current_mode = "LEVEL"
	Engine.max_fps = 60
	fit_level_camera(selected)
	update_selection_outline()
	update_hud()
	update_render_lod()

func step_level(delta: int) -> void:
	var next_level := semantic_view.step_level(world,delta)
	select_level(next_level)

func set_mode(mode: String) -> void:
	if not mode in ["HOUSE","LEVEL","ROOM","FOLLOW"]:
		return
	Engine.max_fps = 30 if mode == "HOUSE" else 60
	build_mode = false
	if build_marker:
		build_marker.visible = false
	current_mode = mode
	match mode:
		"HOUSE":
			follow_id = ""
			semantic_view.set_view(world,"HOUSE")
			fit_house_camera()
		"LEVEL":
			follow_id = ""
			var requested_level: int = int(semantic_view.level)
			if selected_room != "":
				var selected: Dictionary = world.room_by_id(selected_room)
				if not selected.is_empty():
					requested_level = int(selected.get("level",requested_level))
			semantic_view.select_level(world,requested_level)
			semantic_view.set_view(world,"LEVEL","",semantic_view.level)
			fit_level_camera(semantic_view.level)
		"ROOM":
			follow_id = ""
			zoom = 10.5
			if selected_room != "":
				var r: Dictionary = world.room_by_id(selected_room)
				if not r.is_empty():
					semantic_view.set_view(world,"ROOM",selected_room,int(r["level"]))
					var group: Dictionary = world.merged_group(int(r["x"]),int(r["level"]))
					var cx: float = (float(group["x_start"])+float(group["x_end"]))*0.5*W
					desired_focus = Vector3(cx,float(r["level"])*H+1.45,0.0)
					zoom = 10.8+maxf(0.0,float(group["width"]-1))*3.1
			else:
				semantic_view.set_view(world,"ROOM","",semantic_view.level)
		"FOLLOW":
			semantic_view.set_view(world,"FOLLOW",selected_room,semantic_view.level)
			zoom = 16.0
	update_selection_outline()
	update_hud()
	update_render_lod()

func follow_actor(id: String) -> void:
	if not actor_sprites.has(id) or not world.residents.has(id):
		return
	var actor: Dictionary = world.residents[id]
	follow_id = id
	selected_room = str(actor.get("room_id",selected_room))
	current_mode = "FOLLOW"
	semantic_view.set_view(world,"FOLLOW",selected_room,int(actor.get("level",0)))
	Engine.max_fps = 60
	build_mode = false
	update_selection_outline()
	zoom = minf(zoom,20.0)
	update_hud()
	update_render_lod()

func toggle_build() -> void:
	build_mode = not build_mode
	if build_mode:
		follow_id = ""
		current_mode = "BUILD"
		Engine.max_fps = 60
		update_selection_outline()
		if zoom < 16.0:
			zoom = 22.0
		if build_marker == null:
			build_marker = MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3(W * float(build_size) * 0.94, 2.9, 3.9)
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

func room_activity_lines(group: Dictionary) -> Array:
	# ROOM mode should expose what the visible residents are actually doing,
	# without putting floating labels over faces/furniture.
	var room_ids:Dictionary={}
	for cell in group.get("cells",[]):
		room_ids[str(cell.get("id",""))]=true
	var entries:Array=[]
	for id in world.residents:
		var actor:Dictionary=world.residents[id]
		if not bool(actor.get("active",false)) or str(actor.get("phase",""))!="perform":
			continue
		var activity_room:String=str(actor.get("station_room_id",
			actor.get("room_id","")))
		if not room_ids.has(activity_room):
			continue
		entries.append("%s — %s" % [
			str(actor.get("name",id)),public_journal.status(world,life,actor)])
	entries.sort()
	return entries

func update_hud() -> void:
	if hud_status == null:
		return
	var tracked: Dictionary = world.residents.get(follow_id, {})
	var sisters:=0
	var guests:=0
	for id in actor_sprites:
		if str(world.residents.get(id,{}).get("entity_type",""))=="guest":
			guests+=1
		elif str(id).begins_with("RES_"):
			sisters+=1
	hud_status.text = "Режим: %s | уровень: %d | комнат: %d | сёстры: %d / 24 | гости: %d" % [
		current_mode, semantic_view.level, world.rooms.size(), sisters,guests]
	if hud_brief != null:
		hud_brief.text = "%s · L%d · %d комнат · %d/24 + %d гост." % [
			current_mode,semantic_view.level,world.rooms.size(),sisters,guests]
	hud_status.text += "\nУтверждено: %d / 24 | технически: %d" % [validated_visual_banks,preview_visual_banks]
	if qa_visual_preview:
		hud_status.text += "\nВИД: QA-ПРОСМОТР (не утверждено)"
	if not tracked.is_empty():
		hud_status.text += "\nСлежение: %s — %s" % [tracked.get("name", "?"), public_journal.status(world,life,tracked)]
		if architecture_review and life.candidate_cups.beverages.enabled and world.public_cutaway_allowed(world.room_by_id(str(tracked.get("room_id","")))):
			var beverage=life.candidate_cups.beverages
			var prefs:Dictionary=beverage.history(follow_id)
			var counts:Dictionary=prefs["drink_counts"]
			var keys:Array=counts.keys()
			keys.sort_custom(func(a,b):return int(counts[a])>int(counts[b]))
			for i in range(mini(3,keys.size())):
				var key:String=str(keys[i])
				hud_status.text+="\n%s: %d" % [beverage.by_id[key]["display_name_ru"],int(counts[key])]
			var content:Dictionary=beverage.content(str(tracked.get("cup_task_id","")))
			if float(content.get("remaining_ml",0))>0:
				hud_status.text+="\n%s · %.0f мл" % [content["display_name"],float(content["remaining_ml"])]
	if current_mode == "ROOM" and selected_room != "":
		var r: Dictionary = world.room_by_id(selected_room)
		if not r.is_empty():
			var merged: int = world.merged_run_length(int(r["x"]),int(r["level"]))
			hud_status.text += "\n%s  R%d  |  уровень %d" % [
				room_names.get(r["type"],r["type"]),merged,int(r["level"])]
			var group: Dictionary = world.merged_group(int(r["x"]),int(r["level"]))
			if world.public_cutaway_allowed(r):
				var occupied := 0
				var capacity := 0
				for cell in group.get("cells",[]):
					occupied += life.stations.used_slots(world,str(cell["id"])).size()
					capacity += life.stations.capacity(cell)
				hud_status.text += "\nМеста действий: %d / %d" % [occupied,capacity]
				var activities:Array=room_activity_lines(group)
				for i in range(mini(3,activities.size())):
					hud_status.text += "\n" + str(activities[i])
				if activities.size()>3:
					hud_status.text += "\n…ещё %d" % (activities.size()-3)
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

func zoom_around_pointer(mouse: Vector2, multiplier: float) -> void:
	# Shelter-style anchoring: keep the world point under the cursor stable
	# while zooming the camera. Following a resident takes precedence.
	var old_zoom: float = zoom
	var new_zoom: float = clampf(old_zoom*multiplier,4.5,160.0 if architecture_review else 110.0)
	if is_equal_approx(new_zoom,old_zoom):
		return
	if follow_id == "":
		var target = ray_to_front_plane(mouse)
		if target != null:
			var ratio: float = new_zoom / old_zoom
			desired_focus.x = float(target.x) - (float(target.x)-desired_focus.x)*ratio
			desired_focus.y = float(target.y) - (float(target.y)-desired_focus.y)*ratio
	zoom = new_zoom
	# Wheel-only inspection must retain the same detail access as mouse pan.
	if architecture_review and not build_mode and follow_id=="" and current_mode in ["HOUSE","LEVEL"] and new_zoom<44.0:
		current_mode="FREE"
		Engine.max_fps=60
		update_hud()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index==MOUSE_BUTTON_LEFT and e.pressed and e.shift_pressed and not build_mode and not (content_viewer!=null and content_viewer.visible) and not (door_note_panel!=null and door_note_panel.visible):
			var entry:Dictionary=content_hotspot_at_screen(e.position)
			var object_id:String=str(entry.get("item_id",""))
			var object:Dictionary=world.physical_object(object_id)
			if not object.is_empty() and (bool(object.get("movable",false)) or str(object.get("display_mode",""))=="wall") and str(object.get("current_holder_id",""))=="" and (
					str(object.get("state",""))!="STASHED"):
				var room_id:String=str(object.get("current_room_id",""))
				var room:Dictionary=world.room_by_id(room_id)
				var raw=object.get("current_anchor",[])
				if not room.is_empty() and typeof(raw)==TYPE_ARRAY and (raw as Array).size()==2:
					object_home_drag_id=object_id
					object_home_drag_room_id=room_id
					object_home_drag_anchor=Vector2(float(raw[0]),float(raw[1]))
					object_home_drag_world_x=world.room_center_pos(room).x+object_home_drag_anchor.x
					object_home_drag_wall_y=-1.0
					var mounted:Array=object.get("display_anchor",[])
					if str(object.get("display_mode",""))=="wall" and mounted.size()==3:
						object_home_drag_wall_y=float(mounted[1])
					notice.text="Переставляю %s · отпусти ЛКМ, чтобы назначить новый дом" % [
						str(object.get("display_name",object_id))]
					get_viewport().set_input_as_handled()
					return
		if e.button_index==MOUSE_BUTTON_LEFT and not e.pressed and object_home_drag_id!="":
			var moved_id:String=object_home_drag_id
			var moved_room:String=object_home_drag_room_id
			var moved_anchor:Vector2=object_home_drag_anchor
			var wall_y:float=object_home_drag_wall_y
			object_home_drag_id=""
			object_home_drag_room_id=""
			object_home_drag_wall_y=-1.0
			var allowed:=true
			if wall_y>=0.0:
				var object:Dictionary=world.physical_object(moved_id)
				allowed=WallPlacementScript.valid(world,teea008_review if teea008_review.enabled else null,life.candidate_navigation,world.room_by_id(moved_room),Vector2(moved_anchor.x,wall_y),WallPlacementScript.object_extent(object),moved_id)
			var moved:=false
			if allowed and wall_y<0.0 and architecture_review and life.candidate_navigation!=null and world.physical_object(moved_id).get("viewer_category","")=="artifacts":
				var target:Dictionary=world.room_by_id(moved_room)
				if world.public_cutaway_allowed(target):
					var slot:Dictionary=artifact_cubes.pick_slot(target,moved_id,moved_anchor)
					if not slot.is_empty():
						var p:Array=slot["xyz"]
						if moved_anchor.distance_to(Vector2(p[0],p[2]))<0.65:
							moved=world.assign_physical_object_home(moved_id,moved_room,Vector2(p[0],p[2]),true,str(slot["id"]))
			elif allowed:
				moved=world.assign_physical_object_home(moved_id,moved_room,moved_anchor,true,"",wall_y)
			if moved:
				world.save_world()
				life.refresh_changed_station_claims()
				_refresh_conditional_dressing()
				notice.text="Новое место назначено домом: %s" % str(
					world.physical_object(moved_id).get("display_name",moved_id))
			else:
				notice.text="Место занято или не подходит по размеру; прежний дом сохранён"
			update_physical_objects()
			update_hud()
			get_viewport().set_input_as_handled()
			return
		if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
			zoom_around_pointer(e.position,0.87)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
			zoom_around_pointer(e.position,1.15)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			moving_view = e.pressed
	if event is InputEventMouseMotion:
		var e: InputEventMouseMotion = event
		if object_home_drag_id!="":
			var room:Dictionary=world.room_by_id(object_home_drag_room_id)
			if not room.is_empty():
				var drag_scale:float=zoom_current*0.0019
				var dragged:Dictionary=world.physical_object(object_home_drag_id)
				var wall:bool=str(dragged.get("display_mode",""))=="wall"
				object_home_drag_world_x+=e.relative.x*drag_scale
				if not wall:
					object_home_drag_anchor.y+=e.relative.y*drag_scale
				else:
					object_home_drag_wall_y=clampf(object_home_drag_wall_y-e.relative.y*drag_scale,0.65,2.8)
				var absolute_x:float=object_home_drag_world_x
				var candidate:Dictionary=world.get_room(roundi(absolute_x/W),int(room.get("level",0)))
				if world.public_cutaway_allowed(candidate) and str(candidate["id"])!=object_home_drag_room_id:
					room=candidate
					object_home_drag_room_id=str(room["id"])
				object_home_drag_anchor.x=absolute_x-world.room_center_pos(room).x
				var half_width:float=world.room_space.half_width(room)
				var edge:float=0.60 if wall else 0.16
				object_home_drag_anchor.x=clampf(
					object_home_drag_anchor.x,-half_width+edge,half_width-edge)
				object_home_drag_anchor.y=clampf(
					object_home_drag_anchor.y,
					float(world.room_space.BACK_Z)+0.12,
					float(world.room_space.FRONT_Z)-0.12)
				var node:Node3D=object_nodes.get(object_home_drag_id)
				if node!=null:
					var pos:Vector3=world.room_local_to_world(room,object_home_drag_anchor)
					var height:float=0.0 if node.has_meta("artifact_cube_side") else 0.22
					if wall:
						height=object_home_drag_wall_y
						if teea008_review.enabled and bool(visual_room_groups.get(object_home_drag_room_id,{}).get("teea008_review",false)):pos.z=-1.98
					node.position=Vector3(depth_visual_x(object_home_drag_room_id,pos.x,pos.z),pos.y+height,pos.z)
					node.scale=Vector3.ONE*depth_visual_scale(pos.z)
				notice.text="Новый дом X %.2f · высота %.2f" % [object_home_drag_anchor.x,object_home_drag_wall_y] if wall else "Новый дом X %.2f · Z %.2f" % [object_home_drag_anchor.x,object_home_drag_anchor.y]
			get_viewport().set_input_as_handled()
			return
		if not moving_view and not build_mode:
			update_content_hover(e.position)
		if moving_view and not build_mode:
			follow_id = "" # moving away manually cancels Follow
			current_mode = "FREE"
			Engine.max_fps = 60
			var scale: float = zoom_current * 0.0019
			desired_focus.x -= e.relative.x * scale
			desired_focus.y += e.relative.y * scale
		elif build_mode:
			var hit = ray_to_front_plane(e.position)
			if hit != null:
				build_cell = Vector2i(roundi(hit.x / W), roundi(hit.y / H))
				var center_x:float=(float(build_cell.x)+(float(build_size)-1.0)*0.5)*W
				build_marker.position = Vector3(center_x,float(build_cell.y)*H+1.4,0.0)
				var cube:BoxMesh=build_marker.mesh
				cube.size.x=W*float(build_size)*0.94
				var permitted: bool = bool(world.can_build_room(
					build_cell.x, build_cell.y, build_type, build_size))
				var preview_mat: StandardMaterial3D = build_marker.material_override
				preview_mat.albedo_color = Color(0.22,0.90,0.55,0.28) if permitted else Color(0.82,0.23,0.26,0.28)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_ESCAPE and content_viewer!=null and content_viewer.visible:
			content_viewer.close_viewer()
			return
		if event.keycode==KEY_ESCAPE and door_note_panel!=null and door_note_panel.visible:
			close_door_note()
			return
		match event.keycode:
			KEY_ESCAPE:
				if current_mode == "FOLLOW":
					var tracked: Dictionary = world.residents.get(follow_id,{})
					if not tracked.is_empty():
						selected_room = str(tracked.get("room_id",selected_room))
					follow_id = ""
					set_mode("ROOM")
				elif current_mode == "ROOM":
					set_mode("LEVEL")
				elif current_mode == "LEVEL":
					set_mode("HOUSE")
				else:
					set_mode("HOUSE")
			KEY_F: follow_actor("MANJKA")
			KEY_B: toggle_build()
			KEY_Q: yaw = clampf(yaw - 0.10, -0.34, 0.34)
			KEY_E: yaw = clampf(yaw + 0.10, -0.34, 0.34)
			KEY_J: toggle_journal()
			KEY_M: toggle_media_panel()
			KEY_V: toggle_qa_art_preview()
			KEY_K: toggle_bank_gallery()
			KEY_TAB: toggle_hud()
			KEY_PAGEUP: step_level(1)
			KEY_PAGEDOWN: step_level(-1)
			KEY_1: set_mode("HOUSE")
			KEY_2: set_mode("LEVEL")
			KEY_3: set_mode("ROOM")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var e: InputEventMouseButton = event
		if e.button_index != MOUSE_BUTTON_LEFT or not e.pressed:
			return
		if door_note_panel!=null and door_note_panel.visible:
			return
		if content_viewer!=null and content_viewer.visible:
			return
		var content_entry:Dictionary=content_hotspot_at_screen(e.position)
		if not build_mode and not content_entry.is_empty() and open_content_hotspot(content_entry):
			return
		var note_room_id:String=door_note_at_screen(e.position)
		if note_room_id!="":
			if open_door_note(note_room_id):
				return
		if build_mode:
			if build_cell == Vector2i(99,99):
				return
			if world.build_room(build_cell.x, build_cell.y, build_type, build_size):
				make_rooms()
				update_render_lod()
				notice.text = "Построено: %s R%d (%d, %d)" % [
					room_names.get(build_type, build_type), build_size,
					build_cell.x, build_cell.y]
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
				if not world.public_cutaway_allowed(room):
					notice.text = "Закрытая территория: камера остаётся у двери"
				else:
					notice.text = room_names.get(room["type"], room["type"])
				set_mode("ROOM")

func effective_camera_fov() -> float:
	# HOUSE keeps the restrained overview lens. As the camera approaches a room
	# we widen the lens and move the camera closer while preserving framing.
	# That makes the physical 3.6 m X/Z room produce real perspective instead
	# of relying on a telephoto view plus exaggerated sprite scaling.
	var close_t:float=1.0-clampf(
		(zoom_current-CLOSE_FOV_NEAR_ZOOM)/
		(CLOSE_FOV_FAR_ZOOM-CLOSE_FOV_NEAR_ZOOM),0.0,1.0)
	return lerpf(BASE_FOV,CLOSE_FOV,close_t)

func effective_camera_distance(view_fov: float = -1.0) -> float:
	var fov_value:float=view_fov if view_fov>0.0 else effective_camera_fov()
	var base_tan:float=tan(deg_to_rad(BASE_FOV*0.5))
	var view_tan:float=maxf(0.01,tan(deg_to_rad(fov_value*0.5)))
	return zoom_current*base_tan/view_tan

func effective_camera_yaw() -> float:
	# Close rooms need a genuinely oblique Shelter-like view so X/Z reads as
	# volume. HOUSE fades toward frontal readability; Q/E remains additive.
	var close_bias: float=clampf((48.0-zoom_current)/34.0,0.0,1.0)*0.18
	return clampf(yaw+close_bias,-0.42,0.42)

func effective_camera_height_ratio() -> float:
	# At ROOM/FREE close zoom, look down enough to expose the traversable floor.
	# At HOUSE scale flatten the angle so the whole cutaway stays readable.
	var close_t:float=1.0-clampf((zoom_current-12.0)/36.0,0.0,1.0)
	return lerpf(0.105,0.185,close_t)

func update_cutaway_return_visibility() -> void:
	var view_yaw:float=effective_camera_yaw()
	var cutaway_close:bool=zoom_current<36.0 and absf(view_yaw)>0.045
	for group_node in room_root.get_children():
		if not group_node.visible:
			continue
		var structure:Node3D=group_node.get_node_or_null("Layer_Structure")
		if structure==null:
			continue
		var left:Node3D=structure.get_node_or_null("ConnectorRearReturn_L")
		var right:Node3D=structure.get_node_or_null("ConnectorRearReturn_R")
		if left!=null:
			left.visible=not (cutaway_close and view_yaw<0.0)
		if right!=null:
			right.visible=not (cutaway_close and view_yaw>0.0)

func apply_camera(delta: float) -> void:
	if follow_id != "" and world.residents.has(follow_id):
		var actor: Dictionary = world.residents[follow_id]
		var actor_level := int(actor.get("level",0))
		var actor_room := str(actor.get("room_id",""))
		if current_mode == "FOLLOW" and (semantic_view.level != actor_level or semantic_view.active_room != actor_room):
			semantic_view.set_view(world,"FOLLOW",actor_room,actor_level)
			selected_room = actor_room
			update_render_lod()
		var target_room: Dictionary = world.room_by_id(actor.get("room_id", ""))
		# Do not track private interior coordinates even when the owner can
		# enter that room. Public frontage is the only visible exception.
		var public_frontage:bool=world.allows_transit(target_room) and str(actor.get("phase",""))=="travel" and float(actor.get("z",0))>=1.35
		if world.public_cutaway_allowed(target_room) or public_frontage:
			var target := Vector3(float(actor.get("x", 0)),
				float(actor.get("visual_y", float(actor.get("level", 0))*H)) + 1.05,
				float(actor.get("z", 0)))
			var half_height: float = tan(deg_to_rad(BASE_FOV*0.5))*zoom_current
			var aspect: float = get_viewport().get_visible_rect().size.aspect()
			var deadzone_x: float = half_height * aspect * follow_deadzone_ratio
			var deadzone_y: float = half_height * follow_deadzone_ratio
			if absf(target.x - desired_focus.x) > deadzone_x:
				desired_focus.x = target.x - signf(target.x - desired_focus.x)*deadzone_x
			if absf(target.y - desired_focus.y) > deadzone_y:
				desired_focus.y = target.y - signf(target.y - desired_focus.y)*deadzone_y
		# The follow target may reach a private room, but camera will not cross its threshold.
	var bounds: Rect2 = camera_world_bounds()
	var edge_padding := Vector2(W*1.2,H*1.0)
	desired_focus.x = clampf(desired_focus.x,bounds.position.x-edge_padding.x,
		bounds.end.x+edge_padding.x)
	desired_focus.y = clampf(desired_focus.y,bounds.position.y-edge_padding.y,
		bounds.end.y+edge_padding.y)
	var k: float = 1.0 - exp(-4.0 * minf(delta,0.25))
	smooth_focus = smooth_focus.lerp(desired_focus,k)
	zoom_current = lerpf(zoom_current,zoom,1.0-exp(-4.6*minf(delta,0.25)))
	var view_fov:float=effective_camera_fov()
	camera.fov=view_fov
	var camera_distance:float=effective_camera_distance(view_fov)
	var view_yaw: float=effective_camera_yaw()
	var x_shift := sin(view_yaw) * camera_distance
	var z_shift := cos(view_yaw) * camera_distance
	var height_ratio:float=effective_camera_height_ratio()
	camera.global_position = smooth_focus + Vector3(
		x_shift,camera_distance*height_ratio,z_shift)
	camera.look_at(smooth_focus,Vector3.UP)
	update_cutaway_return_visibility()
	register_loaded_foregrounds()

func _refresh_guest_facades()->bool:
	if not architecture_review or room_root==null:return false
	var changed:=false
	for id in canonical_guest_nodes.keys():
		var node:Node3D=canonical_guest_nodes[id]
		if not is_instance_valid(node):continue
		var room:Dictionary=world.room_by_id(str(id))
		if room.is_empty():continue
		var closed:bool=not world.public_cutaway_allowed(room)
		if bool(node.get_meta("facade_only",false))==closed:continue
		_release_room_art(node)
		_release_furniture(node)
		room_root.remove_child(node)
		node.free()
		make_room(world.merged_group(int(room["x"]),int(room["level"])))
		changed=true
	return changed

func _update_roof_label(label:Label3D,group:Dictionary)->void:
	if label==null or not architecture_review or camera==null:return
	var at:Vector3=label.global_position
	if camera.is_position_behind(at):return
	var one:Vector2=camera.unproject_position(at)
	var up:Vector2=camera.unproject_position(at+Vector3.UP)
	var per_meter:float=maxf(1.0,one.distance_to(up))
	var span:float=float(group.get("width",1))*W
	var left:Vector2=camera.unproject_position(at-Vector3.RIGHT*span*0.45)
	var right:Vector2=camera.unproject_position(at+Vector3.RIGHT*span*0.45)
	var width_px:float=left.distance_to(right)
	var desired:float=12.0 if str(group.get("type","")) not in ["private","lift"] else 10.0
	var estimated_chars:float=maxf(1.0,float(label.text.length())*0.60)
	var target:float=minf(desired,width_px/estimated_chars)
	label.pixel_size=clampf(target/(float(label.font_size)*per_meter),0.0037,0.035)

func _refresh_conditional_dressing()->void:
	if not architecture_review:return
	var used:Dictionary={}
	for record in world.runtime_state.get("teea008_book_slot_assignments",{}).values():
		used[str(record.get("room_id",""))+"|"+str(record.get("slot_id",""))]=true
	# An incoming book owns its return support before it physically arrives.
	for key in life.media_runtime._book_return_reservations():used[key]=true
	for obj in world.objects.values():
		for pair in [["home_room_id","home_support_id"],["current_room_id","current_support_id"]]:
			var slot:String=str(obj.get(pair[1],""))
			if slot!="":used[str(obj.get(pair[0],""))+"|"+slot]=true
	for node in get_tree().get_nodes_in_group("canonical_conditional_dressing"):
		if node is Node3D:
			var key:String=str(node.get_meta("room_id",""))+"|"+str(node.get_meta("decor_slot_id",""))
			node.visible=not used.has(key)

# Bound costly mounted interiors, including legacy fallback furniture; shells and real
# overview models stay visible. Rank by physical camera focus, not actor AI.
func _canonical_detail_budget()->Dictionary:
	var candidates:Array=[]
	for node in room_root.get_children():
		var group:Dictionary=visual_room_groups.get(node.name,{})
		if group.is_empty() or node.get_node_or_null("LocalFurniture")==null or _group_facade_only(group) or not semantic_view.group_visible(group):continue
		if not _is_near_detail(node):continue
		var half_width:float=float(group.get("width",1))*W*0.5
		var dx:float=maxf(0.0,absf(node.position.x-smooth_focus.x)-half_width)
		var dy:float=absf(node.position.y+1.45-smooth_focus.y)
		# Prefer the focused floor; modest retention avoids boundary churn.
		var score:float=dx+dy*2.0+absf(node.position.x-smooth_focus.x)*0.03
		if detailed_room_groups.has(node.name):score-=0.20
		candidates.append({"id":str(node.name),"score":score})
	candidates.sort_custom(func(a,b):return str(a["id"])<str(b["id"]) if is_equal_approx(float(a["score"]),float(b["score"])) else float(a["score"])<float(b["score"]))
	var chosen:Dictionary={}
	for i in range(mini(2,candidates.size())):chosen[candidates[i]["id"]]=true
	return chosen

func update_render_lod() -> void:
	_refresh_guest_facades()
	var detail_budget:Dictionary=_canonical_detail_budget() if architecture_review else {}
	# Keep the inexpensive shell/cues visible at HOUSE scale. Detailed 3D depth,
	# rear alcoves, rich furniture and accepted full-resolution art are useful
	# only near the camera; rendering them across the whole house wastes draw
	# calls on geometry that is smaller than a few screen pixels.
	# The camera never activates an owner-private interior.
	for group_node in room_root.get_children():
		var group: Dictionary = visual_room_groups.get(group_node.name,{})
		var semantic_visible := not group.is_empty() and semantic_view.group_visible(group)
		group_node.visible = semantic_visible
		if not semantic_visible:
			_release_room_art(group_node)
			_release_furniture(group_node)
			continue
		var furniture: Node3D = group_node.get_node_or_null("LocalFurniture")
		var cues: Node3D = group_node.get_node_or_null("Layer_OverviewCues")
		if architecture_review and _group_facade_only(group):
			# Access can change after the scene was constructed. Never leave a
			# guest cutaway or its overview meshes exposed after door closure.
			_release_room_art(group_node)
			_release_furniture(group_node)
			if furniture!=null:furniture.visible=false
			if cues!=null:cues.visible=false
			var private_label:Label3D=group_node.get_node_or_null("RoomRoofLabel")
			if private_label!=null:
				private_label.visible=zoom_current>=25.0 and current_mode!="FOLLOW"
				_update_roof_label(private_label,group)
			continue
		# Real room art is part of the Fallout-Shelter cutaway at every zoom.
		# Camera proximity controls only heavier 3D/furniture detail. Manual FREE
		# navigation is equivalent to ROOM for detail materialization.
		if bool(group.get("has_art",false)):
			_load_room_art(group_node)
		else:
			_release_room_art(group_node)
		var near: bool = _is_near_detail(group_node) if furniture != null else false
		if architecture_review:
			near=detail_budget.has(str(group_node.name))
		if furniture != null:
			# Model-only furnishings are the room's visible art at all zooms.
			# Semantic visibility above still evicts inaccessible/offscreen groups.
			var show_furniture:bool=near or (not architecture_review and bool(group.get("native_decor",false)) and not bool(group.get("teea008_review",false)))
			if show_furniture:
				_populate_furniture(group_node)
			else:
				_release_furniture(group_node)
			furniture.visible=show_furniture
			if cues != null:
				cues.visible=not show_furniture and (bool(group.get("teea008_review",false)) or not art_loaded_groups.has(group_node.name))
		var cutaway_depth: Node3D = group_node.get_node_or_null(
			"Layer_Structure/Stage_CutawayDepth")
		if cutaway_depth != null:
			cutaway_depth.visible = near
		var rear_stage: Node3D = group_node.get_node_or_null(
			"Layer_Background/Stage_Backwall")
		if rear_stage != null:
			var art_layer: Node3D = group_node.get_node_or_null("Layer_ApprovedArt")
			var backdrop_loaded: bool = art_layer != null and (
				art_layer.get_node_or_null("Art_backdrop") != null)
			# The physical rear shell is cheap and is the room's architecture,
			# not close-range furniture. If a sparse photographic backdrop is
			# suppressed, the rear wall must remain visible in HOUSE/FREE too.
			rear_stage.visible = not backdrop_loaded
		var roof_label: Label3D = group_node.get_node_or_null("RoomRoofLabel")
		if roof_label != null:
			roof_label.visible = zoom_current >= 25.0 and current_mode != "FOLLOW"
			_update_roof_label(roof_label,group)
	_refresh_conditional_dressing()
	var micro_detail_visible: bool = zoom_current < 31.0
	for node in get_tree().get_nodes_in_group("low_end_micro_detail"):
		if node is Node3D:
			node.visible = micro_detail_visible

func _show_recovery_blocked()->void:
	if recovery_screen_visible:return
	recovery_screen_visible=true
	# No life setup, content import, camera or autosave on failed startup.
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if DisplayServer.get_name()=="headless":
		get_tree().quit(1)
		return
	var layer:=CanvasLayer.new()
	add_child(layer)
	var panel:=ColorRect.new()
	layer.add_child(panel)
	panel.color=Color("#19171e")
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center:=CenterContainer.new()
	panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var message:=Label.new()
	message.text="Дом не запущен: требуется восстановление сохранения.\nИсходные файлы сохранены. Не удаляйте их и не создавайте новый мир.\n\nКод: "+world.load_status+"\nЗакройте окно и восстановите проверенную резервную копию."
	message.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	message.custom_minimum_size=Vector2(480,0)
	var column:=VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	center.add_child(column)
	column.add_child(message)
	var exit_button:=Button.new()
	exit_button.text="Закрыть без новой записи"
	exit_button.pressed.connect(_request_shutdown)
	column.add_child(exit_button)

func _process(delta: float) -> void:
	if world.recovery_blocked:
		_show_recovery_blocked()
		return
	# The camera never chooses activities. Life is a separate simulation clock.
	# Candidate layouts are deliberately visual-only until measured stations and
	# actor footprint paths are bound. Do not simulate against stale furniture.
	if not teea008_review.enabled or teea008_live:
		life.tick(delta)
	# A save can also fail inside a life action. Never advance another tick
	# or reset the checkpoint deadline after an unsuccessful write.
	if not world.checkpoint_if_due():
		_show_recovery_blocked()
		return
	# The three guest facade transitions are cheap to check each frame.
	if _refresh_guest_facades():update_render_lod()
	# Seat projection must use the actual camera transform of this frame.
	apply_camera(delta)
	update_residents(delta)
	update_creatures(delta)
	update_physical_objects()
	if teea008_live:
		_update_physical_books()
	if Engine.get_process_frames() % 40 == 0:
		update_hud()
		update_render_lod()
		if teea008_review.enabled:
			_update_teea008_media_previews()
		if journal_open:
			update_journal()

func _request_shutdown()->void:
	# Window close and visible exit button share exactly one checkpoint path.
	if shutdown_requested:return
	shutdown_requested=true
	if not world.recovery_blocked and not world.save_world():
		shutdown_requested=false
		_show_recovery_blocked()
		return
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_shutdown()


func _activate_teea008_roster()->void:
	# Separate live-review save only. A validated technical sprite bank is
	# sufficient for a QA actor, not for production autonomy approval.
	if bool(world.runtime_state.get("teea008_full_roster_initialized",false)):
		return
	var nav=life.candidate_navigation
	var active:Dictionary={}
	for actor in world.residents.values():
		if not bool(actor.get("active",false)):
			continue
		var rid:String=str(actor.get("room_id",""))
		var room:Dictionary=world.room_by_id(rid)
		if room.is_empty():
			continue
		var center:Vector3=world.room_center_pos(room)
		if not active.has(rid):
			active[rid]=[]
		active[rid].append(Vector2(float(actor.get("x",center.x))-center.x,float(actor.get("z",0.0))))
	for profile in world.read_resident_profiles():
		var id:String=str(profile["id"])
		var actor:Dictionary=world.residents.get(id,{})
		if actor.is_empty() or bool(actor.get("active",false)):
			continue
		var wardrobe:String=asset_banks.preferred_wardrobe(id,str(actor.get("appearance_profile","")),true)
		if wardrobe=="":
			continue
		var best_room:Dictionary={}
		var best_point:=Vector2.ZERO
		var best_score:=INF
		for room in world.rooms:
			var kind:String=str(room.get("type",""))
			if not world.public_cutaway_allowed(room) or kind in ["guest","corridor","lift"] or not nav.has_layout(room):
				continue
			var rid:String=str(room["id"])
			var used:Array=active.get(rid,[])
			var points:Array=nav.candidate_spots(room)
			var score:float=float(used.size())/float(maxi(1,points.size()))
			if score>=best_score:
				continue
			for spot in points:
				var point:Vector2=spot["offset"]
				if used.any(func(p):return point.distance_to(p)<0.65):
					continue
				best_room=room
				best_point=point
				best_score=score
				break
		if best_room.is_empty():
			continue
		var rid:String=str(best_room["id"])
		var center:Vector3=world.room_center_pos(best_room)
		if not active.has(rid):
			active[rid]=[]
		active[rid].append(best_point)
		actor.merge({"active":true,"room_id":rid,"x":center.x+best_point.x,
			"level":int(best_room["level"]),"visual_y":center.y,"z":best_point.y,
			"intent":"PURPOSEFUL_EXPLORE","phase":"idle","until":world.sim_clock,
			"needs":{"rest":0.5,"social":0.4,"curiosity":0.5},
			"traits":{"reading":0.45,"music":0.35},"habits":{},"last_location":"",
			"route":[],"path_index":0,"autonomy_enabled":true,
			"production_visual_ready":false,"visual_status":"CANDIDATE_LIVE_REVIEW"},true)
		world._append_journal("TEEA008_REVIEW_ACTOR_ACTIVATED",id,id,"",rid,{"wardrobe":wardrobe,"owner_approved":false})
	world.runtime_state["teea008_full_roster_initialized"]=true

func _assign_teea008_media(room_id:String,surface_id:String,category:String,item_id:String)->void:
	if not teea008_review.enabled or not teea008_media_bindings.assign(room_id,surface_id,category,item_id):
		notice.text="Назначение не выполнено: несовместимый держатель или недоступный контент"
		return
	world.save_world()
	_update_teea008_media_previews()
	notice.text="Держатель обновлён: "+surface_id

func _update_teea008_media_previews()->void:
	if content_viewer==null:
		return
	for anchor in get_tree().get_nodes_in_group("teea008_media_surface"):
		if not is_instance_valid(anchor) or not anchor.is_visible_in_tree():
			continue
		var room_id:String=str(anchor.get_meta("room_id",""))
		var surface_id:String=str(anchor.get_meta("surface_id",""))
		if bool(anchor.get_meta("carrier_hit_only",false)):
			var obsolete:Node3D=anchor.get_node_or_null("BoundPreview")
			if obsolete!=null:obsolete.free()
			continue
		var item:Dictionary=teea008_media_bindings.resolve(room_id,surface_id)
		var path:String=str(item.get("preview",item.get("preview_path","")))
		if str(anchor.get_meta("preview_source",""))==path:
			continue
		anchor.set_meta("preview_source",path)
		var panel:MeshInstance3D=anchor.get_node_or_null("BoundPreview")
		if panel!=null:
			panel.free()
		var texture:Texture2D=content_viewer._load_preview(path)
		if texture==null:
			continue
		var size:Vector2=anchor.get_meta("surface_size",Vector2.ZERO)
		var fit:float=minf(size.x/float(texture.get_width()),size.y/float(texture.get_height()))
		var quad:=QuadMesh.new()
		quad.size=Vector2(texture.get_width(),texture.get_height())*fit*0.98
		var material:=StandardMaterial3D.new()
		material.albedo_texture=texture
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		var mesh:=MeshInstance3D.new()
		mesh.name="BoundPreview"
		mesh.mesh=quad
		mesh.material_override=material
		mesh.position.z=0.003
		anchor.add_child(mesh)

func _create_physical_book(book:Dictionary)->Node3D:
	var node:=Node3D.new()
	node.name="Book_"+str(book["id"]).validate_node_name()
	book_root.add_child(node)
	var volume:=BoxMesh.new()
	volume.size=Vector3(0.16,0.18,0.045)
	var body:=MeshInstance3D.new()
	body.mesh=volume
	body.position.y=0.09
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("#594238")
	body.material_override=mat
	node.add_child(body)
	var path:String=str(book.get("preview",book.get("preview_path","")))
	var tex:Texture2D=content_viewer._load_preview(path) if content_viewer!=null else null
	if tex!=null:
		var quad:=QuadMesh.new()
		var fit:float=minf(0.16/float(tex.get_width()),0.18/float(tex.get_height()))
		quad.size=Vector2(tex.get_width(),tex.get_height())*fit
		var cover:=MeshInstance3D.new()
		cover.mesh=quad
		cover.position=Vector3(0,0.09,0.023)
		var cover_mat:=StandardMaterial3D.new()
		cover_mat.albedo_texture=tex
		cover.material_override=cover_mat
		node.add_child(cover)
	for child in node.get_children():child.set_meta("closed_book_geometry",true)
	return node

# A rendering-only variant of the same physical book, never a second copy.
# The spine stays at the same calibrated centre used by the closed volume.
func _set_book_open(node:Node3D,opened:bool)->void:
	var pages:Node3D=node.get_node_or_null("OpenBook")
	if opened and pages==null:
		pages=Node3D.new()
		pages.name="OpenBook"
		node.add_child(pages)
		var cover_mat:=StandardMaterial3D.new()
		cover_mat.albedo_color=Color("#594238")
		var paper_mat:=StandardMaterial3D.new()
		paper_mat.albedo_color=Color("#e4d9ba")
		var edge_mat:=StandardMaterial3D.new()
		edge_mat.albedo_color=Color("#a69678")
		for side in [-1,1]:
			var leaf:=Node3D.new()
			leaf.position.y=0.09
			leaf.rotation.z=0.0
			leaf.rotation.y=float(side)*0.15
			pages.add_child(leaf)
			var cover:=MeshInstance3D.new()
			var cover_box:=BoxMesh.new()
			cover_box.size=Vector3(0.125,0.185,0.008)
			cover.mesh=cover_box
			cover.material_override=cover_mat
			cover.position=Vector3(float(side)*0.0625,0,-0.008)
			leaf.add_child(cover)
			var paper:=MeshInstance3D.new()
			var paper_box:=BoxMesh.new()
			paper_box.size=Vector3(0.114,0.172,0.012)
			paper.mesh=paper_box
			paper.material_override=paper_mat
			paper.position=Vector3(float(side)*0.061,0,0.004)
			leaf.add_child(paper)
			var line:=MeshInstance3D.new()
			var line_box:=BoxMesh.new()
			line_box.size=Vector3(0.003,0.168,0.001)
			line.mesh=line_box
			line.material_override=edge_mat
			line.position=Vector3(float(side)*0.006,0,0.0105)
			leaf.add_child(line)
	for child in node.get_children():
		if child.has_meta("closed_book_geometry"):child.visible=not opened
	if pages!=null:pages.visible=opened
	node.set_meta("book_open",opened)

func _update_physical_books()->void:
	if book_root==null:return
	var visible_ids:Dictionary={}
	for book in world.media.get("books",[]):
		if not bool(book.get("physical",true)):continue
		var id:String=str(book["id"])
		var slot:Dictionary=life.media_runtime.book_slot(id)
		var holder_id:String=str(book.get("holder_id",""))
		# Possession is authoritative even if a shelf assignment needs repair.
		if slot.is_empty() and holder_id=="":continue
		var room:Dictionary={}
		var position_value:=Vector3.ZERO
		var scale_value:=1.0
		if holder_id!="":
			var actor:Dictionary=world.residents.get(holder_id,{})
			room=world.room_by_id(str(actor.get("room_id","")))
			if actor.is_empty() or not semantic_view.actor_visible(actor) or not world.public_cutaway_allowed(room):continue
			# Only an actually rendered, calibrated pose with a baked book may hide the physical volume.
			var contact:Dictionary=_active_station_render_contact(actor)
			if str(contact.get("state",""))=="READ" and bool(contact.get("book_baked",false)) and str(actor_animations.get(holder_id,{}).get("state",""))=="READ":continue
			var z:float=float(actor.get("z",0))
			scale_value=depth_visual_scale(z)
			position_value=Vector3(depth_visual_x(str(room["id"]),float(actor["x"]),z)+0.20*scale_value,float(actor.get("visual_y",0))+0.90*scale_value,z+0.14)
		else:
			if str(book.get("location_room_id",""))!=str(slot["room_id"]):continue
			room=world.room_by_id(str(slot["room_id"]))
			if not world.public_cutaway_allowed(room):continue
			if not detailed_room_groups.has(str(room["id"])):continue
			var pos:Array=slot["xyz"]
			var inst:Array=slot["instance_xyz"]
			var center:Vector3=world.room_center_pos(room)
			scale_value=depth_visual_scale(float(inst[2]))
			position_value=Vector3(center.x+float(pos[0])*scale_value,center.y+float(inst[1])+(float(pos[1])-float(inst[1]))*scale_value,float(inst[2])+(float(pos[2])-float(inst[2]))*scale_value)
		var node:Node3D=book_nodes.get(id)
		if not is_instance_valid(node):
			node=_create_physical_book(book)
			book_nodes[id]=node
		node.rotation=Vector3.ZERO
		node.position=position_value
		node.scale=Vector3.ONE*scale_value
		node.set_meta("hand_contact_status","SHELF" if holder_id=="" else "UNCALIBRATED")
		if holder_id!="":_place_book_at_verified_hand(node,world.residents[holder_id])
		_set_book_open(node,str(node.get_meta("hand_contact_status",""))=="READ_FRAME_MARKED")
		node.visible=true
		visible_ids[id]=true
	for id in book_nodes.keys():
		if not visible_ids.has(id):
			book_nodes[id].visible=false
			book_nodes[id].queue_free()
			book_nodes.erase(id)

func _place_teea008_artifact(room_id:String,surface_id:String,item_id:String)->void:
	if not teea008_live:return
	var obj:Dictionary=world.physical_object(item_id)
	var node:Node3D=object_nodes.get(item_id)
	if obj.is_empty() or not is_instance_valid(node):
		notice.text="Предмет не доступен"
		return
	var sprite:Sprite3D=node.get_node_or_null("Visual")
	# Do not infer physical size from missing images or invent a support fit.
	if not node.has_meta("artifact_cube_side") and (sprite==null or sprite.texture==null):
		notice.text="Нет измеряемого изображения предмета"
		return
	var height:float=float(obj.get("display_world_height",0.48))
	var width:float=height
	if sprite!=null and sprite.texture!=null:width=height*float(sprite.texture.get_width())/maxf(1.0,float(sprite.texture.get_height()))
	var depth:float=0.04
	if node.has_meta("artifact_cube_side"):
		width=ARTIFACT_CUBE_SIDE
		height=ARTIFACT_CUBE_SIDE
		depth=ARTIFACT_CUBE_SIDE
	if not teea008_media_bindings.place_artifact(room_id,surface_id,item_id,life.candidate_navigation,width,height,depth):
		notice.text="Нет свободной совместимой опоры для этого предмета"
		return
	world.save_world()
	life.refresh_changed_station_claims()
	update_physical_objects()
	_refresh_conditional_dressing()
	_update_teea008_media_previews()
	notice.text="Дом предмета назначен на измеренной опоре"

func _seat_render_projection(contact:Vector3,front_z:float,base_scale:float)->Dictionary:
	if camera==null or not camera.is_inside_tree():
		return {"position":contact,"scale":base_scale}
	var origin:Vector3=camera.global_position
	var target_z:float=front_z+0.035
	var depth:float=origin.z-contact.z
	if depth<=0.1 or target_z<=contact.z or target_z>=origin.z-0.1:
		return {"position":contact,"scale":base_scale}
	var ratio:float=(origin.z-target_z)/depth
	return {"position":origin+(contact-origin)*ratio,"scale":base_scale*ratio}

func _place_book_at_verified_hand(node:Node3D,actor:Dictionary)->bool:
	var id:String=str(actor.get("id",""))
	var anim:Dictionary=actor_animations.get(id,{})
	var state:String=str(anim.get("state",""))
	if life.candidate_navigation==null or int(anim.get("frame",-1))!=0:return false
	var profile:Dictionary={}
	var point:Array=[]
	if state=="READ":
		if _active_station_render_contact(actor).is_empty():return false
		profile=life.candidate_navigation.pose_profile(actor,state)
		point=profile.get("book_px",[])
	elif state=="IDLE_S":
		profile=life.candidate_navigation.hand_contact(actor,state,0)
		point=profile.get("hand_px",[])
	if point.size()!=2 or not _calibrated_frame_matches(actor,state,profile):return false
	var actor_node:Node3D=actor_sprites.get(id)
	if not is_instance_valid(actor_node) or not actor_node.is_visible_in_tree():return false
	var sprite:Sprite3D=actor_node.get_node_or_null("Body")
	var canvas:Array=profile.get("canvas",[])
	if sprite==null or sprite.texture==null or canvas.size()!=2 or sprite.texture.get_width()!=int(canvas[0]) or sprite.texture.get_height()!=int(canvas[1]):return false
	var facing:Vector3=_sprite_camera_right().cross(Vector3.UP).normalized()
	var scale_value:float=actor_node.scale.x
	var basis_value:=Basis(Vector3.UP,atan2(facing.x,facing.z))
	if state=="READ":basis_value=basis_value*Basis(Vector3.RIGHT,-PI/3.0)
	basis_value=basis_value.scaled(Vector3.ONE*scale_value)
	var target:Vector3=_sprite_pixel_world(actor_node,sprite,point)+facing*0.035*scale_value
	# Physical book mesh has its centre 0.09m above its base pivot.
	node.global_transform=Transform3D(basis_value,target-basis_value*Vector3(0,0.09,0))
	node.set_meta("hand_contact_status","READ_FRAME_MARKED" if state=="READ" else "IDLE_FRAME_MARKED")
	node.set_meta("hand_contact_target",target)
	return true

func _place_cup_at_verified_hand(anchor:Node3D,holder:Dictionary)->bool:
	var id:String=str(holder.get("id",""))
	var animation:Dictionary=actor_animations.get(id,{})
	if life.candidate_navigation==null or camera==null:return false
	var contact:Dictionary=life.candidate_navigation.hand_contact(holder,str(animation.get("state","")),int(animation.get("frame",-1)))
	if contact.is_empty() or not _calibrated_frame_matches(holder,"IDLE_S",contact):return false
	var actor_node:Node3D=actor_sprites.get(id)
	if not is_instance_valid(actor_node) or not actor_node.is_visible_in_tree():return false
	var sprite:Sprite3D=actor_node.get_node_or_null("Body")
	var pickup:Node3D=anchor.find_child("PICKUP_ANCHOR",true,false)
	if sprite==null or sprite.texture==null or pickup==null:return false
	var canvas:Array=contact["canvas"]
	if sprite.texture.get_width()!=int(canvas[0]) or sprite.texture.get_height()!=int(canvas[1]):return false
	var px:Array=contact["hand_px"]
	# Fixed-Y billboard uses the camera's horizontal right axis. Project the
	# marked source pixel into the rendered sprite plane, not a generic hip.
	var right:Vector3=camera.global_transform.basis.x
	right.y=0
	right=right.normalized()
	if right.length_squared()<0.99:return false
	var facing:Vector3=right.cross(Vector3.UP).normalized()
	var scale_value:float=actor_node.scale.x
	var meters_per_pixel:float=sprite.pixel_size*scale_value
	var hand:Vector3=sprite.global_position+right*(float(px[0])-float(canvas[0])*0.5)*meters_per_pixel+Vector3.UP*(float(canvas[1])*0.5-float(px[1]))*meters_per_pixel
	var marker:Vector3=anchor.to_local(pickup.global_position)
	var angle:float=atan2(facing.x,facing.z)+(PI if str(contact.get("side",""))=="right" else 0.0)
	var cup_basis:=Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_value)
	# A small camera-facing offset keeps the handle out of the flat sprite.
	var target:Vector3=hand+facing*0.035*scale_value
	anchor.global_transform=Transform3D(cup_basis,target-cup_basis*marker)
	anchor.set_meta("hand_contact_status","IDLE_FRAME_MARKED")
	anchor.set_meta("hand_contact_target",target)
	return true

func _open_drink_qa()->void:
	var actor_id:String=follow_id
	var actor:Dictionary=world.residents.get(actor_id,{})
	var beverage=life.candidate_cups.beverages
	if actor.is_empty() or actor_id=="MANJKA" or not beverage.enabled:
		notice.text="Для QA напитков выбери сестру или гостя и включи слежение"
		return
	var window:=Window.new()
	window.title="QA напитков · "+str(actor.get("name",actor_id))
	window.size=Vector2i(800,580)
	window.transient=true
	window.exclusive=true
	add_child(window)
	window.close_requested.connect(window.queue_free)
	var column:=VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window.add_child(column)
	var context:=OptionButton.new()
	context.add_item("Контекст: автоматически")
	context.set_item_metadata(0,"")
	for key in beverage.config["weights"]:
		context.add_item(str(key))
		context.set_item_metadata(context.item_count-1,str(key))
		if str(beverage.forced_contexts.get(actor_id,""))==str(key):context.select(context.item_count-1)
	context.item_selected.connect(func(i):
		var value:String=str(context.get_item_metadata(i))
		if value=="":beverage.forced_contexts.erase(actor_id)
		else:beverage.forced_contexts[actor_id]=value)
	column.add_child(context)
	var drink:=OptionButton.new()
	drink.add_item("Напиток: автоматически")
	drink.set_item_metadata(0,"")
	for row in beverage.entries:
		drink.add_item(str(row["display_name_ru"]))
		drink.set_item_metadata(drink.item_count-1,str(row["drink_id"]))
		if str(beverage.forced_drinks.get(actor_id,""))==str(row["drink_id"]):drink.select(drink.item_count-1)
	drink.item_selected.connect(func(i):
		var value:String=str(drink.get_item_metadata(i))
		if value=="":beverage.forced_drinks.erase(actor_id)
		else:beverage.forced_drinks[actor_id]=value)
	column.add_child(drink)
	var report:=RichTextLabel.new()
	report.bbcode_enabled=false
	report.size_flags_vertical=Control.SIZE_EXPAND_FILL
	report.text=beverage.summary(actor_id)
	column.add_child(report)
	var actions:=HBoxContainer.new()
	column.add_child(actions)
	var refresh:=Button.new()
	refresh.text="Обновить"
	refresh.pressed.connect(func():report.text=beverage.summary(actor_id))
	actions.add_child(refresh)
	var simulation:=Button.new()
	simulation.text="1000 выборов"
	simulation.pressed.connect(func():
		var value:String=str(context.get_item_metadata(context.selected))
		report.text=beverage.simulate(actor_id,value if value!="" else "GENERIC"))
	actions.add_child(simulation)
	var empty:=Button.new()
	empty.text="Опустошить её чашки"
	empty.pressed.connect(func():
		for cid in world.runtime_state.get("beverages",{}).get("cups",{}):
			if str(beverage.content(str(cid)).get("consumer_id",""))==actor_id:beverage.empty_cup(str(cid))
		world.save_world()
		report.text=beverage.summary(actor_id))
	actions.add_child(empty)
	var reset:=Button.new()
	reset.text="Сбросить историю"
	reset.pressed.connect(func():
		beverage.reset_history(actor_id)
		world.save_world()
		report.text=beverage.summary(actor_id))
	actions.add_child(reset)
	window.popup_centered()
