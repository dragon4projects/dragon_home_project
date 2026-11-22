extends SceneTree
## This test MUST run only after checkout with actual Git LFS bytes.
const W = preload("res://scripts/world_model.gd")
const R = preload("res://scripts/asset_bank_resolver.gd")
const M = preload("res://scripts/media_runtime.gd")

func _initialize() -> void:
	var resolver = R.new()
	assert(resolver.initialize(), "Normalized 1.4 MB registry must exist")
	var world = W.new()
	world.save_path = "user://test_lfs_registry_integration.json"
	world.seed_world()
	var profiles: Array = world.read_resident_profiles()
	assert(profiles.size()==24)
	assert(resolver.preview_count(profiles)==21, "21/24 technical banks must resolve real LFS files")
	assert(resolver.accepted_count(profiles)==0, "Nobody is silently artist-approved")
	assert(resolver.preferred_wardrobe("RES_05","HELGA_08",true)=="SHORT")
	assert(resolver.preferred_wardrobe("RES_08","HELGA_07",true)=="CITY")
	assert(resolver.preferred_wardrobe("RES_07","EXISTING_EVMOCHKA",true)=="HOME")
	assert(resolver.preferred_wardrobe("RES_22","LISA_03",true)=="")
	assert(resolver.manka_frame_count("WALK_LEFT")==4)
	assert(resolver.manka_frame_count("WALK_RIGHT")==4)
	assert(resolver.manka_texture("WALK_LEFT",0)!=null)
	assert(resolver.manka_texture("REST",0)!=null)
	var props := ["CUBE_LETTERS","POSTER_SHURSHUN","PHOTO_MOON","PORTRAIT_SHURS",
		"MUG_BLUE_A","MUG_BLUE_B","MUG_RED_A","MUG_RED_B"]
	for prop_id in props:
		assert(resolver.prop_master_path(prop_id)!="")
		assert(resolver.prop_display_texture(prop_id)!=null)
	var catalog: Array = resolver.manifest.get("media_previews",{}).get("books",[])
	assert(catalog.size()==76)
	var imported := world.merge_reference_book_metadata(catalog)
	assert(imported==76)
	assert(world.media["books"].size()==76)
	assert(world.merge_reference_book_metadata(catalog)==0, "import is idempotent")
	var media = M.new()
	media.setup(world)
	assert(media.available_books().is_empty(), "metadata ≠ physical books")
	assert(not media.borrow("RES_01",catalog[0]["id"]), "Can't borrow cloud metadata")
	var loaded = W.new()
	loaded.save_path = world.save_path
	loaded.load_or_seed()
	assert(loaded.media["books"].size()==76, "catalog persists")
	for suffix in ["",".bak",".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(world.save_path+suffix))
	print("LFS_REGISTRY_INTEGRATION_PASS candidates=21 Manka=7 props=8 books=76 physical=0 approved=0")
	quit(0)

